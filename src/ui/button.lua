local Button = {}
Button.__index = Button

function Button.new(label, x, y, w, h, on_click)
  return setmetatable({ label = label, x = x, y = y, w = w, h = h, on_click = on_click, pressed = false }, Button)
end

function Button:contains(px, py)
  return px >= self.x and px <= self.x + self.w and py >= self.y and py <= self.y + self.h
end

function Button:mousepressed(x, y, button)
  if button == 1 and self:contains(x, y) then
    self.pressed = true
  end
end

function Button:mousereleased(x, y, button)
  if button == 1 and self.pressed and self:contains(x, y) and self.on_click then
    self.on_click()
  end
  self.pressed = false
end

function Button:draw()
  love.graphics.setColor(self.pressed and {0.76, 0.58, 0.32} or {0.88, 0.72, 0.4})
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 8, 8)
  love.graphics.setColor(0.1, 0.1, 0.12)
  love.graphics.printf(self.label, self.x, self.y + self.h / 2 - 10, self.w, "center")
end

return Button
