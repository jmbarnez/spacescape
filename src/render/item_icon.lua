local item_icon = {}

-- Generic item icon renderer.
--
-- The goal of this module is to keep icon rendering consistent across:
-- - In-world pickups (floating in space)
-- - HUD windows (cargo, loot panel)
-- - Future UI panels
--
-- All callers should route through this helper so icons do not drift.

local resourceDefs = require("src.data.mining.resources")
local item_icons = require("src.render.item_icons")

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

-- Draw a resource icon by id.
--
-- opts fields:
-- - x, y: center position
-- - size: icon radius-ish (passed to resource drawer)
-- - palette: colors table (optional)
-- - age: used for animated/procedural variation (defaults to 0 for UI)
-- - pulse: optional pulse 0..1 (defaults to 0 for UI)
function item_icon.drawResource(resourceId, opts)
    if not resourceId then
        return
    end

    opts = opts or {}

    local cx = opts.x or 0
    local cy = opts.y or 0
    local size = opts.size or 16

    local def = resourceDefs[resourceId]
    if not def then
        drawUnknownIcon(cx, cy, size)
        return
    end

    local it = opts.item
    if not it then
        it = {
            x = cx,
            y = cy,
            radius = size,
            age = opts.age or 0,
            itemType = "resource",
            resourceType = resourceId,
        }
    end

    local palette = opts.palette or {}
    local pulse = opts.pulse or 0

    item_icons.drawResource(it, def, palette, size, pulse)
end

function item_icon.drawUnknown(x, y, size)
    drawUnknownIcon(x, y, size)
end

return item_icon
