--------------------------------------------------------------------------------
-- COLLISION SYSTEM
-- Unified collision handling using Box2D callbacks with type-based dispatch
--
-- This system registers itself with the physics module to receive collision
-- events. When two fixtures collide, Box2D calls our onBeginContact handler,
-- which dispatches to the appropriate handler based on entity types.
--
-- ARCHITECTURE:
-- 1. Each entity has userData attached to its fixture: { type = "...", entity = ref }
-- 2. Box2D filters ensure only valid pairs collide (via category/mask in physics.lua)
-- 3. onBeginContact receives both entities and dispatches to a handler
-- 4. Handlers are registered in a lookup table for O(1) dispatch
--
-- ADDING NEW ENTITY TYPES:
-- 1. Add category/mask in physics.lua
-- 2. Create entity with physics.createPolygonBody() or physics.createCircleBody()
-- 3. Add handler function below
-- 4. Register handler in COLLISION_HANDLERS table
--------------------------------------------------------------------------------

local physics = require("src.core.physics")
local enemyModule = require("src.entities.enemy")
local projectileModule = require("src.entities.projectile")
local asteroidModule = require("src.entities.asteroid")
local explosionFx = require("src.entities.explosion_fx")
local shieldImpactFx = require("src.entities.shield_impact_fx")
local floatingText = require("src.entities.floating_text")
local baseColors = require("src.core.colors")
local config = require("src.core.config")
local playerModule = require("src.entities.player")
local projectileShards = require("src.entities.projectile_shards")
local itemModule = require("src.entities.item")

local collision = {}

--------------------------------------------------------------------------------
-- MODULE REFERENCES
-- Direct references to entity lists for fast access during collision handling
--------------------------------------------------------------------------------
local enemies = enemyModule.list
local bullets = projectileModule.list
local asteroids = asteroidModule.list

local ENABLE_CONTINUOUS_SHIP_ASTEROID_RESOLVE = false

--- CONFIGURATION
-- Colors and settings for visual feedback
--------------------------------------------------------------------------------
local DAMAGE_COLOR_ENEMY = baseColors.damageEnemy   -- Yellow-ish for damage to enemies
local DAMAGE_COLOR_PLAYER = baseColors.damagePlayer -- Red-ish for damage to player
local MISS_BG_COLOR = baseColors.missBg             -- Blue background for miss text

--------------------------------------------------------------------------------
-- RUNTIME STATE
-- These are set during init() and used by collision handlers
--------------------------------------------------------------------------------
local currentParticles = nil
local currentColors = nil
local currentDamagePerHit = config.combat.damagePerHit
local playerDiedThisFrame = false

--------------------------------------------------------------------------------
-- PENDING COLLISION QUEUE
-- Box2D callbacks happen during world:update(), so we can't safely modify
-- physics objects (destroy bodies) during the callback. Instead, we queue
-- collisions and process them after the physics step.
--------------------------------------------------------------------------------
local pendingCollisions = {}

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
-- Shared helpers used by multiple collision handlers
--------------------------------------------------------------------------------

--- Calculate the contact point between two entities
--- Places the contact on the target's surface along the line toward the projectile.
--- @param x1 number Center X of first entity (projectile)
--- @param y1 number Center Y of first entity (projectile)
--- @param x2 number Center X of second entity (target)
--- @param y2 number Center Y of second entity (target)
--- @param boundingRadius number Approximate bounding radius of target (for visual offset)
--- @return number, number Contact point X and Y (approximated on target surface)
local function getContactPoint(x1, y1, x2, y2, boundingRadius)
    local dx = x1 - x2
    local dy = y1 - y2
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance > 0 and boundingRadius and boundingRadius > 0 then
        local invDist = 1.0 / distance
        -- Point on the target's surface, facing the projectile's center
        return x2 + dx * invDist * boundingRadius,
            y2 + dy * invDist * boundingRadius
    end

    -- Fallback: just use the projectile position if something is degenerate
    return x1, y1
end

--- Get the bounding radius of an entity (for visual effects positioning)
--- Works for both circular and polygon colliders
--- @param entity table The entity to get bounding radius for
--- @return number The bounding radius
local function getBoundingRadius(entity)
    -- For polygon bodies, use stored collision radius or compute from vertices
    if entity.collisionRadius then
        return entity.collisionRadius
    end
    -- For ships with procedural data
    if entity.ship and entity.ship.boundingRadius then
        return entity.ship.boundingRadius
    end
    -- For asteroids with procedural data
    if entity.data and entity.data.shape and entity.data.shape.boundingRadius then
        return entity.data.shape.boundingRadius
    end
    -- Fallback to size
    return entity.size or 10
