local Button = require("src.ui.button")

return function(game)
  local state = { begin_button = nil }

  function state:enter()
    self.begin_button = Button.new("Begin Reading", 540, 520, 200, 50, function()
      game.fsm:transition_to("reading_active")
    end)
  end

  function state:draw()
    local client = game.state.encounter.client
    love.graphics.setColor(0.93, 0.88, 0.8)
    love.graphics.printf(client.name, 0, 180, 1280, "center")
    love.graphics.setColor(0.85, 0.8, 0.75)
    love.graphics.printf(client.context, 220, 250, 840, "center")
    self.begin_button:draw()
  end

  function state:mousepressed(x, y, button)
    self.begin_button:mousepressed(x, y, button)
  end

  function state:mousereleased(x, y, button)
    self.begin_button:mousereleased(x, y, button)
  end

  return state
end
