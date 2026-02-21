import fs from "fs";
import path from "path";

const DATA_DIR = path.join(process.cwd(), "..", "data");

export interface CardDef {
  name: string;
  front_image: string;
  arcana: "major" | "minor";
  suit: string;
  value: string;
  numeric_value: number;
  sentiment?: "positive" | "negative" | "neutral";
  keywords?: string[];
  description?: string;
}

export interface ClientDef {
  name: string;
  story: string;
}

export interface Slot {
  index: number;
  card?: string | null;
  text?: string | null;
}

export interface GameState {
  client: {
    name: string;
    age?: number;
    situation: string;
  };
  slots: Slot[];
}

export function loadCards(): CardDef[] {
  const cardsDir = path.join(DATA_DIR, "cards");
  const files = fs.readdirSync(cardsDir).filter((f) => f.endsWith(".json"));
  return files
    .map((f) => JSON.parse(fs.readFileSync(path.join(cardsDir, f), "utf-8")))
    .sort((a, b) => a.numeric_value - b.numeric_value || a.name.localeCompare(b.name));
}

export function loadClients(): ClientDef[] {
  const clientsPath = path.join(DATA_DIR, "clients.json");
  return JSON.parse(fs.readFileSync(clientsPath, "utf-8"));
}
