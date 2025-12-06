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
local floatingText = require("src.entities.floating_text")

local collision = {}

--------------------------------------------------------------------------------
-- MODULE REFERENCES
-- Direct references to entity lists for fast access during collision handling
--------------------------------------------------------------------------------
local enemies = enemyModule.list
local bullets = projectileModule.list
local asteroids = asteroidModule.list

--------------------------------------------------------------------------------
-- CONFIGURATION
-- Colors and settings for visual feedback
--------------------------------------------------------------------------------
local DAMAGE_COLOR_ENEMY = {1.0, 0.9, 0.4}   -- Yellow-ish for damage to enemies
local DAMAGE_COLOR_PLAYER = {1.0, 0.4, 0.4}  -- Red-ish for damage to player
local MISS_BG_COLOR = {0.3, 0.6, 1.0}        -- Blue background for miss text

--------------------------------------------------------------------------------
-- RUNTIME STATE
-- These are set during init() and used by collision handlers
--------------------------------------------------------------------------------
local currentPlayer = nil
local currentParticles = nil
local currentColors = nil
local currentDamagePerHit = 20
local playerDiedThisFrame = false

--------------------------------------------------------------------------------
-- PENDING COLLISION QUEUE
-- Box2D callbacks happen during world:update(), so we can't safely modify
-- physics objects (destroy bodies) during the callback. Instead, we queue
-- collisions and process them after the physics step.
--------------------------------------------------------------------------------
local pendingCollisions = {}

-- Debug impact points (for visualizing projectile contact locations)
local debugImpacts = {}

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
--- @param color table RGB color for the text background
--- @param options table Optional settings (bgColor, etc.)
local function spawnDamageText(amount, x, y, radius, color, options)
    local textY = y - radius - 10
    floatingText.spawn(tostring(math.floor(amount + 0.5)), x, textY, color, options)
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
            table.remove(bullets, i)
        end
    end
end