end

--- Spawn floating damage text above an entity
--- @param amount number Damage amount to display
--- @param x number X position
--- @param y number Y position
--- @param radius number Entity radius (text appears above)
--- @param color table RGB color for the text (hull/shield)
--- @param options table Optional settings (duration, etc.)
local function spawnDamageText(amount, x, y, radius, color, options)
    local textY = y - radius - 10

    -- Configure floating text to use colored text only (no background box)
    options = options or {}
    if color then
        options.textColor = color
    end
    -- Transparent background so only glyphs are visible
    options.bgColor = options.bgColor or { 0, 0, 0, 0 }

    floatingText.spawn(tostring(math.floor(amount + 0.5)), x, textY, nil, options)
end

--- Remove an entity from a list and destroy its physics body
--- @param list table The entity list
--- @param entity table The entity to remove
local function removeEntity(list, entity)
    for i = #list, 1, -1 do
        if list[i] == entity then
            if entity.body then
                entity.body:destroy()
            end
            entity._removed = true
            table.remove(list, i)
            return true
        end
    end
    return false
end

--- Clean up all projectiles targeting a specific entity
--- @param target table The target entity being removed
local function cleanupProjectilesForTarget(target)
    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        if bullet.target == target then
            if bullet.body then
                bullet.body:destroy()
            end
            bullet._removed = true
            table.remove(bullets, i)
        end
    end
end

--- Apply damage to an entity and check for death
--- @param entity table The entity to damage
--- @param damage number Amount of damage
--- @return boolean True if entity died, shieldDamage, hullDamage
local function applyDamage(entity, damage)
    if not entity or not damage or damage <= 0 then
        return false, 0, 0
    end

    local shieldDamage = 0
    local hullDamage = 0

    local shield = entity.shield or 0
    if shield > 0 then
        if damage <= shield then
            entity.shield = shield - damage
            shieldDamage = damage
            return false, shieldDamage, hullDamage
        else
            entity.shield = 0
            shieldDamage = shield
            damage = damage - shield
        end
    end

    entity.health = (entity.health or 0) - damage
    hullDamage = damage
    return entity.health <= 0, shieldDamage, hullDamage
end

--- Roll hit chance based on weapon stats and distance traveled
--- @param projectile table The projectile entity
--- @return boolean True if the shot hits
local function rollHitChance(projectile)
    local weapon = projectile.weapon or (projectile.owner and projectile.owner.weapon) or {}
    local traveled = projectile.distanceTraveled or 0
    local hitChance = projectileModule.calculateHitChance(weapon, traveled)
    return math.random() <= hitChance
end

local function spawnProjectileShards(projectile, target, contactX, contactY, radius, countScale)
    if not projectileShards then
        return
    end

    local px = projectile.x or (projectile.body and projectile.body:getX())
    local py = projectile.y or (projectile.body and projectile.body:getY())
    local tx = target and target.x or contactX or px
    local ty = target and target.y or contactY or py
    local ix = contactX or tx or px
    local iy = contactY or ty or py

    if not ix or not iy or not px or not py then
        return
    end

    local dirX = px - tx
    local dirY = py - ty
    if dirX == 0 and dirY == 0 then
        dirX, dirY = math.cos(projectile.angle or 0), math.sin(projectile.angle or 0)
    end

    local baseSpeed = projectile.speed or (physics.constants and physics.constants.projectileSpeed) or 350

    -- Scale shard count based on projectile size (subtle: 3-5 shards max)
    local projectileRadius = 4 -- Default projectile radius
    local baseCount = math.max(2, math.min(5, math.floor(projectileRadius / 2) + 2))
    if countScale and countScale > 0 then
        baseCount = math.max(2, math.floor(baseCount * countScale))
    end

    local projectileConfig = projectile.projectileConfig or (projectile.weapon and projectile.weapon.projectile)
    local projectileColor = (projectileConfig and projectileConfig.color)
        or (currentColors and currentColors.projectile)
        or baseColors.projectile
        or baseColors.white

    projectileShards.spawn(ix, iy, dirX, dirY, baseSpeed, baseCount, projectileColor)
end

