-- Card object with drag-drop state machine
-- States: IDLE, HOVERING, HOLDING, MOVING
local Tween = require("src.fx.tween")
local util = require("src.lib.util")

local Card = {}
Card.__index = Card

-- Global mutual exclusion counters
Card.hovering_count = 0
Card.holding_count = 0

-- States
Card.IDLE = "idle"
Card.HOVERING = "hovering"
Card.HOLDING = "holding"
Card.MOVING = "moving"

local HOVER_DISTANCE = 30
local HOVER_SCALE = 1.15
local HOVER_DURATION = 0.12
local MOVE_SPEED = 1200
local DRAG_Z_OFFSET = 1000

local allowed_transitions = {
    idle = {hovering = true, holding = true, moving = true},
    hovering = {idle = true, holding = true, moving = true},
    holding = {idle = true, moving = true},
    moving = {idle = true},
}

function Card.new(name, card_data)
    local self = setmetatable({}, Card)
    self.card_name = name
    self.card_info = card_data:get_info(name) or {}
    self.texture = card_data:get_texture(name, false)
    self.reversed_texture = card_data:get_texture(name, true)
    self.back_texture = card_data.back_texture
    self.card_size = {x = card_data.card_size.x, y = card_data.card_size.y}

    self.x = 0
    self.y = 0
    self.rotation = 0
    self.scale_x = 1
    self.scale_y = 1
    self.z_index = 0
    self.stored_z_index = 0

    self.show_front = true
    self.is_reversed = false
    self.can_interact = true
    self.state = Card.IDLE

    -- Hover/drag state
    self.is_mouse_inside = false
    self.original_x = 0
    self.original_y = 0
    self.original_rotation = 0
    self.original_scale_x = 1
    self.original_scale_y = 1
    self.hover_x = 0
    self.hover_y = 0
    self.hold_offset_x = 0
    self.hold_offset_y = 0

    -- Move target
    self.target_x = 0
    self.target_y = 0
    self.target_rotation = 0

    -- Container reference
    self.container = nil

    -- Tweens
    self.hover_tween = nil
    self.move_tween = nil

    return self
end

function Card:change_state(new_state)
    if new_state == self.state then return true end
    if not allowed_transitions[self.state] or not allowed_transitions[self.state][new_state] then
        return false
    end

    self:_exit_state(self.state)
    local old = self.state
    self.state = new_state
    self:_enter_state(new_state, old)
    return true
end

function Card:_enter_state(state, from_state)
    if state == Card.IDLE then
        self.z_index = self.stored_z_index
    elseif state == Card.HOVERING then
        Card.hovering_count = Card.hovering_count + 1
        self.z_index = self.stored_z_index + DRAG_Z_OFFSET
        self:_start_hover()
    elseif state == Card.HOLDING then
        Card.holding_count = Card.holding_count + 1
        if from_state == Card.HOVERING then
            self:_preserve_hover()
        end
        local mx, my = love.mouse.getPosition()
        self.hold_offset_x = mx - self.x
        self.hold_offset_y = my - self.y
        self.z_index = self.stored_z_index + DRAG_Z_OFFSET
        self.rotation = self.original_rotation
        if self.container then
            self.container:hold_card(self)
        end
    elseif state == Card.MOVING then
        if self.hover_tween and self.hover_tween:is_running() then
            self.hover_tween:kill()
            self.hover_tween = nil
        end
        self.z_index = self.stored_z_index + DRAG_Z_OFFSET
    end
end

function Card:_exit_state(state)
    if state == Card.HOVERING then
        Card.hovering_count = Card.hovering_count - 1
        self.z_index = self.stored_z_index
        self:_stop_hover()
    elseif state == Card.HOLDING then
        Card.holding_count = Card.holding_count - 1
        self.z_index = self.stored_z_index
        self.scale_x = self.original_scale_x
        self.scale_y = self.original_scale_y
        self.rotation = self.original_rotation
    elseif state == Card.MOVING then
        -- nothing extra
    end
end

