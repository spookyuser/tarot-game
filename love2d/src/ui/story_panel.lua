-- Right-side story panel: title, client context, reading text

local StoryPanel = {}
StoryPanel.__index = StoryPanel

local SLOT_COLORS = {
    {0.88, 0.72, 0.78, 1},   -- #e0b8c8
    {0.72, 0.88, 0.78, 1},   -- #b8e0c8
    {0.72, 0.78, 0.88, 1},   -- #b8c8e0
}

local HOVER_COLORS = {
    {0.63, 0.47, 0.53, 1},   -- #a07888
    {0.47, 0.63, 0.53, 1},   -- #78a088
    {0.47, 0.53, 0.63, 1},   -- #7888a0
}

StoryPanel.SLOT_COLORS = SLOT_COLORS
StoryPanel.HOVER_COLORS = HOVER_COLORS

function StoryPanel.new(x, y, w, h)
    local self = setmetatable({}, StoryPanel)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.title = ""
    self.context = ""
    return self
end

function StoryPanel:draw(font, small_font, richtext, slot_filled, slot_readings, active_slot, hover_slot, hover_text)
    -- Panel background overlay
    love.graphics.setColor(0.06, 0.03, 0.12, 0.85)
    love.graphics.rectangle("fill", self.x + 6, self.y + 6, self.w - 12, self.h - 12)

    -- Title
    love.graphics.setFont(font)
    love.graphics.setColor(0.85, 0.7, 0.4, 1)
    local tw = font:getWidth(self.title)
    love.graphics.print(self.title, self.x + (self.w - tw) * 0.5, self.y + 24)

    -- Divider
    love.graphics.setColor(0.85, 0.7, 0.4, 0.3)
    love.graphics.rectangle("fill", self.x + 40, self.y + 62, self.w - 80, 1)

    -- Client context
    if self.context and self.context ~= "" then
        love.graphics.setFont(small_font)
        love.graphics.setColor(0.8, 0.75, 0.9, 1)
        love.graphics.printf(self.context, self.x + 24, self.y + 74, self.w - 48, "left")
    end

    -- Readings
    local ry = self.y + 280
    love.graphics.setFont(small_font)
    for i = 1, 3 do
        local reading = slot_readings and slot_readings[i] or ""
        if reading ~= "" then
            local color
            if slot_filled and slot_filled[i] then
                color = SLOT_COLORS[i]
            elseif i == hover_slot and hover_text and hover_text ~= "" then
                color = HOVER_COLORS[i]
            else
                color = {0.29, 0.23, 0.38, 1}
            end
            love.graphics.setColor(color)

            if reading == "..." then
                love.graphics.print("...", self.x + 24, ry)
            else
                love.graphics.printf(reading, self.x + 24, ry, self.w - 48, "left")
            end
        elseif i <= (active_slot or 1) then
            love.graphics.setColor(0.29, 0.23, 0.38, 1)
            love.graphics.print("...", self.x + 24, ry)
        end
        ry = ry + 80
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return StoryPanel
