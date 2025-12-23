--------------------------------------------------------------------------------
-- ECS COMPONENTS
-- All component definitions for the Concord ECS system
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local config = require("src.core.config")

--------------------------------------------------------------------------------
-- IDENTITY / TAGS
--------------------------------------------------------------------------------

-- Faction: player, enemy, neutral
Concord.component("faction", function(c, name)
    c.name = name or "neutral"
end)

-- Entity type tags
Concord.component("projectile")
Concord.component("ship")
Concord.component("asteroid")
Concord.component("item")
Concord.component("wreck")
Concord.component("debris")

--------------------------------------------------------------------------------
-- TRANSFORM / PHYSICS
--------------------------------------------------------------------------------

Concord.component("position", function(c, x, y)
    c.x = x or 0
    c.y = y or 0
end)

Concord.component("velocity", function(c, vx, vy)
    c.vx = vx or 0
    c.vy = vy or 0
end)

Concord.component("rotation", function(c, angle, targetAngle)
    c.angle = angle or 0
    c.targetAngle = targetAngle or angle or 0
end)

Concord.component("physics", function(c, body, shapes, fixtures)
    c.body = body
    c.shapes = shapes
    c.fixtures = fixtures
end)

Concord.component("collisionRadius", function(c, radius)
    c.radius = radius or 10
end)

Concord.component("thrust", function(c, power, maxSpeed)
    c.power = power or 200
    c.maxSpeed = maxSpeed or 300
    c.isThrusting = false
end)

Concord.component("damping", function(c, value)
    c.value = value or 0.1
end)

--------------------------------------------------------------------------------
-- COMBAT
--------------------------------------------------------------------------------

Concord.component("health", function(c, current, max)
    c.current = current or 100
    c.max = max or current or 100
end)

Concord.component("shield", function(c, current, max)
    c.current = current or 0
    c.max = max or current or 0
end)

Concord.component("damage", function(c, amount)
    c.amount = amount or 10
end)

Concord.component("damageable")

Concord.component("weapon", function(c, data)
    c.data = data
    c.fireTimer = 0
end)

Concord.component("projectileData", function(c, owner, target, weapon, distanceTraveled)
    c.owner = owner
    c.target = target
    c.weapon = weapon
    c.distanceTraveled = distanceTraveled or 0
end)

--------------------------------------------------------------------------------
-- RENDERING
--------------------------------------------------------------------------------

Concord.component("shipVisual", function(c, shipData)
    c.ship = shipData
end)

Concord.component("asteroidVisual", function(c, data)
    c.data = data
end)

Concord.component("debrisVisual", function(c, flatPoints, color)
    c.flatPoints = flatPoints or {}
    c.color = color or { 0.5, 0.5, 0.5, 1 }
end)

Concord.component("projectileVisual", function(c, config)
    c.config = config
end)

Concord.component("asteroidSurfaceDamage", function(c, cellCount)
    c.cellCount = cellCount or 16
    c.cells = {}
    c.marks = {}
end)

Concord.component("size", function(c, value)
    c.value = value or 10
end)

--------------------------------------------------------------------------------
-- REWARDS / LOOT
--------------------------------------------------------------------------------

Concord.component("xpReward", function(c, amount)
    c.amount = amount or 0
end)

Concord.component("tokenReward", function(c, amount)
    c.amount = amount or 0
end)

Concord.component("loot", function(c, cargo, coins)
    c.cargo = cargo or {}
    c.coins = coins or 0
end)

Concord.component("resourceYield", function(c, resources)
    c.resources = resources or {}
end)

--------------------------------------------------------------------------------
-- AI / BEHAVIOR
--------------------------------------------------------------------------------

Concord.component("aiState", function(c, state, detectionRange, attackRange)
    c.state = state or "idle"
    c.detectionRange = detectionRange or config.enemy.detectionRange or 1000
    c.attackRange = attackRange or config.enemy.attackRange or 350
end)

Concord.component("enemyLevel", function(c, level)
    c.level = level or 1
end)

Concord.component("wanderBehavior", function(c, angle, timer, radius)
    c.angle = angle or math.random() * math.pi * 2
    c.timer = timer or 0
    c.radius = radius or 300
end)

Concord.component("spawnPosition", function(c, x, y)
    c.x = x or 0
    c.y = y or 0
end)

--------------------------------------------------------------------------------
-- PLAYER-SPECIFIC
--------------------------------------------------------------------------------

Concord.component("playerControlled")

Concord.component("destination", function(c, x, y)
    c.x = x
    c.y = y
    c.active = (x ~= nil and y ~= nil)
end)

Concord.component("experience", function(c, xp, level, totalXp)
    c.xp = xp or 0
    c.current = c.xp
    c.level = level or 1
    c.totalXp = totalXp or 0

    local base = (config.player and config.player.xpBase) or 100
    local growth = (config.player and config.player.xpGrowth) or 0
    local xpToNext = base + growth * ((c.level or 1) - 1)
    if xpToNext <= 0 then
        xpToNext = 1
    end

    c.xpToNext = xpToNext
    c.xpRatio = math.max(0, math.min(1, (c.xp or 0) / xpToNext))
end)

Concord.component("currency", function(c, tokens)
    c.tokens = tokens or 0
end)

Concord.component("cargo", function(c, slots, maxSlots)
    c.slots = slots or {}
    c.maxSlots = maxSlots or 20
end)

Concord.component("miningSkill", function(c, xp, level)
    c.xp = xp or 0
    c.level = level or 1

    local base = 40
    local growth = 18
    local xpToNext = base + growth * ((c.level or 1) - 1)
    if xpToNext <= 0 then
        xpToNext = 1
    end

    c.xpToNext = xpToNext
    c.xpRatio = math.max(0, math.min(1, (c.xp or 0) / xpToNext))
end)

Concord.component("magnet", function(c, radius, pickupRadius)
    c.radius = radius or 150
    c.pickupRadius = pickupRadius or 30
end)

--------------------------------------------------------------------------------
-- LIFETIME / CLEANUP

--------------------------------------------------------------------------------

Concord.component("lifetime", function(c, remaining)
    c.remaining = remaining or 60
end)

Concord.component("removed")

--------------------------------------------------------------------------------
-- RESPAWN
--------------------------------------------------------------------------------

Concord.component("respawnOnDeath", function(c, delay, enemyDef)
    c.delay = delay or 30
    c.enemyDef = enemyDef
end)

Concord.component("respawnTimer", function(c, current, enemyDef, x, y)
    c.current = current or 30
    c.enemyDef = enemyDef
    c.x = x or 0
    c.y = y or 0
end)

Concord.component("dead")

return true
