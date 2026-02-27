local util = require("src.lib.util")

local Hand = {}
Hand.__index = Hand

function Hand.new()
  return setmetatable({ cards = {}, center_x = 640, base_y = 620 }, Hand)
end

function Hand:add_card(card)
  card.source = "hand"
  card.slot_index = nil
  self.cards[#self.cards + 1] = card
  self:layout()
end

function Hand:remove_card(card)
  for i, c in ipairs(self.cards) do
    if c == card then
      table.remove(self.cards, i)
      break
    end
  end
  self:layout()
end

function Hand:layout()
  local count = #self.cards
  if count == 0 then return end
  local spacing = 700 / (count + 1)
  for i, card in ipairs(self.cards) do
    local t = count == 1 and 0.5 or (i - 1) / (count - 1)
    card.target_x = self.center_x + (i * spacing) - 350
    card.target_y = self.base_y - (35 * 4 * t * (1 - t))
    card.target_rotation = util.lerp(math.rad(-12), math.rad(12), t)
    card.z_index = 100 + i
  end
end

return Hand
