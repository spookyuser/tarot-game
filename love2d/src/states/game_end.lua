-- Game end phase: show encounter summary, "Play Again"

local game_end = {}

function game_end.enter(game)
    game.show_cards = false
    game.show_loading = false
    game.show_resolution = false
    game.show_intro = false
    game.show_end = true
    game.play_again_pressed = false
end

function game_end.update(game, dt)
    if game.play_again_pressed then
        game.play_again_pressed = false
        game:reset()
        game.fsm:transition("init")
    end
end

function game_end.draw(game)
    -- End screen drawn by game.lua
end

function game_end.mousepressed(game, x, y, button)
    if button ~= 1 then return end
    if game.play_again_button and game.play_again_button:contains(x, y) then
        game.play_again_pressed = true
    end
end

return game_end
