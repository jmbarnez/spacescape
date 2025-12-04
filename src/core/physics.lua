local physics = {}

physics.world = nil

-- Zero-G space physics constants
physics.constants = {
    -- Ship movement
    shipThrust = 120,           -- Acceleration when thrusting (pixels/s²)
    shipMaxSpeed = 200,         -- Maximum ship velocity
    shipRotationSpeed = 3.0,    -- Radians per second for rotation
    
    -- Enemy movement
    enemyThrust = 80,           -- Enemy acceleration
    enemyMaxSpeed = 150,        -- Enemy max velocity
    
    -- Asteroid drift
    asteroidMaxDrift = 15,      -- Max asteroid drift speed
    asteroidMinDrift = 2,       -- Min asteroid drift speed
    
    -- Projectile speeds (slower for space feel)
    projectileSpeed = 350,      -- Base projectile speed
    
    -- Damping (very low for space - simulates minor thruster corrections)
    linearDamping = 0.1,        -- Near-zero drag in space
    angularDamping = 0.5,       -- Slight rotational stabilization
}

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

-- Apply thrust in a direction (returns new velocity components)
function physics.applyThrust(vx, vy, angle, thrust, dt, maxSpeed)
    local ax = math.cos(angle) * thrust
    local ay = math.sin(angle) * thrust
    
    vx = vx + ax * dt
    vy = vy + ay * dt
    
    -- Clamp to max speed
    local speed = math.sqrt(vx * vx + vy * vy)
    if speed > maxSpeed then
        vx = (vx / speed) * maxSpeed
        vy = (vy / speed) * maxSpeed
    end
    
    return vx, vy
end

-- Apply minimal damping (simulates micro-thruster stabilization)
function physics.applyDamping(vx, vy, damping, dt)
    local factor = 1 - (damping * dt)
    if factor < 0 then factor = 0 end
    return vx * factor, vy * factor
end

-- Get velocity magnitude
function physics.getSpeed(vx, vy)
    return math.sqrt(vx * vx + vy * vy)
end

-- Normalize angle to -pi to pi
function physics.normalizeAngle(angle)
    while angle > math.pi do angle = angle - 2 * math.pi end
    while angle < -math.pi do angle = angle + 2 * math.pi end
    return angle
end

-- Smoothly rotate towards target angle
function physics.rotateTowards(currentAngle, targetAngle, rotSpeed, dt)
    local diff = physics.normalizeAngle(targetAngle - currentAngle)
    local maxRotation = rotSpeed * dt
    
    if math.abs(diff) <= maxRotation then
        return targetAngle
    elseif diff > 0 then
        return currentAngle + maxRotation
    else
        return currentAngle - maxRotation
    end
end

return physics
