-- Portrait loader: loads sprite sheets, returns single-frame atlas textures
local util = require("src.lib.util")

local Portraits = {}
Portraits.__index = Portraits

local FALLBACK_PATHS = {
    "assets/portraits/MiniPeasant.png",
    "assets/portraits/MiniWorker.png",
    "assets/portraits/MiniVillagerMan.png",
    "assets/portraits/MiniOldMan.png",
    "assets/portraits/MiniOldWoman.png",
    "assets/portraits/MiniNobleWoman.png",
    "assets/portraits/MiniPrincess.png",
    "assets/portraits/MiniQueen.png",
}

local NAMED_PORTRAITS = {
    ["Maria the Widow"] = "assets/portraits/MiniVillagerWoman.png",
    ["The Stranger"] = "assets/portraits/MiniNobleMan.png",
}

local FRAME_SIZE = 32

function Portraits.new()
    local self = setmetatable({}, Portraits)
    self.textures = {}  -- path -> {image, quad}
    return self
end

function Portraits:load_all()
    local all_paths = {}
    for _, path in pairs(NAMED_PORTRAITS) do
        all_paths[path] = true
    end
    for _, path in ipairs(FALLBACK_PATHS) do
        all_paths[path] = true
    end

    for path in pairs(all_paths) do
        if love.filesystem.getInfo(path) then
            local img = love.graphics.newImage(path)
            img:setFilter("nearest", "nearest")
            local iw, ih = img:getDimensions()
            local quad = love.graphics.newQuad(0, 0, math.min(FRAME_SIZE, iw), math.min(FRAME_SIZE, ih), iw, ih)
            self.textures[path] = {image = img, quad = quad}
        end
    end
end

function Portraits:get_portrait(client_name)
    -- Check named portraits first
    if NAMED_PORTRAITS[client_name] then
        local path = NAMED_PORTRAITS[client_name]
        if self.textures[path] then
            return self.textures[path].image
        end
    end

    -- Fallback based on name hash
    local hash = util.string_hash(client_name)
    local idx = (hash % #FALLBACK_PATHS) + 1
    local path = FALLBACK_PATHS[idx]
    if self.textures[path] then
        return self.textures[path].image
    end

    return nil
end

return Portraits
