-- Sound manager: ambient, SFX, reading music

local SoundManager = {}
SoundManager.__index = SoundManager

function SoundManager.new()
    local self = setmetatable({}, SoundManager)
    self.ambient = nil
    self.shuffle = nil
    self.card_drop = nil
    self.reading_tracks = {}
    self.current_reading = nil
    return self
end

function SoundManager:load()
    local function try_load(path, source_type)
        if love.filesystem.getInfo(path) then
            local src = love.audio.newSource(path, source_type or "stream")
            return src
        end
        return nil
    end

    self.ambient = try_load("assets/audio/ambience.mp3", "stream")
    if self.ambient then self.ambient:setLooping(true) end

    self.shuffle = try_load("assets/audio/card_shuffle.mp3", "static")
    self.card_drop = try_load("assets/audio/card_drop.mp3", "static")

    local reading_files = {
        cups = "assets/audio/reading_happy.mp3",
        swords = "assets/audio/reading_death.mp3",
        wands = "assets/audio/reading_mystery.mp3",
        gold = "assets/audio/reading_sad.mp3",
        major = "assets/audio/reading_mystery.mp3",
    }

    for suit, path in pairs(reading_files) do
        local src = try_load(path, "stream")
        if src then
            src:setLooping(true)
            self.reading_tracks[suit] = src
        end
    end
end

function SoundManager:play_ambient()
    if self.ambient then
        self.ambient:play()
    end
end

function SoundManager:stop_ambient()
    if self.ambient then
        self.ambient:stop()
    end
end

function SoundManager:play_shuffle()
    if self.shuffle then
        self.shuffle:stop()
        self.shuffle:play()
    end
end

function SoundManager:play_card_drop()
    if self.card_drop then
        self.card_drop:stop()
        self.card_drop:play()
    end
end

function SoundManager:play_reading(suit)
    local key = (suit or "major"):lower()
    if not self.reading_tracks[key] then key = "major" end
    local track = self.reading_tracks[key]
    if not track then return end

    if self.current_reading and self.current_reading ~= track then
        self.current_reading:stop()
    end

    self.current_reading = track
    if not track:isPlaying() then
        track:play()
        -- Seek to middle for variety
        local dur = track:getDuration()
        if dur > 0 then
            track:seek(dur * 0.5)
        end
    end
end

function SoundManager:stop_reading()
    if self.current_reading then
        self.current_reading:stop()
        self.current_reading = nil
    end
end

return SoundManager
