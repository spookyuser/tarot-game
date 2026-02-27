local json = {}

local function decode_error(str, idx, msg)
  error(string.format("JSON decode error at %d: %s (%s)", idx, msg, str:sub(math.max(1, idx - 10), idx + 10)))
end

local function skip_ws(str, i)
  local _, j = str:find("^[ \n\r\t]+", i)
  return (j or i - 1) + 1
end

local parse_value

local function parse_string(str, i)
  i = i + 1
  local out = {}
  while i <= #str do
    local c = str:sub(i, i)
    if c == '"' then
      return table.concat(out), i + 1
    elseif c == "\\" then
      local n = str:sub(i + 1, i + 1)
      local map = {['"']='"', ["\\"]="\\", ["/"]="/", b="\b", f="\f", n="\n", r="\r", t="\t"}
      if map[n] then
        out[#out + 1] = map[n]
        i = i + 2
      else
        decode_error(str, i, "invalid escape")
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  decode_error(str, i, "unterminated string")
end

local function parse_number(str, i)
  local num = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
  if not num or num == "" or num == "-" then
    decode_error(str, i, "invalid number")
  end
  return tonumber(num), i + #num
end

local function parse_array(str, i)
  i = i + 1
  local out = {}
  i = skip_ws(str, i)
  if str:sub(i, i) == "]" then
    return out, i + 1
  end
  while true do
    local value
    value, i = parse_value(str, i)
    out[#out + 1] = value
    i = skip_ws(str, i)
    local c = str:sub(i, i)
    if c == "]" then
      return out, i + 1
    elseif c == "," then
      i = skip_ws(str, i + 1)
    else
      decode_error(str, i, "expected ',' or ']'")
    end
  end
end

local function parse_object(str, i)
  i = i + 1
  local out = {}
  i = skip_ws(str, i)
  if str:sub(i, i) == "}" then
    return out, i + 1
  end
  while true do
    if str:sub(i, i) ~= '"' then
      decode_error(str, i, "expected string key")
    end
    local key
    key, i = parse_string(str, i)
    i = skip_ws(str, i)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':'")
    end
    i = skip_ws(str, i + 1)
    out[key], i = parse_value(str, i)
    i = skip_ws(str, i)
    local c = str:sub(i, i)
    if c == "}" then
      return out, i + 1
    elseif c == "," then
      i = skip_ws(str, i + 1)
    else
      decode_error(str, i, "expected ',' or '}'")
    end
  end
end

parse_value = function(str, i)
  i = skip_ws(str, i)
  local c = str:sub(i, i)
  if c == '"' then
    return parse_string(str, i)
  elseif c == "{" then
    return parse_object(str, i)
  elseif c == "[" then
    return parse_array(str, i)
  elseif c == "-" or c:match("%d") then
    return parse_number(str, i)
  elseif str:sub(i, i + 3) == "true" then
    return true, i + 4
  elseif str:sub(i, i + 4) == "false" then
    return false, i + 5
  elseif str:sub(i, i + 3) == "null" then
    return nil, i + 4
  end
  decode_error(str, i, "unexpected token")
end

function json.decode(str)
  local value, idx = parse_value(str, 1)
  idx = skip_ws(str, idx)
  if idx <= #str then
    decode_error(str, idx, "trailing characters")
  end
  return value
end

return json
