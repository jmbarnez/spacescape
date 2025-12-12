local Concord = require("lib.concord")

-- We intentionally avoid `require("src.entities.enemy")` here.
-- `enemy.lua` depends on `src.ecs.world`, which loads this system; requiring `enemy` here
-- creates a circular module load.
local RespawnerSystem = Concord.system({
    timers = { "respawnTimer" }
})

function RespawnerSystem:update(dt)
    dt = dt or 0

    -- Iterate backwards safely (Concord pools are Lists with a `.size` field).
    for i = self.timers.size, 1, -1 do
        local e = self.timers[i]
        if not e then
            goto continue
        end

        local timer = e.respawnTimer
        if not timer then
            goto continue
        end

        -- Defensively normalize timer state so a bad respawn payload doesn't crash
        -- the entire game loop.
        if type(timer.current) ~= "number" then
            timer.current = 0
        end

        timer.current = timer.current - dt

        if timer.current <= 0 then
            -- Respawn the enemy at original location.
            -- Spawn via the ECS world to keep this system decoupled from legacy entity modules.
            local world = self:getWorld()
            if world and world.spawnEnemy then
                pcall(function()
                    -- Explicit spawn spec:
                    --   - { def = enemyDef } so assemblages.enemy can normalize consistently.
                    local spec = nil
                    if timer.enemyDef then
                        spec = { def = timer.enemyDef }
                    end
                    world:spawnEnemy(timer.x or 0, timer.y or 0, spec)
                end)
            end

            -- Destroy the timer entity (actual removal occurs on the next world flush).
            e:destroy()
        end

        ::continue::
    end
end

return RespawnerSystem
