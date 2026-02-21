import { generateText } from "ai";
import { anthropic } from "@ai-sdk/anthropic";
import { NextRequest, NextResponse } from "next/server";
import { GameState } from "@/lib/data";

const SYSTEM_PROMPT = `You are the narrator of fates. People sit before you for a tarot reading. Whatever you write becomes real — these are not predictions, they are events that will happen.

You will receive a JSON object representing a tarot reading in progress. It contains a client and three slots (past, present, future). One slot will have a card but no text. Write the text for that slot.

## Rules

- Write in second person ("you")
- One to two sentences only
- Be specific. Names, places, moments. No metaphors. No abstractions. No poetic language.
- These events WILL happen to this person. Write them as facts.
- If other slots already have text, continue that narrative coherently
- Never contradict or undo what earlier slots established
- The card's traditional tarot meaning should guide the tone and direction, but the text must be grounded in the client's specific situation
- Do not acknowledge that you are an AI, a game, or a narrator

Return ONLY the text for the empty slot. No JSON. No quotes. No commentary. Just the sentence.`;

export async function POST(request: NextRequest) {
  let body: GameState;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  if (!body?.client?.situation) {
    return NextResponse.json(
      { error: "client.situation is required" },
      { status: 400 }
    );
  }

  if (!Array.isArray(body.slots) || body.slots.length === 0) {
    return NextResponse.json(
      { error: "slots array is required" },
      { status: 400 }
    );
  }

  const targetIndex = body.slots.findIndex(
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
      model: anthropic("claude-haiku-4-5"),
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: JSON.stringify(body, null, 2) }],
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

  const updatedSlots = body.slots.map((slot, i) =>
    i === targetIndex ? { ...slot, text: generated } : slot
  );

  return NextResponse.json({
    client: body.client,
    slots: updatedSlots,
    generated,
    filled_position: body.slots[targetIndex].position,
  });
}
