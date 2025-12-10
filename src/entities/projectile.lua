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
    -- Handle both old-style shooters (with .x, .y) and ECS entities (with .position)
    local sx, sy, size, weapon, faction

    if shooter.position then
        -- ECS entity
        sx = shooter.position.x
        sy = shooter.position.y
        size = shooter.size and shooter.size.value or 20
        weapon = shooter.weapon and shooter.weapon.data or {}
        faction = shooter.faction and shooter.faction.name or "player"
    else
        -- Legacy entity
        sx = shooter.x
        sy = shooter.y
        size = shooter.size or 20
        weapon = shooter.weapon or {}
        faction = shooter.faction or "player"
    end

    local dx = targetX - sx
    local dy = targetY - sy
    local angle = math.atan2(dy, dx)
    local speed = weapon.projectileSpeed or 600
    local damage = weapon.damage or 20

    local x = sx + math.cos(angle) * size
    local y = sy + math.sin(angle) * size

    -- Create ECS entity
    local e = Concord.entity(ecsWorld)
    e:give("position", x, y)
        :give("velocity", math.cos(angle) * speed, math.sin(angle) * speed)
        :give("rotation", angle)
        :give("projectile")
        :give("damage", damage)
        :give("faction", faction)
        :give("projectileData", shooter, targetEntity, weapon, 0)
        :give("collisionRadius", 4)

    if weapon.projectile then
        e:give("projectileVisual", weapon.projectile)
    end

    -- Create physics body
    local categoryName = (faction == "enemy") and "ENEMY_PROJECTILE" or "PLAYER_PROJECTILE"
    local body, shape, fixture = physics.createCircleBody(
        x, y, 4, categoryName, e,
        { isSensor = true, isBullet = true }
    )

    if body then
        e:give("physics", body, shape and { shape } or nil, fixture and { fixture } or nil)
        body:setLinearVelocity(math.cos(angle) * speed, math.sin(angle) * speed)
    end

    -- Update shooter angle
    if shooter.rotation then
        shooter.rotation.angle = angle
    end

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
