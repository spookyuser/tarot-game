return function(game)
  local state = {}

  function state:enter()
    game:reset_run_data()
    game.fsm:transition_to("client_loading")
  end

  return state
end