local function spawnShieldImpactVisual(target, projectile, contactX, contactY, radius)
    if not shieldImpactFx or not shieldImpactFx.spawn then
        return
    end
    if not target then
        return
    end

    local cx = target.x or contactX or (projectile and projectile.x)
    local cy = target.y or contactY or (projectile and projectile.y)
    local ix = contactX or cx
    local iy = contactY or cy
    local shieldRadius = radius or getBoundingRadius(target)

    if not shieldRadius or shieldRadius <= 0 then
        return
    end
    if not cx or not cy or not ix or not iy then
        return
    end

    local color = baseColors.shieldDamage or baseColors.projectile or baseColors.white

    --------------------------------------------------------------------------
    -- Pass the target through to the FX so the shield ring can track the
    -- entity's live position instead of staying behind at the impact point.
    -- This is especially important for the player, who can still drift after
    -- being hit.
    --------------------------------------------------------------------------
    shieldImpactFx.spawn(cx, cy, ix, iy, shieldRadius * 1.15, color, target)
end

local function awardXpAndTokensOnKill(xp, tokens)
    local playerState = playerModule and playerModule.state or nil
    if not playerState then
        return
    end

    if xp and xp > 0 and playerModule.addExperience then
        playerModule.addExperience(xp)
        local value = math.floor(xp + 0.5)
        local baseText = "XP"
        floatingText.spawn(baseText, playerState.x, playerState.y - 22, nil, {
            duration = 1.1,
            riseSpeed = 26,
            scale = 0.8,
            alpha = 1.0,
            bgColor = { 0, 0, 0, 0 },
            textColor = baseColors.health or baseColors.white,
            stackKey = "xp_total",
            stackValueIncrement = value,
            stackBaseText = baseText,
            iconPreset = "xp_only",
        })
    end

    if tokens and tokens > 0 and playerModule.addCurrency then
        playerModule.addCurrency(tokens)
        local value = math.floor(tokens + 0.5)
        local baseText = "Tokens"
        floatingText.spawn(baseText, playerState.x, playerState.y - 8, nil, {
            duration = 1.1,
            riseSpeed = 26,
            scale = 0.8,
            alpha = 1.0,
            bgColor = { 0, 0, 0, 0 },
            textColor = baseColors.uiText or baseColors.white,
            stackKey = "tokens_total",
            stackValueIncrement = value,
            stackBaseText = baseText,
            iconPreset = "token_only",
        })
    end
end

--- Compute a simple resource yield table for an asteroid based on its
--- procedural stone/ice/mithril composition and size.
--- @param asteroid table The asteroid entity
--- @param radius number Approximate asteroid radius (for scaling yield)
--- @return table Resource amounts { stone = n, ice = n, mithril = n }
local function computeAsteroidResourceYield(asteroid, radius)
    local size = asteroid and asteroid.size or radius or 20
    local baseChunks = math.max(1, math.floor((size or 20) / 10))
    local data = asteroid and asteroid.data
    local comp = data and data.composition

    if not comp then
        return { stone = baseChunks }
    end

    local stone = comp.stone or 0
    local ice = comp.ice or 0
    local mithril = comp.mithril or 0
    local total = stone + ice + mithril
    if total <= 0 then
        return { stone = baseChunks }
    end

    local scale = baseChunks / total
    local stoneAmt = math.max(0, math.floor(stone * scale + 0.5))
    local iceAmt = math.max(0, math.floor(ice * scale + 0.5))
    local mithrilAmt = math.max(0, math.floor(mithril * scale + 0.5))

    -- Ensure at least one chunk of something so every destroyed asteroid feels
    -- tangibly rewarding.
    if stoneAmt + iceAmt + mithrilAmt <= 0 then
        stoneAmt = baseChunks
    end

    return {
        stone = stoneAmt,
        ice = iceAmt,
        mithril = mithrilAmt,
    }
end

--- Compute a lightweight salvage yield for a destroyed enemy ship. For now we
--- treat this as generic "stone" scrap scaled very loosely by its radius.
--- @param enemy table The enemy entity
--- @param radius number Approximate enemy radius
--- @return table Resource amounts
local function computeEnemyResourceYield(enemy, radius)
    local r = radius or getBoundingRadius(enemy)
    local baseChunks = math.max(1, math.floor((r or 12) / 8))
    return {
        stone = baseChunks,
    }
end

