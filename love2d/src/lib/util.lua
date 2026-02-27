local util = {}

function util.deep_copy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = util.deep_copy(v)
    end
    return copy
end

function util.shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function util.point_in_rect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

function util.string_hash(s)
    local h = 0
    for i = 1, #s do
        h = (h * 31 + s:byte(i)) % 2147483647
    end
    return h
end

function util.lerp(a, b, t)
    return a + (b - a) * t
end

function util.clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

function util.hex_to_color(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    local a = 1
    if #hex >= 8 then
        a = tonumber(hex:sub(7, 8), 16) / 255
    end
    return {r, g, b, a}
end

function util.humanize_token(s)
    if not s or s == "" then return s end
    local words = {}
    for part in s:gmatch("[^_]+") do
        if #part > 0 then
            words[#words+1] = part:sub(1, 1):upper() .. part:sub(2):lower()
        end
    end
    return table.concat(words, " ")
end

function util.strip_markdown_fence(text)
    if not text:find("^```") then return text end
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        lines[#lines+1] = line
    end
    if #lines > 0 and lines[1]:find("^```") then
        table.remove(lines, 1)
    end
    if #lines > 0 and lines[#lines]:match("^%s*```") then
        table.remove(lines, #lines)
    end
    return table.concat(lines, "\n")
end

return util
