-- Vignette + spotlight shader effect
local Tween = require("src.fx.tween")

local Vignette = {}
Vignette.__index = Vignette

local SHADER_CODE = [[
extern float intensity;
extern float softness;
extern vec4 vignette_color;
extern float spotlight_enabled;
extern vec2 viewport_size;
extern vec2 spotlight_center_px;
extern float spotlight_radius_px;
extern float spotlight_feather_px;
extern float spotlight_strength;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords - 0.5;
    float dist = length(uv) * 2.0;
    float vignette = smoothstep(1.0 - softness, 1.0, dist);
    float overlay_alpha = vignette * intensity;

    if (spotlight_enabled > 0.5) {
        vec2 pixel_pos = texture_coords * viewport_size;
        float spotlight_dist = distance(pixel_pos, spotlight_center_px);
        float spot = smoothstep(spotlight_radius_px, spotlight_radius_px + spotlight_feather_px, spotlight_dist);
        overlay_alpha = max(overlay_alpha, spot * spotlight_strength);
    }

    return vec4(vignette_color.rgb, clamp(overlay_alpha, 0.0, 1.0));
}
]]

function Vignette.new()
    local self = setmetatable({}, Vignette)
    self.shader = love.graphics.newShader(SHADER_CODE)
    self.intensity = 0
    self.softness = 0.5
    self.spotlight_enabled = 0
    self.spotlight_center_x = 640
    self.spotlight_center_y = 360
    self.spotlight_radius = 180
    self.spotlight_feather = 120
    self.spotlight_strength = 0
    self.tween = nil
    self.spotlight_tween = nil
    return self
end

function Vignette:fade_in()
    if self.tween and self.tween:is_running() then self.tween:kill() end
    self.tween = Tween.new()
    self.tween:tween_property(self, "intensity", 0.7, 0.4)
end

function Vignette:fade_out()
    if self.tween and self.tween:is_running() then self.tween:kill() end
    self.tween = Tween.new()
    self.tween:tween_property(self, "intensity", 0, 0.3)
end

function Vignette:set_spotlight(cx, cy, radius, strength, feather)
    self.spotlight_enabled = 1
    self.spotlight_center_x = cx
    self.spotlight_center_y = cy
    self.spotlight_radius = radius or 180
    self.spotlight_feather = feather or 120
    self.spotlight_strength = strength or 0.88
end

function Vignette:fade_spotlight(cx, cy, radius, duration, strength, feather)
    self.spotlight_enabled = 1
    if self.spotlight_tween and self.spotlight_tween:is_running() then
        self.spotlight_tween:kill()
    end
    self.spotlight_tween = Tween.new()
    self.spotlight_tween:set_parallel(true)
    self.spotlight_tween:tween_property(self, "spotlight_center_x", cx, duration or 0.26)
    self.spotlight_tween:tween_property(self, "spotlight_center_y", cy, duration or 0.26)
    self.spotlight_tween:tween_property(self, "spotlight_radius", radius or 180, duration or 0.26)
    self.spotlight_tween:tween_property(self, "spotlight_strength", strength or 0.88, duration or 0.26)
    self.spotlight_tween:tween_property(self, "spotlight_feather", feather or 136, duration or 0.26)
end

function Vignette:fade_out_spotlight(duration)
    if self.spotlight_tween and self.spotlight_tween:is_running() then
        self.spotlight_tween:kill()
    end
    if self.spotlight_enabled < 0.5 then return end
    self.spotlight_tween = Tween.new()
    self.spotlight_tween:tween_property(self, "spotlight_strength", 0, duration or 0.18)
    self.spotlight_tween:tween_callback(function()
        self.spotlight_enabled = 0
    end)
end

function Vignette:clear()
    self.spotlight_enabled = 0
    self.spotlight_strength = 0
    self.intensity = 0
    if self.tween and self.tween:is_running() then self.tween:kill() end
    if self.spotlight_tween and self.spotlight_tween:is_running() then self.spotlight_tween:kill() end
end

function Vignette:draw()
    self.shader:send("intensity", self.intensity)
    self.shader:send("softness", self.softness)
    self.shader:send("vignette_color", {0.04, 0.02, 0.08, 1})
    self.shader:send("spotlight_enabled", self.spotlight_enabled)
    self.shader:send("viewport_size", {1280, 720})
    self.shader:send("spotlight_center_px", {self.spotlight_center_x, self.spotlight_center_y})
    self.shader:send("spotlight_radius_px", self.spotlight_radius)
    self.shader:send("spotlight_feather_px", self.spotlight_feather)
    self.shader:send("spotlight_strength", self.spotlight_strength)

    love.graphics.setShader(self.shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)
    love.graphics.setShader()
end

return Vignette