--- Spawn a bursting cluster of resource chunks at the given position.
--- The total resources for each type are distributed across a handful of
--- pickups so that collection still feels like a satisfying spray.
--- @param x number World X position
--- @param y number World Y position
--- @param resources table Map resourceType -> totalAmount
local function spawnResourceChunksAt(x, y, resources)
    if not itemModule or not itemModule.spawnResourceChunk then
        return
    end
    if not resources then
        return
    end

    for resourceType, totalAmount in pairs(resources) do
        local total = math.floor(totalAmount or 0)
        if total > 0 then
            -- Split into a small, visually pleasing number of chunks.
            local minChunks = 2
            local maxChunks = 5
            local chunkCount = math.min(maxChunks, math.max(minChunks, math.floor(total / 2)))
            if chunkCount <= 0 then
                chunkCount = 1
            end

            local baseAmount = math.floor(total / chunkCount)
            if baseAmount < 1 then
                baseAmount = 1
            end
            local remainder = total - baseAmount * chunkCount

            for i = 1, chunkCount do
                local amount = baseAmount
                if remainder > 0 then
                    amount = amount + 1
                    remainder = remainder - 1
                end

                local angle = math.random() * math.pi * 2
                local radius = (math.random() * 14) + 6
                local sx = x + math.cos(angle) * radius
                local sy = y + math.sin(angle) * radius

                itemModule.spawnResourceChunk(sx, sy, resourceType, amount)
            end
        end
    end
end

--- Generic helper for handling a projectile hitting a target
--- This centralizes miss logic, particles, damage, and death effects.
--- @param projectile table The projectile entity
--- @param target table The target entity (enemy, player, asteroid)
--- @param contactX number|nil Optional contact X from Box2D
--- @param contactY number|nil Optional contact Y from Box2D
--- @param radius number|nil Optional precomputed target radius
--- @param config table Behavior config:
---   canMiss: boolean (if true, rollHitChance is used)
---   missOptions: table (options for miss floating text)
---   damageTextColor: table (RGB for damage text)
---   impactColor: table (RGB for impact particles)
---   impactCount: integer (particle count, default 6)
---   onKill: function(target, radius, damage) called if target dies
---   explosionOnHit: boolean (if true, spawn a small explosion at impact)
local function resolveProjectileHit(projectile, target, contactX, contactY, radius, config)
    if not projectile or not target then
        return
    end

    config = config or {}
    radius = radius or getBoundingRadius(target)

    -- Derive contact point if not provided
    if (not contactX or not contactY) and projectile.x and projectile.y and target.x and target.y then
        contactX, contactY = getContactPoint(
            projectile.x, projectile.y,
            target.x, target.y,
            radius
        )
    end

    -- Handle miss logic (for shots that can miss)
    if config.canMiss and not rollHitChance(projectile) then
        spawnProjectileShards(projectile, target, contactX, contactY, radius, 0.6)

        if target and target.shield and target.shield > 0 then
            spawnShieldImpactVisual(target, projectile, contactX, contactY, radius)
        end

        removeEntity(bullets, projectile)
        return
    end

    spawnProjectileShards(projectile, target, contactX, contactY, radius, 1.0)

    -- Apply damage and spawn floating numbers for shield vs hull
    local damage = projectile.damage or currentDamagePerHit

    local died, shieldDamage, hullDamage = applyDamage(target, damage)

    -- Shield damage (bright blue)
    if shieldDamage and shieldDamage > 0 then
        local shieldColor = baseColors.shieldDamage or baseColors.projectile or
        (currentColors and currentColors.projectile) or baseColors.white
        spawnDamageText(shieldDamage, target.x, target.y, radius, shieldColor, nil)
        spawnShieldImpactVisual(target, projectile, contactX, contactY, radius)
    end

    -- Hull damage (use configured damage text color)
    if hullDamage and hullDamage > 0 then
        local hullColor = config.damageTextColor or DAMAGE_COLOR_ENEMY
        spawnDamageText(hullDamage, target.x, target.y, radius, hullColor, nil)
    end

    -- Remove the projectile on any resolved hit
    removeEntity(bullets, projectile)

    -- Death handling
    if died and config.onKill then
        config.onKill(target, radius, damage)
    end
end

--------------------------------------------------------------------------------
-- COLLISION HANDLERS
-- Each handler processes a specific pair of entity types
-- Handlers receive (entityA, entityB) where types are guaranteed by dispatch
--------------------------------------------------------------------------------

