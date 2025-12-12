--------------------------------------------------------------------------------
-- BOX2D COLLISION PROCESSOR SYSTEM (ECS)
--
-- Purpose:
--   Drains Box2D beginContact events that were queued during physics.world:update
--   and forwards them into the ECS CollisionSystem.
--
-- Safety / migration notes:
--   - We only process contacts where BOTH entities are Concord ECS entities.
--     This lets us run ECS collisions in parallel with the legacy collision
--     pipeline while the player is still legacy.
--   - Legacy collision code continues to own legacy-vs-legacy and legacy-vs-ECS
--     pairs until we migrate the remaining actors.
--------------------------------------------------------------------------------

local Concord = require("lib.concord")

local collisionQueue = require("src.ecs.box2d_collision_queue")
local collisionSystems = require("src.ecs.systems.collision")

local Box2DCollisionProcessorSystem = Concord.system({})

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function isEcsEntity(e)
    return type(e) == "table" and e.__isEntity == true
end

--------------------------------------------------------------------------------
-- SYSTEM UPDATE
--------------------------------------------------------------------------------

function Box2DCollisionProcessorSystem:update(dt)
    local pending = collisionQueue.drain()
    if not pending or #pending == 0 then
        return
    end

    local world = self:getWorld()
    if not world then
        return
    end

    local collisionSystem = world:getSystem(collisionSystems.CollisionSystem)
    if not collisionSystem then
        return
    end

    for i = 1, #pending do
        local entry = pending[i]
        local dataA = entry.dataA
        local dataB = entry.dataB

        local entityA = dataA and dataA.entity or nil
        local entityB = dataB and dataB.entity or nil

        -- Only process ECS-vs-ECS contacts here.
        if isEcsEntity(entityA) and isEcsEntity(entityB) then
            collisionSystem:processCollision(entityA, entityB, entry.contactX, entry.contactY)
        end
    end
end

return Box2DCollisionProcessorSystem
