local playerModule = require("src.entities.player")
local world = require("src.core.world")
local camera = require("src.core.camera")
local combatSystem = require("src.systems.combat")

local input = {}

local player = playerModule.state
local SELECTION_RADIUS = 40

function input.update(dt)
    if love.mouse.isDown(2) then
        local sx, sy = love.mouse.getPosition()
        local worldX, worldY = camera.screenToWorld(sx, sy)
        worldX, worldY = world.clampToWorld(worldX, worldY, player.size)
        playerModule.setTarget(worldX, worldY)
    end
end

function input.mousepressed(x, y, button)
    local worldX, worldY = camera.screenToWorld(x, y)
    worldX, worldY = world.clampToWorld(worldX, worldY, player.size)

    if button == 2 then
        playerModule.setTarget(worldX, worldY)
    elseif button == 1 then
        combatSystem.handleLeftClick(worldX, worldY, SELECTION_RADIUS)
    end
end

function input.wheelmoved(x, y)
    if y ~= 0 then
        -- Positive y = wheel up = zoom in; negative y = zoom out
        camera.zoom(y * 0.1)
    end
end

return input