--- Handle player projectile hitting an enemy
--- @param projectile table The projectile entity
--- @param enemy table The enemy entity
--- @param contactX number Contact point X (optional)
--- @param contactY number Contact point Y (optional)
local function handlePlayerProjectileVsEnemy(projectile, enemy, contactX, contactY)
    -- Skip if projectile is targeting a different enemy
    if projectile.target and projectile.target ~= enemy then
        return
    end

    local enemyRadius = getBoundingRadius(enemy)

    resolveProjectileHit(projectile, enemy, contactX, contactY, enemyRadius, {
        canMiss = true,
        missOptions = { bgColor = MISS_BG_COLOR },
        -- Use red for hull damage numbers (matches player hull color)
        damageTextColor = DAMAGE_COLOR_PLAYER,
        impactColor = currentColors and currentColors.projectile or nil,
        impactCount = 10,
        onKill = function(target, radius)
            explosionFx.spawn(target.x, target.y, currentColors.enemy, radius * 1.4)
            cleanupProjectilesForTarget(target)
            removeEntity(enemies, target)
            local owner = projectile.owner
            if owner and owner.faction ~= "enemy" then
                local xp = config.player.xpPerEnemy or 0
                local tokens = config.player.tokensPerEnemy or 0
                awardXpAndTokensOnKill(xp, tokens)
                local resources = computeEnemyResourceYield(target, radius)
                spawnResourceChunksAt(target.x, target.y, resources)
            end
        end,
    })
end

--- Handle enemy projectile hitting the player
--- @param projectile table The projectile entity
--- @param player table The player entity
--- @param contactX number Contact point X (optional)
--- @param contactY number Contact point Y (optional)
local function handleEnemyProjectileVsPlayer(projectile, player, contactX, contactY)
    local playerRadius = player.size or getBoundingRadius(player)

    resolveProjectileHit(projectile, player, contactX, contactY, playerRadius, {
        canMiss = true,
        missOptions = { bgColor = MISS_BG_COLOR },
        damageTextColor = DAMAGE_COLOR_PLAYER,
        impactColor = currentColors and currentColors.projectile or nil,
        impactCount = 10,
        onKill = function(target, radius)
            explosionFx.spawn(target.x, target.y, currentColors.ship, radius * 2.2)
            playerDiedThisFrame = true
        end,
    })
end

--- Handle any projectile hitting an asteroid
--- @param projectile table The projectile entity
--- @param asteroid table The asteroid entity
--- @param contactX number Contact point X (optional)
--- @param contactY number Contact point Y (optional)
local function handleProjectileVsAsteroid(projectile, asteroid, contactX, contactY)
    local asteroidRadius = getBoundingRadius(asteroid)
    local asteroidColor = (asteroid.data and asteroid.data.color) or (currentColors and currentColors.enemy) or
    baseColors.enemy

    -- Asteroids always get hit (no miss chance)
    resolveProjectileHit(projectile, asteroid, contactX, contactY, asteroidRadius, {
        canMiss = false,
        damageTextColor = DAMAGE_COLOR_ENEMY,
        -- Use projectile color for impact particles, asteroid color only for big death explosions
        impactColor = currentColors and currentColors.projectile or nil,
        impactCount = 14,
        onKill = function(target, radius)
            if currentParticles then
                currentParticles.explosion(target.x, target.y, asteroidColor)
            end
            cleanupProjectilesForTarget(target)
            removeEntity(asteroids, target)
            local owner = projectile.owner
            if owner and owner.faction ~= "enemy" then
                local xp = config.player.xpPerAsteroid or 0
                local tokens = config.player.tokensPerAsteroid or 0
                awardXpAndTokensOnKill(xp, tokens)
                local resources = computeAsteroidResourceYield(target, radius)
                spawnResourceChunksAt(target.x, target.y, resources)
            end
        end,
    })
end

--- Handle player colliding with an enemy (ram damage)
--- @param player table The player entity
--- @param enemy table The enemy entity
--- @param contactX number|nil Contact point X (optional)
--- @param contactY number|nil Contact point Y (optional)
local function handlePlayerVsEnemy(player, enemy, contactX, contactY)
    local enemyRadius = getBoundingRadius(enemy)

    -- Destroy the enemy on contact
    explosionFx.spawn(enemy.x, enemy.y, currentColors.enemy, enemyRadius * 1.4)
    cleanupProjectilesForTarget(enemy)
    removeEntity(enemies, enemy)
    local xp = config.player.xpPerEnemy or 0
    local tokens = config.player.tokensPerEnemy or 0
    awardXpAndTokensOnKill(xp, tokens)
    local resources = computeEnemyResourceYield(enemy, enemyRadius)
    spawnResourceChunksAt(enemy.x, enemy.y, resources)

    -- Damage the player; shields absorb before hull
    local damage = currentDamagePerHit
    local died, shieldDamage, hullDamage = applyDamage(player, damage)

    -- Shield damage text (bright blue)
    if shieldDamage and shieldDamage > 0 then
        local shieldColor = baseColors.shieldDamage or baseColors.projectile or
        (currentColors and currentColors.projectile) or baseColors.white
        spawnDamageText(shieldDamage, player.x, player.y, player.size, shieldColor, nil)
    end

    if shieldDamage and shieldDamage > 0 and shieldImpactFx and shieldImpactFx.spawn then
        local px = player.x
        local py = player.y
        local ix = contactX or (enemy and enemy.x) or px
        local iy = contactY or (enemy and enemy.y) or py
        local radius = getBoundingRadius(player)
        if radius and radius > 0 and px and py and ix and iy then
            ------------------------------------------------------------------
            -- Attach the FX to the player state so the ring visually follows
            -- the ship if it continues to move after the ram impact.
            ------------------------------------------------------------------
            shieldImpactFx.spawn(px, py, ix, iy, radius * 1.15,
                baseColors.shieldDamage or baseColors.projectile or baseColors.white,
                player)
        end
    end

    -- Hull damage text (red for player)
    if hullDamage and hullDamage > 0 then
        spawnDamageText(hullDamage, player.x, player.y, player.size, DAMAGE_COLOR_PLAYER, nil)
    end

    if died then
        explosionFx.spawn(player.x, player.y, currentColors.ship, player.size * 2.2)
        playerDiedThisFrame = true
    end
