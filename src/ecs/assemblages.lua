--------------------------------------------------------------------------------
-- ECS ASSEMBLAGES
-- Entity blueprints for spawning common entity types
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local config = require("src.core.config")
local physics = require("src.core.physics")
local weapons = require("src.core.weapons")
local ship_generator = require("src.utils.procedural_ship_generator")

local assemblages = {}

--------------------------------------------------------------------------------
-- PROJECTILE ASSEMBLAGE
--------------------------------------------------------------------------------

function assemblages.projectile(e, shooter, targetX, targetY, targetEntity)
    local weapon = shooter.weapon and shooter.weapon.data or {}
    local speed = weapon.projectileSpeed or 600
    local damage = weapon.damage or 20
    local faction = shooter.faction and shooter.faction.name or "player"

    local sx = shooter.position.x
    local sy = shooter.position.y
    local size = shooter.size and shooter.size.value or 20

    local dx = targetX - sx
    local dy = targetY - sy
    local angle = math.atan2(dy, dx)

    local x = sx + math.cos(angle) * size
    local y = sy + math.sin(angle) * size

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
end

--------------------------------------------------------------------------------
-- ENEMY SHIP ASSEMBLAGE
--------------------------------------------------------------------------------

function assemblages.enemy(e, x, y, shipSize)
    local size = shipSize or config.enemy.sizeMin + math.random() * (config.enemy.sizeMax - config.enemy.sizeMin)
    local ship = ship_generator.generate(size)
    local maxHealth = config.enemy.maxHealth
    local collisionRadius = (ship and ship.boundingRadius) or size
    local consts = physics.constants

    e:give("position", x, y)
        :give("velocity",
            (math.random() - 0.5) * config.enemy.initialDriftSpeed,
            (math.random() - 0.5) * config.enemy.initialDriftSpeed)
        :give("rotation", math.random() * math.pi * 2)
        :give("faction", "enemy")
        :give("ship")
        :give("damageable")
        :give("health", maxHealth, maxHealth)
        :give("size", size)
        :give("collisionRadius", collisionRadius)
        :give("thrust", consts.enemyThrust, consts.enemyMaxSpeed)
        :give("weapon", weapons.enemyPulseLaser)
        :give("shipVisual", ship)
        :give("aiState", "idle")
        :give("wanderBehavior")
        :give("spawnPosition", x, y)
        :give("xpReward", config.player.xpPerEnemy or 0)
        :give("tokenReward", config.player.tokensPerEnemy or 0)
end

--------------------------------------------------------------------------------
-- ASTEROID ASSEMBLAGE
--------------------------------------------------------------------------------

function assemblages.asteroid(e, x, y, asteroidData, size)
    local s = size or 30
    local data = asteroidData or {}
    local collisionRadius = (data.shape and data.shape.boundingRadius) or s

    e:give("position", x, y)
        :give("velocity", 0, 0)
        :give("rotation", math.random() * math.pi * 2)
        :give("asteroid")
        :give("damageable")
        :give("health", s * 2, s * 2)
        :give("size", s)
        :give("collisionRadius", collisionRadius)
        :give("asteroidVisual", data)

    -- Resource yield based on composition
    if data.composition then
        e:give("resourceYield", data.composition)
    end
end

--------------------------------------------------------------------------------
-- PLAYER ASSEMBLAGE
--------------------------------------------------------------------------------

function assemblages.player(e, x, y, shipData)
    local size = config.player.size or 20
    local ship = shipData or ship_generator.generate(size)
    local maxHealth = config.player.maxHealth or 100
    local maxShield = config.player.maxShield or 50
    local collisionRadius = (ship and ship.boundingRadius) or size
    local consts = physics.constants

    e:give("position", x, y)
        :give("velocity", 0, 0)
        :give("rotation", 0)
        :give("faction", "player")
        :give("ship")
        :give("playerControlled")
        :give("damageable")
        :give("health", maxHealth, maxHealth)
        :give("shield", maxShield, maxShield)
        :give("size", size)
        :give("collisionRadius", collisionRadius)
        :give("thrust", consts.playerThrust, consts.playerMaxSpeed)
        :give("shipVisual", ship)
        :give("destination")
        :give("experience", 0, 1)
        :give("currency", 0)
        :give("cargo", {}, 20)
end

--------------------------------------------------------------------------------
-- WRECK ASSEMBLAGE
--------------------------------------------------------------------------------

function assemblages.wreck(e, x, y, cargo, coins)
    e:give("position", x, y)
        :give("wreck")
        :give("loot", cargo or {}, coins or 0)
        :give("lifetime", 120)
        :give("size", 20)
        :give("collisionRadius", 20)
end

--------------------------------------------------------------------------------
-- ITEM/PICKUP ASSEMBLAGE
--------------------------------------------------------------------------------

function assemblages.item(e, x, y, resourceType, amount)
    e:give("position", x, y)
        :give("velocity", 0, 0)
        :give("item")
        :give("size", 8)
        :give("collisionRadius", 12)
        :give("resourceYield", { [resourceType] = amount })
        :give("lifetime", 60)
end

return assemblages
