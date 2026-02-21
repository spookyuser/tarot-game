import { generateObject } from "ai";
import { z } from "zod";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";

dotenv.config({ path: path.join(__dirname, "..", ".env") });

const CARDS_DIR = path.join(__dirname, "..", "..", "data", "cards");

const CardAttributesSchema = z.object({
  sentiment: z.enum(["positive", "negative", "neutral"]),
  keywords: z.array(z.string()).min(3).max(5),
  description: z.string(),
});

interface CardJson {
  name: string;
  front_image: string;
  arcana: string;
  suit: string;
  value: string;
  numeric_value: number;
  sentiment?: string;
  keywords?: string[];
  description?: string;
}

async function generateForCard(card: CardJson) {
  const displayName = card.name.replace(/_/g, " ");

  const result = await generateObject({
    model: "anthropic/claude-haiku-4.5",
    schema: CardAttributesSchema,
    prompt: `Generate tarot card attributes for "${displayName}" (${card.arcana} arcana${card.suit !== "major" ? `, suit of ${card.suit}` : ""}).

Return:
- sentiment: "positive", "negative", or "neutral" — the card's overall emotional valence in traditional tarot
- keywords: 3-5 short phrases (2-4 words each) capturing the card's core meanings in plain language a newcomer would understand
- description: 2-3 sentences (40-80 words) explaining what this card represents, written for someone who has never seen tarot before. Be direct and specific, not flowery.`,
  });

  return result.object;
}

async function main() {
  const files = fs.readdirSync(CARDS_DIR).filter((f) => f.endsWith(".json"));
  console.log(`Found ${files.length} card files`);

  let processed = 0;
  let skipped = 0;

  for (const file of files) {
    const filePath = path.join(CARDS_DIR, file);
    const card: CardJson = JSON.parse(fs.readFileSync(filePath, "utf-8"));

    if (card.sentiment && card.keywords && card.description) {
      skipped++;
      continue;
    }

    try {
      const attrs = await generateForCard(card);
      const updated = { ...card, ...attrs };
      fs.writeFileSync(filePath, JSON.stringify(updated, null, 2) + "\n");
      processed++;
      console.log(`[${processed + skipped}/${files.length}] ${card.name}`);
    } catch (err) {
      console.error(`Failed: ${card.name}`, err);
    }
  }

  console.log(
    `Done. Processed: ${processed}, Skipped (already had attrs): ${skipped}`
  );
}

main();
