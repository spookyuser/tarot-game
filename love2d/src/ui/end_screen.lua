-- End screen: scrollable encounter summary
local util = require("src.lib.util")

local EndScreen = {}
EndScreen.__index = EndScreen

function EndScreen.new()
    local self = setmetatable({}, EndScreen)
    self.encounters = {}
    self.scroll_y = 0
    self.card_data = nil
    self.portraits = nil
    return self
end

function EndScreen:populate(encounters, card_data, portraits)
    self.encounters = encounters or {}
    self.card_data = card_data
    self.portraits = portraits
    self.scroll_y = 0
end

function EndScreen:draw(font, small_font)
    -- Overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Panel background
    local px, py = 640 - 340, 360 - 240
    local pw, ph = 680, 480
    love.graphics.setColor(0.06, 0.03, 0.12, 0.92)
    love.graphics.rectangle("fill", px + 8, py + 8, pw - 16, ph - 16, 4, 4)
    love.graphics.setColor(0.85, 0.7, 0.4, 0.6)
    love.graphics.rectangle("line", px, py, pw, ph, 4, 4)

    -- Title
    love.graphics.setFont(font)
    love.graphics.setColor(0.85, 0.7, 0.4, 1)
    love.graphics.printf("The Reading Concludes", px, py + 20, pw, "center")

    -- Encounters list
    love.graphics.setFont(small_font)
    local ey = py + 70 - self.scroll_y

    for _, encounter in ipairs(self.encounters) do
        local client = encounter.client or {}
        local client_name = client.name or "Unknown"
        local slots = encounter.slots or {}

        -- Portrait
        if self.portraits then
            local portrait = self.portraits:get_portrait(client_name)
            if portrait then
                local ppw, pph = portrait:getDimensions()
                local scale = math.min(48 / ppw, 48 / pph)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(portrait, px + 40, ey, 0, scale, scale)
            end
        end

        -- Name
        love.graphics.setColor(0.85, 0.7, 0.4, 1)
        love.graphics.print(client_name, px + 100, ey + 10)

        -- Cards
        local card_x = px + 300
        for _, slot in ipairs(slots) do
            local card_name = slot.card or ""
            if card_name ~= "" and self.card_data then
                local reversed = (slot.orientation == "reversed")
                local tex = self.card_data:get_texture(card_name, reversed)
                if tex then
                    local tw, th = tex:getDimensions()
                    local sx = 36 / tw
                    local sy = 52 / th
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(tex, card_x, ey, 0, sx, sy)
                end
            end
            card_x = card_x + 44
        end

        ey = ey + 60
    end

    -- Play Again button drawn by game controller
    love.graphics.setColor(1, 1, 1, 1)
end

function EndScreen:wheelmoved(x, y)
    self.scroll_y = math.max(0, self.scroll_y - y * 30)
end

return EndScreen
