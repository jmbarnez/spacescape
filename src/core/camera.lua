local world = require("src.core.world")
local config = require("src.core.config")

local camera = {
    x = 0,
    y = 0,
    scale = 1,
    minScale = config.camera.minScale,
    maxScale = config.camera.maxScale
}

function camera.centerOnEntity(entity)
    camera.target = entity
    -- Teleport immediately
    if entity then
        local ex = entity.position and entity.position.x or entity.x or 0
        local ey = entity.position and entity.position.y or entity.y or 0
        camera.x = ex
        camera.y = ey
    end
end

function camera.update(dt)
    -- Follow target if we have one
    if camera.target then
        local t = camera.target
        local tx = t.position and t.position.x or t.x or 0
        local ty = t.position and t.position.y or t.y or 0

        -- Lerp towards target
        local lerp = config.camera.lerpSpeed or 5
        local speed = lerp * dt
        camera.x = camera.x + (tx - camera.x) * speed
        camera.y = camera.y + (ty - camera.y) * speed
    end

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local scale = camera.scale or 1
    local halfW = (width / 2) / scale
    local halfH = (height / 2) / scale

    local minCamX = world.minX + halfW
    local maxCamX = world.maxX - halfW
    local minCamY = world.minY + halfH
    local maxCamY = world.maxY - halfH

    -- Clamp camera to world bounds
    if world.width <= width / scale then
        camera.x = world.centerX
    else
        camera.x = math.max(minCamX, math.min(maxCamX, camera.x))
    end

    if world.height <= height / scale then
        camera.y = world.centerY
    else
        camera.y = math.max(minCamY, math.min(maxCamY, camera.y))
    end
end

function camera.setScale(scale)
    local minScale = camera.minScale or config.camera.minScale
    local maxScale = camera.maxScale or config.camera.maxScale
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
