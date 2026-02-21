import { generateText } from "ai";
import { NextRequest, NextResponse } from "next/server";
import { GameState, Slot } from "@/lib/data";

const SLOT_COUNT = 3;

const SYSTEM_PROMPT = `You are the narrator of fates. People sit before you for a tarot reading. Whatever you write becomes real — these are not predictions, they are events that will happen.

You will receive a JSON object with:
- "reading": the current client and three reading slots (slot 0, 1, 2) filled in order.
- "context": full encounter/game-state context that may help narrative continuity.

Exactly one slot in reading.slots will have a card but no text. Write text for that slot only.

## Rules

- Write in second person ("you")
- One to two sentences only
- Be specific. Names, places, moments. No metaphors. No abstractions. No poetic language.
- These events WILL happen to this person. Write them as facts.
- If other slots already have text, continue that narrative coherently
- Never contradict or undo what earlier slots established
- Do not acknowledge that you are an AI, a game, or a narrator

Return ONLY the text for the empty slot. No JSON. No quotes. No commentary. Just the sentence.`;

type JsonRecord = Record<string, unknown>;

interface NormalizedReadingRequest {
  client: GameState["client"];
  slots: Slot[];
  gameState?: JsonRecord;
  activeEncounterIndex?: number;
  encounterStory?: string;
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function asString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function asNonEmptyString(value: unknown): string | null {
  const parsed = asString(value);
  if (parsed === null) {
    return null;
  }
  const trimmed = parsed.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function asInteger(value: unknown): number | null {
  return typeof value === "number" && Number.isInteger(value) ? value : null;
}

function normalizeCardName(cardName: string): string {
  return cardName.replace(/_/g, " ").trim();
}

function normalizeSlot(input: unknown, index: number): Slot {
  const slotRecord = isRecord(input) ? input : {};

  const rawCard = asNonEmptyString(slotRecord.card);
  const rawText = asNonEmptyString(slotRecord.text);

  return {
    index,
    card: rawCard ? normalizeCardName(rawCard) : null,
    text: rawText ?? null,
  };
}

function normalizeFromDirectPayload(raw: JsonRecord): NormalizedReadingRequest | null {
  const clientRecord = isRecord(raw.client) ? raw.client : null;
  const slotInputs = asArray(raw.slots);
  if (clientRecord === null || slotInputs.length === 0) {
    return null;
  }

  const name = asNonEmptyString(clientRecord.name);
  const situation = asNonEmptyString(clientRecord.situation);
  if (name === null || situation === null) {
    return null;
  }

  const client: GameState["client"] = { name, situation };
  if (typeof clientRecord.age === "number" && Number.isFinite(clientRecord.age)) {
    client.age = clientRecord.age;
  }

  const slots = Array.from({ length: SLOT_COUNT }, (_, i) => normalizeSlot(slotInputs[i], i));
  return { client, slots };
}

function normalizeFromGamePayload(raw: JsonRecord): NormalizedReadingRequest | null {
  const gameState = isRecord(raw.game_state) ? raw.game_state : null;
  if (gameState === null) {
    return null;
  }

  const encounters = asArray(gameState.encounters);
  if (encounters.length === 0) {
    return null;
  }

  const requestedIndex = asInteger(raw.active_encounter_index) ?? 0;
  const activeEncounterIndex = Math.min(
    Math.max(requestedIndex, 0),
    encounters.length - 1
  );

  const encounter = isRecord(encounters[activeEncounterIndex])
    ? encounters[activeEncounterIndex]
    : null;
  if (encounter === null) {
    return null;
  }

  const encounterClient = isRecord(encounter.client) ? encounter.client : null;
  const name = encounterClient ? asNonEmptyString(encounterClient.name) : null;
  const situation = encounterClient
    ? asNonEmptyString(encounterClient.context) ??
      asNonEmptyString(encounterClient.situation)
    : null;
  if (name === null || situation === null) {
    return null;
  }

  const runtimeState = isRecord(raw.runtime_state) ? raw.runtime_state : {};
  const runtimeCards = asArray(runtimeState.slot_cards);
  const runtimeTexts = asArray(runtimeState.slot_texts);
  const encounterSlots = asArray(encounter.slots);

  const slots = Array.from({ length: SLOT_COUNT }, (_, index) => {
    const hasRuntimeCard = runtimeCards[index] !== undefined;
    const hasRuntimeText = runtimeTexts[index] !== undefined;

    if (hasRuntimeCard || hasRuntimeText) {
      const runtimeCardName = asNonEmptyString(runtimeCards[index]);
      const runtimeText = asNonEmptyString(runtimeTexts[index]);
      return {
        index,
        card: runtimeCardName ? normalizeCardName(runtimeCardName) : null,
        text: runtimeText ?? null,
      };
    }

    const normalized = normalizeSlot(encounterSlots[index], index);
    return {
      index,
      card: normalized.card ?? null,
      text: normalized.text ?? null,
    };
  });

  return {
    client: { name, situation },
    slots,
    gameState,
    activeEncounterIndex,
    encounterStory: asString(encounter.story) ?? undefined,
  };
}

function normalizeRequestPayload(body: unknown): NormalizedReadingRequest | null {
  if (!isRecord(body)) {
    return null;
  }

  const fromGamePayload = normalizeFromGamePayload(body);
  if (fromGamePayload) {
    return fromGamePayload;
  }

  return normalizeFromDirectPayload(body);
}

function buildPromptPayload(request: NormalizedReadingRequest): string {
  const payload: JsonRecord = {
    reading: {
      client: request.client,
      slots: request.slots,
    },
  };

  const context: JsonRecord = {};
  if (request.gameState) {
    context.game_state = request.gameState;
  }
  if (typeof request.activeEncounterIndex === "number") {
    context.active_encounter_index = request.activeEncounterIndex;
  }
  if (request.encounterStory) {
    context.encounter_story = request.encounterStory;
  }

  if (Object.keys(context).length > 0) {
    payload.context = context;
  }

  return JSON.stringify(payload, null, 2);
}

function buildUpdatedGameState(
  request: NormalizedReadingRequest,
  updatedSlots: Slot[]
): JsonRecord | null {
  if (!request.gameState) {
    return null;
  }

  const nextGameState = structuredClone(request.gameState) as JsonRecord;
  const encounters = asArray(nextGameState.encounters);
  if (
    typeof request.activeEncounterIndex !== "number" ||
    request.activeEncounterIndex < 0 ||
    request.activeEncounterIndex >= encounters.length
  ) {
    return nextGameState;
  }

  const encounterValue = encounters[request.activeEncounterIndex];
  if (!isRecord(encounterValue)) {
    return nextGameState;
  }

  encounterValue.slots = updatedSlots.map((slot) => ({
    card: slot.card ?? "",
    text: slot.text ?? "",
  }));
  encounters[request.activeEncounterIndex] = encounterValue;
  nextGameState.encounters = encounters;
  return nextGameState;
}

export async function POST(request: NextRequest) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const normalized = normalizeRequestPayload(body);
  if (!normalized) {
    return NextResponse.json(
      {
        error:
          "Invalid request body. Send either { client, slots } or { game_state, active_encounter_index, runtime_state }.",
      },
      { status: 400 }
    );
  }

  if (!normalized.client.situation) {
    return NextResponse.json(
      { error: "client.situation is required" },
      { status: 400 }
    );
  }

  const targetIndex = normalized.slots.findIndex(
    (s) => s.card && (s.text === null || s.text === undefined || s.text === "")
  );

  if (targetIndex === -1) {
    return NextResponse.json(
      { error: "No target slot found. One slot must have a card with no text." },
      { status: 400 }
    );
  }

  let generated: string;
  try {
    const result = await generateText({
      model: "anthropic/claude-haiku-4.5",
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: buildPromptPayload(normalized) }],
      maxOutputTokens: 150,
    });
    generated = result.text.trim();
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json(
      { error: "Generation failed", detail: message },
      { status: 502 }
    );
  }

  const updatedSlots = normalized.slots.map((slot, i) =>
    i === targetIndex ? { ...slot, text: generated } : slot
  );
  const updatedGameState = buildUpdatedGameState(normalized, updatedSlots);

  return NextResponse.json({
    client: normalized.client,
    slots: updatedSlots,
    generated,
    filled_slot: targetIndex,
    game_state: updatedGameState,
    active_encounter_index: normalized.activeEncounterIndex ?? null,
  });
}
