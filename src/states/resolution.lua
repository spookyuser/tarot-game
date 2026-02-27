local Button = require("src.ui.button")

return function(game)
  local state = { timer = 2.5, next_button = nil, revealed = false }

  function state:enter()
    self.timer = 2.5
    self.revealed = false
    self.next_button = Button.new("Next Client", 540, 620, 200, 50, function()
      if game:is_run_complete() then
        game.fsm:transition_to("game_end")
      else
        game.fsm:transition_to("client_loading")
      end
    end)
    game:record_encounter()
  end

  function state:update(dt)
    self.timer = self.timer - dt
    if self.timer <= 0 then self.revealed = true end
  end

  function state:draw()
    game:draw_board()
    love.graphics.setColor(0.12, 0.1, 0.14, 0.92)
    love.graphics.rectangle("fill", 120, 120, 1040, 520, 12, 12)
    love.graphics.setColor(0.96, 0.92, 0.8)
    love.graphics.printf("The Reading", 120, 150, 1040, "center")
    if self.revealed then
      local y = 210
      for i, slot in ipairs(game.slots) do
        love.graphics.setColor(0.9, 0.86, 0.76)
        love.graphics.printf(string.format("%d) %s", i, slot.reading), 170, y, 940, "left")
        y = y + 110
      end
      self.next_button:draw()
    else
      love.graphics.printf("Interpreting the cards...", 120, 360, 1040, "center")
    end
  end

  function state:mousepressed(x, y, button)
    if self.revealed then self.next_button:mousepressed(x, y, button) end
  end

  function state:mousereleased(x, y, button)
    if self.revealed then self.next_button:mousereleased(x, y, button) end
  end

  return state
end
