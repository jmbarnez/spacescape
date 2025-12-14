--------------------------------------------------------------------------------
-- PLAYER CONTROL SYSTEM (ECS)
-- Handles player input for movement, targeting, and looting
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local physics = require("src.core.physics")
local config = require("src.core.config")

local DEFAULT_LOOT_RANGE = 90

local PlayerControlSystem = Concord.system({
    -- Only entities with player control tag and movement components
    players = { "playerControlled", "position", "velocity", "rotation", "destination", "thrust" }
})

--------------------------------------------------------------------------------
-- UPDATE LOOP
--------------------------------------------------------------------------------

function PlayerControlSystem:prePhysics(dt)
    local world = self:getWorld()
    for i = 1, self.players.size do
        local e = self.players[i]

        -- Loot targeting logic
        -- If we have a loot target, update destination to follow it
        local lootTarget = e.lootTarget
        if lootTarget then
            -- Validate target still exists and has position
            local isValid = false
            local tx, ty

            if lootTarget.position then
                tx, ty = lootTarget.position.x, lootTarget.position.y
                isValid = true
            elseif lootTarget.x and lootTarget.y then
                tx, ty = lootTarget.x, lootTarget.y
                isValid = true
            end

            if isValid then
                if lootTarget._removed or lootTarget.removed then
                    isValid = false
                elseif lootTarget.wreck == nil and lootTarget.wreck ~= true then
                    -- Not a wreck entity.
                    isValid = false
                end
            end

            if isValid then
                e.destination.x = tx
                e.destination.y = ty
                e.destination.active = true

                -- Check for arrival (loot range)
                local dx = tx - e.position.x
                local dy = ty - e.position.y
                local dist = math.sqrt(dx * dx + dy * dy)
                local lootRange = (config.player and config.player.lootRange) or DEFAULT_LOOT_RANGE

                if dist <= lootRange then
                    -- Arrived! Stop and open loot
                    e.destination.active = false
                    e.destination.x = e.position.x
                    e.destination.y = e.position.y
                    e.isLooting = true
                    -- Clear velocity
                    e.velocity.vx = 0
                    e.velocity.vy = 0
                end
            else
                -- Target lost
                e.lootTarget = nil
                e.isLooting = false
            end
        end

        -- Standard movement logic
        if e.destination.active then
            local dest = e.destination
            local pos = e.position
            local vel = e.velocity
            local thrust = e.thrust
            local damping = e.damping

            local dx = dest.x - pos.x
            local dy = dest.y - pos.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local speed = math.sqrt(vel.vx * vel.vx + vel.vy * vel.vy)

            -- Arrival parameters
            local stopRadius = config.player.stopRadius or 10
            local slowRadius = config.player.slowRadius or 200
            local arrivalSpeedThreshold = config.player.arrivalSpeedThreshold or 10
            local settleRadius = math.max(stopRadius * 3, stopRadius + 6)

            if damping then
                damping.base = damping.base or damping.value
                local t = 1
                if slowRadius > 0 then
                    t = math.max(0, math.min(1, dist / slowRadius))
                end
                local maxDamping = (config.player and config.player.autopilotMaxDamping) or 6.0
                damping.value = damping.base + (maxDamping - damping.base) * (1 - t)
            end

            thrust.isThrusting = false

            if (dist < stopRadius and speed < arrivalSpeedThreshold) or
                (dist < settleRadius and speed < arrivalSpeedThreshold * 2) then
                -- Arrived
                vel.vx = 0
                vel.vy = 0
                dest.x = pos.x
                dest.y = pos.y
                dest.active = false
                if damping and damping.base then
                    damping.value = damping.base
                end
            else
                if dist > 0 then
                    local dirX = dx / dist
                    local dirY = dy / dist

                    local slowScale = 1
                    if dist < slowRadius then
                        slowScale = dist / slowRadius
                    end
                    local desiredSpeed = thrust.maxSpeed * slowScale
                    local brakeDist = math.max(0, dist - stopRadius)
                    local brakeSpeed = math.sqrt(2 * thrust.power * brakeDist)
                    if brakeSpeed < desiredSpeed then
                        desiredSpeed = brakeSpeed
                    end

                    local desiredVx = dirX * desiredSpeed
                    local desiredVy = dirY * desiredSpeed

                    local dvx = desiredVx - vel.vx
                    local dvy = desiredVy - vel.vy
                    local dvLen = math.sqrt(dvx * dvx + dvy * dvy)

                    if dvLen > 1 then
                        e.rotation.targetAngle = math.atan2(dvy, dvx)
                    else
                        e.rotation.targetAngle = math.atan2(dy, dx)
                    end

                    local turnThenMoveThreshold = (config.player and config.player.turnThenMoveAngleThreshold) or 0.12
                    local angleDiff = math.abs(physics.normalizeAngle(e.rotation.targetAngle - e.rotation.angle))
                    if dvLen > 1 and angleDiff < turnThenMoveThreshold then
                        thrust.isThrusting = true
                    end
                end
            end
        else
            -- No destination: ensure we don't keep thrusting from a previous frame.
            e.thrust.isThrusting = false
            if e.damping and e.damping.base then
                e.damping.value = e.damping.base
            end
        end
    end
end

return PlayerControlSystem
