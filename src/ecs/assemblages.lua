--------------------------------------------------------------------------------
-- ECS ASSEMBLAGES
-- Entity blueprints for spawning common entity types
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local config = require("src.core.config")
local physics = require("src.core.physics")
local weapons = require("src.core.weapons")
local ship_generator = require("src.utils.procedural_ship_generator")
local core_ship = require("src.core.ship")
local enemyDefs = require("src.data.enemies")

local assemblages = {}

local function randFloat(min, max)
    if min == nil and max == nil then
        return 0
    end
    if max == nil then
        return min
    end
    return min + math.random() * (max - min)
end

local function pickEnemyDef(defId)
    if defId and enemyDefs and enemyDefs[defId] then
        return enemyDefs[defId]
    end

    if enemyDefs and enemyDefs.list and #enemyDefs.list > 0 then
        return enemyDefs.list[math.random(1, #enemyDefs.list)]
    end

    return enemyDefs and enemyDefs.default or nil
end

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
    local consts = physics.constants

    -- shipSize is historically a numeric size override, but to keep the API
    -- flexible we also accept:
    --   - string: enemy definition id (e.g. "scout")
    --   - table:  { id = "scout", size = 20 }
    local sizeOverride = nil
    local defId = nil
    if type(shipSize) == "number" then
        sizeOverride = shipSize
    elseif type(shipSize) == "string" then
        defId = shipSize
    elseif type(shipSize) == "table" then
        defId = shipSize.id or shipSize.enemyId or shipSize.defId
        sizeOverride = shipSize.size
    end

    local def = pickEnemyDef(defId)
    if not def then
        return
    end

    ------------------------------------------------------------------------
    -- Level + size
    ------------------------------------------------------------------------
    local levelMin = (def.levelRange and def.levelRange.min) or enemyConfig.levelMin or 1
    local levelMax = (def.levelRange and def.levelRange.max) or enemyConfig.levelMax or levelMin
    if levelMax < levelMin then
        levelMax = levelMin
    end
    local level = math.random(levelMin, levelMax)
    local levelStep = level - 1

    local sizeMin = (def.sizeRange and def.sizeRange.min) or enemyConfig.sizeMin
    local sizeMax = (def.sizeRange and def.sizeRange.max) or enemyConfig.sizeMax
    local size = sizeOverride or randFloat(sizeMin, sizeMax)

    ------------------------------------------------------------------------
    -- Ship layout
    ------------------------------------------------------------------------
    local ship = core_ship.buildInstanceFromBlueprint(def.shipBlueprint, size)
    local collisionRadius = (ship and ship.boundingRadius) or size

    ------------------------------------------------------------------------
    -- Health
    ------------------------------------------------------------------------
    local baseHealth = (def.health and def.health.base) or enemyConfig.maxHealth
    local healthPerLevel = (def.health and def.health.perLevel) or enemyConfig.healthPerLevel or 0
    local maxHealth = baseHealth
    if levelStep > 0 and healthPerLevel ~= 0 then
        maxHealth = maxHealth * (1 + levelStep * healthPerLevel)
    end

    ------------------------------------------------------------------------
    -- AI ranges (detection does not scale)
    ------------------------------------------------------------------------
    local detectionRange = (def.ai and def.ai.detectionRange) or enemyConfig.detectionRange
    local attackRange = (def.ai and def.ai.attackRange) or enemyConfig.attackRange
    local attackPerLevel = (def.ai and def.ai.attackRangePerLevel) or enemyConfig.attackRangePerLevel or 0
    if levelStep > 0 and attackPerLevel ~= 0 then
        attackRange = attackRange * (1 + levelStep * attackPerLevel)
    end

    ------------------------------------------------------------------------
    -- Weapon
    ------------------------------------------------------------------------
    local weaponId = (def.weapon and def.weapon.id) or "enemyPulseLaser"
    local baseWeapon = weapons[weaponId] or weapons.enemyPulseLaser
    local weaponData = {}
    if baseWeapon then
        for k, v in pairs(baseWeapon) do
            weaponData[k] = v
        end

        if def.weapon and def.weapon.damage ~= nil then
            weaponData.damage = def.weapon.damage
        end

        local damagePerLevel = (def.weapon and def.weapon.damagePerLevel) or enemyConfig.weaponDamagePerLevel or 0
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
        :give("wanderBehavior", nil, nil, enemyConfig.wanderRadius)
        :give("spawnPosition", x, y)
        :give("xpReward", (def.rewards and def.rewards.xp) or config.player.xpPerEnemy or 0)
        :give("tokenReward", (def.rewards and def.rewards.tokens) or config.player.tokensPerEnemy or 0)
        :give("damping", 0.8)

    if def.rewards and def.rewards.loot then
        e:give("loot", def.rewards.loot.cargo, def.rewards.loot.coins)
    end

    ------------------------------------------------------------------------
    -- Physics body (Box2D) so collisions work the same as legacy enemy spawns.
    ------------------------------------------------------------------------
    local collisionVertices = ship and ship.collisionVertices

    local body, shapes, fixtures
    if collisionVertices and #collisionVertices >= 6 then
        body, shapes, fixtures = physics.createPolygonBody(x, y, collisionVertices, "ENEMY", e, {})
    else
        local b, s, f = physics.createCircleBody(x, y, collisionRadius, "ENEMY", e, {})
        body = b
        shapes = s and { s } or nil
        fixtures = f and { f } or nil
    end

    if body then
        e:give("physics", body, shapes, fixtures)
    end
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
