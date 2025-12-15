--------------------------------------------------------------------------------
-- AI SYSTEM (ECS)
-- Handles enemy behavior: idle, chase, attack states
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local config = require("src.core.config")
local physics = require("src.core.physics")

local AISystem = Concord.system({
    enemies = { "aiState", "position", "velocity", "rotation", "faction", "thrust" },
})

AISystem["physics.pre_step"] = function(self, dt, playerEntity, world)
    self:prePhysics(dt, playerEntity, world)
end

--------------------------------------------------------------------------------
-- BOUNDS AVOIDANCE (WORLD EDGES)
--------------------------------------------------------------------------------

local function getCollisionRadius(e)
    local cr = e.collisionRadius
    if type(cr) == "table" then
        return cr.radius or 0
    elseif type(cr) == "number" then
        return cr
    end

    return 0
end

local function computeWorldBoundsAvoidance(pos, radius, world)
    if not world or not pos then
        return 0, 0
    end

    local enemyCfg = config.enemy or {}
    local avoidDist = enemyCfg.avoidanceRadius or 180
    local strength = enemyCfg.avoidanceStrength or 1.0
    if avoidDist <= 0 or strength == 0 then
        return 0, 0
    end

    local ax, ay = 0, 0

    local leftDist = pos.x - (world.minX + radius)
    if leftDist < avoidDist then
        ax = ax + (avoidDist - leftDist) / avoidDist
    end

    local rightDist = (world.maxX - radius) - pos.x
    if rightDist < avoidDist then
        ax = ax - (avoidDist - rightDist) / avoidDist
    end

    local topDist = pos.y - (world.minY + radius)
    if topDist < avoidDist then
        ay = ay + (avoidDist - topDist) / avoidDist
    end

    local bottomDist = (world.maxY - radius) - pos.y
    if bottomDist < avoidDist then
        ay = ay - (avoidDist - bottomDist) / avoidDist
    end

    return ax * strength, ay * strength
end

local function applyBoundsAvoidanceToAngle(baseAngle, pos, radius, world)
    if not baseAngle or not world or not pos then
        return baseAngle
    end

    local ax, ay = computeWorldBoundsAvoidance(pos, radius, world)
    if ax == 0 and ay == 0 then
        return baseAngle
    end

    local bx = math.cos(baseAngle)
    local by = math.sin(baseAngle)

    local nx = bx + ax
    local ny = by + ay
    local len = math.sqrt(nx * nx + ny * ny)
    if len <= 0 then
        return baseAngle
    end

    return math.atan2(ny / len, nx / len)
end

-- Update AI for all enemies (pre-physics phase).
function AISystem:prePhysics(dt, playerEntity, world)
    if not playerEntity or not playerEntity.position then return end

    local playerX = playerEntity.position.x
    local playerY = playerEntity.position.y

    -- Update each enemy
    for i = 1, self.enemies.size do
        local e = self.enemies[i]
        if e.faction.name == "enemy" then
            -- Check distance for activation
            local dx = playerX - e.position.x
            local dy = playerY - e.position.y
            local distSq = dx * dx + dy * dy
            local detectionRange = e.aiState.detectionRange

            -- Active if within detection range
            local isActive = distSq <= detectionRange * detectionRange

            self:updateEnemy(e, isActive, playerX, playerY, dt, world)
        end
    end
end

function AISystem:update(dt, playerEntity, world)
    self:prePhysics(dt, playerEntity, world)
end

