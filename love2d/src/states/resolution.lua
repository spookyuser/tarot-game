-- Resolution phase: show reading summary, wait for "Next"

local resolution = {}

function resolution.enter(game)
    game.resolution_timer = 1.2
    game.resolution_shown = false
    game.show_cards = false
    game.next_pressed = false
end

function resolution.update(game, dt)
    -- Poll for any pending reading responses
    game.api_client:update()

    if not game.resolution_shown then
        game.resolution_timer = game.resolution_timer - dt
        if game.resolution_timer <= 0 then
            game.resolution_shown = true
            game.show_resolution = true

            -- Populate resolution data
            local client = game.current_encounter and game.current_encounter.client or {}
            game.resolution_title = "Reading for " .. (client.name or "Unknown")
            game.resolution_readings = {}
            for i = 1, 3 do
                game.resolution_readings[i] = game.slot_readings[i] or ""
            end
        end
    end

    if game.next_pressed then
        game.show_resolution = false
        game.next_pressed = false

        -- Clean up cards
        game:destroy_all_cards()

        -- Check if deck is exhausted
        if game.hand:get_card_count() < 3 then
            game.fsm:transition("game_end")
        else
            -- Request next client
            game.fsm:transition("client_loading")
        end
    end
end

function resolution.draw(game)
    -- Resolution panel drawn by game.lua
end

function resolution.mousepressed(game, x, y, button)
    if button ~= 1 then return end
    if game.resolution_shown and game.next_button and game.next_button:contains(x, y) then
        game.next_pressed = true
    end
end

return resolution
