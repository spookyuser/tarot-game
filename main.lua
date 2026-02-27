local Game = require("src.game")

local game

function love.load()
  love.graphics.setBackgroundColor(0.07, 0.05, 0.08)
  game = Game.new()
end

function love.update(dt)
  game:update(dt)
end

function love.draw()
  game:draw()
end

function love.mousemoved(x, y, dx, dy)
  game:mousemoved(x, y, dx, dy)
end

function love.mousepressed(x, y, button)
  game:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
  game:mousereleased(x, y, button)
end

function love.wheelmoved(_, y)
  game:wheelmoved(y)
end
