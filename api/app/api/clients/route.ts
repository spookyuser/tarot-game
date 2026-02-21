import { generateObject } from "ai";
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";

const SYSTEM_PROMPT = `A new person approaches your tarot table for a reading. Invent them.

Output a JSON object:
- "name": A short descriptive name (e.g., "Elara the Betrayed", "The Lost Merchant", "Anya").
- "context": One sentence — what the client says to you in their own voice, first person.
- "story": NOT used for display — leave it as an empty string "".
`;

const clientSchema = z.object({
  name: z.string(),
  context: z.string(),
  story: z.string(),
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
      prompt += `\n\nPrevious clients have included: ${previousNames}. Make sure this new client is significantly different from them.`;
    }
  }

  try {
    const result = await generateObject({
      model: "anthropic/claude-haiku-4.5",
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
