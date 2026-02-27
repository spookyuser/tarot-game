local util = {}

function util.shuffle(t)
  for i = #t, 2, -1 do
    local j = love.math.random(i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

function util.deep_copy(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for k, v in pairs(value) do
    out[util.deep_copy(k)] = util.deep_copy(v)
  end
  return out
end

function util.point_in_rect(px, py, rect)
  return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

function util.lerp(a, b, t)
  return a + (b - a) * t
end

return util
