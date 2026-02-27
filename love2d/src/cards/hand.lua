-- Fan-shaped card hand layout
-- Port of Godot Hand class with curve-based positioning
local Card = require("src.cards.card")

local Hand = {}
Hand.__index = Hand

function Hand.new(center_x, center_y)
    local self = setmetatable({}, Hand)
    self.center_x = center_x
    self.center_y = center_y
    self.cards = {}
    self.max_hand_size = 9
    self.max_spread = 700
    self.drop_zone = {x = 0, y = 0, w = 0, h = 0}
    return self
end

function Hand:add_card(card)
    if #self.cards >= self.max_hand_size then return false end
    card.container = self
    card.show_front = true
    card.can_interact = true
    self.cards[#self.cards + 1] = card
    self:update_layout()
    return true
end

function Hand:remove_card(card)
    for i, c in ipairs(self.cards) do
        if c == card then
            table.remove(self.cards, i)
            self:update_layout()
            return true
        end
    end
    return false
end

function Hand:get_card_count()
    return #self.cards
end

function Hand:has_card(card)
    for _, c in ipairs(self.cards) do
        if c == card then return true end
    end
    return false
end

function Hand:hold_card(card)
    -- nothing extra needed for hand
end

function Hand:on_card_move_done(card)
    -- nothing extra
end

function Hand:release_holding_cards()
    -- called when a card is released
end

function Hand:check_drop(cards, mx, my)
    if not self:_point_in_drop_zone(mx, my) then return false end
    if #cards == 1 and self:has_card(cards[1]) then
        return true -- reorder within hand
    end
    return #self.cards + #cards <= self.max_hand_size
end

function Hand:move_cards(cards)
    for _, card in ipairs(cards) do
        if not self:has_card(card) then
            card.container = self
            self.cards[#self.cards + 1] = card
        end
    end
    self:update_layout()
    return true
end

function Hand:update_layout()
    local count = #self.cards
    if count == 0 then
        self.drop_zone = {x = self.center_x - 100, y = self.center_y - 80, w = 200, h = 160}
        return
    end

    local x_min, x_max = math.huge, -math.huge
    local y_min, y_max = math.huge, -math.huge

    for i, card in ipairs(self.cards) do
        local t = 0.5
        if count > 1 then
            t = (i - 1) / (count - 1)
        end

        -- Horizontal spacing
        local spacing = self.max_spread / (count + 1)
        local tx = self.center_x + i * spacing - self.max_spread * 0.5

        -- Vertical lift: parabola peaking at 35px
        local lift = 35 * 4 * t * (1 - t)
        local ty = self.center_y - lift

        -- Rotation: linear -12 to +12 degrees
        local rot = math.rad(-12 + 24 * t)

        card.stored_z_index = 100 + i
        if card.state == Card.IDLE or card.state == Card.MOVING then
            card:move_to(tx, ty, rot)
        end
        card.show_front = true
        card.can_interact = true

        -- Track bounds for drop zone
        local cw, ch = card.card_size.x, card.card_size.y
        x_min = math.min(x_min, tx)
        x_max = math.max(x_max, tx + cw)
        y_min = math.min(y_min, ty)
        y_max = math.max(y_max, ty + ch)
    end

    self.drop_zone = {
        x = x_min,
        y = y_min,
        w = x_max - x_min,
        h = y_max - y_min,
    }
end

function Hand:clear()
    self.cards = {}
end

function Hand:_point_in_drop_zone(px, py)
    local dz = self.drop_zone
    return px >= dz.x and px <= dz.x + dz.w and py >= dz.y and py <= dz.y + dz.h
end

function Hand:get_cards_sorted_by_z()
    local sorted = {}
    for _, c in ipairs(self.cards) do sorted[#sorted + 1] = c end
    table.sort(sorted, function(a, b) return a.z_index < b.z_index end)
    return sorted
end

return Hand
