-- Simple tween system for property animation
local util = require("src.lib.util")

local Tween = {}
Tween.__index = Tween

-- Easing functions
local ease = {}

function ease.linear(t) return t end

function ease.in_cubic(t) return t * t * t end

function ease.out_cubic(t)
    t = t - 1
    return t * t * t + 1
end

function ease.in_out_cubic(t)
    if t < 0.5 then return 4 * t * t * t end
    t = t - 1
    return 1 + 4 * t * t * t
end

Tween.ease = ease

-- Active tweens registry
local active_tweens = {}

function Tween.new()
    local self = setmetatable({}, Tween)
    self.tracks = {}   -- list of {target, key, from, to, duration, elapsed, ease_fn, done}
    self.callbacks = {} -- list of {delay, fn, fired}
    self.running = true
    self.parallel = false
    self.total_elapsed = 0
    active_tweens[self] = true
    return self
end

function Tween:set_parallel(p)
    self.parallel = p
    return self
end

function Tween:tween_property(target, key, to, duration, ease_fn)
    ease_fn = ease_fn or ease.out_cubic
    local from = target[key]
    local track = {
        target = target,
        key = key,
        from = from,
        to = to,
        duration = math.max(duration, 0.001),
        elapsed = 0,
        ease_fn = ease_fn,
        done = false,
        delay = self:_current_delay(),
    }
    self.tracks[#self.tracks + 1] = track
    return self
end

function Tween:tween_callback(fn, delay)
    delay = delay or self:_current_delay()
    self.callbacks[#self.callbacks + 1] = {delay = delay, fn = fn, fired = false}
    return self
end

function Tween:_current_delay()
    if self.parallel then return 0 end
    -- Sequential: delay = sum of all previous track durations
    local d = 0
    for _, track in ipairs(self.tracks) do
        d = math.max(d, track.delay + track.duration)
    end
    return d
end

function Tween:kill()
    self.running = false
    active_tweens[self] = nil
end

function Tween:is_running()
    return self.running
end

function Tween:update(dt)
    if not self.running then return end
    self.total_elapsed = self.total_elapsed + dt

    local all_done = true
    for _, track in ipairs(self.tracks) do
        if not track.done then
            local effective_time = self.total_elapsed - track.delay
            if effective_time >= 0 then
                track.elapsed = math.min(effective_time, track.duration)
                local t = track.elapsed / track.duration
                local eased = track.ease_fn(t)
                if type(track.from) == "number" then
                    track.target[track.key] = util.lerp(track.from, track.to, eased)
                end
                if track.elapsed >= track.duration then
                    track.target[track.key] = track.to
                    track.done = true
                else
                    all_done = false
                end
            else
                all_done = false
            end
        end
    end

    for _, cb in ipairs(self.callbacks) do
        if not cb.fired and self.total_elapsed >= cb.delay then
            cb.fired = true
            cb.fn()
        end
    end

    if all_done then
        local all_callbacks_fired = true
        for _, cb in ipairs(self.callbacks) do
            if not cb.fired then all_callbacks_fired = false; break end
        end
        if all_callbacks_fired then
            self:kill()
        end
    end
end

-- Global update: call once per frame
function Tween.update_all(dt)
    for tw in pairs(active_tweens) do
        tw:update(dt)
    end
end

return Tween
