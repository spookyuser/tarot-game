local json = require("src.lib.json")

local card_data = { cards = {}, images = {} }

function card_data.load_all()
  local files = love.filesystem.getDirectoryItems("data/cards")
  for _, file in ipairs(files) do
    local body = love.filesystem.read("data/cards/" .. file)
    local decoded = json.decode(body)
    card_data.cards[decoded.name] = decoded
    card_data.images[decoded.name] = love.graphics.newImage("assets/cards/" .. decoded.front_image)
  end
  card_data.back_image = love.graphics.newImage("assets/card_back.png")
end

function card_data.build_deck_names()
  local deck = {}
  for name in pairs(card_data.cards) do
    deck[#deck + 1] = name
  end
  return deck
end

return card_data
