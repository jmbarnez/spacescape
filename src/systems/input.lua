local playerModule = require("src.entities.player")
local combatSystem = require("src.systems.combat")
local config = require("src.core.config")

local input = {}

local SELECTION_RADIUS = config.input.selectionRadius

function input.update(dt, player, world, camera)
    if love.mouse.isDown(2) then
        local sx, sy = love.mouse.getPosition()
        local worldX, worldY = camera.screenToWorld(sx, sy)
        -- Clamp movement targets using the player's collision radius (derived
        -- from the owned ship layout) when available so clicks near the world
        -- edge behave consistently with the physical ship size.
        worldX, worldY = world.clampToWorld(worldX, worldY, player.collisionRadius or player.size)
        playerModule.setTarget(worldX, worldY)
    end
end

function input.mousepressed(x, y, button, player, world, camera)
    local worldX, worldY = camera.screenToWorld(x, y)
    -- Same clamp logic as in update(): prefer the collision radius so the
    -- click target never places the ship partially outside the world.
    worldX, worldY = world.clampToWorld(worldX, worldY, player.collisionRadius or player.size)

    if button == 2 then
        playerModule.setTarget(worldX, worldY)
    elseif button == 1 then
        combatSystem.handleLeftClick(worldX, worldY, config.input.selectionRadius)
    end
end

function input.wheelmoved(x, y, camera)
    if y ~= 0 then
        -- Positive y = wheel up = zoom in; negative y = zoom out
        camera.zoom(y * config.camera.zoomWheelScale)
    end
end

return input
