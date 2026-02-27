-- Minimal JSON encoder/decoder (pure Lua)
-- Supports: objects, arrays, strings, numbers, booleans, null

local json = {}

-- Decode --

local function skip_whitespace(s, i)
    local p = s:find("[^ \t\r\n]", i)
    return p or #s + 1
end

local function decode_string(s, i)
    -- i points at opening quote
    local j = i + 1
    local parts = {}
    while j <= #s do
        local c = s:sub(j, j)
        if c == '"' then
            return table.concat(parts), j + 1
        elseif c == '\\' then
            j = j + 1
            local esc = s:sub(j, j)
            if esc == '"' then parts[#parts+1] = '"'
            elseif esc == '\\' then parts[#parts+1] = '\\'
            elseif esc == '/' then parts[#parts+1] = '/'
            elseif esc == 'n' then parts[#parts+1] = '\n'
            elseif esc == 'r' then parts[#parts+1] = '\r'
            elseif esc == 't' then parts[#parts+1] = '\t'
            elseif esc == 'b' then parts[#parts+1] = '\b'
            elseif esc == 'f' then parts[#parts+1] = '\f'
            elseif esc == 'u' then
                local hex = s:sub(j+1, j+4)
                local code = tonumber(hex, 16)
                if code then
                    if code < 128 then
                        parts[#parts+1] = string.char(code)
                    else
                        parts[#parts+1] = "?"
                    end
                end
                j = j + 4
            end
            j = j + 1
        else
            parts[#parts+1] = c
            j = j + 1
        end
    end
    error("Unterminated string")
end

local decode_value -- forward declaration

local function decode_array(s, i)
    -- i points at '['
    local arr = {}
    i = skip_whitespace(s, i + 1)
    if s:sub(i, i) == ']' then return arr, i + 1 end
    while true do
        local val
        val, i = decode_value(s, i)
        arr[#arr+1] = val
        i = skip_whitespace(s, i)
        local c = s:sub(i, i)
        if c == ']' then return arr, i + 1 end
        if c ~= ',' then error("Expected ',' in array at " .. i) end
        i = skip_whitespace(s, i + 1)
    end
end

local function decode_object(s, i)
    -- i points at '{'
    local obj = {}
    i = skip_whitespace(s, i + 1)
    if s:sub(i, i) == '}' then return obj, i + 1 end
    while true do
        i = skip_whitespace(s, i)
        if s:sub(i, i) ~= '"' then error("Expected string key at " .. i) end
        local key
        key, i = decode_string(s, i)
        i = skip_whitespace(s, i)
        if s:sub(i, i) ~= ':' then error("Expected ':' at " .. i) end
        i = skip_whitespace(s, i + 1)
        local val
        val, i = decode_value(s, i)
        obj[key] = val
        i = skip_whitespace(s, i)
        local c = s:sub(i, i)
        if c == '}' then return obj, i + 1 end
        if c ~= ',' then error("Expected ',' in object at " .. i) end
        i = skip_whitespace(s, i + 1)
    end
end

function decode_value(s, i)
    i = skip_whitespace(s, i)
    local c = s:sub(i, i)
    if c == '"' then return decode_string(s, i)
    elseif c == '{' then return decode_object(s, i)
    elseif c == '[' then return decode_array(s, i)
    elseif c == 't' then
        if s:sub(i, i+3) == 'true' then return true, i + 4 end
    elseif c == 'f' then
        if s:sub(i, i+4) == 'false' then return false, i + 5 end
    elseif c == 'n' then
        if s:sub(i, i+3) == 'null' then return nil, i + 4 end
    else
        -- number
        local num_str = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
        if num_str then
            return tonumber(num_str), i + #num_str
        end
    end
    error("Unexpected character at " .. i .. ": " .. c)
end

function json.decode(s)
    if type(s) ~= "string" then return nil end
    local ok, result, _ = pcall(decode_value, s, 1)
    if ok then return result end
    return nil
end

-- Encode --

local function encode_string(s)
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    return '"' .. s .. '"'
end

local encode_value -- forward declaration

local function is_array(t)
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end

function encode_value(val, indent, level)
    local t = type(val)
    if val == nil then return "null"
    elseif t == "boolean" then return val and "true" or "false"
    elseif t == "number" then
        if val ~= val then return "null" end
        if val == math.huge or val == -math.huge then return "null" end
        if val == math.floor(val) and val >= -2^53 and val <= 2^53 then
            return string.format("%.0f", val)
        end
        return tostring(val)
    elseif t == "string" then return encode_string(val)
    elseif t == "table" then
        local parts = {}
        if is_array(val) then
            for i = 1, #val do
                parts[i] = encode_value(val[i], indent, level + 1)
            end
            if indent then
                local nl = "\n" .. string.rep(indent, level)
                local inner_nl = "\n" .. string.rep(indent, level + 1)
                return "[" .. inner_nl .. table.concat(parts, "," .. inner_nl) .. nl .. "]"
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local keys = {}
            for k in pairs(val) do keys[#keys+1] = k end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            for _, k in ipairs(keys) do
                parts[#parts+1] = encode_string(tostring(k)) .. (indent and ": " or ":") .. encode_value(val[k], indent, level + 1)
            end
            if indent then
                local nl = "\n" .. string.rep(indent, level)
                local inner_nl = "\n" .. string.rep(indent, level + 1)
                return "{" .. inner_nl .. table.concat(parts, "," .. inner_nl) .. nl .. "}"
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

function json.encode(val, pretty)
    return encode_value(val, pretty and "  " or nil, 0)
end

return json
