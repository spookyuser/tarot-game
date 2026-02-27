# The Reading Room: Godot 4.6 → Love2D Migration Plan

## Project Summary

"The Reading Room" is a 1280x720 tarot card game (~2,500 lines of GDScript + 2 addons) where AI-generated clients visit a tarot reader. Players drag cards from a fan-shaped hand into 3 reading slots, each generating an AI reading via the Claude API. The game loops through clients until the 78-card deck is exhausted.

---

## Architecture Mapping

### What Changes

| Godot Concept | Love2D Equivalent |
|---|---|
| Scene tree / node hierarchy | Flat Lua modules with explicit draw-order |
| Control nodes + anchors | Hardcoded pixel coordinates (fixed 1280×720) |
| Signals (`connect`/`emit`) | Lightweight event bus (~20 lines) or direct calls |
| Tweens (parallel, eased) | `flux` library (or hand-rolled ~80 lines) |
| `mouse_entered`/`mouse_exited` | Manual per-frame hit testing + hover tracking |
| Beehave Behavior Tree (18 leaf nodes) | Simple FSM with 6 phase objects (~100 lines) |
| Blackboard (key-value store) | Plain Lua table |
| `NinePatchRect` | Custom 9-slice draw function (~40 lines) |
| `RichTextLabel` + BBCode | Custom rich text renderer (~150 lines) |
| HTTPRequest node (async) | `lua-https` in `love.thread` worker |
| AudioStreamPlayer | `love.audio.newSource()` |
| GLSL shader (`canvas_item`) | Love2D GLSL shader (near-direct port) |
| `load()` / `preload()` | `love.graphics.newImage()` at startup |
| `get_tree().reload_current_scene()` | Reset game state table + transition to init |

### What Stays the Same

- All 78 card PNGs, JSON data, portraits, fonts, audio files, UI textures → copy directly
- Cloudflare Workers proxy → unchanged (already CORS-enabled)
- Game design, flow, and UX → identical
- Vignette + spotlight shader → near-direct GLSL port

---

## Project Structure

```
the-reading-room/
├── main.lua                     -- love.load/update/draw/mouse callbacks
├── conf.lua                     -- 1280×720, non-resizable, "The Reading Room"
│
├── src/
│   ├── game.lua                 -- Top-level controller, owns FSM + systems
│   │
│   ├── states/                  -- Phase state machine (replaces BT + 18 leaf scripts)
│   │   ├── fsm.lua              -- transition_to(phase), ~20 lines
│   │   ├── init.lua             -- Build deck, shuffle, deal, → client_loading
│   │   ├── client_loading.lua   -- Fire API, show loading, poll response
│   │   ├── intro.lua            -- Show client portrait/context, wait for "Begin"
│   │   ├── reading_active.lua   -- Card drag-drop, hover previews, slot management
│   │   ├── resolution.lua       -- Timer → show readings → wait for "Next"
│   │   └── game_end.lua         -- Summary screen, "Play Again"
│   │
│   ├── cards/                   -- Card interaction system
│   │   ├── card.lua             -- Card object: state machine, textures, reversed
│   │   ├── hand.lua             -- Fan layout (arc math), card collection
│   │   ├── slot.lua             -- Simplified pile: accept 1 card, display it
│   │   ├── drag_manager.lua     -- Hit testing, drag-drop routing, z-ordering
│   │   └── card_data.lua        -- JSON loader, image cache, deck builder
│   │
│   ├── systems/                 -- Game systems
│   │   ├── api_client.lua       -- Async HTTPS via love.thread worker
│   │   ├── reading_manager.lua  -- Hover preview, reading cache, API coordination
│   │   ├── sound_manager.lua    -- Ambient, SFX, reading audio
│   │   ├── deck.lua             -- Shuffle, draw, track discard
│   │   └── game_state.lua       -- Encounter history, slot persistence
│   │
│   ├── ui/                      -- UI components
│   │   ├── button.lua           -- Clickable rect with normal/pressed textures
│   │   ├── ninepatch.lua        -- 9-slice texture drawing
│   │   ├── richtext.lua         -- Colored text, italic, [wave] animation
│   │   ├── sidebar.lua          -- Portrait, name, progress, deck count
│   │   ├── story_panel.lua      -- Right-side narrative display
│   │   ├── hover_panel.lua      -- Card info tooltip with slide animation
│   │   └── end_screen.lua       -- Scrollable encounter summary
│   │
│   ├── fx/                      -- Visual effects
│   │   ├── tween.lua            -- Property interpolation with easing
│   │   └── vignette.lua         -- Shader wrapper + spotlight management
│   │
│   └── lib/                     -- Third-party / utilities
│       ├── json.lua             -- lunajson or dkjson (single file)
│       ├── flux.lua             -- Tween library (optional, vs hand-rolled)
│       └── util.lua             -- deep_copy, shuffle, point_in_rect, hash
│
├── assets/                      -- Copied directly from Godot project
│   ├── cards/                   -- 78 card PNGs
│   ├── data/                    -- 78 card JSON definitions
│   ├── card_back.png
│   ├── portraits/               -- 10 sprite sheets (32×32)
│   ├── audio/                   -- 7 MP3 files
│   ├── fonts/                   -- Spectral-Bold.ttf + BoldItalic.ttf
│   └── ui/                      -- Panels, buttons, icons
│
├── shaders/
│   └── vignette.glsl            -- Ported vignette + spotlight shader
│
└── worker/                      -- Cloudflare Worker (unchanged)
```

