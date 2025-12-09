local player = {}

local physics = require("src.core.physics")
local weapons = require("src.core.weapons")
local config = require("src.core.config")
local core_ship = require("src.core.ship")
local ship_renderer = require("src.render.ship_renderer")
local player_drone = require("src.data.ships.player_drone")

local function renderDrone(colors, size)
    -- Build a concrete world-space layout for the current player blueprint
    -- and delegate all actual drawing to the shared ship renderer so that
    -- player ships use the same flexible template-driven pipeline as other
    -- ships.
    local layout = core_ship.buildInstanceFromBlueprint(player_drone, size)
    ship_renderer.drawPlayer(layout, colors)
end

--- Generate the collision polygon for the player drone
--- Matches the visual shape from renderDrone(), using the same shared
--- core.ship layout so physics and visuals stay perfectly aligned.
--- @param size number The player size
--- @return table Flat vertex array for collision shape
local function generateDroneCollisionVertices(size)
    -- Build the same world-space layout used by rendering. If a dedicated
    -- collision hull is provided in the blueprint, core.ship will project
    -- that to world space; otherwise it falls back to the main hull.
    local layout = core_ship.buildInstanceFromBlueprint(player_drone, size)
    if not layout or not layout.collisionVertices or #layout.collisionVertices < 6 then
        return {}
    end

    return layout.collisionVertices
end

player.state = {
    x = 0,
    y = 0,
    -- Velocity components for zero-g physics
    vx = 0,
    vy = 0,
    -- Target position (where player clicked)
    targetX = 0,
    targetY = 0,
    -- Physics properties
    thrust = physics.constants.shipThrust,
    maxSpeed = physics.constants.shipMaxSpeed,
    size = config.player.size,
    angle = 0,
    targetAngle = 0,
    approachAngle = nil,
    health = config.player.maxHealth,
    maxHealth = config.player.maxHealth,
    shield = config.player.maxShield or 0,
    maxShield = config.player.maxShield or 0,
    level = 1,
    xp = 0,
    xpToNext = config.player.xpBase,
    xpRatio = 0,
    isThrusting = false,
    body = nil,
    shapes = nil,   -- Table of shapes (polygon body may have multiple)
    fixtures = nil, -- Table of fixtures
    collisionVertices = nil, -- Stored collision vertices
    weapon = weapons.pulseLaser
}

local function recalcXpProgress(p)
    local base = config.player.xpBase or 100
    local growth = config.player.xpGrowth or 0
    local level = p.level or 1
    local xp = p.xp or 0

    local xpToNext = base + growth * (level - 1)
    if xpToNext <= 0 then
        xpToNext = 1
    end

    p.xpToNext = xpToNext
    p.xpRatio = math.max(0, math.min(1, xp / xpToNext))
end

function player.addExperience(amount)
    local p = player.state
    if not amount or amount <= 0 then
        return false
    end

    p.xp = (p.xp or 0) + amount
    local leveledUp = false

    while true do
        local base = config.player.xpBase or 100
        local growth = config.player.xpGrowth or 0
        local level = p.level or 1
        local xpToNext = base + growth * (level - 1)
        if xpToNext <= 0 then
            xpToNext = 1
        end

        if p.xp >= xpToNext then
            p.xp = p.xp - xpToNext
            p.level = level + 1
            leveledUp = true
        else
            break
        end
    end

    recalcXpProgress(p)
    return leveledUp
end

function player.resetExperience()
    local p = player.state
    p.level = 1
    p.xp = 0
    recalcXpProgress(p)
end

function player.centerInWindow()
    local p = player.state
    p.x = love.graphics.getWidth() / 2
    p.y = love.graphics.getHeight() / 2
    p.targetX = p.x
    p.targetY = p.y
end

--------------------------------------------------------------------------------
-- PHYSICS BODY CREATION
-- Creates the player's physics body with proper collision filtering
--------------------------------------------------------------------------------
local function createBody()
    local p = player.state
    
    -- Clean up existing body if present
    if p.body then
        p.body:destroy()
        p.body = nil
        p.shapes = nil
        p.fixtures = nil
    end
    
    -- Generate collision vertices matching the drone shape
    p.collisionVertices = generateDroneCollisionVertices(p.size)
    
    -- Create polygon body with collision filtering
    p.body, p.shapes, p.fixtures = physics.createPolygonBody(
        p.x, p.y,
        p.collisionVertices,
        "PLAYER",
        p  -- Pass player state as the entity reference
    )
end

function player.reset()
    local p = player.state
    player.centerInWindow()
    player.resetExperience()
    p.health = p.maxHealth
    p.shield = p.maxShield
    -- Reset velocity for zero-g
    p.vx = 0
    p.vy = 0
    p.isThrusting = false
    p.angle = 0
    p.targetAngle = 0
    p.approachAngle = nil
    createBody()
    p.weapon = weapons.pulseLaser
