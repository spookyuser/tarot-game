## Game Loop

A client arrives with a story — a short narrative with three blanks where tarot readings will go. The player starts with 10 random cards drawn from the 78-card tarot deck — that's all they get, no reshuffling. Cards are dealt into the hand and dragged one at a time into three slots (left to right). While hovering a held card over the active slot, a preview reading appears both under the slot and inline in the story text. Dropping the card locks the reading permanently and opens the next slot. Once all three slots are filled, a resolution overlay shows the complete story with all readings woven in. The player clicks "Next Client" to discard everything and deal remaining cards for the next encounter.


## Current State

Three-column UI redesign just implemented. Core gameplay loop works: shuffle → draw → drag to slots → readings → next client. Single client ("Maria the Widow") in `data/clients.json`. AI readings served by Next.js API (`api/`) — Godot sends full game state to `POST /api/reading` and receives contextual narrative text. Portrait system loads MinifolksVillagers sprites but only has one explicit mapping. No save/load, no scoring, no multiple rounds beyond cycling the deck.

## Project Overview

Godot 4.6 tarot card reading game built on a reusable card framework addon. Players draw cards from a 78-card tarot deck and place them into story slots for procedurally-generated readings. The card framework addon (`addons/card-framework/`) is a general-purpose drag-and-drop card system; the game logic lives in `scenes/main.gd`.

## Running the Project

Open in Godot Engine 4.6. Main scene: `res://scenes/main.tscn`. Viewport: 1280x720, GL Compatibility renderer. No external build tools, package managers, or test frameworks.

### Reading API

AI-generated readings are served by the Next.js API in `api/`. Start it with `cd api && pnpm dev` (runs on `http://localhost:3000`). The API requires `ANTHROPIC_API_KEY` in `api/.env`. Godot's `scenes/claude_api.gd` calls `POST /api/reading` with the full game state (client + slots) and receives the generated reading text. Without the API running, readings will show "The cards are silent..."

To override the API URL, create `config/api_url.cfg`:
```ini
[api]
url=http://localhost:3000/api/reading
```

## Card Framework Architecture

### Class Hierarchy

```
DraggableObject (state machine: IDLE → HOVERING → HOLDING → MOVING)
  └── Card (card_name, card_info, front/back textures, static hover/hold counters)

CardContainer (base container with drop zone, card registry, undo history)
  ├── Hand (fan layout using Curve resources for rotation/vertical displacement)
  └── Pile (directional stack: UP/DOWN/LEFT/RIGHT, get_top_cards())

CardManager (@tool, central orchestrator, container registry, drag-drop routing)
CardFactory → JsonCardFactory (loads card JSON + PNG assets, instantiates Card nodes)
DropZone (sensor-based hit detection with vertical/horizontal partitioning)
CardFrameworkSettings (constants for animation speeds, z-indices, layout defaults)
HistoryElement (undo tracking with precise index restoration)
```

### Critical Positioning Constraint

**Pile** uses `position + offset` in `_update_target_positions()` and passes it to `card.move()` which tweens `global_position`. This means Pile nodes must be direct children of a parent whose global position is (0,0), or card positions will be wrong. **Hand** uses `global_position` directly, so it works anywhere.

### Scene Tree Order Matters

