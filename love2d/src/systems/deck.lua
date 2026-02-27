-- Deck management: shuffle, draw, track discard
local util = require("src.lib.util")

local Deck = {}
Deck.__index = Deck

function Deck.new()
    local self = setmetatable({}, Deck)
    self.all_card_names = {}
    self.cards = {}     -- remaining cards to draw
    self.discard = {}   -- used cards
    return self
end

function Deck:build(card_data)
    self.all_card_names = card_data:get_all_names()
end

function Deck:shuffle(hand_size)
    local pool = {}
    for _, name in ipairs(self.all_card_names) do
        pool[#pool + 1] = name
    end
    util.shuffle(pool)
    self.cards = {}
    for i = 1, math.min(hand_size, #pool) do
        self.cards[#self.cards + 1] = pool[i]
    end
    self.discard = {}
end

function Deck:draw(count)
    local drawn = {}
    for _ = 1, math.min(count, #self.cards) do
        drawn[#drawn + 1] = table.remove(self.cards)
    end
    return drawn
end

function Deck:remaining()
    return #self.cards
end

return Deck
