--------------------------------------------------------------------------------
-- BOX2D COLLISION QUEUE (ECS)
--
-- Purpose:
--   Box2D beginContact callbacks occur inside physics.world:update(dt), where we
--   should avoid mutating gameplay state (destroying bodies, removing entities)
--   directly.
--
--   This module stores a small queue of contacts that can be processed later
--   during the ECS update phase.
--
-- Notes:
--   - This queue is intentionally data-only and does NOT depend on ecsWorld.
--   - The processor system decides which contacts to handle (ECS/ECS only).
--------------------------------------------------------------------------------

local queue = {}

--------------------------------------------------------------------------------
-- INTERNAL STATE
--------------------------------------------------------------------------------

-- Pending collisions in the current frame.
-- Each entry:
--   {
--     dataA = fixtureA.userData,
--     dataB = fixtureB.userData,
--     contactX = number|nil,
--     contactY = number|nil,
--   }
local pending = {}

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Box2D callback hook: record a beginContact event.
--- @param dataA table UserData from fixture A: { type = string, entity = any }
--- @param dataB table UserData from fixture B: { type = string, entity = any }
--- @param contact userdata Box2D contact object
function queue.onBeginContact(dataA, dataB, contact)
    if not dataA or not dataB then
        return
    end

    local contactX, contactY = nil, nil

    -- Extract a contact point if Box2D provides it. This matches the legacy
    -- collision dispatcher logic so handlers can use consistent impact points.
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

    pending[#pending + 1] = {
        dataA = dataA,
        dataB = dataB,
        contactX = contactX,
        contactY = contactY,
    }
end

--- Drain the queue (returns the current pending array and clears it).
--- @return table pendingCollisions
function queue.drain()
    local drained = pending
    pending = {}
    return drained
end

--- Clear the queue without returning it.
function queue.clear()
    pending = {}
end

return queue