end

--- Resolve a generic ship colliding with an asteroid (push ship away, no damage)
--- @param ship table The ship entity (player or enemy)
--- @param asteroid table The asteroid entity
--- @param contactX number|nil Contact point X from Box2D (optional)
--- @param contactY number|nil Contact point Y from Box2D (optional)
local function resolveShipVsAsteroid(ship, asteroid, contactX, contactY)
    if not ship or not asteroid then
        return
    end

    local dx = ship.x - asteroid.x
    local dy = ship.y - asteroid.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance <= 0 then
        return
    end

    local shipRadius
    local asteroidRadius

    if contactX and contactY then
        local sx = contactX - ship.x
        local sy = contactY - ship.y
        shipRadius = math.sqrt(sx * sx + sy * sy)

        local ax = contactX - asteroid.x
        local ay = contactY - asteroid.y
        asteroidRadius = math.sqrt(ax * ax + ay * ay)
    else
        shipRadius = getBoundingRadius(ship)
        asteroidRadius = getBoundingRadius(asteroid)
    end

    if not shipRadius or not asteroidRadius or shipRadius <= 0 or asteroidRadius <= 0 then
        return
    end

    local minDistance = shipRadius + asteroidRadius

    -- Push ship away from asteroid
    if distance < minDistance then
        local overlap = minDistance - distance
        local invDist = 1.0 / distance

        ------------------------------------------------------------------
        -- Positional resolve: push the ship out of the asteroid so that the
        -- two shapes no longer overlap. This keeps the physics stable and
        -- avoids jitter at the contact point.
        ------------------------------------------------------------------
        ship.x = ship.x + dx * invDist * overlap
        ship.y = ship.y + dy * invDist * overlap

        -- Sync physics body position
        if ship.body then
            ship.body:setPosition(ship.x, ship.y)
        end

        ------------------------------------------------------------------
        -- Visual sparks at the contact point; reused for both player and
        -- enemy ships so asteroid impacts always feel physical.
        ------------------------------------------------------------------
        local sparkX, sparkY = contactX, contactY
        if not sparkX or not sparkY then
            sparkX = asteroid.x + dx * invDist * asteroidRadius
            sparkY = asteroid.y + dy * invDist * asteroidRadius
        end

        if sparkX and sparkY and currentParticles then
            currentParticles.spark(sparkX, sparkY, baseColors.asteroidSpark, 2)
        end

        ------------------------------------------------------------------
        -- Shield impact FX + bounce for the player ship when shields are up.
        -- Enemies keep their existing sliding behavior so they do not jitter
        -- around asteroids as aggressively.
        ------------------------------------------------------------------
        if ship == playerModule.state and ship.shield and ship.shield > 0 then
            if shieldImpactFx and shieldImpactFx.spawn then
                local sx = ship.x
                local sy = ship.y
                local ix = sparkX
                local iy = sparkY
                local shieldRadius = getBoundingRadius(ship)

                if shieldRadius and shieldRadius > 0 and sx and sy and ix and iy then
                    ------------------------------------------------------------------
                    -- Attach the asteroid bump FX to the player ship so the
                    -- ring remains centered on the hull while the short
                    -- bounce animation plays out.
                    ------------------------------------------------------------------
                    shieldImpactFx.spawn(sx, sy, ix, iy, shieldRadius * 1.15,
                        baseColors.shieldDamage or baseColors.projectile or baseColors.white,
                        ship)
                end
            end

            -- Reflect the player's velocity around the contact normal so that
            -- the ship "bounces" off the asteroid surface while losing a bit
            -- of speed according to the configured bounceFactor.
            local vx = ship.vx or 0
            local vy = ship.vy or 0
            local speedSq = vx * vx + vy * vy
            if speedSq > 0 then
                local nx = dx * invDist
                local ny = dy * invDist
                local dot = vx * nx + vy * ny

                -- Only reflect if we are actually moving into the surface.
                if dot < 0 then
                    local bounce = config.player.bounceFactor or 0.5
                    local rvx = vx - 2 * dot * nx
                    local rvy = vy - 2 * dot * ny
                    ship.vx = rvx * bounce
                    ship.vy = rvy * bounce
                end
            end
        end
    end
