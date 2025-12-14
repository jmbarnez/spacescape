local playerModule = require("src.entities.player")
local combatSystem = require("src.systems.combat")
local config = require("src.core.config")
local coreInput = require("src.core.input")

local input = {}

local SELECTION_RADIUS = config.input.selectionRadius

local function getClampMargin(player)
    if not player then
        return 0
    end

    if player.collisionRadius then
        return type(player.collisionRadius) == "table" and (player.collisionRadius.value or player.collisionRadius.radius or 0)
            or player.collisionRadius
    end
    if player.size then
        return type(player.size) == "table" and (player.size.value or player.size.radius or 0)
            or player.size
    end

    return 0
end

function input.update(dt, player, world, camera)
    if coreInput.pressed("mouse_secondary") then
        local worldX, worldY = coreInput.getMouseWorld(camera)
        -- Clamp movement targets using the player's collision radius (derived
        -- from the owned ship layout) when available so clicks near the world
        -- edge behave consistently with the physical ship size.
        worldX, worldY = world.clampToWorld(worldX, worldY, getClampMargin(player))
        playerModule.setTarget(worldX, worldY)
    end
end

function input.mousepressed(x, y, button, player, world, camera)
    local worldX, worldY = camera.screenToWorld(x, y)
    -- Same clamp logic as in update(): prefer the collision radius so the
    -- click target never places the ship partially outside the world.
    worldX, worldY = world.clampToWorld(worldX, worldY, getClampMargin(player))

    -- Handle movement: RIGHT CLICK
    if button == 2 then
        if player and player.destination then
            player.destination.x = worldX
            player.destination.y = worldY
            player.destination.active = true

            -- Clear interaction state if present
            if player.lootTarget then player.lootTarget = nil end
            if player.isLooting then player.isLooting = false end

            -- Legacy: clear legacy state if it exists (for safety)
            if player.targetX then player.targetX = worldX end
            if player.targetY then player.targetY = worldY end
        elseif player and player.setTarget then
            -- Fallback to module method if passed module instead of entity
            player.setTarget(worldX, worldY)
        end
    elseif button == 1 then
        -- Check for wreck first (loot interaction takes priority)
        local wreck = combatSystem.findWreckAtPosition(worldX, worldY, config.input.selectionRadius)
        if wreck then
            playerModule.setLootTarget(wreck)
            if combatSystem.lockEntity then
                combatSystem.lockEntity(wreck)
            end
        else
            combatSystem.handleLeftClick(worldX, worldY, config.input.selectionRadius)
        end
    end
end

function input.wheelmoved(x, y, camera)
    if y ~= 0 then
        -- Positive y = wheel up = zoom in; negative y = zoom out
        camera.zoom(y * config.camera.zoomWheelScale)
    end
end

return input
