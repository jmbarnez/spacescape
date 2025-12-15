--------------------------------------------------------------------------------
-- WORLD BOUNDS SYSTEM (ECS)
-- Keeps entities inside the simulation area (Bounce or Clamp)
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local config = require("src.core.config")
local colors = require("src.core.colors")
local shieldImpactFx = require("src.entities.shield_impact_fx")

local WorldBoundsSystem = Concord.system({
    -- All entities that move and should respect bounds
    bounded = { "position", "velocity", "collisionRadius" }
})

WorldBoundsSystem["physics.pre_step"] = function(self, dt, player, worldBox)
    self:prePhysics(dt, player, worldBox)
end

local function handleShieldBounce(e, bx, by)
    if not (e.shield and e.shield.current > 0) then return end

    -- Visual FX only
    if shieldImpactFx and shieldImpactFx.spawn then
        local radius = e.collisionRadius and e.collisionRadius.radius or e.size or 20
        shieldImpactFx.spawn(e.position.x, e.position.y, bx, by, radius * 1.15, colors.shieldDamage, e)
    end
end

function WorldBoundsSystem:prePhysics(dt, player, worldBox)
    -- If no world bounds provided, maybe default to screen?
    -- But usually this system runs with simulation bounds.
    if not worldBox then return end

    local minX, maxX = worldBox.minX, worldBox.maxX
    local minY, maxY = worldBox.minY, worldBox.maxY

    for i = 1, self.bounded.size do
        local e = self.bounded[i]
        local pos = e.position
        local vel = e.velocity
        local radius = e.collisionRadius.radius or 10

        -- Logic depends on entity type/tags.
        -- To be purely data-driven, we should have a "WorldBoundsBehavior" component.
        -- But for now, we infer from tags (ASTEROID vs SHOOTER vs PLAYER) or just default behavior.

        -- Behavior: BOUNCE (Elastic)
        -- Used by: Asteroids, Player
        -- Behavior: CLAMP (Slide)
        -- Used by: Enemies

        local isEnemy = (e.faction and e.faction.name == "enemy")
        local isAsteroid = e.asteroid ~= nil
        local isPlayer = e.playerControlled ~= nil

        local margin = radius

        if isEnemy then
            -- CLAMP / SLIDE
            if pos.x < minX + margin then
                pos.x = minX + margin
                if vel.vx < 0 then vel.vx = 0 end
            elseif pos.x > maxX - margin then
                pos.x = maxX - margin
                if vel.vx > 0 then vel.vx = 0 end
            end

            if pos.y < minY + margin then
                pos.y = minY + margin
                if vel.vy < 0 then vel.vy = 0 end
            elseif pos.y > maxY - margin then
                pos.y = maxY - margin
                if vel.vy > 0 then vel.vy = 0 end
            end
        elseif isAsteroid then
            -- BOUNCE (Elastic)
            -- simple bounce, no energy loss
            if pos.x < minX + margin then
                pos.x = minX + margin
                vel.vx = math.abs(vel.vx)
            elseif pos.x > maxX - margin then
                pos.x = maxX - margin
                vel.vx = -math.abs(vel.vx)
            end

            if pos.y < minY + margin then
                pos.y = minY + margin
                vel.vy = math.abs(vel.vy)
            elseif pos.y > maxY - margin then
                pos.y = maxY - margin
                vel.vy = -math.abs(vel.vy)
            end
        elseif isPlayer then
            -- BOUNCE (Damped) + FX
            local bounceFactor = config.player and config.player.bounceFactor or 0.5
            local hit = false
            local hx, hy = pos.x, pos.y

            if pos.x < minX + margin then
                pos.x = minX + margin
                vel.vx = math.abs(vel.vx) * bounceFactor
                hx, hy = minX + margin, pos.y
                hit = true
            elseif pos.x > maxX - margin then
                pos.x = maxX - margin
                vel.vx = -math.abs(vel.vx) * bounceFactor
                hx, hy = maxX - margin, pos.y
                hit = true
            end

            if pos.y < minY + margin then
                pos.y = minY + margin
                vel.vy = math.abs(vel.vy) * bounceFactor
                hx, hy = pos.x, minY + margin
                hit = true
            elseif pos.y > maxY - margin then
                pos.y = maxY - margin
                vel.vy = -math.abs(vel.vy) * bounceFactor
                hx, hy = pos.x, maxY - margin
                hit = true
            end

            if hit then
                handleShieldBounce(e, hx, hy)
            end
        else
            -- Default: do nothing? Or cleanup?
            -- Projectiles usually have their own lifecycle or bounds (MovementSystem ignores them usually?)
            -- Or we can cull them here.
            -- For generic entities, let's just Clamp so they don't drift forever.
            -- CLAMP
            if pos.x < minX + margin then
                pos.x = minX + margin; if vel.vx < 0 then vel.vx = 0 end
            end
            if pos.x > maxX - margin then
                pos.x = maxX - margin; if vel.vx > 0 then vel.vx = 0 end
            end
            if pos.y < minY + margin then
                pos.y = minY + margin; if vel.vy < 0 then vel.vy = 0 end
            end
            if pos.y > maxY - margin then
                pos.y = maxY - margin; if vel.vy > 0 then vel.vy = 0 end
            end
        end

        -- Sync physics body if present, as MovementSystem might have already synced the out-of-bounds position.
        if e.physics and e.physics.body then
            e.physics.body:setPosition(pos.x, pos.y)
        end
    end
end

return WorldBoundsSystem
