-- Init phase: build deck, shuffle, set up first encounter
local util = require("src.lib.util")

local init = {}

function init.enter(game)
    -- Build deck and shuffle 9 cards
    game.deck:build(game.card_data)
    game.deck:shuffle(9)

    -- Set up initial game state with hardcoded first client
    game.state = {
        encounters = {
            {
                client = {
                    name = "Maria the Widow",
                    context = "I got married at 23. Everyone told me not to but i did and last week, my husband just, he's just dead, i'm sad and i don't know what to do. is he at peace?"
                },
                slots = {
                    {card = "", text = "", orientation = ""},
                    {card = "", text = "", orientation = ""},
                    {card = "", text = "", orientation = ""},
                }
            }
        },
        encounter_index = 0,
        client_count = 0,
    }

    -- Set current encounter to first one
    game.current_encounter = util.deep_copy(game.state.encounters[1])
    game.state.encounter_index = 1

    -- Play audio
    game.sound:play_shuffle()
    game.sound:play_ambient()

    -- Transition to intro for first client
    game.fsm:transition("intro")
end

return init
