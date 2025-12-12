--------------------------------------------------------------------------------
-- COLLISION DISPATCH
-- Handler registration and Box2D callback integration
--------------------------------------------------------------------------------

local handlers = require("src.systems.collision.handlers")
local utils = require("src.systems.collision.utils")

local dispatch = {}

--------------------------------------------------------------------------------
-- COLLISION DISPATCH TABLE
-- Maps type pairs to handler functions for O(1) lookup
-- Key format: "typeA:typeB" (alphabetically sorted for consistency)
--------------------------------------------------------------------------------
local COLLISION_HANDLERS = {}

--- Register a collision handler for a type pair
--- @param typeA string First entity type
--- @param typeB string Second entity type
--- @param handler function Handler function(entityA, entityB, contactX, contactY, context)
local function registerHandler(typeA, typeB, handler)
    -- Store both orderings for fast lookup
    COLLISION_HANDLERS[typeA .. ":" .. typeB] = { handler = handler, order = "ab" }
    COLLISION_HANDLERS[typeB .. ":" .. typeA] = { handler = handler, order = "ba" }
end

-- Register all collision handlers
registerHandler("playerprojectile", "enemy", handlers.handlePlayerProjectileVsEnemy)
registerHandler("enemyprojectile", "player", handlers.handleEnemyProjectileVsPlayer)
registerHandler("playerprojectile", "asteroid", handlers.handleProjectileVsAsteroid)
registerHandler("enemyprojectile", "asteroid", handlers.handleProjectileVsAsteroid)
registerHandler("player", "enemy", handlers.handlePlayerVsEnemy)
registerHandler("player", "asteroid", handlers.handlePlayerVsAsteroid)
registerHandler("enemy", "asteroid", handlers.handleEnemyVsAsteroid)

--------------------------------------------------------------------------------
-- PENDING COLLISION QUEUE
-- Box2D callbacks happen during world:update(), so we can't safely modify
-- physics objects (destroy bodies) during the callback. Instead, we queue
-- collisions and process them after the physics step.
--------------------------------------------------------------------------------
local pendingCollisions = {}

--------------------------------------------------------------------------------
-- BOX2D CALLBACK HANDLER
--------------------------------------------------------------------------------

--- Queue a collision for processing after the physics step
--- @param dataA table UserData from fixture A: { type = "...", entity = ref }
--- @param dataB table UserData from fixture B: { type = "...", entity = ref }
--- @param contact userdata Box2D contact object
function dispatch.onBeginContact(dataA, dataB, contact)
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
--- @param contactX number|nil Contact point X
--- @param contactY number|nil Contact point Y
--- @param context table Runtime context
local function processCollision(dataA, dataB, contactX, contactY, context)
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
            entry.handler(entityA, entityB, contactX, contactY, context)
        else
            entry.handler(entityB, entityA, contactX, contactY, context)
        end
    else
        if context and context.bullets then
            if typeA == "playerprojectile" or typeA == "enemyprojectile" then
                utils.removeEntity(context.bullets, entityA)
            elseif typeB == "playerprojectile" or typeB == "enemyprojectile" then
                utils.removeEntity(context.bullets, entityB)
            end
        end
    end
end

--- Process all pending collisions
--- @param context table Runtime context
function dispatch.processPending(context)
    for _, pending in ipairs(pendingCollisions) do
        processCollision(pending.dataA, pending.dataB, pending.contactX, pending.contactY, context)
    end
end

--- Clear the pending collision queue
function dispatch.clearPending()
    pendingCollisions = {}
end

--- Get the pending collisions count (for debugging)
--- @return number Count of pending collisions
function dispatch.getPendingCount()
    return #pendingCollisions
end

return dispatch
