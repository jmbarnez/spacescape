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

--- PROJECTILE ASSEMBLAGE
--------------------------------------------------------------------------------

function assemblages.projectile(e, shooter, targetX, targetY, targetEntity)
    local sx, sy, size, weapon, faction

    if shooter.position then
        sx = shooter.position.x
        sy = shooter.position.y
        size = shooter.size and shooter.size.value or 20
        weapon = shooter.weapon and shooter.weapon.data or {}
        faction = shooter.faction and shooter.faction.name or "player"
    else
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

    local categoryName = (faction == "enemy") and "ENEMY_PROJECTILE" or "PLAYER_PROJECTILE"
    local body, shape, fixture = physics.createCircleBody(
        x, y, 4, categoryName, e,
        { isSensor = true, isBullet = true }
    )

    if body then
        e:give("physics", body, shape and { shape } or nil, fixture and { fixture } or nil)
        body:setLinearVelocity(math.cos(angle) * speed, math.sin(angle) * speed)
    end
end

--------------------------------------------------------------------------------
-- ENEMY SHIP ASSEMBLAGE
--------------------------------------------------------------------------------

function assemblages.enemy(e, x, y, shipSize)
    local enemyConfig = config.enemy
    local size = shipSize or enemyConfig.sizeMin + math.random() * (enemyConfig.sizeMax - enemyConfig.sizeMin)
    local ship = ship_generator.generate(size)
    local maxHealth = enemyConfig.maxHealth
    local collisionRadius = (ship and ship.boundingRadius) or size
    local consts = physics.constants

    local levelMin = enemyConfig.levelMin or 1
    local levelMax = enemyConfig.levelMax or levelMin
    local level = math.random(levelMin, levelMax)
    local levelStep = level - 1

    local healthPerLevel = enemyConfig.healthPerLevel or 0
    if levelStep > 0 and healthPerLevel ~= 0 then
        maxHealth = maxHealth * (1 + levelStep * healthPerLevel)
    end

    local detectionRange = enemyConfig.detectionRange
    local attackRange = enemyConfig.attackRange
    local detectionPerLevel = enemyConfig.detectionRangePerLevel or 0
    local attackPerLevel = enemyConfig.attackRangePerLevel or 0
    if levelStep > 0 then
        if detectionRange and detectionPerLevel ~= 0 then
            detectionRange = detectionRange * (1 + levelStep * detectionPerLevel)
        end
        if attackRange and attackPerLevel ~= 0 then
            attackRange = attackRange * (1 + levelStep * attackPerLevel)
        end
    end

    local baseWeapon = weapons.enemyPulseLaser
    local weaponData = {}
    if baseWeapon then
        for k, v in pairs(baseWeapon) do
            weaponData[k] = v
        end
        local damagePerLevel = enemyConfig.weaponDamagePerLevel or 0
        local baseDamage = weaponData.damage or 1
        if levelStep > 0 and damagePerLevel ~= 0 then
            weaponData.damage = baseDamage * (1 + levelStep * damagePerLevel)
        end
    end

    e:give("position", x, y)
        :give("velocity",
            (math.random() - 0.5) * enemyConfig.initialDriftSpeed,
            (math.random() - 0.5) * enemyConfig.initialDriftSpeed)
        :give("rotation", math.random() * math.pi * 2)
        :give("faction", "enemy")
        :give("ship")
        :give("damageable")
        :give("health", maxHealth, maxHealth)
        :give("size", size)
        :give("collisionRadius", collisionRadius)
        :give("thrust", consts.enemyThrust, consts.enemyMaxSpeed)
        :give("weapon", weaponData)
        :give("shipVisual", ship)
        :give("aiState", "idle", detectionRange, attackRange)
        :give("enemyLevel", level)
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
