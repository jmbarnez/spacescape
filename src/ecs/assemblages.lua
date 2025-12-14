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
local player_drone = require("src.data.ships.player_drone")

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
        local setLinearVelocity = body["setLinearVelocity"]
        if setLinearVelocity then
            setLinearVelocity(body, math.cos(angle) * speed, math.sin(angle) * speed)
        end
    end
end

--------------------------------------------------------------------------------
-- ENEMY SHIP ASSEMBLAGE
--------------------------------------------------------------------------------

function assemblages.enemy(e, x, y, shipSize)
    local enemyConfig = config.enemy
    local consts = physics.constants

    -- shipSize is historically a numeric size override, but we now treat the
    -- 3rd parameter as a flexible spawn "spec":
    --   - { def = enemyDef }   -- explicit definition table
    --   - { id = "scout" }     -- select by enemy definition id
    --   - { size = 20 }        -- size override while keeping random enemy type
    --
    -- Backward compatible legacy forms:
    --   - number -> size override
    --   - string -> enemy id
    --   - table  -> spec (or raw enemyDef table)
    local sizeOverride = nil
    local defId = nil
    local def = nil

    if type(shipSize) == "number" then
        sizeOverride = shipSize
    elseif type(shipSize) == "string" then
        defId = shipSize
    elseif type(shipSize) == "table" then
        -- Explicit spec wrapper.
        if shipSize.def or shipSize.enemyDef then
            def = shipSize.def or shipSize.enemyDef
            defId = shipSize.id or shipSize.enemyId or shipSize.defId
            sizeOverride = shipSize.size
        else
            -- Spec shape.
            defId = shipSize.id or shipSize.enemyId or shipSize.defId
            sizeOverride = shipSize.size

            -- If the table looks like a raw enemy definition (as stored in
            -- src/data/enemies/*.lua), treat it as the definition directly.
            if not defId and shipSize.shipBlueprint then
                def = shipSize
            end
        end
    end

    def = def or pickEnemyDef(defId)
    if not def then
        return
    end

    ------------------------------------------------------------------------
    -- Definition reference
    --
    -- Store the resolved enemy definition on the entity so other systems
    -- (legacy collision rewards, loot drops, UI, etc.) can read per-enemy
    -- tuning values without having to re-resolve the definition.
    ------------------------------------------------------------------------
    e.enemyDef = def
    e.enemyDefId = def.id

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

    if def.respawn then
        e:give("respawnOnDeath", def.respawn.delay, def)
    end

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

    local function calculateSizeInterpolation(value)
        local minSize = config.asteroid and config.asteroid.minSize or 0
        local maxSize = config.asteroid and config.asteroid.maxSize or minSize
        local range = maxSize - minSize
        if range <= 0 then
            return 0
        end
        local t = (value - minSize) / range
        return math.max(0, math.min(1, t))
    end

    local function buildCompositionText(asteroidVisualData)
        if not asteroidVisualData or not asteroidVisualData.composition then
            return "Stone and ice"
        end

        local c = asteroidVisualData.composition
        local stone = c.stone or 0
        local ice = c.ice or 0
        local mithril = c.mithril or 0

        local total = stone + ice + mithril
        if total <= 0 then
            return "Stone and ice"
        end

        local stonePercent = math.floor((stone / total) * 100 + 0.5)
        local icePercent = math.floor((ice / total) * 100 + 0.5)
        local mithrilPercent = math.floor((mithril / total) * 100 + 0.5)

        if mithrilPercent >= 10 then
            return string.format("Stone %d%%, Ice %d%%, Mithril %d%%", stonePercent, icePercent, mithrilPercent)
        elseif mithrilPercent > 0 then
            return string.format("Stone %d%%, Ice %d%%, traces of Mithril", stonePercent, icePercent)
        end

        return string.format("Stone %d%%, Ice %d%%", stonePercent, icePercent)
    end

    -- Convert the asteroid's authored composition (0..1-ish weights) into a
    -- concrete integer resource yield so the ECS RewardSystem can spawn drops
    -- without depending on legacy collision reward code.
    local yield = nil
    if data.composition then
        local comp = data.composition
        local stone = tonumber(comp.stone) or 0
        local ice = tonumber(comp.ice) or 0
        local mithril = tonumber(comp.mithril) or 0
        local total = stone + ice + mithril

        -- Scale total number of chunks by asteroid size.
        local baseChunks = math.max(1, math.floor((s or 20) / 10))

        if total <= 0 then
            yield = { stone = baseChunks }
        else
            local function roundShare(v)
                return math.max(0, math.floor((v / total) * baseChunks + 0.5))
            end

            local stoneAmt = roundShare(stone)
            local iceAmt = roundShare(ice)
            local mithrilAmt = roundShare(mithril)

            if (stoneAmt + iceAmt + mithrilAmt) <= 0 then
                stoneAmt = baseChunks
            end

            yield = {
                stone = stoneAmt,
                ice = iceAmt,
                mithril = mithrilAmt,
            }
        end
    end

    local t = calculateSizeInterpolation(s)
    local minHealth = config.asteroid and config.asteroid.minHealth or (s * 2)
    local maxHealthCfg = config.asteroid and config.asteroid.maxHealth or minHealth
    local maxHealth = minHealth + t * (maxHealthCfg - minHealth)

    local consts = physics.constants or {}
    local minDrift = consts.asteroidMinDrift or 0
    local maxDrift = consts.asteroidMaxDrift or minDrift
    local driftSpeed = minDrift + math.random() * (maxDrift - minDrift)
    local driftAngle = math.random() * math.pi * 2
    local vx = math.cos(driftAngle) * driftSpeed
    local vy = math.sin(driftAngle) * driftSpeed

    local rotationSpeedRange = config.asteroid and config.asteroid.rotationSpeedRange or 0
    local rotationSpeed = (math.random() - 0.5) * rotationSpeedRange
    local compositionText = buildCompositionText(data)

    e:give("position", x, y)
        :give("velocity", vx, vy)
        :give("rotation", math.random() * math.pi * 2)
        :give("asteroid")
        :give("damageable")
        :give("health", maxHealth, maxHealth)
        :give("size", s)
        :give("collisionRadius", collisionRadius)
        :give("asteroidVisual", data)

    -- Award XP when the player destroys an asteroid.
    e:give("xpReward", config.player.xpPerAsteroid or 0)

    -- Resource yield based on composition
    if yield then
        e:give("resourceYield", yield)
    end

    e.rotationSpeed = rotationSpeed
    e.composition = compositionText
    e.data = data

    local collisionVertices = data and data.shape and data.shape.flatPoints
    local body, shapes, fixtures
    if collisionVertices and #collisionVertices >= 6 then
        body, shapes, fixtures = physics.createPolygonBody(x, y, collisionVertices, "ASTEROID", e, {})
    else
        local b, s2, f2 = physics.createCircleBody(x, y, collisionRadius, "ASTEROID", e, {})
        body = b
        shapes = s2 and { s2 } or nil
        fixtures = f2 and { f2 } or nil
    end

    if body then
        e:give("physics", body, shapes, fixtures)
    end
end

--------------------------------------------------------------------------------
-- PLAYER ASSEMBLAGE
--------------------------------------------------------------------------------

function assemblages.player(e, x, y, shipData)
    local size = config.player.size or 20

    local function looksLikeNormalizedBlueprint(data)
        if type(data) ~= "table" then
            return false
        end
        if not (data.hull and data.hull.points and data.hull.points[1]) then
            return false
        end

        local p = data.hull.points[1]
        if type(p) ~= "table" then
            return false
        end

        local px = tonumber(p[1]) or 0
        local py = tonumber(p[2]) or 0

        -- Normalized authored blueprints use values around [-1.5, 1.5].
        -- World-space instances use values scaled by ship size (e.g. 30+).
        return math.abs(px) <= 3 and math.abs(py) <= 3
    end

    local ship = nil
    if shipData then
        if looksLikeNormalizedBlueprint(shipData) then
            ship = core_ship.buildInstanceFromBlueprint(shipData, size)
        else
            ship = shipData
        end
    end

    ship = ship or core_ship.buildInstanceFromBlueprint(player_drone, size)
    ship = ship or ship_generator.generate(size)

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
        :give("damping", consts.linearDamping)
        :give("shipVisual", ship)
        :give("destination")
        :give("experience", 0, 1)
        :give("currency", 0)
        :give("cargo", {}, 20)
        :give("magnet", config.player and config.player.magnetRadius, config.player and config.player.magnetPickupRadius)
        :give("weapon", weapons.pulseLaser)

    local collisionVertices = ship and ship.collisionVertices
    local body, shapes, fixtures
    if collisionVertices and #collisionVertices >= 6 then
        body, shapes, fixtures = physics.createPolygonBody(x, y, collisionVertices, "PLAYER", e, {})
    else
        local b, s, f = physics.createCircleBody(x, y, collisionRadius, "PLAYER", e, {})
        body = b
        shapes = s and { s } or nil
        fixtures = f and { f } or nil
    end

    if body then
        e:give("physics", body, shapes, fixtures)
    end
end

--------------------------------------------------------------------------------
-- WRECK ASSEMBLAGE
--------------------------------------------------------------------------------

function assemblages.wreck(e, x, y, cargo, coins)
    -- Wrecks are loot containers: they drift slowly, can be clicked/hovered,
    -- and can be target-locked (for UX parity with asteroids/enemies), but
    -- they do not participate in combat collisions.
    local size = 24
    local collisionRadius = size

    -- Random slow drift + slow rotation so wrecks feel like debris.
    local driftSpeed = 8
    local driftAngle = math.random() * math.pi * 2
    local rotationSpeed = (math.random() - 0.5) * 0.3

    e:give("position", x, y)
        :give("rotation", math.random() * math.pi * 2)
        :give("wreck")
        :give("loot", cargo or {}, coins or 0)
        :give("lifetime", 180)
        :give("size", size)
        :give("collisionRadius", collisionRadius)

    -- Drift velocity is stored as plain fields to avoid being double-integrated
    -- by the ECS movement system and the legacy wreck update loop.
    -- UPDATE: Now using ECS MovementSystem, so we give Velocity component.
    e:give("velocity", math.cos(driftAngle) * driftSpeed, math.sin(driftAngle) * driftSpeed)


    -- Store total lifetime as a plain entity field so legacy-style draw code
    -- can fade out near expiry without needing a second ECS component.
    e.lifetimeTotal = 180

    -- Stored on the entity (not a component) because it is purely visual.
    e.rotationSpeed = rotationSpeed

    -- Provide collision vertices for the hover outline renderer so wrecks
    -- get the same nice polygon outline behavior as ships/asteroids.
    local half = size / 2
    e.collisionVertices = {
        -half, -half,
        half, -half,
        half, half,
        -half, half,
    }

    -- Create a non-colliding sensor body so wrecks are still represented in
    -- the physics world (and can be queried/debugged consistently).
    local body, shape, fixture = physics.createCircleBody(
        x, y, collisionRadius,
        "WRECK",
        e,
        { isSensor = true, bodyType = "dynamic" }
    )

    if body then
        e:give("physics", body, shape and { shape } or nil, fixture and { fixture } or nil)
    end
end

--------------------------------------------------------------------------------
-- ITEM/PICKUP ASSEMBLAGE
--------------------------------------------------------------------------------

function assemblages.item(e, x, y, resourceType, amount)
    e:give("position", x, y)
        :give("velocity", 0, 0)
        :give("item")
        :give("size", 6)
        :give("collisionRadius", 8)
        :give("resourceYield", { [resourceType] = amount })
        :give("lifetime", 60)
end

return assemblages
