local function new_state()
  return {
    phase = "init",
    session = {
      encounters = {},
      encounter_index = 0,
    },
    encounter = {
      client = nil,
      slots = {
        { card = nil, text = "", filled = false },
        { card = nil, text = "", filled = false },
        { card = nil, text = "", filled = false },
      },
      active_slot = 1,
    },
  }
end

return { new = new_state }