function Card:_start_hover()
    if self.hover_tween and self.hover_tween:is_running() then
        self.hover_tween:kill()
        self.x = self.original_x
        self.y = self.original_y
        self.scale_x = self.original_scale_x
        self.scale_y = self.original_scale_y
        self.rotation = self.original_rotation
    end
    self.original_x = self.x
    self.original_y = self.y
    self.original_scale_x = self.scale_x
    self.original_scale_y = self.scale_y
    self.original_rotation = self.rotation
    self.hover_x = self.x
    self.hover_y = self.y

    local target_y = self.y - HOVER_DISTANCE

    self.hover_tween = Tween.new()
    self.hover_tween:set_parallel(true)
    self.hover_tween:tween_property(self, "y", target_y, HOVER_DURATION)
    self.hover_tween:tween_property(self, "scale_x", self.original_scale_x * HOVER_SCALE, HOVER_DURATION)
    self.hover_tween:tween_property(self, "scale_y", self.original_scale_y * HOVER_SCALE, HOVER_DURATION)
end

function Card:_stop_hover()
    if self.hover_tween and self.hover_tween:is_running() then
        self.hover_tween:kill()
    end
    self.hover_tween = Tween.new()
    self.hover_tween:set_parallel(true)
    self.hover_tween:tween_property(self, "y", self.original_y, HOVER_DURATION)
    self.hover_tween:tween_property(self, "scale_x", self.original_scale_x, HOVER_DURATION)
    self.hover_tween:tween_property(self, "scale_y", self.original_scale_y, HOVER_DURATION)
end

function Card:_preserve_hover()
    if self.hover_tween and self.hover_tween:is_running() then
        self.hover_tween:kill()
        self.hover_tween = nil
    end
end

function Card:move_to(tx, ty, rot)
    self:change_state(Card.MOVING)
    if self.move_tween and self.move_tween:is_running() then
        self.move_tween:kill()
    end
    self.target_x = tx
    self.target_y = ty
    self.target_rotation = rot

    local dist = math.sqrt((tx - self.x)^2 + (ty - self.y)^2)
    local duration = math.max(dist / MOVE_SPEED, 0.01)

    self.rotation = 0

    self.move_tween = Tween.new()
    self.move_tween:set_parallel(true)
    self.move_tween:tween_property(self, "x", tx, duration)
    self.move_tween:tween_property(self, "y", ty, duration)
    self.move_tween:set_parallel(false)
    self.move_tween:tween_callback(function()
        self.rotation = rot
        self.original_x = tx
        self.original_y = ty
        self.original_rotation = rot
        self:change_state(Card.IDLE)
        if self.container then
            self.container:on_card_move_done(self)
        end
    end)
end

function Card:return_to_original()
    self:move_to(self.original_x, self.original_y, self.original_rotation)
end

function Card:update(dt)
    if self.state == Card.HOLDING then
        local mx, my = love.mouse.getPosition()
        self.x = mx - self.hold_offset_x
        self.y = my - self.hold_offset_y
    end
end

function Card:get_rect()
    return self.x, self.y, self.card_size.x, self.card_size.y
end

function Card:contains_point(px, py)
    -- AABB hit test (rotation is small enough to ignore)
    local cx = self.x + self.card_size.x * 0.5
    local cy = self.y + self.card_size.y * 0.5
    local hw = self.card_size.x * 0.5 * self.scale_x
    local hh = self.card_size.y * 0.5 * self.scale_y
    return px >= cx - hw and px <= cx + hw and py >= cy - hh and py <= cy + hh
end

function Card:can_start_hovering()
    return Card.hovering_count == 0 and Card.holding_count == 0
end

function Card:draw()
    local tex
    if self.show_front then
        if self.is_reversed then
            tex = self.reversed_texture
        else
            tex = self.texture
        end
    else
        tex = self.back_texture
    end

    if not tex then return end

    local ox = self.card_size.x * 0.5
    local oy = self.card_size.y * 0.5
    local tw, th = tex:getDimensions()
    local sx = (self.card_size.x / tw) * self.scale_x
    local sy = (self.card_size.y / th) * self.scale_y

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(tex, self.x + ox, self.y + oy, self.rotation, sx, sy, tw * 0.5, th * 0.5)
end

return Card
