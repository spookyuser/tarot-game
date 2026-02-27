-- Client loading phase: request new client from API, show loading screen
local util = require("src.lib.util")

local client_loading = {}

function client_loading.enter(game)
    game.show_loading = true
    game.show_cards = false
    game.show_resolution = false
    game.show_intro = false

    -- Clear slot labels
    for i = 1, 3 do
        game.slot_readings[i] = ""
        game.slot_labels[i] = ""
        game.slot_filled[i] = false
    end

    -- Request new client from API
    game.client_data_ready = false
    game.client_request_failed = false
    game.api_client:generate_client("client_req", game.state)
end

function client_loading.update(game, dt)
    -- Poll for API response
    game.api_client:update()

    if game.client_data_ready then
        -- Store the new client
        local client_data = game.pending_client_data
        game.show_loading = false

        local new_encounter = {
            client = {
                name = client_data.name or "Unknown",
                context = client_data.context or "",
            },
            slots = {
                {card = "", text = "", orientation = ""},
                {card = "", text = "", orientation = ""},
                {card = "", text = "", orientation = ""},
            }
        }

        game.state.encounters[#game.state.encounters + 1] = new_encounter
        game.state.encounter_index = #game.state.encounters
        game.current_encounter = util.deep_copy(new_encounter)

        game.client_data_ready = false
        game.fsm:transition("intro")
    elseif game.client_request_failed then
        game.show_loading = false
        game.client_error = game.client_error_message or "Unknown error"
        game.fsm:transition("game_end")
    end
end

function client_loading.draw(game)
    -- Loading panel drawn by game.lua
end

return client_loading