end

--- Handle player colliding with an asteroid (Box2D event wrapper)
--- @param player table The player entity
--- @param asteroid table The asteroid entity
--- @param contactX number|nil Contact point X (optional)
--- @param contactY number|nil Contact point Y (optional)
local function handlePlayerVsAsteroid(player, asteroid, contactX, contactY)
    resolveShipVsAsteroid(player, asteroid, contactX, contactY)
end

local function handleEnemyVsAsteroid(enemy, asteroid, contactX, contactY)
    resolveShipVsAsteroid(enemy, asteroid, contactX, contactY)
end

--------------------------------------------------------------------------------
-- COLLISION DISPATCH TABLE
-- Maps type pairs to handler functions for O(1) lookup
-- Key format: "typeA:typeB" (alphabetically sorted for consistency)
--------------------------------------------------------------------------------
local COLLISION_HANDLERS = {}

--- Register a collision handler for a type pair
--- @param typeA string First entity type
--- @param typeB string Second entity type
--- @param handler function Handler function(entityA, entityB)
local function registerHandler(typeA, typeB, handler)
    -- Store both orderings for fast lookup
    COLLISION_HANDLERS[typeA .. ":" .. typeB] = { handler = handler, order = "ab" }
    COLLISION_HANDLERS[typeB .. ":" .. typeA] = { handler = handler, order = "ba" }
end

-- Register all collision handlers
registerHandler("playerprojectile", "enemy", handlePlayerProjectileVsEnemy)
registerHandler("enemyprojectile", "player", handleEnemyProjectileVsPlayer)
registerHandler("playerprojectile", "asteroid", handleProjectileVsAsteroid)
registerHandler("enemyprojectile", "asteroid", handleProjectileVsAsteroid)
registerHandler("player", "enemy", handlePlayerVsEnemy)
registerHandler("player", "asteroid", handlePlayerVsAsteroid)
registerHandler("enemy", "asteroid", handleEnemyVsAsteroid)

--------------------------------------------------------------------------------
-- BOX2D CALLBACK HANDLER
-- Called by physics.lua when two fixtures begin overlapping
--------------------------------------------------------------------------------

--- Queue a collision for processing after the physics step
--- @param dataA table UserData from fixture A: { type = "...", entity = ref }
--- @param dataB table UserData from fixture B: { type = "...", entity = ref }
--- @param contact userdata Box2D contact object
function collision.onBeginContact(dataA, dataB, contact)
    local contactX, contactY = nil, nil

    if contact then
        local x1, y1, x2, y2 = contact:getPositions()
        if x1 and y1 and x2 and y2 then
            contactX = (x1 + x2) * 0.5
            contactY = (y1 + y2) * 0.5
        elseif x1 and y1 then
            contactX, contactY = x1, y1
        elseif x2 and y2 then
            contactX, contactY = x2, y2
        end
    end

    -- Queue the collision for processing after physics step
    table.insert(pendingCollisions, {
        dataA = dataA,
        dataB = dataB,
        contactX = contactX,
        contactY = contactY
    })
end

--- Process a single collision between two entities
--- @param dataA table UserData from fixture A
--- @param dataB table UserData from fixture B
local function processCollision(dataA, dataB, contactX, contactY)
    local entityA = dataA.entity
    local entityB = dataB.entity
    if not entityA or not entityB or entityA._removed or entityB._removed then
        return
    end

    local typeA = dataA.type
    local typeB = dataB.type

    -- Look up the handler
    local key = typeA .. ":" .. typeB
    local entry = COLLISION_HANDLERS[key]

    if entry then
        -- Call handler with entities in correct order
        if entry.order == "ab" then
            entry.handler(entityA, entityB, contactX, contactY)
        else
            entry.handler(entityB, entityA, contactX, contactY)
        end
    end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Initialize the collision system
--- Must be called after physics.init()
function collision.init()
    physics.setCollisionHandler(collision)
end

