local world = require("src.core.world")

local camera = {
    x = 0,
    y = 0,
    scale = 1,
    minScale = 0.5,
    maxScale = 2.0
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

function camera.setScale(scale)
    local minScale = camera.minScale or 0.5
    local maxScale = camera.maxScale or 2.0
    local current = camera.scale or 1
    scale = scale or current
    if scale < minScale then
        scale = minScale
    elseif scale > maxScale then
        scale = maxScale
    end
    camera.scale = scale
end

function camera.zoom(delta)
    local current = camera.scale or 1
    camera.setScale(current + (delta or 0))
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
