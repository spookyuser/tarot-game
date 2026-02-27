-- Reading active phase: card drag-drop, hover previews, slot management
local Card = require("src.cards.card")
local util = require("src.lib.util")

local reading_active = {}

local pulse_time = 0

function reading_active.enter(game)
    game.show_cards = true
    game.show_intro = false
    game.show_loading = false
    game.show_resolution = false
    game.active_slot = 1
    game.all_slots_filled = false
    pulse_time = 0

    -- Enable first slot
    for i = 1, 3 do
        game.slots[i].enabled = (i == 1)
    end
end

function reading_active.update(game, dt)
    pulse_time = pulse_time + dt * 3.0

    -- Update drag manager
    local all_cards = {}
    for _, card in ipairs(game.hand.cards) do
        all_cards[#all_cards + 1] = card
    end
    for i = 1, 3 do
        if game.slots[i].card then
            all_cards[#all_cards + 1] = game.slots[i].card
        end
    end
    game.drag_manager:update_card_list(all_cards)
    game.drag_manager:update(dt)

    -- Check for hover preview
    reading_active._update_hover_preview(game)

    -- Detect slot fills
    reading_active._detect_drops(game)

    -- Update hover info panel
    reading_active._update_hover_panel(game)

    -- Check if all slots filled
    if game.slot_filled[1] and game.slot_filled[2] and game.slot_filled[3] then
        if not game.all_slots_filled then
            game.all_slots_filled = true
            game.resolution_timer = 1.2
            game.fsm:transition("resolution")
        end
    end
end

function reading_active._update_hover_preview(game)
    if game.active_slot > 3 then return end

    local held = game.drag_manager:get_held_card()
    local new_hover_slot = -1
    local new_hover_card = nil

    if held and held.container == game.hand then
        -- Check if hovering over active slot
        local mx, my = love.mouse.getPosition()
        if game.slots[game.active_slot]:contains_point(mx, my) then
            new_hover_slot = game.active_slot
            new_hover_card = held
        end
    end

    -- Hover exit
    if game.hover_slot > 0 and (game.hover_slot ~= new_hover_slot or game.hover_card ~= new_hover_card) then
        game.sound:stop_reading()
        if not game.slot_filled[game.hover_slot] then
            game.slot_readings[game.hover_slot] = ""
            game.hover_preview_text = ""
        end
    end

    if new_hover_slot == -1 then
        if game.hover_slot > 0 then
            if not game.slot_filled[game.active_slot] then
                game.slot_readings[game.active_slot] = ""
            end
            game.hover_preview_text = ""
        end
        game.hover_slot = -1
        game.hover_card = nil
        return
    end

    -- Same hover as last frame
    if new_hover_slot == game.hover_slot and new_hover_card == game.hover_card then
        return
    end

    -- Hover enter
    game.hover_slot = new_hover_slot
    game.hover_card = new_hover_card

    local orient_key = new_hover_card.is_reversed and "reversed" or "upright"
    local cache_key = new_hover_card.card_name .. ":" .. orient_key .. ":" .. new_hover_slot

    if game.reading_cache[cache_key] then
        game.slot_readings[new_hover_slot] = game.reading_cache[cache_key]
        game.hover_preview_text = game.reading_cache[cache_key]
        return
    end

    -- Show loading text and request reading
    game.slot_readings[new_hover_slot] = "The cards are speaking..."
    game.hover_preview_text = "The cards are speaking..."
    game.loading_slots[new_hover_slot] = true

    local suit = (new_hover_card.card_info or {}).suit or "major"
    game.sound:play_reading(suit)

    -- Build reading request
    game.pending_reading_requests[cache_key] = new_hover_slot
    local request_state = reading_active._build_reading_state(game, new_hover_slot, new_hover_card)
    game.api_client:generate_reading(cache_key, request_state)
end

function reading_active._detect_drops(game)
    if game.active_slot > 3 then return end

    local slot = game.slots[game.active_slot]
    if slot.card and not game.slot_filled[game.active_slot] then
        -- A card was just placed
        game.sound:play_card_drop()
        game.sound:stop_reading()
        game.slot_filled[game.active_slot] = true
        slot.enabled = false

        local card = slot.card
        local orient_key = card.is_reversed and "reversed" or "upright"
        local cache_key = card.card_name .. ":" .. orient_key .. ":" .. game.active_slot

        local reading
        if game.reading_cache[cache_key] then
            reading = game.reading_cache[cache_key]
        else
            reading = "The cards are speaking..."
        end

        game.slot_readings[game.active_slot] = reading
        game.slot_labels[game.active_slot] = util.humanize_token(card.card_name) ..
            (card.is_reversed and " (Reversed)" or "")

        -- Persist to encounter state
        reading_active._persist_slot(game, game.active_slot, card.card_name, orient_key, reading)

        -- Track discard
        game.deck.discard[#game.deck.discard + 1] = card.card_name

        -- Invalidate unfilled caches
        for key in pairs(game.reading_cache) do
            local parts = {}
            for part in key:gmatch("[^:]+") do parts[#parts+1] = part end
            if #parts == 3 then
                local idx = tonumber(parts[3])
                if idx and not game.slot_filled[idx] then
                    game.reading_cache[key] = nil
                end
            end
        end

        -- Advance to next slot
        game.hover_slot = -1
        game.hover_card = nil
        game.hover_preview_text = ""
        game.loading_slots[game.active_slot] = nil

        game.active_slot = game.active_slot + 1
        if game.active_slot <= 3 then
            game.slots[game.active_slot].enabled = true
        end
    end
end

function reading_active._update_hover_panel(game)
    -- Find hovered card in hand
    game.hover_info_card = nil
    for _, card in ipairs(game.hand.cards) do
        if card.state == Card.HOVERING then
            game.hover_info_card = card
            break
        end
    end
end

function reading_active._build_reading_state(game, slot_index, hover_card)
    local slot_cards = {"", "", ""}
    local slot_texts = {"", "", ""}
    local slot_orientations = {"", "", ""}

    for i = 1, 3 do
        if game.slot_filled[i] and game.slots[i].card then
            slot_cards[i] = game.slots[i].card.card_name
            slot_texts[i] = game.slot_readings[i] or ""
            slot_orientations[i] = game.slots[i].card.is_reversed and "reversed" or "upright"
        elseif i == slot_index and hover_card then
            slot_cards[i] = hover_card.card_name
            slot_orientations[i] = hover_card.is_reversed and "reversed" or "upright"
        end
    end

    return {
        game_state = util.deep_copy(game.state),
        active_encounter_index = game.state.encounter_index - 1,
        runtime_state = {
            slot_cards = slot_cards,
            slot_texts = slot_texts,
            slot_orientations = slot_orientations,
        },
    }
end

function reading_active._persist_slot(game, slot_index, card_name, orientation, text)
    local enc_idx = game.state.encounter_index
    if enc_idx < 1 or enc_idx > #game.state.encounters then return end
    local encounter = game.state.encounters[enc_idx]
    if not encounter.slots then
        encounter.slots = {{}, {}, {}}
    end
    encounter.slots[slot_index] = {
        card = card_name,
        text = text,
        orientation = orientation,
    }
end

function reading_active.draw(game)
    -- Draw slot backgrounds with pulse on active slot
    for i = 1, 3 do
        local slot = game.slots[i]
        if i == game.active_slot and not game.slot_filled[i] then
            local pulse = (math.sin(pulse_time) + 1) * 0.5
            local alpha = 0.5 + 0.5 * pulse
            love.graphics.setColor(0.88, 0.72, 0.8, alpha * 0.6)
        else
            love.graphics.setColor(1, 1, 1, 0.4)
        end
        love.graphics.rectangle("line", slot.x, slot.y, slot.w, slot.h, 4, 4)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function reading_active.mousepressed(game, x, y, button)
    game.drag_manager:mousepressed(x, y, button)
end

function reading_active.mousereleased(game, x, y, button)
    game.drag_manager:mousereleased(x, y, button)
end

return reading_active
