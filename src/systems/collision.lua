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
-- 2. Create entity with physics.createCircleBody()
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

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
-- Shared helpers used by multiple collision handlers
--------------------------------------------------------------------------------

--- Calculate the contact point between two circular entities
--- @param x1 number Center X of first entity
--- @param y1 number Center Y of first entity
--- @param x2 number Center X of second entity
--- @param y2 number Center Y of second entity
--- @param radius2 number Radius of second entity (contact point is on its surface)
--- @return number, number Contact point X and Y
local function getContactPoint(x1, y1, x2, y2, radius2)
    local dx = x1 - x2
    local dy = y1 - y2
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0 then
        local invDist = 1.0 / distance
        return x2 + dx * invDist * radius2, y2 + dy * invDist * radius2
    end
    
    return x1, y1
end

--- Get the collision radius of an entity
--- @param entity table The entity to get radius for
--- @return number The collision radius
local function getRadius(entity)
    return entity.collisionRadius or entity.size or 10
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

--------------------------------------------------------------------------------
-- COLLISION HANDLERS
-- Each handler processes a specific pair of entity types
-- Handlers receive (entityA, entityB) where types are guaranteed by dispatch
--------------------------------------------------------------------------------

--- Handle player projectile hitting an enemy
--- @param projectile table The projectile entity
--- @param enemy table The enemy entity
local function handlePlayerProjectileVsEnemy(projectile, enemy)
    -- Skip if projectile is targeting a different enemy
    if projectile.target and projectile.target ~= enemy then
        return
    end
    
    local enemyRadius = getRadius(enemy)
    local contactX, contactY = getContactPoint(projectile.x, projectile.y, enemy.x, enemy.y, enemyRadius)
    
    -- Roll for hit/miss based on weapon accuracy
    if not rollHitChance(projectile) then
        spawnDamageText(0, enemy.x, enemy.y, enemyRadius, nil, { bgColor = MISS_BG_COLOR })
        removeEntity(bullets, projectile)
        return
    end
    
    -- Hit! Spawn impact particles
    if currentParticles then
        currentParticles.impact(contactX, contactY, currentColors.projectile, 6)
    end
    
    -- Apply damage and show floating text
    local damage = projectile.damage or currentDamagePerHit
    spawnDamageText(damage, enemy.x, enemy.y, enemyRadius, DAMAGE_COLOR_ENEMY)
    
    -- Remove the projectile
    removeEntity(bullets, projectile)
    
    -- Check if enemy died
    if applyDamage(enemy, damage) then
        explosionFx.spawn(enemy.x, enemy.y, currentColors.enemy, enemyRadius * 1.4)
        cleanupProjectilesForTarget(enemy)
        removeEntity(enemies, enemy)
    end
end

--- Handle enemy projectile hitting the player
--- @param projectile table The projectile entity
--- @param player table The player entity
local function handleEnemyProjectileVsPlayer(projectile, player)
    local playerRadius = player.size or 10
    local contactX, contactY = getContactPoint(projectile.x, projectile.y, player.x, player.y, playerRadius)
    
    -- Roll for hit/miss
    if not rollHitChance(projectile) then
        spawnDamageText(0, player.x, player.y, playerRadius, nil, { bgColor = MISS_BG_COLOR })
        removeEntity(bullets, projectile)
        return
    end
    
    -- Hit! Spawn impact particles
    if currentParticles then
        currentParticles.impact(contactX, contactY, currentColors.projectile, 6)
    end
    
    -- Apply damage
    local damage = projectile.damage or currentDamagePerHit
    spawnDamageText(damage, player.x, player.y, playerRadius, DAMAGE_COLOR_PLAYER)
    removeEntity(bullets, projectile)
    
    if applyDamage(player, damage) then
        explosionFx.spawn(player.x, player.y, currentColors.ship, playerRadius * 2.2)
        playerDiedThisFrame = true
    end
end

--- Handle any projectile hitting an asteroid
--- @param projectile table The projectile entity
--- @param asteroid table The asteroid entity
local function handleProjectileVsAsteroid(projectile, asteroid)
    local asteroidRadius = getRadius(asteroid)
    local contactX, contactY = getContactPoint(projectile.x, projectile.y, asteroid.x, asteroid.y, asteroidRadius)
    
    -- Asteroids always get hit (no miss chance)
    local asteroidColor = (asteroid.data and asteroid.data.color) or currentColors.projectile
    if currentParticles then
        currentParticles.impact(contactX, contactY, asteroidColor, 6)
    end
    
    -- Apply damage
    local damage = projectile.damage or currentDamagePerHit
    spawnDamageText(damage, asteroid.x, asteroid.y, asteroidRadius, DAMAGE_COLOR_ENEMY)
    removeEntity(bullets, projectile)
    
    -- Check if asteroid was destroyed
    if applyDamage(asteroid, damage) then
        if currentParticles then
            currentParticles.explosion(asteroid.x, asteroid.y, asteroidColor)
        end
        cleanupProjectilesForTarget(asteroid)
        removeEntity(asteroids, asteroid)
    end
end

--- Handle player colliding with an enemy (ram damage)
--- @param player table The player entity
--- @param enemy table The enemy entity
local function handlePlayerVsEnemy(player, enemy)
    local enemyRadius = getRadius(enemy)
    
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

--- Handle player colliding with an asteroid (push away, no damage)
--- @param player table The player entity
--- @param asteroid table The asteroid entity
local function handlePlayerVsAsteroid(player, asteroid)
    local asteroidRadius = getRadius(asteroid)
    local dx = player.x - asteroid.x
    local dy = player.y - asteroid.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local minDistance = player.size + asteroidRadius
    
    -- Push player away from asteroid
    if distance > 0 and distance < minDistance then
        local overlap = minDistance - distance
        local invDist = 1.0 / distance
        player.x = player.x + dx * invDist * overlap
        player.y = player.y + dy * invDist * overlap
        
        -- Sync physics body position
        if player.body then
            player.body:setPosition(player.x, player.y)
        end
        
        -- Subtle spark effect
        local contactX = asteroid.x + dx * invDist * asteroidRadius
        local contactY = asteroid.y + dy * invDist * asteroidRadius
        if currentParticles then
            currentParticles.spark(contactX, contactY, {0.9, 0.85, 0.7}, 4)
        end
    end
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
    -- Queue the collision for processing after physics step
    table.insert(pendingCollisions, { dataA = dataA, dataB = dataB })
end

--- Process a single collision between two entities
--- @param dataA table UserData from fixture A
--- @param dataB table UserData from fixture B
local function processCollision(dataA, dataB)
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
            entry.handler(entityA, entityB)
        else
            entry.handler(entityB, entityA)
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
        processCollision(pending.dataA, pending.dataB)
    end

    ------------------------------------------------------------------------
    -- Continuous player vs asteroid resolution
    --
    -- Box2D's beginContact callback only fires once when a contact starts.
    -- Since our movement is mostly kinematic (we manually set positions), we
    -- also run a simple distance-based check every frame to keep the player
    -- pushed out of asteroid overlap. This ensures a consistent "bump"
    -- behaviour even if the contact event is missed or only fires once.
    ------------------------------------------------------------------------
    if player and asteroids and #asteroids > 0 then
        for i = 1, #asteroids do
            local a = asteroids[i]
            if a then
                handlePlayerVsAsteroid(player, a)
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
