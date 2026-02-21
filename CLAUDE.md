## Game Loop

A client arrives with a story — a short narrative with three blanks where tarot readings will go. The player starts with 10 random cards drawn from the 78-card tarot deck — that's all they get, no reshuffling. Cards are dealt into the hand and dragged one at a time into three slots (left to right). While hovering a held card over the active slot, a preview reading appears both under the slot and inline in the story text. Dropping the card locks the reading permanently and opens the next slot. Once all three slots are filled, a resolution overlay shows the complete story with all readings woven in. The player clicks "Next Client" to discard everything and deal remaining cards for the next encounter.


## Current State

Three-column UI redesign just implemented. Core gameplay loop works: shuffle → draw → drag to slots → readings → next client. Single client ("Maria the Widow") in `data/clients.json`. AI readings served by Next.js API (`api/`) — Godot sends full game state to `POST /api/reading` and receives contextual narrative text. Portrait system loads MinifolksVillagers sprites but only has one explicit mapping. No save/load, no scoring, no multiple rounds beyond cycling the deck.

## Project Overview

Godot 4.6 tarot card reading game built on a reusable card framework addon. Players draw cards from a 78-card tarot deck and place them into story slots for procedurally-generated readings. The card framework addon (`addons/card-framework/`) is a general-purpose drag-and-drop card system; the game logic is decomposed across several scripts under `scenes/`.

### Game Architecture

```
Main (scenes/main.gd, ~290 lines — session orchestrator)
  ├── Sidebar (Control child, scenes/sidebar.gd) — left column UI: portrait, client info, deck count, progress stars, restart
  ├── DeckManager (RefCounted) — deck state, shuffle, draw
  ├── PortraitLoader (RefCounted) — portrait texture loading + lookup
  ├── ReadingSlotManager (Node child) — slots, hover previews, API callbacks, drop detection
  ├── StoryRenderer (Node child) — renders story column with inline readings
  ├── CardHoverInfoPanel (script on NinePatchRect) — tooltip positioning + tweens
  ├── VignetteEffect (script on ColorRect) — shader fade tweens
  ├── EndScreen (script on EndPanel Control) — end summary display
  ├── SoundManager (unchanged, scenes/sound_manager.gd)
  └── ClaudeAPI (unchanged, scenes/claude_api.gd)
```

**Signal flow**: ReadingSlotManager emits `slot_locked`, `all_slots_filled`, `reading_received`, `story_changed`, `request_*_sound`, `waiting_for_reading_*` signals. Main mediates — connects sound signals to SoundManager, story changes to StoryRenderer, vignette signals to VignetteEffect. No sibling-to-sibling communication.

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

`PortraitLoader` (RefCounted in `scenes/portrait_loader.gd`) maps client names → portrait sprite sheet paths via `CLIENT_PORTRAITS` dict. `load_all()` extracts the first 32x32 frame from each sheet via `AtlasTexture`. `get_portrait(name)` returns the texture, falling back to a deterministic pick from `PORTRAIT_FALLBACKS` using name hash.

To add a new client portrait: add entry to `CLIENT_PORTRAITS` dict in `portrait_loader.gd` with path to a sprite sheet in `assets/portraits/`.

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
- `assets/ui/` — Pixel art UI kit: `panels/` (gold/wood/silver NinePatchRect sources), `buttons/`, `icons/` (stars, arrows).
- `assets/portraits/` — Character sprite sheets (32x32 frames). Used for client portraits via AtlasTexture.
- `assets/audio/` — Audio files: ambient music, card SFX, and suit-themed reading tones (MP3).
- `assets/fonts/spectral/` — Spectral font family (SIL OFL).

## Sound System

`scenes/sound_manager.gd` (`SoundManager` node in Main) provides centralized audio with three `AudioStreamPlayer` children: `AmbientPlayer` (looping background), `SFXPlayer` (one-shot effects), `ReadingPlayer` (looping tone during reading generation). Generated sine wave tones serve as fallbacks if no audio file is assigned.

### Audio File Mapping

| Sound | File | Exported Property | Loops |
|-------|------|-------------------|-------|
| Ambient | `ambience.mp3` | `ambient_stream` | Yes |
| Shuffle | `card_shuffle.mp3` | `shuffle_stream` | No |
| Card drop | `card_drop.mp3` | `card_drop_stream` | No |
| Reading (cups) | `reading_happy.mp3` | `reading_cups_stream` | Yes |
| Reading (swords) | `reading_sad.mp3` | `reading_swords_stream` | Yes |
| Reading (wands) | `reading_death.mp3` | `reading_wands_stream` | Yes |
| Reading (gold) | `reading_mystery.mp3` | `reading_gold_stream` | Yes |
| Reading (major) | `reading_mystery.mp3` | `reading_major_stream` | Yes |

### Integration Points

Sound is triggered via signals from `ReadingSlotManager` → Main → `SoundManager`:
- `_ready()` → `play_ambient()` / `play_shuffle()` — called directly by Main
- `request_card_drop_sound` → `play_card_drop()` — emitted when card locks into slot
- `request_reading_sound(suit)` → `play_reading(suit)` — emitted when hover preview starts loading
- `request_stop_reading_sound` → `stop_reading()` — emitted on hover exit or reading arrival

### Swapping Audio Files

To replace a sound, assign a different `AudioStream` to the corresponding exported property on the `SoundManager` node in the Inspector. The `_set_loop()` helper handles looping for MP3, OGG, and WAV formats automatically.
