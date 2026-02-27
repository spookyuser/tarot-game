-- 9-slice texture drawing
local NinePatch = {}
NinePatch.__index = NinePatch

function NinePatch.new(texture, margin)
    local self = setmetatable({}, NinePatch)
    self.texture = texture
    self.margin = margin or 8
    self.quads = {}
    self:_build_quads()
    return self
end

function NinePatch:_build_quads()
    local tw, th = self.texture:getDimensions()
    local m = self.margin

    -- corners
    self.quads.tl = love.graphics.newQuad(0, 0, m, m, tw, th)
    self.quads.tr = love.graphics.newQuad(tw - m, 0, m, m, tw, th)
    self.quads.bl = love.graphics.newQuad(0, th - m, m, m, tw, th)
    self.quads.br = love.graphics.newQuad(tw - m, th - m, m, m, tw, th)

    -- edges
    self.quads.top = love.graphics.newQuad(m, 0, tw - 2*m, m, tw, th)
    self.quads.bottom = love.graphics.newQuad(m, th - m, tw - 2*m, m, tw, th)
    self.quads.left = love.graphics.newQuad(0, m, m, th - 2*m, tw, th)
    self.quads.right = love.graphics.newQuad(tw - m, m, m, th - 2*m, tw, th)

    -- center
    self.quads.center = love.graphics.newQuad(m, m, tw - 2*m, th - 2*m, tw, th)

    self.inner_w = tw - 2 * m
    self.inner_h = th - 2 * m
end

function NinePatch:draw(x, y, w, h)
    local m = self.margin
    local iw = self.inner_w
    local ih = self.inner_h
    local sx = (w - 2 * m) / iw
    local sy = (h - 2 * m) / ih

    love.graphics.setColor(1, 1, 1, 1)

    -- corners
    love.graphics.draw(self.texture, self.quads.tl, x, y)
    love.graphics.draw(self.texture, self.quads.tr, x + w - m, y)
    love.graphics.draw(self.texture, self.quads.bl, x, y + h - m)
    love.graphics.draw(self.texture, self.quads.br, x + w - m, y + h - m)

    -- edges
    love.graphics.draw(self.texture, self.quads.top, x + m, y, 0, sx, 1)
    love.graphics.draw(self.texture, self.quads.bottom, x + m, y + h - m, 0, sx, 1)
    love.graphics.draw(self.texture, self.quads.left, x, y + m, 0, 1, sy)
    love.graphics.draw(self.texture, self.quads.right, x + w - m, y + m, 0, 1, sy)

    -- center
    love.graphics.draw(self.texture, self.quads.center, x + m, y + m, 0, sx, sy)
end

return NinePatch
