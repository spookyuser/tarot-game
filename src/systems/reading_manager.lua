local ReadingManager = {}
ReadingManager.__index = ReadingManager

local slot_labels = { "Past", "Present", "Future" }

function ReadingManager.new()
  return setmetatable({}, ReadingManager)
end

function ReadingManager:generate(card, slot_index)
  local orientation = card.reversed and "reversed" or "upright"
  local outcome = card.data.outcome or "mixed"
  return string.format("%s — %s appears %s in the %s. Theme: %s.", card.data.name, slot_labels[slot_index], orientation, string.lower(slot_labels[slot_index]), outcome)
end

return ReadingManager
