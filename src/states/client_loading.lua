return function(game)
  local state = { timer = 0 }

  function state:enter()
    self.timer = 0.6
    game:prepare_next_client()
  end

  function state:update(dt)
    self.timer = self.timer - dt
    if self.timer <= 0 then
      game.fsm:transition_to("intro")
    end
  end

  function state:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Consulting the ether...", 0, 320, 1280, "center")
  end

  return state
end
