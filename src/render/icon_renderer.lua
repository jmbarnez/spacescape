-- Generic icon rendering module.
-- Provides a single API for drawing resource icons in both UI and in-space contexts.

local icon_renderer = {}

local itemDefs = require("src.data.items")

--------------------------------------------------------------------------------
-- INTERNAL HELPERS
--------------------------------------------------------------------------------

local function snap(v, step)
    step = step or 1
    return math.floor(v / step + 0.5) * step
end

local function drawUnknownIcon(cx, cy, size)
    love.graphics.setColor(0.15, 0.15, 0.15, 0.95)
    love.graphics.rectangle("fill", cx - size, cy - size, size * 2, size * 2, 3, 3)
    love.graphics.setColor(1.0, 1.0, 1.0, 0.65)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx - size, cy - size, size * 2, size * 2, 3, 3)
    love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
    local font = love.graphics.getFont()
    local q = "?"
    love.graphics.print(q, cx - font:getWidth(q) / 2, cy - font:getHeight() / 2)
end

--------------------------------------------------------------------------------
-- GENERIC SHAPE DRAWERS
--------------------------------------------------------------------------------

-- Draw a jagged chunk shape (stone-like)
local function drawChunk(cx, cy, r, segments, jaggedness, baseColor, outlineColor, spin)
    local points = {}
    for i = 0, segments - 1 do
        local t = i / segments
        local angle = t * math.pi * 2 + (spin or 0)
        local noise = 1 + math.sin(i * 2.1 + (spin or 0) * 7.5) * jaggedness
        local pr = r * (0.7 + 0.3 * noise)
        local px = snap(cx + math.cos(angle) * pr, 0.5)
        local py = snap(cy + math.sin(angle) * pr, 0.5)
        points[#points + 1] = px
        points[#points + 1] = py
    end

    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1.0)
    love.graphics.polygon("fill", points)
    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 0.95)
    love.graphics.setLineWidth(1.4)
    love.graphics.polygon("line", points)
end

-- Draw a crystal/diamond shape (mithril-like)
local function drawCrystal(cx, cy, r, baseColor, outlineColor, pulse)
    local pr = r * (1.0 + 0.05 * (pulse or 0))
    local topX, topY = snap(cx, 0.5), snap(cy - pr, 0.5)
    local rightX, rightY = snap(cx + pr * 0.75, 0.5), snap(cy, 0.5)
    local bottomX, bottomY = snap(cx, 0.5), snap(cy + pr * 1.1, 0.5)
    local leftX, leftY = snap(cx - pr * 0.75, 0.5), snap(cy, 0.5)

    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1.0)
    love.graphics.polygon("fill", topX, topY, rightX, rightY, bottomX, bottomY, leftX, leftY)
    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 0.95)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", topX, topY, rightX, rightY, bottomX, bottomY, leftX, leftY)
    -- Inner shine line
    love.graphics.setColor(baseColor[1] * 1.2, baseColor[2] * 1.2, baseColor[3] * 1.2, 0.95)
    love.graphics.setLineWidth(1.0)
    love.graphics.line(cx, cy - pr * 0.5, cx, cy + pr * 0.7)
end

-- Draw a scrap/rectangular shape
local function drawScrap(cx, cy, r, baseColor, outlineColor)
    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1.0)
    love.graphics.rectangle("fill", cx - r * 0.6, cy - r * 0.3, r * 1.2, r * 0.6, 2, 2)
    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(cx - r * 0.3, cy - r * 0.3, cx - r * 0.3, cy + r * 0.3)
    love.graphics.line(cx + r * 0.3, cy - r * 0.3, cx + r * 0.3, cy + r * 0.3)
end

--------------------------------------------------------------------------------
-- MAIN DRAW FUNCTION
--------------------------------------------------------------------------------

--- Draw a resource icon.
-- @param resourceId string The resource type id (e.g. "stone", "ice", "mithril")
-- @param opts table Options:
--   - x, y: center position (required)
--   - size: icon radius (default 16)
--   - context: "ui" or "inspace" (default "ui")
--   - age: animation time for in-space context (default 0)
--   - pulse: 0..1 pulse value for in-space context (default 0)
--   - palette: optional color overrides
function icon_renderer.draw(resourceId, opts)
    if not resourceId then
        return
    end

    opts = opts or {}
    local cx = opts.x or 0
    local cy = opts.y or 0
    local size = opts.size or 16
    local context = opts.context or "ui"

    local def = itemDefs[resourceId]
    if not def then
        drawUnknownIcon(cx, cy, size)
        return
    end

    -- Context determines animation behavior
    local age = (context == "inspace") and (opts.age or 0) or 0
    local pulse = (context == "inspace") and (opts.pulse or 0) or 0
    local spin = (context == "inspace") and (0.4 * age) or 0

    -- Get icon parameters from definition
    local icon = def.icon or {}
    local radiusScale = icon.radius or 1.0
    local r = size * radiusScale

    local baseColor = def.color or {0.5, 0.5, 0.5, 1.0}
    local outlineColor = def.outlineColor or {0.05, 0.05, 0.05, 0.9}
    local shape = icon.shape or "chunk"

    -- Draw based on shape type
    if shape == "crystal" then
        drawCrystal(cx, cy, r, baseColor, outlineColor, pulse)
    elseif shape == "scrap" or shape == "plate" then
        drawScrap(cx, cy, r, baseColor, outlineColor)
    else
        -- Default: chunk shape
        local segments = icon.segments or 7
        local jaggedness = icon.jaggedness or 0.35
        drawChunk(cx, cy, r, segments, jaggedness, baseColor, outlineColor, spin)
    end
end

--- Draw unknown item icon.
function icon_renderer.drawUnknown(x, y, size)
    drawUnknownIcon(x, y, size)
end

return icon_renderer
