-- Simple rich text renderer supporting [color=#hex], [i], [wave], [center]
local util = require("src.lib.util")

local RichText = {}
RichText.__index = RichText

function RichText.new(font, italic_font)
    local self = setmetatable({}, RichText)
    self.font = font
    self.italic_font = italic_font or font
    self.time = 0
    return self
end

function RichText:update(dt)
    self.time = self.time + dt
end

-- Parse BBCode-like text into styled spans
function RichText:parse(text)
    local spans = {}
    local pos = 1
    local color = {1, 1, 1, 1}
    local italic = false
    local wave = false
    local wave_amp = 20
    local wave_freq = 5
    local center = false

    local color_stack = {{1, 1, 1, 1}}
    local italic_stack = {false}
    local wave_stack = {false}

    while pos <= #text do
        -- Check for tags
        local tag_start = text:find("%[", pos)
        if not tag_start then
            -- Rest is plain text
            if pos <= #text then
                spans[#spans+1] = {
                    text = text:sub(pos),
                    color = {color[1], color[2], color[3], color[4]},
                    italic = italic,
                    wave = wave,
                    wave_amp = wave_amp,
                    wave_freq = wave_freq,
                    center = center,
                }
            end
            break
        end

        -- Text before tag
        if tag_start > pos then
            spans[#spans+1] = {
                text = text:sub(pos, tag_start - 1),
                color = {color[1], color[2], color[3], color[4]},
                italic = italic,
                wave = wave,
                wave_amp = wave_amp,
                wave_freq = wave_freq,
                center = center,
            }
        end

        -- Parse tag
        local tag_end = text:find("%]", tag_start)
        if not tag_end then
            spans[#spans+1] = {
                text = text:sub(tag_start),
                color = {color[1], color[2], color[3], color[4]},
                italic = italic,
                wave = wave,
                wave_amp = wave_amp,
                wave_freq = wave_freq,
                center = center,
            }
            break
        end

        local tag = text:sub(tag_start + 1, tag_end - 1)

        if tag:match("^color=#") then
            local hex = tag:match("^color=#(.+)$")
            local c = util.hex_to_color(hex)
            color = c
            color_stack[#color_stack+1] = c
        elseif tag == "/color" then
            if #color_stack > 1 then table.remove(color_stack) end
            color = color_stack[#color_stack]
        elseif tag == "i" then
            italic = true
            italic_stack[#italic_stack+1] = true
        elseif tag == "/i" then
            if #italic_stack > 1 then table.remove(italic_stack) end
            italic = italic_stack[#italic_stack]
        elseif tag:match("^wave") then
            wave = true
            local amp = tag:match("amp=([%d%.]+)")
            local freq = tag:match("freq=([%d%.]+)")
            if amp then wave_amp = tonumber(amp) end
            if freq then wave_freq = tonumber(freq) end
            wave_stack[#wave_stack+1] = true
        elseif tag == "/wave" then
            if #wave_stack > 1 then table.remove(wave_stack) end
            wave = wave_stack[#wave_stack]
        elseif tag == "center" then
            center = true
        elseif tag == "/center" then
            center = false
        end

        pos = tag_end + 1
    end

    return spans
end

function RichText:draw_text(text, x, y, max_width, default_color)
    if not text or text == "" then return 0 end

    default_color = default_color or {0.7, 0.65, 0.8, 1}
    local spans = self:parse(text)
    local cx, cy = x, y
    local line_height = self.font:getHeight() * 1.3

    for _, span in ipairs(spans) do
        local font = span.italic and self.italic_font or self.font
        local color = span.color or default_color

        -- Word wrap
        local words = {}
        for word in span.text:gmatch("[^ ]+") do
            words[#words+1] = word
        end

        for wi, word in ipairs(words) do
            local ww = font:getWidth(word)
            local space_w = font:getWidth(" ")

            -- Newlines
            if word:find("\n") then
                for part in word:gmatch("[^\n]*") do
                    if part == "" then
                        cx = x
                        cy = cy + line_height
                    else
                        if cx + font:getWidth(part) > x + max_width and cx > x then
                            cx = x
                            cy = cy + line_height
                        end
                        love.graphics.setFont(font)
                        if span.wave then
                            self:_draw_wave(part, cx, cy, color, span.wave_amp, span.wave_freq, font)
                        else
                            love.graphics.setColor(color)
                            love.graphics.print(part, cx, cy)
                        end
                        cx = cx + font:getWidth(part) + space_w
                    end
                end
            else
                if cx + ww > x + max_width and cx > x then
                    cx = x
                    cy = cy + line_height
                end

                love.graphics.setFont(font)
                if span.wave then
                    self:_draw_wave(word, cx, cy, color, span.wave_amp, span.wave_freq, font)
                else
                    love.graphics.setColor(color)
                    love.graphics.print(word, cx, cy)
                end
                cx = cx + ww + space_w
            end
        end

        -- Handle raw newlines in text
        if span.text:find("\n\n") then
            cx = x
            cy = cy + line_height
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    return cy - y + line_height
end

function RichText:_draw_wave(text, x, y, color, amp, freq, font)
    love.graphics.setColor(color)
    love.graphics.setFont(font)
    for i = 1, #text do
        local ch = text:sub(i, i)
        local offset_y = amp * 0.05 * math.sin(freq * self.time + i * 0.5)
        local ch_x = x + font:getWidth(text:sub(1, i-1))
        love.graphics.print(ch, ch_x, y + offset_y)
    end
end

return RichText
