-- Reading slot: accepts exactly 1 card
local Card = require("src.cards.card")

local Slot = {}
Slot.__index = Slot

function Slot.new(x, y, w, h, index)
    local self = setmetatable({}, Slot)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.index = index
    self.card = nil
    self.enabled = false
    return self
end

function Slot:check_drop(cards, mx, my)
    if not self.enabled then return false end
    if self.card ~= nil then return false end
    if #cards ~= 1 then return false end
    return self:contains_point(mx, my)
end

function Slot:place_card(card)
    self.card = card
    card.container = self
    card.can_interact = false
    card:move_to(self.x, self.y, 0)
end

function Slot:contains_point(px, py)
    return px >= self.x and px <= self.x + self.w
       and py >= self.y and py <= self.y + self.h
end

function Slot:hold_card(card)
    -- nothing needed
end

function Slot:on_card_move_done(card)
    -- nothing needed
end

function Slot:clear()
    self.card = nil
end

function Slot:get_top_card()
    return self.card
end

return Slot
