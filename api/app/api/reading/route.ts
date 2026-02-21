import { generateText } from "ai";
import { NextRequest, NextResponse } from "next/server";
import { CardDef, GameState, Slot, loadCards } from "@/lib/data";

const SLOT_COUNT = 3;

const SYSTEM_PROMPT = `You are an oracle in a port town. The cards show what will happen — not metaphors, not advice, but events that are already in motion.

You'll receive a client (who they are, what brought them here) and three reading slots. Exactly one slot has a card placed but no text yet. Write one sentence for that slot.

## Voice
- Second person ("you")
- One sentence. Short enough to read at a glance.
- Concrete and specific: a person's name, a street, an object, a time of day. No abstractions, no metaphors, no poetic flourishes
- These events WILL happen. Write them as settled fact.
- Slightly oblique — the event is clear, but its full meaning may not be obvious yet

## Using the Card
A reversed card means the energy is blocked, inverted, or arrives unwanted. The event still happens — it just cuts differently.

## Slot Positions
- Slot 0: Something arrives or is discovered
- Slot 1: Something shifts or complicates
- Slot 2: Where it leads — a door opens or closes
If earlier slots have text, continue from them. Never contradict what's established.

## Echoes Across Readings
If previous readings from other clients are included, you may OCCASIONALLY reuse a specific detail from an earlier reading — the same street name, object, time of day, or person's name — woven naturally into THIS client's event. Do this rarely (at most once per full reading, and not every reading). Never explain the connection. Never call attention to it. The player notices, or they don't.

Return ONLY the sentence. No JSON. No quotes. No commentary. It should be short and direct enough to fit on a small slip of paper.`;

const cardsByName = buildCardLookup();

function buildCardLookup(): Map<string, CardDef> {
  const lookup = new Map<string, CardDef>();
  try {
    for (const card of loadCards()) {
      lookup.set(card.name, card);
      lookup.set(card.name.replace(/_/g, " "), card);
    }
  } catch {
    // Card data unavailable — readings will work without metadata
  }
  return lookup;
}

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

function normalizeOrientation(value: unknown): "upright" | "reversed" | null {
  const str = asNonEmptyString(value);
  if (str === "reversed") return "reversed";
  if (str === "upright") return "upright";
  return null;
}

function normalizeSlot(input: unknown, index: number): Slot {
  const slotRecord = isRecord(input) ? input : {};

  const rawCard = asNonEmptyString(slotRecord.card);
  const rawText = asNonEmptyString(slotRecord.text);
  const orientation = normalizeOrientation(slotRecord.orientation);

  return {
    index,
    card: rawCard ? normalizeCardName(rawCard) : null,
    text: rawText ?? null,
    orientation,
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
  const runtimeOrientations = asArray(runtimeState.slot_orientations);
  const encounterSlots = asArray(encounter.slots);

  const slots = Array.from({ length: SLOT_COUNT }, (_, index) => {
    const hasRuntimeCard = runtimeCards[index] !== undefined;
    const hasRuntimeText = runtimeTexts[index] !== undefined;

    if (hasRuntimeCard || hasRuntimeText) {
      const runtimeCardName = asNonEmptyString(runtimeCards[index]);
      const runtimeText = asNonEmptyString(runtimeTexts[index]);
      const orientation = normalizeOrientation(runtimeOrientations[index]);
      return {
        index,
        card: runtimeCardName ? normalizeCardName(runtimeCardName) : null,
        text: runtimeText ?? null,
        orientation,
      };
    }

    const normalized = normalizeSlot(encounterSlots[index], index);
    return {
      index,
      card: normalized.card ?? null,
      text: normalized.text ?? null,
      orientation: normalized.orientation ?? null,
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

interface EnrichedSlot {
  index: number;
  card: string | null;
  text: string | null;
  orientation: string | null;
  card_meaning?: string;
  card_tags?: string[];
  card_outcome?: string;
}

function enrichSlotWithCardData(slot: Slot): EnrichedSlot {
  const enriched: EnrichedSlot = {
    index: slot.index,
    card: slot.card ?? null,
    text: slot.text ?? null,
    orientation: slot.orientation ?? null,
  };

  if (!slot.card) return enriched;

  const cardDef = cardsByName.get(slot.card) ?? cardsByName.get(slot.card.replace(/ /g, "_"));
  if (cardDef) {
    if (cardDef.description) enriched.card_meaning = cardDef.description;
    if (cardDef.keywords?.length) enriched.card_tags = cardDef.keywords;
    else if (cardDef.tags?.length) enriched.card_tags = cardDef.tags as string[];
    if (cardDef.sentiment) enriched.card_outcome = cardDef.sentiment;
  }

  return enriched;
}

interface PreviousReading {
  client: string;
  readings: string[];
}

function extractPreviousReadings(request: NormalizedReadingRequest): PreviousReading[] {
  if (!request.gameState || typeof request.activeEncounterIndex !== "number") {
    return [];
  }

  const encounters = asArray(request.gameState.encounters);
  const previous: PreviousReading[] = [];

  const startIndex = Math.max(0, request.activeEncounterIndex - 3);
  for (let i = startIndex; i < request.activeEncounterIndex; i++) {
    const enc = encounters[i];
    if (!isRecord(enc)) continue;

    const client = isRecord(enc.client) ? enc.client : null;
    const name = client ? asNonEmptyString(client.name) : null;
    if (!name) continue;

    const slots = asArray(enc.slots);
    const readings = slots
      .map((s) => (isRecord(s) ? asNonEmptyString(s.text) : null))
      .filter((t): t is string => t !== null);

    if (readings.length > 0) {
      previous.push({ client: name, readings });
    }
  }

  return previous;
}

function buildPromptPayload(request: NormalizedReadingRequest): string {
  const enrichedSlots = request.slots.map(enrichSlotWithCardData);

  const payload: JsonRecord = {
    client: request.client,
    slots: enrichedSlots,
  };

  const previousReadings = extractPreviousReadings(request);
  if (previousReadings.length > 0) {
    payload.previous_readings = previousReadings;
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
      model: "anthropic/claude-sonnet-4.6",
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
