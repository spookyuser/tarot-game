-- Drag-and-drop routing: hit testing, hover tracking, drop resolution
local Card = require("src.cards.card")

local DragManager = {}
DragManager.__index = DragManager

function DragManager.new()
    local self = setmetatable({}, DragManager)
    self.containers = {}   -- ordered list: slots first, then hand
    self.all_cards = {}     -- all cards for hit testing (updated each frame)
    self.hovered_card = nil
    self.held_card = nil
    return self
end

function DragManager:set_containers(containers)
    self.containers = containers
end

function DragManager:update_card_list(cards)
    -- Sort by z_index descending for hit testing (topmost first)
    self.all_cards = {}
    for _, c in ipairs(cards) do
        self.all_cards[#self.all_cards + 1] = c
    end
    table.sort(self.all_cards, function(a, b) return a.z_index > b.z_index end)
end

function DragManager:update(dt)
    local mx, my = love.mouse.getPosition()

    -- Update card state machines
    for _, card in ipairs(self.all_cards) do
        card:update(dt)
    end

    -- Hover detection (only when nothing is held)
    if not self.held_card then
        local new_hover = nil
        for _, card in ipairs(self.all_cards) do
            if card.can_interact and card.state ~= Card.MOVING and card:contains_point(mx, my) then
                new_hover = card
                break
            end
        end

        if new_hover ~= self.hovered_card then
            -- Exit old hover
            if self.hovered_card and self.hovered_card.state == Card.HOVERING then
                self.hovered_card:change_state(Card.IDLE)
            end
            -- Enter new hover
            if new_hover and new_hover:can_start_hovering() then
                new_hover:change_state(Card.HOVERING)
                self.hovered_card = new_hover
            else
                self.hovered_card = nil
            end
        end
    end
end

function DragManager:mousepressed(mx, my, button)
    if button ~= 1 then return end

    -- Find topmost card under mouse
    for _, card in ipairs(self.all_cards) do
        if card.can_interact and card.state ~= Card.MOVING and card:contains_point(mx, my) then
            if card.state == Card.HOVERING then
                card:change_state(Card.HOLDING)
            elseif card.state == Card.IDLE and card:can_start_hovering() then
                card:change_state(Card.HOLDING)
            end
            if card.state == Card.HOLDING then
                self.held_card = card
            end
            return
        end
    end
end

function DragManager:mousereleased(mx, my, button)
    if button ~= 1 then return end

    local card = self.held_card
    if not card then return end
    self.held_card = nil

    card:change_state(Card.IDLE)

    -- Try to drop on each container (slots first, then hand)
    for _, container in ipairs(self.containers) do
        if container:check_drop({card}, mx, my) then
            -- Remove from old container
            if card.container and card.container ~= container then
                if card.container.remove_card then
                    card.container:remove_card(card)
                end
            end
            -- Add to new container
            if container.place_card then
                container:place_card(card)
            elseif container.move_cards then
                container:move_cards({card})
            end
            return
        end
    end

    -- No valid drop target - return card to original position
    card:return_to_original()
end

function DragManager:get_held_card()
    return self.held_card
end

function DragManager:get_all_cards_sorted_for_draw()
    local sorted = {}
    for _, c in ipairs(self.all_cards) do
        sorted[#sorted + 1] = c
    end
    table.sort(sorted, function(a, b) return a.z_index < b.z_index end)
    return sorted
end

return DragManager
