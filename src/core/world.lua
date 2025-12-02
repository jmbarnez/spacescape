local world = {
    width = 3000,
    height = 3000,
    centerX = 0,
    centerY = 0,
    minX = 0,
    maxX = 0,
    minY = 0,
    maxY = 0
}

function world.initFromPlayer(player)
    world.centerX = player.x
    world.centerY = player.y
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
