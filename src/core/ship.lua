local ship = {}

-------------------------------------------------------------------------------
-- Generic ship utilities shared by player and enemy.
--
-- The goal is to have a **single data-driven ship layout format** that both
-- authored ships (src.data.ships.*) and procedural ships can conform to.
--
-- This module focuses on:
--   - Scaling normalized blueprint geometry to world space at a given size.
--   - Building collision vertex arrays from hull / collision data.
--   - Computing a simple bounding radius for spawning / UI.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Local helpers
-------------------------------------------------------------------------------

-- Shallow copy for simple tables (we avoid copying nested geometry arrays
-- because those are rebuilt explicitly when scaling).
local function shallowCopy(t)
    if not t or type(t) ~= "table" then
        return t
    end
    local out = {}
    for k, v in pairs(t) do
        out[k] = v
    end
    return out
end

-- Scale a list of {x, y} points from normalized space into world space.
local function scalePoints(points, size)
    if not points then
        return nil
    end
    local out = {}
    for i = 1, #points do
        local p = points[i]
        out[#out + 1] = { (p[1] or 0) * size, (p[2] or 0) * size }
    end
    return out
end

-- Flatten a {{x, y}, ...} list into {x1, y1, x2, y2, ...} for Love2D APIs.
local function flattenPoints(points)
    local flat = {}
    if not points then
        return flat
    end
    for i = 1, #points do
        local p = points[i]
        flat[#flat + 1] = p[1]
        flat[#flat + 1] = p[2]
    end
    return flat
end

ship.flattenPoints = flattenPoints

local function computeConvexHull(points)
    if not points or #points < 3 then
        return points
    end

    table.sort(points, function(a, b)
        if a[1] == b[1] then
            return a[2] < b[2]
        end
        return a[1] < b[1]
    end)

    local function cross(o, a, b)
        return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])
    end

    local lower = {}
    for _, p in ipairs(points) do
        while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do
            table.remove(lower)
        end
        lower[#lower + 1] = p
    end

    local upper = {}
    for i = #points, 1, -1 do
        local p = points[i]
        while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do
            table.remove(upper)
        end
        upper[#upper + 1] = p
    end

    table.remove(lower)
    table.remove(upper)

    local hull = {}
    for i = 1, #lower do
        hull[#hull + 1] = lower[i]
    end
    for i = 1, #upper do
        hull[#hull + 1] = upper[i]
    end

    return hull
end

function ship.buildCombinedOutline(layout)
    if not layout then
        return nil
    end

    local combined = {}

    if layout.hull and layout.hull.points then
        for i = 1, #layout.hull.points do
            local p = layout.hull.points[i]
            combined[#combined + 1] = { p[1], p[2] }
        end
    end

    if layout.wings then
        for _, wing in ipairs(layout.wings) do
            if wing.points then
                for i = 1, #wing.points do
                    local p = wing.points[i]
                    combined[#combined + 1] = { p[1], p[2] }
                end
            end
        end
    end

    if #combined < 3 then
        return nil
    end

    return computeConvexHull(combined)
end

-------------------------------------------------------------------------------
-- Bounding radius computation (world space)
-------------------------------------------------------------------------------

function ship.computeBoundingRadius(layout)
    if not layout then
        return 0
    end

    local radius = layout.size or 0

    -- Hull contribution
    if layout.hull and layout.hull.points then
        for _, p in ipairs(layout.hull.points) do
            local x, y = p[1], p[2]
            local d = math.sqrt(x * x + y * y)
            if d > radius then
                radius = d
            end
        end
    end

    -- Wings contribution
    if layout.wings then
        for _, wing in ipairs(layout.wings) do
            if wing.points then
                for _, p in ipairs(wing.points) do
                    local x, y = p[1], p[2]
                    local d = math.sqrt(x * x + y * y)
                    if d > radius then
                        radius = d
                    end
                end
            end
        end
    end

    -- Engines contribution (position + radius)
    if layout.engines then
        for _, engine in ipairs(layout.engines) do
            local ex = engine.x or 0
            local ey = engine.y or 0
            local r = (engine.radius or (layout.size or 0)) * 1.5
            local d = math.sqrt(ex * ex + ey * ey) + r
            if d > radius then
                radius = d
            end
        end
    end

    return radius
end

-------------------------------------------------------------------------------
-- Instance building from an authored blueprint
-------------------------------------------------------------------------------

-- Build a world-space ship layout from a normalized blueprint.
--
-- blueprint: src.data.ships.* table with fields like hull, wings, engines, ...
-- size:      world size scalar (e.g., config.player.size).
-- overrides: optional table to override top-level fields (e.g. role, stats).
function ship.buildInstanceFromBlueprint(blueprint, size, overrides)
    if not blueprint then
        return nil
    end

    local s = size or blueprint.baseSize or 10

    -- Copy light metadata fields but rebuild geometry explicitly.
    local inst = {
        id       = blueprint.id,
        role     = (overrides and overrides.role) or blueprint.role,
        class    = blueprint.class,
        palette  = blueprint.palette,
        baseSize = blueprint.baseSize,
        size     = s,
        tags     = blueprint.tags,
        metadata = blueprint.metadata,
        stats    = (overrides and overrides.stats) or blueprint.stats,
    }

    -- Geometry: scale normalized coordinates by chosen size.
    if blueprint.hull and blueprint.hull.points then
        inst.hull = { points = scalePoints(blueprint.hull.points, s) }
    end

    if blueprint.wings then
        inst.wings = {}
        for _, wing in ipairs(blueprint.wings) do
            local w = shallowCopy(wing)
            w.points = scalePoints(wing.points, s)
            table.insert(inst.wings, w)
        end
    end

    if blueprint.armorPlates then
        inst.armorPlates = {}
        for _, plate in ipairs(blueprint.armorPlates) do
            local p = shallowCopy(plate)
            p.x = (p.x or 0) * s
            p.y = (p.y or 0) * s
            p.w = (p.w or 0) * s
            p.h = (p.h or 0) * s
            table.insert(inst.armorPlates, p)
        end
    end

    if blueprint.cockpit then
        inst.cockpit = shallowCopy(blueprint.cockpit)
        inst.cockpit.x = (inst.cockpit.x or 0) * s
        inst.cockpit.y = (inst.cockpit.y or 0) * s
        inst.cockpit.radius = (inst.cockpit.radius or 0) * s
    end

    if blueprint.engines then
        inst.engines = {}
        for _, engine in ipairs(blueprint.engines) do
            local e = shallowCopy(engine)
            e.x = (e.x or 0) * s
            e.y = (e.y or 0) * s
            e.radius = (e.radius or 0) * s
            table.insert(inst.engines, e)
        end
    end

    if blueprint.greebles then
        inst.greebles = {}
        for _, g in ipairs(blueprint.greebles) do
            local gg = shallowCopy(g)
            gg.x = (gg.x or 0) * s
            gg.y = (gg.y or 0) * s
            if gg.length then gg.length = gg.length * s end
            if gg.width  then gg.width  = gg.width  * s end
            if gg.radius then gg.radius = gg.radius * s end
            table.insert(inst.greebles, gg)
        end
    end

    -- Collision vertices in world space: either explicit override or hull.
    local collisionSource = nil
    if blueprint.collision and blueprint.collision.vertices then
        collisionSource = scalePoints(blueprint.collision.vertices, s)
    else
        collisionSource = ship.buildCombinedOutline(inst)
        if not collisionSource and inst.hull and inst.hull.points then
            collisionSource = inst.hull.points
        end
    end

    inst.collision = inst.collision or {}
    inst.collision.vertices = collisionSource
    inst.collisionVertices = flattenPoints(collisionSource or {})

    -- Convenience: base hull outline as flat array for rendering.
    if collisionSource then
        inst.baseOutline = flattenPoints(collisionSource)
    elseif inst.hull and inst.hull.points then
        inst.baseOutline = flattenPoints(inst.hull.points)
    end

    -- Bounding radius for spawning / health bar positioning, etc.
    inst.boundingRadius = ship.computeBoundingRadius(inst)

    return inst
end

return ship
