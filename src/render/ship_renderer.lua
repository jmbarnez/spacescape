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

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpColor(a, b, t)
    return {
        lerp(a[1] or 0, b[1] or 0, t),
        lerp(a[2] or 0, b[2] or 0, t),
        lerp(a[3] or 0, b[3] or 0, t),
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
    local projectileColor = colors.projectile or shipColor
    local engineGlowColor = colors.engineTrailA or projectileColor
    local engineSecondaryColor = colors.engineTrailB or engineGlowColor
    local outlineBase = colors.shipOutline or {0, 0, 0, 0.8}

    -- Derive related shades so each piece has distinct color identity.
    local primaryHullColor = shipColor
    local wingColor = lerpColor(shipColor, engineSecondaryColor, 0.6)
    local armorColor = mulColor(shipColor, 0.55)
    local greeblePanelColor = lerpColor(shipColor, projectileColor, 0.5)
    local greebleLightColor = engineGlowColor
    local cockpitInnerColor = lerpColor(projectileColor, engineGlowColor, 0.7)
    local cockpitOuterColor = {
        cockpitInnerColor[1],
        cockpitInnerColor[2],
        cockpitInnerColor[3],
        0.45,
    }
    local engineRecessColor = {0.03, 0.05, 0.08, 1.0}
    local engineInnerGlowColor = engineGlowColor
    local hullOutlineColor = {
        outlineBase[1] or 0,
        outlineBase[2] or 0,
        outlineBase[3] or 0,
        (outlineBase[4] or 1.0) * 0.45,
    }
    local wingOutlineColor = {
        wingColor[1] * 0.6,
        wingColor[2] * 0.6,
        wingColor[3] * 0.6,
        0.4,
    }
    local armorOutlineColor = {
        armorColor[1] * 0.8,
        armorColor[2] * 0.8,
        armorColor[3] * 0.8,
        0.55,
    }

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
        for _, plate in ipairs(layout.armorPlates) do
            local px = plate.x or 0
            local py = plate.y or 0
            local w = plate.w or 0
            local h = plate.h or 0
            local angle = plate.angle or 0

            love.graphics.push()
            love.graphics.translate(px, py)
            love.graphics.rotate(angle)
            love.graphics.setColor(armorColor)
            love.graphics.rectangle(
                "fill",
                -w * 0.5,
                -h * 0.5,
                w,
                h,
                math.min(w, h) * 0.2,
                math.min(w, h) * 0.2
            )
            love.graphics.setColor(armorOutlineColor)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle(
                "line",
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

        love.graphics.setColor(cockpitOuterColor)
        love.graphics.circle("fill", cx, cy, r * 1.25)
        love.graphics.setColor(cockpitInnerColor[1], cockpitInnerColor[2], cockpitInnerColor[3], 0.95)
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
            love.graphics.setColor(engineRecessColor)
            love.graphics.circle("fill", ex, ey, er)

            -- Inner glow; flame visuals come from the engine trail system.
            love.graphics.setColor(engineInnerGlowColor[1], engineInnerGlowColor[2], engineInnerGlowColor[3], 0.0)
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
    ------------------------------------------------------------------------
    love.graphics.setLineWidth(1)
    love.graphics.setColor(hullOutlineColor)
    love.graphics.polygon("line", hullVerts)

    if layout.wings then
        love.graphics.setColor(wingOutlineColor)
        for _, wing in ipairs(layout.wings) do
            if wing.points then
                local wingVerts = {}
                for _, p in ipairs(wing.points) do
                    wingVerts[#wingVerts + 1] = p[1]
                    wingVerts[#wingVerts + 1] = p[2]
                end
                love.graphics.polygon("line", wingVerts)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- ENEMY / PROCEDURAL SHIP RENDERING
-------------------------------------------------------------------------------

function ship_renderer.drawEnemy(layout, colors)
    if not layout or not layout.hull or not layout.hull.points then
        return
    end

    -- Palette comes from the procedural generator; global colors carry the
    -- overarching enemy tint used by the rest of the game (HUD, effects).
    local palette = layout.palette or {}
    local primary = palette.primary or (colors and colors.enemy) or {1, 1, 1}
    local secondary = palette.secondary or primary
    local accent = palette.accent or secondary
    local glow = palette.glow or accent

    local baseColor = (colors and colors.enemy) or primary
    local outlineBase = (colors and colors.enemyOutline) or {0, 0, 0, 0.9}

    -- Derive related shades so each piece has distinct color identity.
    local hullBaseColor = mulColor(baseColor, 0.85)
    local primaryHullColor = hullBaseColor
    local wingColor = lerpColor(hullBaseColor, secondary, 0.6)
    local armorColor = mulColor(hullBaseColor, 0.55)
    local greeblePanelColor = lerpColor(hullBaseColor, accent, 0.7)
    local greebleLightColor = glow
    local cockpitInnerColor = lerpColor(accent, glow, 0.7)
    local cockpitOuterColor = {
        cockpitInnerColor[1],
        cockpitInnerColor[2],
        cockpitInnerColor[3],
        0.4,
    }
    local engineRecessColor = {0.02, 0.02, 0.03, 1.0}
    local engineInnerGlowColor = glow
    local hullOutlineColor = {
        outlineBase[1] or 0,
        outlineBase[2] or 0,
        outlineBase[3] or 0,
        1.0,
    }
    local wingOutlineColor = {
        wingColor[1] * 0.5,
        wingColor[2] * 0.5,
        wingColor[3] * 0.5,
        0.9,
    }
    local armorOutlineColor = {
        armorColor[1] * 0.8,
        armorColor[2] * 0.8,
        armorColor[3] * 0.8,
        1.0,
    }

    ------------------------------------------------------------------------
    -- HULL
    ------------------------------------------------------------------------
    local hullVerts = {}
    for _, p in ipairs(layout.hull.points) do
        hullVerts[#hullVerts + 1] = p[1]
        hullVerts[#hullVerts + 1] = p[2]
    end

    love.graphics.setColor(primaryHullColor)
    love.graphics.polygon("fill", hullVerts)

    ------------------------------------------------------------------------
    -- WINGS
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
    -- ARMOR PLATES (procedural ships typically have none, but we support
    -- them for future variants / elites).
    ------------------------------------------------------------------------
    if layout.armorPlates then
        for _, plate in ipairs(layout.armorPlates) do
            local px = plate.x or 0
            local py = plate.y or 0
            local w = plate.w or 0
            local h = plate.h or 0
            local angle = plate.angle or 0

            love.graphics.push()
            love.graphics.translate(px, py)
            love.graphics.rotate(angle)
            love.graphics.setColor(armorColor)
            love.graphics.rectangle(
                "fill",
                -w * 0.5,
                -h * 0.5,
                w,
                h,
                math.min(w, h) * 0.2,
                math.min(w, h) * 0.2
            )
            love.graphics.setColor(armorOutlineColor)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle(
                "line",
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
    -- COCKPIT (optional: many procedural ships omit this)
    ------------------------------------------------------------------------
    if layout.cockpit then
        local cx = layout.cockpit.x or 0
        local cy = layout.cockpit.y or 0
        local r = layout.cockpit.radius or (layout.size or 10) * 0.25

        love.graphics.setColor(cockpitOuterColor)
        love.graphics.circle("fill", cx, cy, r * 1.2)
        love.graphics.setColor(cockpitInnerColor[1], cockpitInnerColor[2], cockpitInnerColor[3], 0.95)
        love.graphics.circle("fill", cx, cy, r)
    end

    ------------------------------------------------------------------------
    -- ENGINES
    ------------------------------------------------------------------------
    if layout.engines then
        for _, engine in ipairs(layout.engines) do
            local ex = engine.x or 0
            local ey = engine.y or 0
            local er = engine.radius or (layout.size or 10) * 0.20

            love.graphics.setColor(engineRecessColor)
            love.graphics.circle("fill", ex, ey, er)

            love.graphics.setColor(engineInnerGlowColor[1], engineInnerGlowColor[2], engineInnerGlowColor[3], 0.0)
            love.graphics.circle("fill", ex, ey, er * 0.7)
        end
    end

    ------------------------------------------------------------------------
    -- GREEBLES
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

                love.graphics.setColor(greebleLightColor[1], greebleLightColor[2], greebleLightColor[3], 0.35)
                love.graphics.circle("fill", lx, ly, lr * 1.5)
                love.graphics.setColor(greebleLightColor[1], greebleLightColor[2], greebleLightColor[3], 0.9)
                love.graphics.circle("fill", lx, ly, lr)
            end
        end
    end

    ------------------------------------------------------------------------
    -- OUTLINE
    ------------------------------------------------------------------------
    love.graphics.setLineWidth(1)
    love.graphics.setColor(hullOutlineColor)
    love.graphics.polygon("line", hullVerts)

    if layout.wings then
        love.graphics.setColor(wingOutlineColor)
        for _, wing in ipairs(layout.wings) do
            if wing.points then
                local wingVerts = {}
                for _, p in ipairs(wing.points) do
                    wingVerts[#wingVerts + 1] = p[1]
                    wingVerts[#wingVerts + 1] = p[2]
                end
                love.graphics.polygon("line", wingVerts)
            end
        end
    end
end

return ship_renderer
