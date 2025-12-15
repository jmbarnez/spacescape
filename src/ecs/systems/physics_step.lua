local Concord = require("lib.concord")
local physics = require("src.core.physics")

local PhysicsStepSystem = Concord.system({})

function PhysicsStepSystem:stepPhysics(dt, playerEntity, worldData)
    local world = self:getWorld()
    if not world then
        return
    end

    world:emit("prePhysics", dt, playerEntity, worldData)
    physics.update(dt)
    world:emit("postPhysics", dt, playerEntity, worldData)
end

return {
    PhysicsStepSystem = PhysicsStepSystem,
}
