-- Intro phase: show client portrait and context, wait for "Begin"

local intro = {}

function intro.enter(game)
    game.show_intro = true
    game.show_cards = false
    game.show_loading = false
    game.show_resolution = false
    game.begin_pressed = false
end

function intro.update(game, dt)
    if game.begin_pressed then
        game.show_intro = false
        game.begin_pressed = false
        -- Set up client UI and deal hand
        game:setup_client_ui()
        game.fsm:transition("reading_active")
    end
end

function intro.draw(game)
    -- Intro panel drawn by game.lua
end

function intro.mousepressed(game, x, y, button)
    if button ~= 1 then return end
    -- Check begin button
    if game.intro_button and game.intro_button:contains(x, y) then
        game.begin_pressed = true
    end
end

return intro
