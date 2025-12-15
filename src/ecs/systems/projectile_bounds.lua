local Concord = require("lib.concord")

local ProjectileBoundsSystem = Concord.system({
    projectiles = { "projectile", "position" },
})

ProjectileBoundsSystem["physics.post_step"] = function(self, dt, player, worldBox)
    self:postPhysics(dt, player, worldBox)
end

function ProjectileBoundsSystem:postPhysics(dt, player, worldBox)
    if not worldBox then
        return
    end

    local minX, maxX = worldBox.minX, worldBox.maxX
    local minY, maxY = worldBox.minY, worldBox.maxY
    if not (minX and maxX and minY and maxY) then
        return
    end

    local margin = 100

    for i = 1, self.projectiles.size do
        local e = self.projectiles[i]
        local pos = e.position

        if pos.x < minX - margin or pos.x > maxX + margin or pos.y < minY - margin or pos.y > maxY + margin then
            e:give("removed")
        end
    end
end

function ProjectileBoundsSystem:update(dt, player, worldBox)
    self:postPhysics(dt, player, worldBox)
end

return ProjectileBoundsSystem
