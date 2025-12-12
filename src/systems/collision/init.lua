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
-- 3. Add handler function in handlers.lua
-- 4. Register handler in dispatch.lua
--------------------------------------------------------------------------------

local physics = require("src.core.physics")
local config = require("src.core.config")
local projectileModule = require("src.entities.projectile")
local asteroidModule = require("src.entities.asteroid")
local ecsWorld = require("src.ecs.world")

local utils = require("src.systems.collision.utils")
local handlers = require("src.systems.collision.handlers")
local dispatch = require("src.systems.collision.dispatch")

local collision = {}

--------------------------------------------------------------------------------
-- MODULE REFERENCES
-- Direct references to entity lists for fast access during collision handling
--------------------------------------------------------------------------------
local function getEnemyEntities()
    local ships = ecsWorld:query({ "ship", "faction", "position" }) or {}
    local enemies = {}
    for _, e in ipairs(ships) do
        if e.faction and e.faction.name == "enemy" and not e._removed and not e.removed then
            table.insert(enemies, e)
        end
    end
    return enemies
end

local ENABLE_CONTINUOUS_SHIP_ASTEROID_RESOLVE = false

--------------------------------------------------------------------------------
-- RUNTIME STATE
--------------------------------------------------------------------------------
local currentParticles = nil
local currentColors = nil
local currentDamagePerHit = config.combat.damagePerHit
local playerDiedThisFrame = false

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Initialize the collision system
--- Must be called after physics.init()
function collision.init()
    physics.setCollisionHandler(collision)
end

--- Box2D callback - queue collision for processing after physics step
--- @param dataA table UserData from fixture A
--- @param dataB table UserData from fixture B
--- @param contact userdata Box2D contact object
function collision.onBeginContact(dataA, dataB, contact)
    dispatch.onBeginContact(dataA, dataB, contact)
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

    local bullets = projectileModule.getList and projectileModule.getList() or projectileModule.list or {}
    local enemies = getEnemyEntities()
    local asteroids = asteroidModule.getList and asteroidModule.getList() or asteroidModule.list or {}

    -- Build the runtime context for handlers
    local context = {
        bullets = bullets,
        enemies = enemies,
        asteroids = asteroids,
        currentParticles = currentParticles,
        currentColors = currentColors,
        currentDamagePerHit = currentDamagePerHit,
        playerDiedThisFrame = false,
    }

    -- Process all pending collisions
    dispatch.processPending(context)

    -- Capture if player died during collision processing
    playerDiedThisFrame = context.playerDiedThisFrame

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
                    handlers.resolveShipVsAsteroid(player, a, nil, nil, context)
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
                            handlers.resolveShipVsAsteroid(e, a, nil, nil, context)
                        end
                    end
                end
            end
        end
    end

    -- Clear the queue
    dispatch.clearPending()

    return playerDiedThisFrame
end

--- Clear all pending collisions (call on game restart)
function collision.clear()
    dispatch.clearPending()
    playerDiedThisFrame = false
end

return collision