CardManager must appear **before** all CardContainer nodes in the scene tree. Containers discover CardManager via scene root meta (set in CardManager's `_ready()`), and CardManager iterates registered containers in insertion order when routing drops — first accepting container wins.

### Container API Differences

- `CardContainer`: `get_card_count()`, `has_card()`, `clear_cards()`, `move_cards()`, `_held_cards` (Array[Card])
- `Pile` adds: `get_top_cards(n)`, directional stacking
- `Hand` adds: `get_random_cards(n)`, fan layout with curves, `max_hand_size` enforcement
- `Hand` does **not** have `get_top_cards()` — use `_held_cards` directly

### Card Lifecycle

1. Created via `card_manager.card_factory.create_card(card_name, target_container)`
2. Dragged by user (state machine handles mouse events)
3. Dropped into container via `CardManager._on_drag_dropped()` → `container.move_cards()`
4. Destroyed via `container.clear_cards()` (calls `queue_free()` on each card)
5. After `clear_cards()`, manually reset `Card.holding_card_count = 0` and `Card.hovering_card_count = 0` since `queue_free()` skips state machine cleanup

## UI Layout (Three-Column)

```
1280x720 viewport
 Col 1 (0-280)       Col 2 (280-830)         Col 3 (830-1280)
 Gold Sidebar         Card Spread             Story Page
┌────────────────┬──────────────────────┬──────────────────┐
│ [Portrait]     │ [Slot0] [Slot1] [Sl2]│ ╔══════════════╗ │
│ Client Name    │ [read]  [read] [read]│ ║ Client Name  ║ │
│ Client #N      │                      │ ║              ║ │
│ ────────       │                      │ ║ Story text   ║ │
│ [deck] 72 left │                      │ ║ with inline  ║ │
│ ────────       │                      │ ║ readings...  ║ │
│ ★ ★ ☆ progress │   [ Player Hand ]    │ ╚══════════════╝ │
└────────────────┴──────────────────────┴──────────────────┘
```

- **Column 1**: `NinePatchRect` (gold_panel.png) with dark overlay. Contains portrait (AtlasTexture from MinifolksVillagers sprite sheet), client name/counter, deck thumbnail + count, 3 progress star icons.
- **Column 2**: 3 card slots (SlotPile0/1/2) with background rects and reading labels, PlayerHand centered at x=555.
- **Column 3**: `NinePatchRect` (wood_panel.png) with dark overlay. Story title + RichTextLabel with bbcode for inline readings (blanks as `___________`, hover previews in italic, filled in highlight color).

### UI Constraints

- **SlotPile0/1/2 and PlayerHand must remain direct children of Main** — Pile positioning constraint (see above). Never nest inside layout containers.
- **All decorative nodes** (panels, labels, icons, dividers) are also direct children of Main with absolute positioning via `offset_*` properties.
- **Decorative nodes must set `mouse_filter = 2`** (IGNORE) to avoid intercepting card drag-and-drop events.
- **ResolutionPanel** uses gold_panel NinePatchRect frame with dark inner fill. NextButton styled with gold_button textures via StyleBoxTexture theme overrides.

### Portrait System

`CLIENT_PORTRAITS` dict in `main.gd` maps client names → MinifolksVillagers sprite sheet paths. `_load_portrait_textures()` extracts the first 32x32 frame from each sheet via `AtlasTexture`. Unknown clients get a deterministic fallback from `PORTRAIT_FALLBACKS` using name hash.

To add a new client portrait: add entry to `CLIENT_PORTRAITS` dict with path to a sprite sheet in `art/MinifolksVillagers/Outline/`.

## Game Data

### Card JSON Format (`data/cards/*.json`)

```json
{"name": "ace_of_cups", "front_image": "ace_of_cups.png", "arcana": "minor", "suit": "cups", "value": "ace", "numeric_value": 1}
```

Major arcana use `"arcana": "major"`, `"suit": "major"`. 78 cards total (22 major + 56 minor across cups/gold/swords/wands).

### Client JSON Format (`data/clients.json`)

Array of objects with `name` (string) and `story` (string with `{0}`, `{1}`, `{2}` placeholders for inline card readings). Each placeholder marks where a generated sentence will be inserted into the prose.

### Art Assets

- `assets/cards/` — Card face PNGs, back face at `assets/card_back.png`. Card size: 110x159.
- `art/fantasy_pixelart_ui/` — Pixel art UI kit: `panels/` (gold/wood/silver NinePatchRect sources), `buttons/`, `icons/` (stars, arrows), `scroll/`, `sliders/`.
- `art/MinifolksVillagers/Outline/` — Character sprite sheets (32x32 frames). Used for client portraits via AtlasTexture.
- `assets/audio/` — Audio files directory (currently empty). Place real `.wav`/`.ogg` files here and assign them to SoundManager's exported `AudioStream` properties in the inspector to replace generated tones.

## Sound System

`scenes/sound_manager.gd` (`SoundManager` node in Main) provides centralized audio with three `AudioStreamPlayer` children: `AmbientPlayer` (looping background), `SFXPlayer` (one-shot effects), `ReadingPlayer` (looping tone during reading generation).

### Placeholder Tones

Each sound uses a generated sine wave at a distinct frequency. Real audio files override these when assigned to the exported `AudioStream` properties in the inspector.

| Sound | Frequency | Duration | Exported Property |
|-------|-----------|----------|-------------------|
| Ambient drone | 80 Hz | 4s loop | `ambient_stream` |
| Shuffle | 300 Hz | 0.3s | `shuffle_stream` |
| Card drop | 200 Hz | 0.2s | `card_drop_stream` |
| Reading (cups) | 440 Hz (A4) | 2s loop | `reading_cups_stream` |
| Reading (swords) | 520 Hz (C5) | 2s loop | `reading_swords_stream` |
| Reading (wands) | 392 Hz (G4) | 2s loop | `reading_wands_stream` |
| Reading (gold) | 349 Hz (F4) | 2s loop | `reading_gold_stream` |
| Reading (major) | 587 Hz (D5) | 2s loop | `reading_major_stream` |

### Integration Points in main.gd

- `_ready()` → `play_ambient()` — background drone starts on game load
- `_shuffle_deck()` → `play_shuffle()` — burst on deck shuffle
- `_lock_slot()` → `play_card_drop()` + `stop_reading()` — thud when card locks
- `_update_hover_previews()` hover enter → `play_reading(suit)` — looping tone while reading generates
- `_update_hover_previews()` hover exit → `stop_reading()` — stops when card leaves slot
- `_on_claude_request_completed()` → `stop_reading()` — stops when reading text arrives

### Swapping in Real Audio

1. Place audio files in `assets/audio/`
2. Select `SoundManager` node in the Main scene
3. In the Inspector, assign files to the corresponding exported `AudioStream` property
4. The SoundManager uses the assigned stream instead of the generated tone

