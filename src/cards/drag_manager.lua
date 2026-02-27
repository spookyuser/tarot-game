local util = require("src.lib.util")

local DragManager = {}
DragManager.__index = DragManager

function DragManager.new(get_cards, slots, hand)
  return setmetatable({
    get_cards = get_cards,
    slots = slots,
    hand = hand,
    hovered_card = nil,
    held_card = nil,
    mouse_x = 0,
    mouse_y = 0,
    hold_offset_x = 0,
    hold_offset_y = 0,
  }, DragManager)
end

function DragManager:update_hover(x, y)
  self.mouse_x, self.mouse_y = x, y
  if self.held_card then return end
  local cards = self.get_cards()
  local found
  for i = #cards, 1, -1 do
    local card = cards[i]
    if card.source == "hand" then
      if util.point_in_rect(x, y, card:get_rect()) then
        found = card
        break
      end
    end
  end
  if found ~= self.hovered_card then
    if self.hovered_card and self.hovered_card.state == "HOVERING" then self.hovered_card.state = "IDLE" end
    self.hovered_card = found
    if self.hovered_card then self.hovered_card.state = "HOVERING" end
  end
end

function DragManager:mousepressed(x, y, button)
  if button ~= 1 then return end
  self:update_hover(x, y)
  if not self.hovered_card then return end
  self.held_card = self.hovered_card
  self.held_card.state = "HOLDING"
  self.held_card.z_index = self.held_card.z_index + 1000
  self.hold_offset_x = x - self.held_card.x
  self.hold_offset_y = y - self.held_card.y
end

function DragManager:mousemoved(x, y)
  self:update_hover(x, y)
  if self.held_card then
    self.held_card.target_x = x - self.hold_offset_x
    self.held_card.target_y = y - self.hold_offset_y
    self.held_card.target_rotation = 0
    self.held_card.state = "MOVING"
  end
end

function DragManager:mousereleased(x, y, button)
  if button ~= 1 or not self.held_card then return nil end
  local card = self.held_card
  card.state = "IDLE"
  local dropped_in_slot = nil
  for _, slot in ipairs(self.slots) do
    if slot:contains(x, y) and slot:accepts(card) then
      self.hand:remove_card(card)
      slot:place(card)
      dropped_in_slot = slot.index
      break
    end
  end
  self.held_card = nil
  self.hovered_card = nil
  self.hand:layout()
  return dropped_in_slot
end

return DragManager
