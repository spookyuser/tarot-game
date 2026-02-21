# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Godot 4.6 tarot card reading game built on a reusable card framework addon. Players draw cards from a 78-card tarot deck and place them into story slots for procedurally-generated readings. The card framework addon (`addons/card-framework/`) is a general-purpose drag-and-drop card system; the game logic lives in `scenes/main.gd`.

## Running the Project

Open in Godot Engine 4.6. Main scene: `res://scenes/main.tscn`. Viewport: 1280x720, GL Compatibility renderer. No external build tools, package managers, or test frameworks.

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

## Game Data

### Card JSON Format (`data/cards/*.json`)

```json
{"name": "ace_of_cups", "front_image": "ace_of_cups.png", "arcana": "minor", "suit": "cups", "value": "ace", "numeric_value": 1}
```

Major arcana use `"arcana": "major"`, `"suit": "major"`. 78 cards total (22 major + 56 minor across cups/gold/swords/wands).

### Client JSON Format (`data/clients.json`)

Array of objects with `name` (string) and `story` (string with `{0}`, `{1}`, `{2}` placeholders for inline card readings). Each placeholder marks where a generated sentence will be inserted into the prose.

### Card Assets

PNGs in `assets/cards/`, shared back face at `assets/card_back.png`. Card size in game: 110x159 (smaller than framework default 150x210).

## Game Flow (scenes/main.gd)

Deck shuffled → client appears with story (blanks shown as `___________`) → draw 3 cards into hand → drag cards to slots (hover shows preview reading inline in story, drop locks permanently) → all 3 filled triggers resolution overlay after 1.2s → "Next Client" button discards and deals fresh. Deck reshuffles discards when running low.

Story uses Mad Libs format: `current_client["story"]` contains `{0}`, `{1}`, `{2}` placeholders replaced inline with card readings. `_render_story()` substitutes filled readings, hover previews, or blank markers into the template.

Reading text is template-based (fallback when no API key): major arcana map to hardcoded meanings, minor arcana combine `VALUE_INTENSITIES[value] + SUIT_THEMES[suit]`, wrapped in `READING_TEMPLATES` sentence frames designed to read as natural inline prose. With API key, Claude generates one sentence per blank that flows with surrounding text.