function AISystem:updateEnemy(e, isActive, playerX, playerY, dt, world)
    local ai = e.aiState
    local pos = e.position
    local rot = e.rotation
    local thrust = e.thrust

    local radius = getCollisionRadius(e)

    local dx = playerX - pos.x
    local dy = playerY - pos.y
    local distance = math.sqrt(dx * dx + dy * dy)

    local attackRange = ai.attackRange
    local detectionRange = ai.detectionRange

    -- Determine state
    if isActive then
        if distance > detectionRange then
            ai.state = "idle"
        elseif distance > attackRange then
            ai.state = "chase"
        else
            ai.state = "attack"
        end
    else
        ai.state = "idle"
    end

    -- Calculate thrust direction
    thrust.isThrusting = false

    if ai.state == "chase" then
        if distance > 0 then
            rot.targetAngle = math.atan2(dy, dx)
            rot.targetAngle = applyBoundsAvoidanceToAngle(rot.targetAngle, pos, radius, world)
            local angleDiff = math.abs(physics.normalizeAngle(rot.targetAngle - rot.angle))
            if angleDiff < math.pi / 2 then
                thrust.isThrusting = true
            end
        end
    elseif ai.state == "attack" then
        rot.targetAngle = math.atan2(dy, dx)
        rot.targetAngle = applyBoundsAvoidanceToAngle(rot.targetAngle, pos, radius, world)

        local tooFar = distance > attackRange * config.enemy.attackTooFarFactor
        local tooClose = distance < attackRange * config.enemy.attackTooCloseFactor

        if tooFar and distance > 0 then
            local angleDiff = math.abs(physics.normalizeAngle(rot.targetAngle - rot.angle))
            if angleDiff < math.pi / 2 then
                thrust.isThrusting = true
            end
        elseif tooClose and distance > 0 then
            local awayAngle = math.atan2(-dy, -dx)
            awayAngle = applyBoundsAvoidanceToAngle(awayAngle, pos, radius, world)
            local angleDiff = math.abs(physics.normalizeAngle(awayAngle - rot.angle))
            if angleDiff < math.pi / 2 then
                thrust.isThrusting = true
            end
        end
    elseif ai.state == "idle" then
        -- Idle wandering
        if e.wanderBehavior then
            local wander = e.wanderBehavior
            wander.timer = wander.timer - dt

            if e.spawnPosition then
                local homeX = e.spawnPosition.x
                local homeY = e.spawnPosition.y
                local dxHome = pos.x - homeX
                local dyHome = pos.y - homeY
                local distHomeSq = dxHome * dxHome + dyHome * dyHome
                local maxRadiusSq = wander.radius * wander.radius

                if distHomeSq > maxRadiusSq then
                    rot.targetAngle = math.atan2(homeY - pos.y, homeX - pos.x)
                    rot.targetAngle = applyBoundsAvoidanceToAngle(rot.targetAngle, pos, radius, world)
                    local angleDiff = math.abs(physics.normalizeAngle(rot.targetAngle - rot.angle))
                    if angleDiff < math.pi / 2 then
                        thrust.isThrusting = true
                    end
                else
                    if wander.timer <= 0 then
                        wander.angle = math.random() * math.pi * 2
                        wander.timer = config.enemy.wanderIntervalBase +
                            math.random() * config.enemy.wanderIntervalRandom
                    end
                    rot.targetAngle = wander.angle
                    rot.targetAngle = applyBoundsAvoidanceToAngle(rot.targetAngle, pos, radius, world)

                    if wander.timer > config.enemy.wanderThrustThreshold then
                        local angleDiff = math.abs(physics.normalizeAngle(rot.targetAngle - rot.angle))
                        if angleDiff < math.pi / 4 then
                            thrust.isThrusting = true
                        end
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- FIRING SYSTEM
-- Handles weapon firing for entities with weapons
--------------------------------------------------------------------------------

local FiringSystem = Concord.system({
    shooters = { "weapon", "position", "rotation", "faction" },
})

FiringSystem["physics.pre_step"] = function(self, dt, playerEntity)
    self:prePhysics(dt, playerEntity)
end

function FiringSystem:prePhysics(dt, playerEntity)
    if not playerEntity or not playerEntity.position then return end

    local playerX = playerEntity.position.x
    local playerY = playerEntity.position.y

      for i = 1, self.shooters.size do
        local e = self.shooters[i]

        -- Only enemies fire automatically
        if e.faction.name ~= "enemy" then goto continue end
        if not e.aiState then goto continue end

        -- Check that the player is at least within this enemy's detection radius
        -- so they start shooting as soon as they "see" the player, instead of
        -- waiting until a tighter attack/optimal range.
        --
        -- IMPORTANT: detection range should NOT be used as the firing range.
        -- Using detectionRange here allows enemies to shoot from very far away
        -- (often off-screen), especially with per-level detection scaling.
        local dx = playerX - e.position.x
        local dy = playerY - e.position.y
        local distSq = dx * dx + dy * dy

        local attackRange = (e.aiState and e.aiState.attackRange) or config.enemy.attackRange or 350
        local fireRange = attackRange * (config.enemy.attackTooFarFactor or 1.0)
        if distSq > fireRange * fireRange then goto continue end

        local weapon = e.weapon
        local weaponData = weapon.data or {}
        local interval = weaponData.fireInterval or 1.0

        weapon.fireTimer = weapon.fireTimer + dt

        if weapon.fireTimer >= interval then
            weapon.fireTimer = 0

            -- Emit fire event for projectile spawning
            self:getWorld():emit("combat.fire_projectile", e, playerX, playerY, playerEntity)
        end

        ::continue::
    end
end

function FiringSystem:update(dt, playerEntity)
    self:prePhysics(dt, playerEntity)
end

return {
    AISystem = AISystem,
    FiringSystem = FiringSystem,
}
