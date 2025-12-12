--------------------------------------------------------------------------------
-- PROJECTILE MODULE (ECS-BACKED)
-- Spawns projectiles as ECS entities, provides legacy API compatibility
--------------------------------------------------------------------------------

local projectile = {}

local ecsWorld = require("src.ecs.world")
local assemblages = require("src.ecs.assemblages")
local Concord = require("lib.concord")
local physics = require("src.core.physics")
local baseColors = require("src.core.colors")

--------------------------------------------------------------------------------
-- HIT CHANCE CALCULATION (kept for collision system)
--------------------------------------------------------------------------------

local function calculateHitChance(weapon, distance)
    local hitMax = weapon.hitMax
    local hitMin = weapon.hitMin
    local optimalRange = weapon.optimalRange
    local maxRange = weapon.maxRange

    if not hitMax and not hitMin then
        return 1.0
    end

    hitMax = hitMax or hitMin
    hitMin = hitMin or hitMax

    if not optimalRange or not maxRange or maxRange <= optimalRange then
        return hitMax
    end

    if distance <= optimalRange then
        return hitMax
    elseif distance >= maxRange then
        return hitMin
    else
        local t = (distance - optimalRange) / (maxRange - optimalRange)
        return hitMax + (hitMin - hitMax) * t
    end
end

projectile.calculateHitChance = calculateHitChance

--------------------------------------------------------------------------------
-- LEGACY LIST (computed from ECS world)
--------------------------------------------------------------------------------

-- This provides backward compatibility - returns all projectile entities
function projectile.getList()
    return ecsWorld:query({ "projectile", "position" }) or {}
end

-- Legacy .list property (computed on access)
setmetatable(projectile, {
    __index = function(t, k)
        if k == "list" then
            return projectile.getList()
        end
        return rawget(t, k)
    end
})

--------------------------------------------------------------------------------
-- SPAWN
--------------------------------------------------------------------------------

function projectile.spawn(shooter, targetX, targetY, targetEntity)
    local e = ecsWorld:spawnProjectile(shooter, targetX, targetY, targetEntity)
    return e
end

--------------------------------------------------------------------------------
-- UPDATE (now handled by ECS systems, but keep for offscreen cleanup)
--------------------------------------------------------------------------------

function projectile.update(dt, world)
    local projectiles = ecsWorld:query({ "projectile", "position" }) or {}

    for i = #projectiles, 1, -1 do
        local e = projectiles[i]
        local pos = e.position

        -- Offscreen check
        local margin = 100
        local offscreen = false
        if world then
            offscreen = pos.x < world.minX - margin or pos.x > world.maxX + margin or
                pos.y < world.minY - margin or pos.y > world.maxY + margin
        end

        if offscreen then
            if e.physics and e.physics.body then
                e.physics.body:destroy()
            end
            e._removed = true
            e:destroy()
        end
    end
end

--------------------------------------------------------------------------------
-- DRAW
--------------------------------------------------------------------------------

function projectile.draw(colors)
    colors = colors or baseColors
    local projectiles = ecsWorld:query({ "projectile", "position" }) or {}

    for _, e in ipairs(projectiles) do
        -- Projectiles can be flagged for removal during collision processing
        -- (via utils.removeEntity setting e._removed and calling e:destroy()).
        -- Concord applies removals on the next ECS flush, which means the
        -- entity can still show up in queries for the remainder of the frame.
        --
        -- If we don't guard against that, beam-style projectiles can appear
        -- to get "stuck" at the impact point until the next ECS update.
        if e._removed or e.removed then
            goto continue
        end

        local px = e.position.x
        local py = e.position.y
        local angle = e.rotation and e.rotation.angle or 0

        local config = e.projectileVisual and e.projectileVisual.config or {}
        local length = config.length or 20
        local width = config.width or 2
        local outerAlpha = config.outerGlowAlpha or 0.3
        local color = config.color or colors.projectile

        local tailX = px - math.cos(angle) * length
        local tailY = py - math.sin(angle) * length

        -- Outer glow
        love.graphics.setColor(color[1], color[2], color[3], outerAlpha)
        love.graphics.setLineWidth(width + 2)
        love.graphics.line(px, py, tailX, tailY)

        -- Core beam
        love.graphics.setColor(color)
        love.graphics.setLineWidth(width)
        love.graphics.line(px, py, tailX, tailY)

        ::continue::
    end

    love.graphics.setLineWidth(1)
end

--------------------------------------------------------------------------------
-- CLEAR
--------------------------------------------------------------------------------

function projectile.clear()
    local projectiles = ecsWorld:query({ "projectile" }) or {}

    for i = #projectiles, 1, -1 do
        local e = projectiles[i]
        if e.physics and e.physics.body then
            e.physics.body:destroy()
        end
        e:destroy()
    end
end

return projectile
