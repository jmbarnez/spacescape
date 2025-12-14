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
local ecsCollisionQueue = require("src.ecs.box2d_collision_queue")

local collision = {}

--------------------------------------------------------------------------------
-- MODULE REFERENCES
-- Direct references to entity lists for fast access during collision handling
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- RUNTIME STATE
--------------------------------------------------------------------------------
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
    ecsCollisionQueue.onBeginContact(dataA, dataB, contact)
end

--- Update the collision system
--- Processes any pending collisions from the physics step
--- @param player table The player entity
--- @param particlesModule table The particles module for visual effects
--- @param colors table Color palette for effects
--- @param damagePerHit number Base damage amount
--- @return boolean True if player died this frame
function collision.update(player, particlesModule, colors, damagePerHit)
    playerDiedThisFrame = false
    return playerDiedThisFrame
end

--- Clear all pending collisions (call on game restart)
function collision.clear()
    ecsCollisionQueue.clear()
    playerDiedThisFrame = false
end

return collision
