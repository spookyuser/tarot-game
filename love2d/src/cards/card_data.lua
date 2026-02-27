-- Loads card JSON definitions and PNG assets, builds the 78-card deck
local json = require("src.lib.json")

local CardData = {}
CardData.__index = CardData

function CardData.new()
    local self = setmetatable({}, CardData)
    self.cards = {}        -- name -> {info, texture, reversed_texture}
    self.back_texture = nil
    self.card_size = {x = 110, y = 159}
    return self
end

function CardData:load_all()
    self.back_texture = love.graphics.newImage("assets/card_back.png")
    self.back_texture:setFilter("nearest", "nearest")

    local data_dir = "assets/data"
    local files = love.filesystem.getDirectoryItems(data_dir)
    for _, filename in ipairs(files) do
        if filename:match("%.json$") then
            local card_name = filename:gsub("%.json$", "")
            local path = data_dir .. "/" .. filename
            local content = love.filesystem.read(path)
            if content then
                local info = json.decode(content)
                if info then
                    local img_path = "assets/cards/" .. card_name .. ".png"
                    local ok, tex = pcall(love.graphics.newImage, img_path)
                    if ok and tex then
                        tex:setFilter("nearest", "nearest")
                        -- Create reversed (flipped) texture
                        local img_data = tex:getData()
                        if img_data then
                            local w, h = img_data:getDimensions()
                            local reversed_data = love.image.newImageData(w, h)
                            for py = 0, h - 1 do
                                for px = 0, w - 1 do
                                    local r, g, b, a = img_data:getPixel(w - 1 - px, h - 1 - py)
                                    reversed_data:setPixel(px, py, r, g, b, a)
                                end
                            end
                            local reversed_tex = love.graphics.newImage(reversed_data)
                            reversed_tex:setFilter("nearest", "nearest")
                            self.cards[card_name] = {
                                info = info,
                                texture = tex,
                                reversed_texture = reversed_tex,
                            }
                        end
                    end
                end
            end
        end
    end
end

function CardData:get_info(card_name)
    local entry = self.cards[card_name]
    return entry and entry.info or nil
end

function CardData:get_texture(card_name, reversed)
    local entry = self.cards[card_name]
    if not entry then return self.back_texture end
    if reversed then
        return entry.reversed_texture or entry.texture
    end
    return entry.texture
end

function CardData:get_all_names()
    local names = {}
    -- Major arcana
    local major = {
        "the_fool", "the_magician", "the_high_priestess", "the_empress",
        "the_emperor", "the_hierophant", "the_lovers", "the_chariot",
        "the_strength", "the_hermit", "the_wheel_of_fortune", "the_justice",
        "the_hanged_man", "the_death", "the_temperance", "the_devil",
        "the_tower", "the_stars", "the_moon", "the_sun",
        "the_judgement", "the_world"
    }
    for _, name in ipairs(major) do names[#names+1] = name end

    local suits = {"cups", "gold", "swords", "wands"}
    local values = {
        "ace", "two", "three", "four", "five", "six", "seven",
        "eight", "nine", "ten", "page", "knight", "queen", "king"
    }
    for _, suit in ipairs(suits) do
        for _, val in ipairs(values) do
            names[#names+1] = val .. "_of_" .. suit
        end
    end
    return names
end

return CardData