---

## External Dependencies

| Library | Purpose | Type |
|---|---|---|
| `lua-https` | HTTPS requests | Bundled in Love 12 |
| `lunajson` or `dkjson` | JSON encode/decode | Pure Lua, single file |
| `flux` (optional) | Tween animations | Pure Lua, single file |

No native/compiled dependencies required.

---

## Key System Designs

### 1. Game State (replaces Blackboard)

A single structured Lua table, reset on "Play Again":

```
game_state = {
  phase = "init",
  session = {
    deck = {},              -- remaining card names
    discard = {},           -- used card names
    encounters = {},        -- completed encounter records
    encounter_index = 0,
  },
  encounter = {
    client = nil,           -- {name, context}
    slots = {
      {card=nil, orientation=nil, text=nil, filled=false},
      {card=nil, orientation=nil, text=nil, filled=false},
      {card=nil, orientation=nil, text=nil, filled=false},
    },
    active_slot = 0,
    reading_cache = {},     -- "name:orient:slot" → text
  },
  ui = {
    hover_card = nil,
    hover_slot = -1,
    hover_preview = "",
    loading_slots = {},
  },
}
```

### 2. Phase State Machine (replaces Behavior Tree)

Each phase is a table with `enter()`, `update(dt)`, `draw()`, `exit()`, and optional input handlers (`mousepressed`, `mousereleased`). Transitions are explicit:

```
Phase flow:
  init → client_loading → intro → reading_active → resolution → {client_loading | game_end}
```

- **init.enter()**: Build 78-card deck, shuffle 9 into hand, load portraits, play ambient, fire first client API request, transition immediately to `client_loading`
- **client_loading.update(dt)**: Poll HTTP response channel. On success → store client, transition to `intro`. On failure → show error
- **intro.enter()**: Show client portrait + context panel. Wait for "Begin" click → transition to `reading_active`
- **reading_active.update(dt)**: Process hover previews, drop detection, spotlight. When all 3 slots filled → transition to `resolution`
- **resolution.enter()**: Start 2.5s timer. When expired, show resolution panel. On "Next" click → cleanup cards, check deck → transition to `client_loading` or `game_end`
- **game_end.enter()**: Show summary of all encounters. "Play Again" → reset state, transition to `init`

### 3. Card Drag-and-Drop System

**State machine per card**: `IDLE → HOVERING → HOLDING → MOVING → IDLE`

**Hit testing**: AABB (cards have ≤12° rotation, AABB is sufficiently accurate). Iterate cards in reverse z-order (topmost first). Track a single `hovered_card` variable, fire enter/exit on change.

**Mutual exclusion**: Module-level `hovering_count` and `holding_count`. Only allow hover when both are 0.

**Fan hand layout** (replaces Godot Curve resources):
- Horizontal: `spacing = 700 / (count + 1)`, card_x = `hand_center_x + (i+1) * spacing - 350`
- Vertical lift: `35 * 4 * t * (1 - t)` where `t = i / (count - 1)` (parabola peaking at 35px)
- Rotation: `lerp(-12°, +12°, t)` (linear)

**Drop routing**: On mouse release, iterate containers (slot piles first, then hand). First container whose drop zone contains the mouse AND accepts the card wins. Otherwise, animate card back to original position.

**Z-ordering**: Flat draw list sorted by `z_index` before each `love.draw()`. Hand cards get base z-index 100+i. Hovered/held cards get +1000 offset.

### 4. Async HTTP (Claude API)

Use `lua-https` inside a `love.thread` worker:
- Main thread pushes requests to a Channel: `{id, url, headers, body}`
- Worker thread loops with `channel:demand()`, executes HTTPS POST, pushes result to response Channel
- Main thread polls `response_channel:pop()` in `love.update(dt)`
- Stale responses ignored by checking if `request_id` is still in `pending_requests` table

### 5. Vignette + Spotlight Shader

