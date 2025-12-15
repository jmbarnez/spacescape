--------------------------------------------------------------------------------
-- BOX2D COLLISION PROCESSOR SYSTEM (ECS)
--
-- Purpose:
--   Drains Box2D beginContact events that were queued during physics.world:update
--   and forwards them into the ECS CollisionSystem.
--
-- Notes:
--   - Contacts are always forwarded to the ECS CollisionSystem.
--   - The CollisionSystem is responsible for ignoring irrelevant pairs.
--------------------------------------------------------------------------------

local Concord = require("lib.concord")

local collisionQueue = require("src.ecs.box2d_collision_queue")
local collisionSystems = require("src.ecs.systems.collision")

local Box2DCollisionProcessorSystem = Concord.system({})

--------------------------------------------------------------------------------
-- SYSTEM UPDATE
--------------------------------------------------------------------------------

function Box2DCollisionProcessorSystem:postPhysics(dt)
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

        if entityA and entityB then
            collisionSystem:processCollision(entityA, entityB, entry.contactX, entry.contactY)
        end
    end
end

function Box2DCollisionProcessorSystem:update(dt)
    self:postPhysics(dt)
end

return Box2DCollisionProcessorSystem
