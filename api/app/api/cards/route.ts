import { NextResponse } from "next/server";
import { loadCards } from "@/lib/data";

export async function GET() {
  try {
    const cards = loadCards();
    return NextResponse.json(cards);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: "Failed to load cards", detail: message }, { status: 500 });
  }
}