Near-direct port of the Godot GLSL. Key changes:
- `uniform` → `extern` (or keep `uniform`, both work in Love2D)
- `bool` uniforms → `float` (0.0/1.0, since Love2D doesn't support bool send)
- `void fragment()` → `vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)`
- `UV` → `texture_coords`
- `COLOR = ...` → `return ...`

Draw as fullscreen rectangle with shader active. Animate uniforms via tween system.

### 6. Rich Text Renderer

Supports only the 4 BBCode tags actually used:
- `[color=#hex]` → `love.graphics.setColor()`
- `[i]` → switch to `Spectral-BoldItalic.ttf` font
- `[wave amp=20 freq=5]` → per-character draw with `y + amp * sin(freq * time + i * 0.5)`
- `[center]` → offset x by `(container_width - line_width) / 2`

Parse into styled spans, word-wrap using `font:getWidth()`, draw sequentially.

---

## Migration Order

### Phase 1: Foundation (MVP — No API, No Audio)

Build the core card interaction loop with hardcoded data.

1. `conf.lua` + `main.lua` skeleton
2. Card rendering (load PNG, draw at position with rotation)
3. Card data loader (parse JSON, build 78-card registry)
4. Deck module (shuffle, draw N)
5. Tween system (value interpolation with cubic easing, cancellation)
6. Hand fan layout (arc math from curves above)
7. Card state machine (IDLE/HOVERING/HOLDING/MOVING)
8. Drag manager (hit testing, hover tracking, mouse follow, drop routing)
9. Slot component (drop zone rect, accept 1 card, display it)
10. Slot progression (active_slot advances 0→1→2, drop zone gating)

**Verification**: Drag cards from hand into 3 slots sequentially. Cards animate smoothly. Only one card hovers/holds at a time.

### Phase 2: Game Flow (Hardcoded Content)

Wire up the full game loop with static client data.

11. FSM framework (enter/update/draw/exit per phase, transition function)
12. All 6 phase states with hardcoded clients/readings
13. UI: sidebar, story panel, column dividers, background
14. Nine-patch panel renderer
15. Button component (hit test + texture states + click callback)
16. Overlay panels: intro, loading, resolution, end screen
17. Colored text renderer (at minimum; wave effect can be deferred)
18. Portrait loader (quad from sprite sheet, hash-based fallback)
19. End screen with scrollable encounter summary

**Verification**: Play through a full game with 2+ clients. Deck exhaustion shows end screen. "Play Again" resets everything.

### Phase 3: API Integration

Connect live Claude API for dynamic content.

20. Thread-based async HTTP client
21. JSON encode/decode integration
22. Reading manager: hover preview → API request → cache → display
23. Client generation via API
24. Request cancellation for stale hovers
25. Error handling (network failures, API errors)
26. Cache invalidation when slots fill (context changes)

**Verification**: Hover card over slot → loading text → AI reading appears. Drop card → reading persists. New clients generated between encounters.

### Phase 4: Polish

Visual and audio parity with Godot version.

27. Sound manager (ambient loop, card SFX, suit-specific reading tracks)
28. Vignette shader (edge darkening, animated intensity)
29. Spotlight effect (follows held card, fades to slot focus)
30. Card hover info panel (slide in/out tooltip with description)
31. `[wave]` text animation for hover previews
32. `[i]` italic text support
33. Cursor management (hand cursor on buttons)
34. Visual polish pass (colors, spacing, A/B comparison with Godot version)

---

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| Card drag-drop fidelity | HIGH | Port early (Phase 1). Test mutual exclusion, hover timing, return animation. |
| Hover preview + cache system | HIGH | Port reading_slot_manager logic carefully. Validate cache keys, invalidation, request cancellation. |
| Web HTTP (love.js) | MEDIUM | Abstract HTTP behind platform interface. Write JS bridge for `fetch()` if targeting web. Test love.js early. |
| BBCode text rendering | MEDIUM | Build minimal renderer for the 4 tags used. Wave effect is polish, not essential. |
| love.js shader compatibility | LOW | Shader is simple (no loops, no texture lookups). Test with love.js in Phase 1. |
| Performance | NONE | 78 small textures, simple shader, <12 cards in play. Trivially within Love2D's capacity. |

---

## Simplifications Over Godot Version

1. **Behavior Tree → FSM**: Eliminates Beehave addon (~50 files) + 18 leaf scripts. Net reduction: ~1000 lines.
2. **Card framework trimming**: No undo/history, no horizontal partitioning, no sensor debugging, no swap-only mode. ~700 lines → ~400 lines.
3. **Procedural audio fallback**: Skip. Require the 7 MP3 files.
4. **Scene tree / node lifecycle**: Replaced by flat Lua modules. No `queue_free()`, no `_ready()` ordering concerns.
5. **Blackboard polling**: Direct state checks instead of flag-based polling. `if slots[1].filled and slots[2].filled and slots[3].filled` replaces checking a boolean flag.

---

## Estimated Size

| Component | Estimated Lua Lines |
|---|---|
| Card system (card, hand, slot, drag_manager) | ~500 |
| Phase states (6 phases + FSM) | ~400 |
| Reading manager + API client | ~300 |
| UI components (panels, buttons, text, sidebar, end screen) | ~400 |
| Effects (tween, vignette, spotlight) | ~150 |
| Utilities (json, deep_copy, hash, deck) | ~100 |
| main.lua + conf.lua + game.lua | ~100 |
| **Total** | **~1,950 lines** |

Comparable to the Godot version's ~2,500 lines (which includes the BT overhead and card framework addon).
