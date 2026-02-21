import { generateObject } from "ai";
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";

const SYSTEM_PROMPT = `You invent people who walk into a tarot reader's tent in a small port town. Each person is real — they have a job, a home, people they care about, a specific problem they can't solve alone.

Output a JSON object:
- "name": First name and a descriptor rooted in who they are — their trade, a habit, a reputation.
- "context": [MAX 1 sentence] A short direct sentence in first person ("I"). What they say when they sit down. Raw, direct, specific. They're stuck and they need answers. 

Guidelines:
- They should have problems that are human and that we all understand — not "I want to find love" but "I can't stop arguing with my partner, and I don't know if we can fix it." Not "I'm stressed about money" but "I lost my job and I have rent due in three days." The more specific, the better. The cards will be more specific in response.
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

  let prompt = "A new visitor walks into the tent. Create them.";
  if (gameState && Array.isArray(gameState.encounters) && gameState.encounters.length > 0) {
    const historyLines = gameState.encounters
      .slice(-4)
      .map((e: any) => {
        const name = e.client?.name || "Unknown";
        const context = e.client?.context || "";
        const readings = (e.slots || [])
          .map((s: any) => s.text)
          .filter((t: any) => t && typeof t === "string" && t.trim().length > 0);
        const readingStr = readings.length > 0
          ? `\n  Readings: ${readings.map((r: string) => `"${r}"`).join(" / ")}`
          : "";
        return `- ${name}: ${context}${readingStr}`;
      })
      .join("\n");

    if (historyLines) {
      prompt += `\n\nOther visitors today (for variety — do NOT reference them or their stories):\n${historyLines}\n\nThis new person has their own life and their own problem. They are not here because of anyone else. Make them distinct from the people above in age, occupation, temperament, and concern.`;
    }
  }

  try {
    const result = await generateObject({
      model: "anthropic/claude-sonnet-4.6",
      temperature: 0.2,
      system: SYSTEM_PROMPT,
      maxOutputTokens: 150,
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
