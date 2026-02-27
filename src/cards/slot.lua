local Slot = {}
Slot.__index = Slot

function Slot.new(index, x, y)
  return setmetatable({
    index = index,
    x = x,
    y = y,
    w = 140,
    h = 220,
    card = nil,
    reading = "",
    loading = false,
    enabled = index == 1,
  }, Slot)
end

function Slot:accepts(card)
  return self.enabled and self.card == nil and card.source == "hand"
end

function Slot:contains(x, y)
  return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

function Slot:place(card)
  self.card = card
  card.source = "slot"
  card.slot_index = self.index
  card.target_x = self.x + self.w / 2
  card.target_y = self.y + self.h / 2
  card.target_rotation = 0
  card.z_index = 400 + self.index
end

function Slot:draw()
  love.graphics.setColor(self.enabled and {0.8, 0.74, 0.6, 0.45} or {0.4, 0.34, 0.34, 0.25})
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 8, 8)
  love.graphics.setColor(0.15, 0.12, 0.14)
  love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 8, 8)
end

return Slot