--- Apply damage to an entity and check for death
--- @param entity table The entity to damage
--- @param damage number Amount of damage
--- @return boolean True if entity died
local function applyDamage(entity, damage)
    entity.health = (entity.health or 0) - damage
    return entity.health <= 0
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
        local missOpts = config.missOptions or { bgColor = MISS_BG_COLOR }

        -- Even on a miss, show a small impact so the collision feels real
        if currentParticles then
            local impactColor = config.impactColor or (currentColors and currentColors.projectile) or {1, 1, 1}
            local count = math.max(2, math.floor((config.impactCount or 6) * 0.5))

            local ix = contactX or target.x
            local iy = contactY or target.y
            if ix and iy then
                -- Debug: record impact point for overlay drawing
                debugImpacts[#debugImpacts + 1] = { x = ix, y = iy }
                currentParticles.impact(ix, iy, impactColor, count)
            end
        end

        spawnDamageText(0, target.x, target.y, radius, nil, missOpts)
        removeEntity(bullets, projectile)
        return
    end

    -- Impact particles (fall back to target center if no explicit contact point)
    if currentParticles then
        local impactColor = config.impactColor or (currentColors and currentColors.projectile) or {1, 1, 1}
        local count = config.impactCount or 6

        local ix = contactX or target.x
        local iy = contactY or target.y
        if ix and iy then
            -- Debug: record impact point for overlay drawing
            debugImpacts[#debugImpacts + 1] = { x = ix, y = iy }
            currentParticles.impact(ix, iy, impactColor, count)
            if config.explosionOnHit then
                -- Small extra burst to make projectile impacts very obvious
                local explCount = math.max(4, math.floor(count * 0.4))
                currentParticles.explosion(ix, iy, impactColor, explCount, 0.5)
            end
        end
    end

    -- Apply damage and floating text
    local damage = projectile.damage or currentDamagePerHit
    spawnDamageText(damage, target.x, target.y, radius, config.damageTextColor)

    -- Remove the projectile on any resolved hit
    removeEntity(bullets, projectile)

    -- Death handling
    if applyDamage(target, damage) and config.onKill then
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
        damageTextColor = DAMAGE_COLOR_ENEMY,
        impactColor = currentColors and currentColors.projectile or nil,
        impactCount = 20,
        onKill = function(target, radius)
            explosionFx.spawn(target.x, target.y, currentColors.enemy, radius * 1.4)
            cleanupProjectilesForTarget(target)
            removeEntity(enemies, target)
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
        impactCount = 20,
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
    local asteroidColor = (asteroid.data and asteroid.data.color) or (currentColors and currentColors.projectile) or {1, 1, 1}

    -- Asteroids always get hit (no miss chance)
    resolveProjectileHit(projectile, asteroid, contactX, contactY, asteroidRadius, {
        canMiss = false,
        damageTextColor = DAMAGE_COLOR_ENEMY,
        impactColor = asteroidColor,
        impactCount = 24,
        onKill = function(target, radius)
            if currentParticles then
                currentParticles.explosion(target.x, target.y, asteroidColor)
            end
            cleanupProjectilesForTarget(target)
            removeEntity(asteroids, target)
        end,
    })
end

--- Handle player colliding with an enemy (ram damage)
--- @param player table The player entity
--- @param enemy table The enemy entity
local function handlePlayerVsEnemy(player, enemy)
    local enemyRadius = getBoundingRadius(enemy)
    
    -- Destroy the enemy on contact
    explosionFx.spawn(enemy.x, enemy.y, currentColors.enemy, enemyRadius * 1.4)
    cleanupProjectilesForTarget(enemy)
    removeEntity(enemies, enemy)
    
    -- Damage the player
    local damage = currentDamagePerHit
    spawnDamageText(damage, player.x, player.y, player.size, DAMAGE_COLOR_PLAYER)
    
    if applyDamage(player, damage) then
        explosionFx.spawn(player.x, player.y, currentColors.ship, player.size * 2.2)
        playerDiedThisFrame = true
    end
end

--- Resolve a generic ship colliding with an asteroid (push ship away, no damage)
--- @param ship table The ship entity (player or enemy)
--- @param asteroid table The asteroid entity
local function resolveShipVsAsteroid(ship, asteroid)
    if not ship or not asteroid then
        return
    end

    local shipRadius = getBoundingRadius(ship)
    local asteroidRadius = getBoundingRadius(asteroid)
    local dx = ship.x - asteroid.x
    local dy = ship.y - asteroid.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local minDistance = shipRadius + asteroidRadius
    
    -- Push ship away from asteroid
    if distance > 0 and distance < minDistance then
        local overlap = minDistance - distance
        local invDist = 1.0 / distance
        ship.x = ship.x + dx * invDist * overlap
        ship.y = ship.y + dy * invDist * overlap
        
        -- Sync physics body position
        if ship.body then
            ship.body:setPosition(ship.x, ship.y)
        end
        
        -- Subtle spark effect
        local contactX = asteroid.x + dx * invDist * asteroidRadius
        local contactY = asteroid.y + dy * invDist * asteroidRadius
        if currentParticles then
            currentParticles.spark(contactX, contactY, {0.9, 0.85, 0.7}, 4)
        end
    end
end

--- Handle player colliding with an asteroid (Box2D event wrapper)
--- @param player table The player entity
--- @param asteroid table The asteroid entity
local function handlePlayerVsAsteroid(player, asteroid)
    resolveShipVsAsteroid(player, asteroid)
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
    local typeA = dataA.type
    local typeB = dataB.type
    local entityA = dataA.entity
    local entityB = dataB.entity
    
    -- Skip if either entity is already dead/removed
    if not entityA or not entityB then
        return
    end
    
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
    currentPlayer = player
    currentParticles = particlesModule
    currentColors = colors
    currentDamagePerHit = damagePerHit or 20
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
    if bullets and #bullets > 0 then
        local bulletRadius = 4  -- Matches projectile collision radius in physics.createCircleBody

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
    if asteroids and #asteroids > 0 then
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

--- Debug draw helper to visualize projectile impact points.
--- Call from the world render pass (after camera transform).
function collision.debugDraw()
    if #debugImpacts == 0 then
        return
    end

    -- Bright magenta circles so they are impossible to miss
    love.graphics.setColor(1.0, 0.1, 1.0, 0.9)
    love.graphics.setLineWidth(3)

    for _, p in ipairs(debugImpacts) do
        love.graphics.circle("line", p.x, p.y, 28)
        love.graphics.circle("fill", p.x, p.y, 6)
    end

    -- Clear after drawing so each impact shows once
    debugImpacts = {}
end

return collision
