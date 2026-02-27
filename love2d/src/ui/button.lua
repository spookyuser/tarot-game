-- Simple button with texture states and click detection
local NinePatch = require("src.ui.ninepatch")

local Button = {}
Button.__index = Button

function Button.new(x, y, w, h, text, normal_tex, pressed_tex)
    local self = setmetatable({}, Button)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.text = text
    self.normal_np = normal_tex and NinePatch.new(normal_tex, 8) or nil
    self.pressed_np = pressed_tex and NinePatch.new(pressed_tex, 8) or nil
    self.is_pressed = false
    self.font = nil  -- set externally
    return self
end

function Button:contains(px, py)
    return px >= self.x and px <= self.x + self.w
       and py >= self.y and py <= self.y + self.h
end

function Button:draw(font)
    font = font or self.font or love.graphics.getFont()

    -- Background
    local np = self.is_pressed and self.pressed_np or self.normal_np
    if np then
        np:draw(self.x, self.y, self.w, self.h)
    else
        love.graphics.setColor(0.3, 0.25, 0.4, 0.8)
        love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 4, 4)
        love.graphics.setColor(0.85, 0.7, 0.4, 0.6)
        love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 4, 4)
    end

    -- Text
    love.graphics.setColor(0.85, 0.7, 0.4, 1)
    local tw = font:getWidth(self.text)
    local th = font:getHeight()
    love.graphics.setFont(font)
    love.graphics.print(self.text, self.x + (self.w - tw) * 0.5, self.y + (self.h - th) * 0.5)
    love.graphics.setColor(1, 1, 1, 1)
end

return Button
