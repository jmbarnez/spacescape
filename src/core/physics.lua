local physics = {}

physics.world = nil

--------------------------------------------------------------------------------
-- COLLISION CATEGORIES (Bitmask values for Box2D filtering)
-- Each category is a power of 2 so they can be combined with bitwise OR
--------------------------------------------------------------------------------
physics.categories = {
    PLAYER           = 0x0001,  -- 1:   Player ship
    ENEMY            = 0x0002,  -- 2:   Enemy ships
    ASTEROID         = 0x0004,  -- 4:   Asteroids
    PLAYER_PROJECTILE = 0x0008, -- 8:   Projectiles fired by player
    ENEMY_PROJECTILE  = 0x0010, -- 16:  Projectiles fired by enemies
}

-- Define what each category can collide with (mask)
-- A fixture collides with another if (categoryA & maskB) != 0 AND (categoryB & maskA) != 0
physics.masks = {
    -- Player collides with: enemies, asteroids, enemy projectiles
    PLAYER = 0x0002 + 0x0004 + 0x0010,
    
    -- Enemies collide with: player, player projectiles (not other enemies or asteroids)
    ENEMY = 0x0001 + 0x0008,
    
    -- Asteroids collide with: player, all projectiles
    ASTEROID = 0x0001 + 0x0008 + 0x0010,
    
    -- Player projectiles collide with: enemies, asteroids
    PLAYER_PROJECTILE = 0x0002 + 0x0004,
    
    -- Enemy projectiles collide with: player, asteroids
    ENEMY_PROJECTILE = 0x0001 + 0x0004,
}

--------------------------------------------------------------------------------
-- COLLISION CALLBACKS
-- These are set on the physics world and called automatically by Box2D
--------------------------------------------------------------------------------
local collisionHandler = nil  -- Will be set by collision system

--- Called when two fixtures begin overlapping
local function beginContact(fixtureA, fixtureB, contact)
    if collisionHandler then
        local dataA = fixtureA:getUserData()
        local dataB = fixtureB:getUserData()
        if dataA and dataB then
            collisionHandler.onBeginContact(dataA, dataB, contact)
        end
    end
end

--- Called when two fixtures stop overlapping
local function endContact(fixtureA, fixtureB, contact)
    -- Currently unused, but available for future use
end

--- Called before collision response is calculated (can disable collision)
local function preSolve(fixtureA, fixtureB, contact)
    -- Currently unused, but available for future use
end

--- Called after collision response is calculated
local function postSolve(fixtureA, fixtureB, contact, normalImpulse, tangentImpulse)
    -- Currently unused, but available for future use
end

--- Register a collision handler module that will receive collision events
--- @param handler table Must have onBeginContact(dataA, dataB, contact) method
function physics.setCollisionHandler(handler)
    collisionHandler = handler
end

--------------------------------------------------------------------------------
-- PHYSICS CONSTANTS
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function physics.init()
    if physics.world then
        return
    end
    
    -- Set the meter scale (32 pixels = 1 meter)
    love.physics.setMeter(32)
    
    -- Create world with zero gravity (space!)
    physics.world = love.physics.newWorld(0, 0, true)
    
    -- Register collision callbacks with Box2D
    physics.world:setCallbacks(beginContact, endContact, preSolve, postSolve)
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

--------------------------------------------------------------------------------
-- FIXTURE SETUP HELPERS
-- These helpers configure fixtures with proper collision filtering and user data
--------------------------------------------------------------------------------

--- Configure a fixture with collision category, mask, and user data
--- @param fixture userdata The Box2D fixture to configure
--- @param categoryName string One of: "PLAYER", "ENEMY", "ASTEROID", "PLAYER_PROJECTILE", "ENEMY_PROJECTILE"
--- @param userData table Data to attach to fixture (must have 'type' and 'entity' fields)
function physics.setupFixture(fixture, categoryName, userData)
    local category = physics.categories[categoryName]
    local mask = physics.masks[categoryName]
    
    if category and mask then
        fixture:setFilterData(category, mask, 0)
    end
    
    if userData then
        fixture:setUserData(userData)
    end
end

--- Create a standard circular body with proper collision setup
--- @param x number World X position
--- @param y number World Y position
--- @param radius number Collision radius
--- @param categoryName string Collision category name
--- @param entity table The game entity this body represents
--- @param options table Optional: { isSensor = bool, isBullet = bool, bodyType = string }
--- @return body, shape, fixture
function physics.createCircleBody(x, y, radius, categoryName, entity, options)
    local world = physics.getWorld()
    if not world then
        return nil, nil, nil
    end
    
    options = options or {}
    local bodyType = options.bodyType or "dynamic"
    
    local body = love.physics.newBody(world, x, y, bodyType)
    local shape = love.physics.newCircleShape(radius)
    local fixture = love.physics.newFixture(body, shape, 1)
    
    -- Configure body properties
    body:setFixedRotation(true)
    
    if options.isBullet then
        body:setBullet(true)
    end
    
    if options.isSensor then
        fixture:setSensor(true)
    end
    
    -- Setup collision filtering and user data
    physics.setupFixture(fixture, categoryName, {
        type = categoryName:lower():gsub("_", ""),  -- e.g., "PLAYER_PROJECTILE" -> "playerprojectile"
        entity = entity
    })
    
    return body, shape, fixture
