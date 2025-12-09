local ship_renderer = {}

-------------------------------------------------------------------------------
-- Generic ship renderer
--
-- This module knows how to draw a "ship layout" produced by core.ship
-- (authored blueprint) or by the procedural generator, using shared
-- conventions: hull, wings, armor plates, cockpit, engines, greebles.
-------------------------------------------------------------------------------

local function mulColor(c, factor)
    return {
        math.max(0, math.min(1, (c[1] or 0) * factor)),
        math.max(0, math.min(1, (c[2] or 0) * factor)),
        math.max(0, math.min(1, (c[3] or 0) * factor)),
    }
end

-------------------------------------------------------------------------------
-- PLAYER SHIP RENDERING
-------------------------------------------------------------------------------

function ship_renderer.drawPlayer(layout, colors)
    if not layout or not layout.hull or not layout.hull.points then
        return
    end

    -- Color palette inputs from the caller (game state passes core colors).
    local shipColor = colors.ship
    local outlineColor = colors.shipOutline or {0, 0, 0}
    local cockpitColor = colors.projectile or shipColor
    local engineColor = colors.engineTrailA or colors.projectile or shipColor

    -- Derive a few related shades so the ship has more visual layering.
    local primaryHullColor = shipColor
    local wingColor = mulColor(shipColor, 0.85)
    local armorColor = mulColor(shipColor, 1.20)
    local greeblePanelColor = mulColor(shipColor, 1.10)
    local greebleLightColor = colors.projectile or shipColor

    ------------------------------------------------------------------------
    -- HULL: solid central body
    ------------------------------------------------------------------------
    local hullVerts = {}
    for _, p in ipairs(layout.hull.points) do
        hullVerts[#hullVerts + 1] = p[1]
        hullVerts[#hullVerts + 1] = p[2]
    end

    love.graphics.setColor(primaryHullColor)
    love.graphics.polygon("fill", hullVerts)

    ------------------------------------------------------------------------
    -- WINGS: heavy side fins that make the ship feel broader and chunkier
    ------------------------------------------------------------------------
    if layout.wings then
        love.graphics.setColor(wingColor)
        for _, wing in ipairs(layout.wings) do
            if wing.points then
                local wingVerts = {}
                for _, p in ipairs(wing.points) do
                    wingVerts[#wingVerts + 1] = p[1]
                    wingVerts[#wingVerts + 1] = p[2]
                end
                love.graphics.polygon("fill", wingVerts)
            end
        end
    end

    ------------------------------------------------------------------------
    -- ARMOR PLATES: large surface panels / structural blocks
    ------------------------------------------------------------------------
    if layout.armorPlates then
        love.graphics.setColor(armorColor)
        for _, plate in ipairs(layout.armorPlates) do
            local px = plate.x or 0
            local py = plate.y or 0
            local w = plate.w or 0
            local h = plate.h or 0
            local angle = plate.angle or 0

            love.graphics.push()
            love.graphics.translate(px, py)
            love.graphics.rotate(angle)
            love.graphics.rectangle(
                "fill",
                -w * 0.5,
                -h * 0.5,
                w,
                h,
                math.min(w, h) * 0.2,
                math.min(w, h) * 0.2
            )
            love.graphics.pop()
        end
    end

    ------------------------------------------------------------------------
    -- COCKPIT / SENSOR DOME: glowing canopy / eye
    ------------------------------------------------------------------------
    if layout.cockpit then
        local cx = layout.cockpit.x or 0
        local cy = layout.cockpit.y or 0
        local r = layout.cockpit.radius or (layout.size or 10) * 0.3

        love.graphics.setColor(cockpitColor[1], cockpitColor[2], cockpitColor[3], 0.9)
        love.graphics.circle("fill", cx, cy, r)
    end

    ------------------------------------------------------------------------
    -- ENGINE CLUSTER: rear thrusters
    ------------------------------------------------------------------------
    if layout.engines then
        for _, engine in ipairs(layout.engines) do
            local ex = engine.x or 0
            local ey = engine.y or 0
            local er = engine.radius or (layout.size or 10) * 0.25

            -- Dark recess
            love.graphics.setColor(0.05, 0.05, 0.05, 1.0)
            love.graphics.circle("fill", ex, ey, er)

            -- Inner glow; flame visuals come from the engine trail system.
            love.graphics.setColor(engineColor[1], engineColor[2], engineColor[3], 0.0)
            love.graphics.circle("fill", ex, ey, er * 0.7)
        end
    end

    ------------------------------------------------------------------------
    -- GREEBLES: micro surface detail (panels and small lights)
    ------------------------------------------------------------------------
    if layout.greebles then
        for _, g in ipairs(layout.greebles) do
            if g.type == "panel" then
                local px = g.x or 0
                local py = g.y or 0
                local len = g.length or 0
                local wid = g.width or 0
                local angle = g.angle or 0

                love.graphics.push()
                love.graphics.translate(px, py)
                love.graphics.rotate(angle)
                love.graphics.setColor(greeblePanelColor[1], greeblePanelColor[2], greeblePanelColor[3], 0.9)
                love.graphics.rectangle("fill", -len * 0.5, -wid * 0.5, len, wid, wid * 0.25, wid * 0.25)
                love.graphics.pop()

            elseif g.type == "light" then
                local lx = g.x or 0
                local ly = g.y or 0
                local lr = g.radius or ((layout.size or 10) * 0.08)

                -- Soft halo
                love.graphics.setColor(greebleLightColor[1], greebleLightColor[2], greebleLightColor[3], 0.35)
                love.graphics.circle("fill", lx, ly, lr * 1.6)
                -- Bright core
                love.graphics.setColor(greebleLightColor[1], greebleLightColor[2], greebleLightColor[3], 0.9)
                love.graphics.circle("fill", lx, ly, lr)
            end
        end
    end

    ------------------------------------------------------------------------
    -- OUTLINE: silhouette
    --
    -- Intentionally disabled for the player drone to keep the look softer
    -- and more "alien-tech". The filled hull/wings plus greebles provide
    -- enough shape definition against the background.
    ------------------------------------------------------------------------
    -- (no outline stroke)
end

return ship_renderer
