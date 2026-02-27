-- Left sidebar: portrait, client name, progress, deck count
local util = require("src.lib.util")

local Sidebar = {}
Sidebar.__index = Sidebar

function Sidebar.new(x, y, w, h)
    local self = setmetatable({}, Sidebar)
    self.x = x
    self.y = y
    self.w = w
    self.h = h

    self.client_name = ""
    self.client_counter = ""
    self.deck_count = 0
    self.portrait = nil
    self.progress = {false, false, false}
    return self
end

function Sidebar:update_client(name, number, portrait)
    self.client_name = name
    self.client_counter = "Client #" .. number
    self.portrait = portrait
end

function Sidebar:update_deck_count(remaining)
    self.deck_count = remaining
end

function Sidebar:update_progress(filled)
    for i = 1, 3 do
        self.progress[i] = filled[i] or false
    end
end

function Sidebar:draw(font, small_font)
    local cx = self.x + self.w * 0.5

    -- Portrait
    if self.portrait then
        local pw, ph = self.portrait:getDimensions()
        local scale = math.min(64 / pw, 64 / ph)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.portrait, cx - (pw * scale) * 0.5, self.y + 30, 0, scale, scale)
    end

    -- Client name
    love.graphics.setFont(font)
    love.graphics.setColor(0.85, 0.7, 0.4, 1)
    local nw = font:getWidth(self.client_name)
    love.graphics.print(self.client_name, cx - nw * 0.5, self.y + 110)

    -- Client counter
    love.graphics.setFont(small_font)
    love.graphics.setColor(0.7, 0.6, 0.8, 0.8)
    local cw = small_font:getWidth(self.client_counter)
    love.graphics.print(self.client_counter, cx - cw * 0.5, self.y + 140)

    -- Progress icons
    local icon_y = self.y + 200
    for i = 1, 3 do
        local ix = cx - 40 + (i - 1) * 30
        if self.progress[i] then
            love.graphics.setColor(0.85, 0.7, 0.4, 1)
        else
            love.graphics.setColor(0.3, 0.25, 0.4, 0.5)
        end
        love.graphics.circle("fill", ix, icon_y, 8)
    end

    -- Deck count
    love.graphics.setFont(small_font)
    love.graphics.setColor(0.7, 0.6, 0.8, 0.7)
    local deck_text = self.deck_count .. " remaining"
    local dw = small_font:getWidth(deck_text)
    love.graphics.print(deck_text, cx - dw * 0.5, self.y + 260)

    love.graphics.setColor(1, 1, 1, 1)
end

return Sidebar
