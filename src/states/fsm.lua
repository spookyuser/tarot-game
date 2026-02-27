local FSM = {}
FSM.__index = FSM

function FSM.new(game)
  return setmetatable({ game = game, current = nil, current_name = nil, states = {} }, FSM)
end

function FSM:register(name, state)
  self.states[name] = state
end

function FSM:transition_to(name)
  if self.current and self.current.exit then self.current:exit() end
  self.current_name = name
  self.current = assert(self.states[name], "Unknown state: " .. name)
  if self.current.enter then self.current:enter() end
end

return FSM