end

--- Create a polygon body with proper collision setup
--- Box2D polygons must be convex with max 8 vertices. For complex shapes,
--- this creates multiple fixtures (convex decomposition).
--- @param x number World X position
--- @param y number World Y position
--- @param vertices table Flat array of vertex coordinates {x1, y1, x2, y2, ...} or array of {x, y} pairs
--- @param categoryName string Collision category name
--- @param entity table The game entity this body represents
--- @param options table Optional: { isSensor = bool, isBullet = bool, bodyType = string }
--- @return body, shapes (table), fixtures (table)
function physics.createPolygonBody(x, y, vertices, categoryName, entity, options)
    local world = physics.getWorld()
    if not world then
        return nil, nil, nil
    end
    
    options = options or {}
    local bodyType = options.bodyType or "dynamic"
    
    -- Normalize vertices to flat array
    local flatVerts = {}
    if vertices[1] and type(vertices[1]) == "table" then
        -- Array of {x, y} pairs
        for _, v in ipairs(vertices) do
            table.insert(flatVerts, v[1])
            table.insert(flatVerts, v[2])
        end
    else
        -- Already flat
        flatVerts = vertices
    end
    
    -- Ensure we have at least 3 vertices (6 values)
    if #flatVerts < 6 then
        return nil, nil, nil
    end
    
    local body = love.physics.newBody(world, x, y, bodyType)
    body:setFixedRotation(true)
    
    if options.isBullet then
        body:setBullet(true)
    end
    
    local shapes = {}
    local fixtures = {}
    local userData = {
        type = categoryName:lower():gsub("_", ""),
        entity = entity
    }
    
    -- Box2D requires convex polygons with max 8 vertices
    -- For simple convex shapes, create directly; otherwise decompose
    local vertCount = #flatVerts / 2
    
    if vertCount <= 8 then
        -- Try to create a single polygon shape
        local success, shape = pcall(love.physics.newPolygonShape, unpack(flatVerts))
        if success and shape then
            local fixture = love.physics.newFixture(body, shape, 1)
            if options.isSensor then
                fixture:setSensor(true)
            end
            physics.setupFixture(fixture, categoryName, userData)
            table.insert(shapes, shape)
            table.insert(fixtures, fixture)
        else
            -- Fallback: create triangles from center (fan triangulation)
            physics.createTriangleFan(body, flatVerts, categoryName, userData, options, shapes, fixtures)
        end
    else
        -- Too many vertices: use fan triangulation
        physics.createTriangleFan(body, flatVerts, categoryName, userData, options, shapes, fixtures)
    end
    
    -- If no fixtures were created, fall back to bounding circle
    if #fixtures == 0 then
        local radius = physics.computeBoundingRadius(flatVerts)
        local shape = love.physics.newCircleShape(radius)
        local fixture = love.physics.newFixture(body, shape, 1)
        if options.isSensor then
            fixture:setSensor(true)
        end
        physics.setupFixture(fixture, categoryName, userData)
        table.insert(shapes, shape)
        table.insert(fixtures, fixture)
    end
    
    return body, shapes, fixtures
end

--- Create triangle fan from vertices (helper for polygon decomposition)
--- @param body userdata The Box2D body
--- @param flatVerts table Flat vertex array
--- @param categoryName string Collision category
--- @param userData table User data for fixtures
--- @param options table Options (isSensor, etc.)
--- @param shapes table Output shapes array
--- @param fixtures table Output fixtures array
function physics.createTriangleFan(body, flatVerts, categoryName, userData, options, shapes, fixtures)
    local vertCount = #flatVerts / 2
    
    -- Compute centroid
    local cx, cy = 0, 0
    for i = 1, vertCount do
        cx = cx + flatVerts[(i - 1) * 2 + 1]
        cy = cy + flatVerts[(i - 1) * 2 + 2]
    end
    cx = cx / vertCount
    cy = cy / vertCount
    
    -- Create triangles from centroid to each edge
    for i = 1, vertCount do
        local i1 = (i - 1) * 2 + 1
        local i2 = (i % vertCount) * 2 + 1
        
        local x1, y1 = flatVerts[i1], flatVerts[i1 + 1]
        local x2, y2 = flatVerts[i2], flatVerts[i2 + 1]
        
        local triVerts = {cx, cy, x1, y1, x2, y2}
        local success, shape = pcall(love.physics.newPolygonShape, unpack(triVerts))
        if success and shape then
            local fixture = love.physics.newFixture(body, shape, 1)
            if options.isSensor then
                fixture:setSensor(true)
            end
            physics.setupFixture(fixture, categoryName, userData)
            table.insert(shapes, shape)
            table.insert(fixtures, fixture)
        end
    end
end

--- Compute bounding radius from flat vertex array
--- @param flatVerts table Flat vertex array {x1, y1, x2, y2, ...}
--- @return number Bounding radius
function physics.computeBoundingRadius(flatVerts)
    local maxDistSq = 0
    local vertCount = #flatVerts / 2
    for i = 1, vertCount do
        local x = flatVerts[(i - 1) * 2 + 1]
        local y = flatVerts[(i - 1) * 2 + 2]
        local distSq = x * x + y * y
        if distSq > maxDistSq then
            maxDistSq = distSq
        end
    end
    return math.sqrt(maxDistSq)
end

return physics
