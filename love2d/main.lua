-- The Reading Room - Love2D port
-- Entry point: delegates to Game controller

local Game = require("src.game")

local game

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setBackgroundColor(0.08, 0.04, 0.14)
    math.randomseed(os.time())

    game = Game.new()
end

function love.update(dt)
    game:update(dt)
end

function love.draw()
    game:draw()
end

function love.mousepressed(x, y, button)
    game:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    game:mousereleased(x, y, button)
end

function love.wheelmoved(x, y)
    game:wheelmoved(x, y)
end

function love.quit()
    game:destroy()
end
