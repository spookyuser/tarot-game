import { generateText } from "ai";
import { NextRequest, NextResponse } from "next/server";

const SYSTEM_PROMPT = `You are the narrator of a tarot reading session. The reader has just finished their shift.
Review the clients they saw today and the readings they gave. 
Write a 2-3 paragraph reflective summary of the day's events.
Write in the third person, focusing on the reader's experience, the atmosphere, and the recurring themes or distinct differences in the clients' fates.
Do NOT just list what happened. Make it a cohesive, atmospheric story about the burden and insight of reading the cards.`;

export async function POST(request: NextRequest) {
    let body: unknown;

    try {
        body = await request.json();
    } catch {
        return NextResponse.json(
            { error: "Invalid JSON body" },
            { status: 400 }
        );
    }

    const gameState = typeof body === "object" && body !== null && "game_state" in body
        ? (body as any).game_state
        : null;

    if (!gameState || !Array.isArray(gameState.encounters) || gameState.encounters.length === 0) {
        return NextResponse.json(
            { error: "Missing or invalid game_state.encounters" },
            { status: 400 }
        );
    }

    // Format the encounters into a readable string for the prompt
    const sessionData = gameState.encounters.map((encounter: any, index: number) => {
        const clientName = encounter.client?.name || "Unknown Client";
        const clientContext = encounter.client?.context || "No context provided.";

        let readingSummary = "";
        if (Array.isArray(encounter.slots)) {
            readingSummary = encounter.slots
                .map((slot: any, i: number) => {
                    if (!slot.text) return "";
                    return `Card ${i + 1} (${slot.card || "Unknown"}${slot.orientation === "reversed" ? " Reversed" : ""}): ${slot.text}`;
                })
                .filter(Boolean)
                .join("\n");
        }

        return `Client ${index + 1}: ${clientName}\nTrouble: ${clientContext}\nReading:\n${readingSummary}`;
    }).join("\n\n");

    const prompt = `Here are the clients the reader saw today:\n\n${sessionData}\n\nPlease write the final reflective summary of the day.`;

    try {
        const result = await generateText({
            model: "anthropic/claude-sonnet-4.6",
            temperature: 0.6,
            system: SYSTEM_PROMPT,
            prompt,
        });

        return NextResponse.json({ summary: result.text });
    } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        return NextResponse.json(
            { error: "Summary generation failed", detail: message },
            { status: 502 }
        );
    }
}
