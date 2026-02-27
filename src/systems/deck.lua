local util = require("src.lib.util")

local Deck = {}
Deck.__index = Deck

function Deck.new(names)
  local self = setmetatable({}, Deck)
  self.remaining = util.shuffle(names)
  self.discard = {}
  return self
end

function Deck:draw_one()
  if #self.remaining == 0 then return nil end
  local card = table.remove(self.remaining)
  self.discard[#self.discard + 1] = card
  return card
end

function Deck:draw_many(n)
  local out = {}
  for _ = 1, n do
    local c = self:draw_one()
    if not c then break end
    out[#out + 1] = c
  end
  return out
end

return Deck
