local world = require("src.core.world")

local camera = {
    x = 0,
    y = 0,
    scale = 1
}

function camera.centerOnPlayer(player)
    camera.x = player.x
    camera.y = player.y
end

function camera.update(dt, player)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local scale = camera.scale or 1
    local halfW = (width / 2) / scale
    local halfH = (height / 2) / scale

    local minCamX = world.minX + halfW
    local maxCamX = world.maxX - halfW
    local minCamY = world.minY + halfH
    local maxCamY = world.maxY - halfH

    if world.width <= width / scale then
        camera.x = world.centerX
    else
        camera.x = math.max(minCamX, math.min(maxCamX, player.x))
    end

    if world.height <= height / scale then
        camera.y = world.centerY
    else
        camera.y = math.max(minCamY, math.min(maxCamY, player.y))
    end
end

function camera.screenToWorld(sx, sy)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local scale = camera.scale or 1
    local worldX = (sx - width / 2) / scale + camera.x
    local worldY = (sy - height / 2) / scale + camera.y
    return worldX, worldY
end

return camera
