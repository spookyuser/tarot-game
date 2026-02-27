-- Card hover info tooltip with slide animation
local Tween = require("src.fx.tween")

local HoverPanel = {}
HoverPanel.__index = HoverPanel

function HoverPanel.new(panel_texture)
    local self = setmetatable({}, HoverPanel)
    self.x = 0
    self.y = 0
    self.w = 150
    self.h = 170
    self.alpha = 0
    self.visible = false
    self.showing = false
    self.panel_texture = panel_texture
    self.body_text = ""
    self.is_reversed = false
    self.tween = nil
    return self
end

function HoverPanel:update(card, font)
    if card then
        local info = card.card_info or {}
        local desc = info.description or "No omen appears."
        self.body_text = desc
        self.is_reversed = card.is_reversed

        if not self.showing then
            self.showing = true
            self:_slide_in(card)
        else
            self:_position(card)
        end
    else
        if self.showing then
            self.showing = false
            self:_slide_out()
        end
    end
end

function HoverPanel:_position(card)
    local cx, cy, cw, ch = card:get_rect()
    local target_x = cx - self.w - 10
    if target_x < 8 then
        target_x = cx + cw + 10
    end
    local target_y = cy
    target_x = math.max(8, math.min(target_x, 1280 - self.w - 8))
    target_y = math.max(8, math.min(target_y, 720 - self.h - 8))
    self.x = target_x
    self.y = target_y
end

function HoverPanel:_slide_in(card)
    if self.tween and self.tween:is_running() then self.tween:kill() end
    self.visible = true
    self:_position(card)
    self.alpha = 0
    self.tween = Tween.new()
    self.tween:tween_property(self, "alpha", 1, 0.15)
end

function HoverPanel:_slide_out()
    if self.tween and self.tween:is_running() then self.tween:kill() end
    self.tween = Tween.new()
    self.tween:tween_property(self, "alpha", 0, 0.1)
    self.tween:tween_callback(function() self.visible = false end)
end

function HoverPanel:hide()
    self.showing = false
    self.visible = false
    self.alpha = 0
    if self.tween and self.tween:is_running() then self.tween:kill() end
end

function HoverPanel:draw(font)
    if not self.visible or self.alpha <= 0 then return end

    love.graphics.setColor(1, 1, 1, self.alpha)

    -- Panel background
    if self.panel_texture then
        local tw, th = self.panel_texture:getDimensions()
        love.graphics.draw(self.panel_texture, self.x, self.y, 0, self.w / tw, self.h / th)
    else
        love.graphics.setColor(0.2, 0.15, 0.3, 0.9 * self.alpha)
        love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 4, 4)
    end

    -- Reversed label
    if self.is_reversed then
        love.graphics.setColor(0.87, 0.56, 0.56, self.alpha)
        love.graphics.setFont(font)
        love.graphics.printf("REVERSED", self.x, self.y - 14, self.w, "center")
    end

    -- Body text
    love.graphics.setColor(0.91, 0.86, 0.77, self.alpha)
    love.graphics.setFont(font)
    love.graphics.printf(self.body_text, self.x + 8, self.y + 8, self.w - 16, "left")

    love.graphics.setColor(1, 1, 1, 1)
end

return HoverPanel
