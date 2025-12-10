local config = require("src.core.config")

local world = {
    width = config.world.width,
    height = config.world.height,
    centerX = 0,
    centerY = 0,
    minX = 0,
    maxX = 0,
    minY = 0,
    maxY = 0
}

function world.initFromPlayer(player)
    local px, py
    if player then
        px = player.x or 0
        py = player.y or 0
    end

    if not px or not py then
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        px = w / 2
        py = h / 2
    end

    world.centerX = px
    world.centerY = py
    world.minX = world.centerX - world.width / 2
    world.maxX = world.centerX + world.width / 2
    world.minY = world.centerY - world.height / 2
    world.maxY = world.centerY + world.height / 2
end

function world.clampToWorld(x, y, margin)
    margin = margin or 0
    x = math.max(world.minX + margin, math.min(world.maxX - margin, x))
    y = math.max(world.minY + margin, math.min(world.maxY - margin, y))
    return x, y
end

return world
