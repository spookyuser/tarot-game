local Button = require("src.ui.button")

return function(game)
  local state = { play_again = nil, scroll = 0 }

  function state:enter()
    self.scroll = 0
    self.play_again = Button.new("Play Again", 540, 640, 200, 44, function()
      game.fsm:transition_to("init")
    end)
  end

  function state:draw()
    love.graphics.setColor(0.95, 0.9, 0.78)
    love.graphics.printf("Session Complete", 0, 40, 1280, "center")
    local y = 120 - self.scroll
    for i, entry in ipairs(game.state.session.encounters) do
      love.graphics.setColor(0.85, 0.8, 0.72)
      love.graphics.printf(string.format("%d. %s", i, entry.client), 100, y, 1080, "left")
      y = y + 30
      for _, text in ipairs(entry.readings) do
        love.graphics.setColor(0.75, 0.72, 0.65)
        love.graphics.printf("- " .. text, 120, y, 1040, "left")
        y = y + 24
      end
      y = y + 12
    end
    self.play_again:draw()
  end

  function state:wheelmoved(y)
    self.scroll = math.max(0, self.scroll - y * 20)
  end

  function state:mousepressed(x, y, button)
    self.play_again:mousepressed(x, y, button)
  end

  function state:mousereleased(x, y, button)
    self.play_again:mousereleased(x, y, button)
  end

  return state
end
