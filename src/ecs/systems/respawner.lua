local Concord = require("lib.concord")

-- We intentionally avoid `require("src.entities.enemy")` here.
-- `enemy.lua` depends on `src.ecs.world`, which loads this system; requiring `enemy` here
-- creates a circular module load.
local RespawnerSystem = Concord.system({
    timers = { "respawnTimer" }
})

function RespawnerSystem:update(dt)
    -- Iterate backwards safely as we might destroy entities
    for i = #self.timers, 1, -1 do
        local e = self.timers[i]
        local timer = e.respawnTimer
        
        timer.current = timer.current - dt
        
        if timer.current <= 0 then
            -- Respawn the enemy at original location
            -- Spawn via the ECS world to keep this system decoupled from legacy entity modules.
            self:getWorld():spawnEnemy(timer.x, timer.y, timer.enemyDef)
            
            -- Destroy the timer entity
            e:destroy()
        end
    end
end

return RespawnerSystem