end

function player.update(dt, world)
    local p = player.state
    local consts = physics.constants
    
    local dx = p.targetX - p.x
    local dy = p.targetY - p.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local speed = physics.getSpeed(p.vx, p.vy)

    -- Arrival parameters
    local stopRadius = config.player.stopRadius       -- Inside this, we consider we "reached" the point
    local slowRadius = config.player.slowRadius     -- Start slowing down when within this distance

    p.isThrusting = false

    -- If we're very close and moving slowly, snap to the target and stop
    if distance < stopRadius and speed < config.player.arrivalSpeedThreshold then
        p.vx = 0
        p.vy = 0
        p.targetX = p.x
        p.targetY = p.y
    else
        -- Desired direction toward the target (for movement)
        local dirX, dirY = 0, 0
        if distance > 0 then
            dirX = dx / distance
            dirY = dy / distance
        end

        -- Desired speed: full speed far away, slower as we approach
        local desiredSpeed
        if distance > slowRadius then
            desiredSpeed = p.maxSpeed
        else
            desiredSpeed = p.maxSpeed * (distance / slowRadius)
        end

        local desiredVx = dirX * desiredSpeed
        local desiredVy = dirY * desiredSpeed

        -- Velocity change we want: this handles both accelerating and braking
        local dvx = desiredVx - p.vx
        local dvy = desiredVy - p.vy
        local dvLen = math.sqrt(dvx * dvx + dvy * dvy)

        if dvLen > 1 then
            -- Use separate thrust direction so visuals stay stable
            local thrustAngle = math.atan2(dvy, dvx)

            -- Visual nose: keep facing along the original approach path
            if distance > stopRadius then
                local noseAngle = p.approachAngle or math.atan2(dy, dx)
                p.targetAngle = noseAngle
                p.angle = physics.rotateTowards(p.angle, p.targetAngle, consts.shipRotationSpeed, dt)
            end

            p.isThrusting = true
            p.vx, p.vy = physics.applyThrust(p.vx, p.vy, thrustAngle, p.thrust, dt, p.maxSpeed)
        else
            -- Close to desired velocity: just keep facing the approach direction
            if distance > stopRadius then
                local noseAngle = p.approachAngle or math.atan2(dy, dx)
                p.targetAngle = noseAngle
                p.angle = physics.rotateTowards(p.angle, p.targetAngle, consts.shipRotationSpeed, dt)
            end
        end
    end

    -- Apply very minimal damping (micro-thruster stabilization)
    p.vx, p.vy = physics.applyDamping(p.vx, p.vy, consts.linearDamping, dt)

    -- Update position based on velocity (momentum carries us)
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    
    -- World boundary handling - bounce off edges with velocity reversal
    if world then
        local margin = p.size
        if p.x < world.minX + margin then
            p.x = world.minX + margin
            p.vx = math.abs(p.vx) * config.player.bounceFactor  -- Bounce with energy loss
        elseif p.x > world.maxX - margin then
            p.x = world.maxX - margin
            p.vx = -math.abs(p.vx) * config.player.bounceFactor
        end
        if p.y < world.minY + margin then
            p.y = world.minY + margin
            p.vy = math.abs(p.vy) * config.player.bounceFactor
        elseif p.y > world.maxY - margin then
            p.y = world.maxY - margin
            p.vy = -math.abs(p.vy) * config.player.bounceFactor
        end
    else
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        if p.x < p.size then
            p.x = p.size
            p.vx = math.abs(p.vx) * config.player.bounceFactor
        elseif p.x > w - p.size then
            p.x = w - p.size
            p.vx = -math.abs(p.vx) * 0.5
        end
        if p.y < p.size then
            p.y = p.size
            p.vy = math.abs(p.vy) * 0.5
        elseif p.y > h - p.size then
            p.y = h - p.size
            p.vy = -math.abs(p.vy) * 0.5
        end
    end

    if p.body then
        p.body:setPosition(p.x, p.y)
    end
end

function player.setTarget(x, y)
    local p = player.state
    p.targetX = x
    p.targetY = y
    local dx = x - p.x
    local dy = y - p.y
    if dx ~= 0 or dy ~= 0 then
        p.approachAngle = math.atan2(dy, dx)
    end
end

function player.draw(colors)
    local p = player.state

    love.graphics.push()
    love.graphics.translate(p.x, p.y)
    love.graphics.rotate(p.angle)

    -- Main body (solid diamond/rhombus drone shape)
    renderDrone(colors, p.size)

    love.graphics.pop()
end

-- Expose renderDrone for preview use (e.g., skin selection)
player.renderDrone = renderDrone

return player
