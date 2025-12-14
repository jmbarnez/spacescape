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

 local function resolveMargin(margin)
     if margin == nil then
         return 0, 0
     end

     if type(margin) == "number" then
         return margin, margin
     end

     if type(margin) == "table" then
         local mx = margin.x or margin[1] or margin.value or margin.radius or 0
         local my = margin.y or margin[2] or mx
         return tonumber(mx) or 0, tonumber(my) or 0
     end

     local n = tonumber(margin) or 0
     return n, n
 end

function world.initFromPlayer(player)
    local px, py
    if player then
        px = (player.position and player.position.x) or player.x or 0
        py = (player.position and player.position.y) or player.y or 0
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
    local mx, my = resolveMargin(margin)
    x = math.max(world.minX + mx, math.min(world.maxX - mx, x))
    y = math.max(world.minY + my, math.min(world.maxY - my, y))
    return x, y
end

return world
