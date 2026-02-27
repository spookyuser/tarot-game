local Card = {}
Card.__index = Card

function Card.new(name, card_data)
  local self = setmetatable({}, Card)
  self.name = name
  self.data = card_data.cards[name]
  self.image = card_data.images[name]
  self.x, self.y = 0, 0
  self.target_x, self.target_y = 0, 0
  self.rotation = 0
  self.target_rotation = 0
  self.scale = 1
  self.state = "IDLE"
  self.reversed = love.math.random() < 0.35
  self.z_index = 0
  self.source = "hand"
  self.slot_index = nil
  return self
end

function Card:update(dt)
  local speed = math.min(1, dt * 12)
  self.x = self.x + (self.target_x - self.x) * speed
  self.y = self.y + (self.target_y - self.y) * speed
  self.rotation = self.rotation + (self.target_rotation - self.rotation) * speed
end

function Card:get_rect()
  local w, h = self.image:getWidth(), self.image:getHeight()
  return { x = self.x - (w * self.scale) / 2, y = self.y - (h * self.scale) / 2, w = w * self.scale, h = h * self.scale }
end

function Card:draw(show_front)
  love.graphics.setColor(1, 1, 1)
  local img = show_front and self.image or self.image
  love.graphics.draw(img, self.x, self.y, self.rotation, self.scale, self.scale, img:getWidth() / 2, img:getHeight() / 2)
  if self.reversed then
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.circle("fill", self.x + 30, self.y - 40, 8)
  end
end

return Card