--- Update the collision system
--- Processes any pending collisions from the physics step
--- @param player table The player entity
--- @param particlesModule table The particles module for visual effects
--- @param colors table Color palette for effects
--- @param damagePerHit number Base damage amount
--- @return boolean True if player died this frame
function collision.update(player, particlesModule, colors, damagePerHit)
    -- Store references for use in handlers
    currentParticles = particlesModule
    currentColors = colors
    currentDamagePerHit = damagePerHit or config.combat.damagePerHit
    playerDiedThisFrame = false

    -- Process all pending collisions
    for _, pending in ipairs(pendingCollisions) do
        processCollision(pending.dataA, pending.dataB, pending.contactX, pending.contactY)
    end

    ------------------------------------------------------------------------
    -- Fallback projectile collisions (distance-based)
    --
    -- In case Box2D contacts are missed (e.g., due to kinematic movement or
    -- very small/tunneling projectiles), we run a lightweight distance-based
    -- check to ensure that any projectile visually overlapping a target still
    -- generates impact FX and damage.
    ------------------------------------------------------------------------
    if false and bullets and #bullets > 0 then
        local bulletRadius = config.combat
        .bulletRadius                                   -- Matches projectile collision radius in physics.createCircleBody

        for bi = #bullets, 1, -1 do
            local b = bullets[bi]
            local hit = false

            if b then
                -- PLAYER projectiles vs ENEMIES
                if b.faction ~= "enemy" and enemies and #enemies > 0 then
                    for ei = #enemies, 1, -1 do
                        local e = enemies[ei]
                        if e then
                            local er = getBoundingRadius(e)
                            local dx = b.x - e.x
                            local dy = b.y - e.y
                            if dx * dx + dy * dy <= (er + bulletRadius) * (er + bulletRadius) then
                                local cx, cy = getContactPoint(b.x, b.y, e.x, e.y, er)
                                handlePlayerProjectileVsEnemy(b, e, cx, cy)
                                hit = true
                                break
                            end
                        end
                    end
                end

                -- Any projectile vs ASTEROIDS
                if not hit and asteroids and #asteroids > 0 then
                    for ai = #asteroids, 1, -1 do
                        local a = asteroids[ai]
                        if a then
                            local ar = getBoundingRadius(a)
                            local dx = b.x - a.x
                            local dy = b.y - a.y
                            if dx * dx + dy * dy <= (ar + bulletRadius) * (ar + bulletRadius) then
                                local cx, cy = getContactPoint(b.x, b.y, a.x, a.y, ar)
                                handleProjectileVsAsteroid(b, a, cx, cy)
                                hit = true
                                break
                            end
                        end
                    end
                end

                -- ENEMY projectiles vs PLAYER
                if not hit and b.faction == "enemy" and player then
                    local pr = player.size or getBoundingRadius(player)
                    local dx = b.x - player.x
                    local dy = b.y - player.y
                    if dx * dx + dy * dy <= (pr + bulletRadius) * (pr + bulletRadius) then
                        local cx, cy = getContactPoint(b.x, b.y, player.x, player.y, pr)
                        handleEnemyProjectileVsPlayer(b, player, cx, cy)
                        hit = true
                    end
                end
            end
        end
    end

    ------------------------------------------------------------------------
    -- Continuous ship vs asteroid resolution (player + enemies)
    --
    -- Box2D's beginContact callback only fires once when a contact starts.
    -- Since our movement is mostly kinematic (we manually set positions), we
    -- also run a simple distance-based check every frame to keep ships pushed
    -- out of asteroid overlap. This ensures a consistent "bump" behaviour
    -- even if the contact event is missed or only fires once.
    ------------------------------------------------------------------------
    if ENABLE_CONTINUOUS_SHIP_ASTEROID_RESOLVE and asteroids and #asteroids > 0 then
        -- Player vs asteroids
        if player then
            for i = 1, #asteroids do
                local a = asteroids[i]
                if a then
                    resolveShipVsAsteroid(player, a)
                end
            end
        end

        -- Enemies vs asteroids
        if enemies and #enemies > 0 then
            for ei = 1, #enemies do
                local e = enemies[ei]
                if e then
                    for ai = 1, #asteroids do
                        local a = asteroids[ai]
                        if a then
                            resolveShipVsAsteroid(e, a)
                        end
                    end
                end
            end
        end
    end

    -- Clear the queue
    pendingCollisions = {}

    return playerDiedThisFrame
end

--- Clear all pending collisions (call on game restart)
function collision.clear()
    pendingCollisions = {}
    playerDiedThisFrame = false
end

return collision
