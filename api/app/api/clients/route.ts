import { generateObject } from "ai";
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";

const SYSTEM_PROMPT = `A new person approaches your tarot table for a reading. Invent them.

Output a JSON object:
- "name": A short descriptive name (e.g., "Elara the Betrayed", "The Lost Merchant", "Anya").
- "context": 2-3 sentences in first person ("I"). What brings them here, what's troubling them. Direct and specific, not flowery. This is what they say to you when they sit down.
`;

const clientSchema = z.object({
  name: z.string(),
  context: z.string(),
});

export async function POST(request: NextRequest) {
  let body: unknown;

  try {
    body = await request.json();
  } catch {
    // It's okay if body is empty
    body = {};
  }

  // The body might contain the previous game_state to vary the generated character
  const gameState = typeof body === "object" && body !== null && "game_state" in body
    ? (body as any).game_state
    : null;

  let prompt = "A new client arrives. Create their character.";
  if (gameState && Array.isArray(gameState.encounters) && gameState.encounters.length > 0) {
    const previousNames = gameState.encounters
      .map((e: any) => e.client?.name)
      .filter(Boolean)
      .join(", ");
    if (previousNames) {
      prompt += `\n\nPrevious clients have included: ${previousNames}. Make sure this new client is significantly different from them, however this client still exists in the same world and may have some connection to the events of previous clients or readings. This is optional though.`;
    }
  }

  try {
    const result = await generateObject({
      model: "anthropic/claude-sonnet-4.6",
      temperature: 0.4,
      system: SYSTEM_PROMPT,
      prompt,
      schema: clientSchema,
    });


    return NextResponse.json(result.object);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json(
      { error: "Generation failed", detail: message },
      { status: 502 }
    );
  }
}
