import { NextResponse } from "next/server";
import { loadClients } from "@/lib/data";

export async function GET() {
  try {
    const clients = loadClients();
    return NextResponse.json(clients);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: "Failed to load clients", detail: message }, { status: 500 });
  }
}
