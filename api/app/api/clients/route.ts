import { generateObject } from "ai";
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";

const SYSTEM_PROMPT = `You are the master weaver of fates. A new person approaches your tarot table for a reading. 
Invent a unique, evocative character and their brief story.

You must output a JSON object representing this person:
- "name": A short descriptive name (e.g., "Elara the Betrayed", "The Lost Merchant", "Anya").
- "context": A one-sentence explanation of why they are seeking a reading (this is what they say to you).
- "story": A short 1-2 paragraph narrative of their situation. Crucially, the story MUST contain EXACTLY THREE placeholders: "{0}", "{1}", and "{2}". These placeholders represent the past, present, and future readings that will be dynamically inserted later.

The placeholders should be woven naturally into the text. You should leave a blank line before and after the placeholders or make them separate sentences.

Example story format:
"You arrive out of the storm, seeking answers about your lost child.

{0}

But the present offers a different perspective.

{1}

And as for what comes next...

{2}"

Make the tones mysterious, solemn, or dramatic.
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
