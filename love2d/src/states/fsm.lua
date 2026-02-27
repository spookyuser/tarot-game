-- Simple finite state machine for game phases
local FSM = {}
FSM.__index = FSM

function FSM.new(states)
    local self = setmetatable({}, FSM)
    self.states = states  -- name -> state table with enter/exit/update/draw/mousepressed/mousereleased
    self.current = nil
    self.current_name = nil
    self.game = nil       -- set by game controller
    return self
end

function FSM:transition(name)
    if self.current and self.current.exit then
        self.current.exit(self.game)
    end
    self.current_name = name
    self.current = self.states[name]
    if self.current and self.current.enter then
        self.current.enter(self.game)
    end
end

function FSM:update(dt)
    if self.current and self.current.update then
        self.current.update(self.game, dt)
    end
end

function FSM:draw()
    if self.current and self.current.draw then
        self.current.draw(self.game)
    end
end

function FSM:mousepressed(x, y, button)
    if self.current and self.current.mousepressed then
        self.current.mousepressed(self.game, x, y, button)
    end
end

function FSM:mousereleased(x, y, button)
    if self.current and self.current.mousereleased then
        self.current.mousereleased(self.game, x, y, button)
    end
end

return FSM
