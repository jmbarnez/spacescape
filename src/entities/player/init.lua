-- Player module
-- Now refactored to be a thin wrapper around the ECS Player Entity.
-- Instead of maintaining its own state table, it exposes the current
-- player entity and provides helpers to interact with it.

local player = {}
 
local ecsWorld = require("src.ecs.world")
 
 
-- The current active player entity.
-- Access this for reading position/components.
player.entity = nil

-- Legacy state table is removed.
-- Any code accessing player.state.x must now access player.entity.position.x

--------------------------------------------------------------------------------
-- LIFECYCLE
--------------------------------------------------------------------------------

--- Reset the player (respawn).
-- This destroys any old player entity and asks the world to spawn a new one.
function player.reset(spawnX, spawnY)
    if not ecsWorld then return end

    -- Clear old entity if it exists (though world:clear() usually handles this)
    if player.entity and player.entity.destroy then
        if player.entity.physics and player.entity.physics.body then
            pcall(function()
                local body = player.entity.physics.body
                if (not body.isDestroyed) or (not body:isDestroyed()) then
                    body:destroy()
                end
            end)
        end
        player.entity:destroy()
    end

    -- Spawn new player entity via the World helper
    -- Note: world.lua's spawnPlayer uses the "player" assemblage we just updated.
    player.entity = ecsWorld:spawnPlayer(spawnX or 0, spawnY or 0, nil)


    -- Ensure the camera knows about the new entity
    local camera = require("src.core.camera")
    if camera and player.entity and player.entity.position then
        camera.centerOnEntity(player.entity)
    end
end

-- Helper to ensure we have a valid entity reference
-- (e.g., if the world was reloaded from outside this module)
function player.getEntity()
    if player.entity and not player.entity._removed and not player.entity.removed then
        return player.entity
    end

    -- Try to find it in the world
    if ecsWorld then
        player.entity = ecsWorld:getPlayer()
    end

    if not player.entity then
        player.reset()
    end

    return player.entity
end

--------------------------------------------------------------------------------
-- GAMEPLAY API (Wrappers for Components)
--------------------------------------------------------------------------------

--- Add a quantity of a specific resource type to the player's cargo.
function player.addCargoResource(resourceType, amount)
    local e = player.getEntity()
    if not (e and e.cargo) then return 0 end

    local cargoComp = e.cargo
    local slots = cargoComp.slots
    local maxSlots = cargoComp.maxSlots
    local key = tostring(resourceType)

    -- Similar logic to old cargo.lua, but operating on component data
    -- 1. Find existing stack
    for _, slot in ipairs(slots) do
        if slot.id == key then
            slot.quantity = (slot.quantity or 0) + amount
            return amount
        end
    end

    -- 2. Find empty slot
    if #slots < maxSlots then
        table.insert(slots, { id = key, quantity = amount })
        return amount
    end

    return 0 -- Full
end

function player.addExperience(amount)
    if ecsWorld and ecsWorld.emit then
        ecsWorld:emit("awardXp", amount)
    end
end

function player.addCurrency(amount)
    if ecsWorld and ecsWorld.emit then
        ecsWorld:emit("awardTokens", amount)
    end
end

function player.resetExperience()
    if ecsWorld and ecsWorld.emit then
        ecsWorld:emit("resetPlayerProgress")
    end
end

function player.centerInWindow()
    -- Meaningless for ECS, usually handled by Camera centering on Entity.
end

function player.setShipBlueprint(blueprint)
    -- This would require swapping the 'shipVisual' and rebuilding physics.
    -- TODO: Implement if needed.
end

-- Update is handled by ECS Systems now.
function player.update(dt, world)
    -- Deprecated
end

function player.setTarget(x, y)
    local e = player.getEntity()
    if e and e.destination then
        e.destination.x = x
        e.destination.y = y
        e.destination.active = true

        -- Clear interaction targets
        if e.lootTarget then e.lootTarget = nil end
        if e.isLooting then e.isLooting = false end
    end
end

function player.setLootTarget(wreck)
    local e = player.getEntity()
    if e then
        -- We can store this on the entity for the InteractionSystem
        e.lootTarget = wreck
        e.isLooting = false

        -- Set movement destination
        if wreck and (wreck.position or wreck.x) then
            local wx = wreck.position and wreck.position.x or wreck.x
            local wy = wreck.position and wreck.position.y or wreck.y
            player.setTarget(wx, wy)
        end
    end
end

function player.clearLootTarget()
    local e = player.getEntity()
    if e then
        e.lootTarget = nil
        e.isLooting = false
    end
end

function player.getLootTarget()
    local e = player.getEntity()
    return e and e.lootTarget
end

function player.isPlayerLooting()
    local e = player.getEntity()
    return e and e.isLooting
end

function player.setLooting(isLooting)
    local e = player.getEntity()
    if e then
        e.isLooting = isLooting
    end
end

function player.draw(colors)
    -- Deprecated: Systems handle drawing.
    -- But for now, game_render might still call this if we missed an update.
end

return player
