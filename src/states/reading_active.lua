return function(game)
  local state = {}

  function state:enter() end

  function state:update()
    if game:all_slots_filled() then
      game.fsm:transition_to("resolution")
    end
  end

  function state:draw()
    game:draw_board()
  end

  function state:mousemoved(x, y)
    game.drag_manager:mousemoved(x, y)
  end

  function state:mousepressed(x, y, button)
    game.drag_manager:mousepressed(x, y, button)
  end

  function state:mousereleased(x, y, button)
    local slot_index = game.drag_manager:mousereleased(x, y, button)
    if slot_index then
      game:on_slot_filled(slot_index)
    end
  end

  return state
end
