local physics = {}

physics.world = nil

function physics.init()
    if physics.world then
        return
    end
    love.physics.setMeter(32)
    physics.world = love.physics.newWorld(0, 0, true)
end

function physics.update(dt)
    if physics.world then
        physics.world:update(dt)
    end
end

function physics.getWorld()
    return physics.world
end

return physics
