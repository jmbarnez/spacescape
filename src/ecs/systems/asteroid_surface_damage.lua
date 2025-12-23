local Concord = require("lib.concord")
local config = require("src.core.config")

local AsteroidSurfaceDamageSystem = Concord.system({
    asteroids = { "asteroid", "position", "health" },
})

AsteroidSurfaceDamageSystem["asteroid.on_hit"] = function(self, asteroidEntity, projectileEntity, hitX, hitY, hullDamage)
    self:onAsteroidHit(asteroidEntity, projectileEntity, hitX, hitY, hullDamage)
end

AsteroidSurfaceDamageSystem["physics.pre_step"] = function(self, dt)
    self:prePhysics(dt)
end

local function isNumber(n)
    return type(n) == "number" and n == n
end

local function clamp01(t)
    if t < 0 then return 0 end
    if t > 1 then return 1 end
    return t
end

local function getAsteroidRadius(a)
    if a and a.collisionRadius then
        local cr = a.collisionRadius
        if type(cr) == "table" then
            return cr.radius or 20
        end
        if type(cr) == "number" then
            return cr
        end
    end
    return 20
end

local function rotateToLocal(dx, dy, angle)
    local c = math.cos(angle)
    local s = math.sin(angle)
    return dx * c + dy * s, -dx * s + dy * c
end

local function pickResourceTypeAndDecrement(resourceYield)
    if not (resourceYield and resourceYield.resources) then
        return nil
    end

    local total = 0
    for _, amount in pairs(resourceYield.resources) do
        local n = tonumber(amount) or 0
        if n > 0 then
            total = total + n
        end
    end

    if total <= 0 then
        return nil
    end

    local roll = math.random() * total
    local running = 0

    for resourceType, amount in pairs(resourceYield.resources) do
        local n = tonumber(amount) or 0
        if n > 0 then
            running = running + n
            if roll <= running then
                resourceYield.resources[resourceType] = n - 1
                return tostring(resourceType)
            end
        end
    end

    return nil
end

local function buildChunkFlatPoints(baseRadius)
    local sides = 5 + math.random(0, 3)
    local verts = {}
    local twoPi = math.pi * 2
    for i = 0, sides - 1 do
        local t = i / sides
        local a = t * twoPi
        local jitter = 0.65 + math.random() * 0.55
        local r = baseRadius * jitter
        verts[#verts + 1] = math.cos(a) * r
        verts[#verts + 1] = math.sin(a) * r
    end
    return verts
end

local function spawnDebris(world, asteroidEntity, hitX, hitY, nx, ny)
    if not (world and asteroidEntity and asteroidEntity.position) then
        return
    end

    local asteroidSize = (asteroidEntity.size and asteroidEntity.size.value) or 20
    local baseRadius = math.max(2.5, math.min(10, asteroidSize * 0.08))

    local color = { 0.32, 0.28, 0.24, 1 }
    local data = (asteroidEntity.asteroidVisual and asteroidEntity.asteroidVisual.data) or asteroidEntity.data
    if data and data.color then
        local c = data.color
        color = { (c[1] or 0.45) * 0.85, (c[2] or 0.38) * 0.85, (c[3] or 0.32) * 0.85, 1 }
    end

    local flatPoints = buildChunkFlatPoints(baseRadius)

    local e = Concord.entity(world)
    e:give("position", hitX, hitY)
        :give("velocity", 0, 0)
        :give("rotation", math.random() * math.pi * 2)
        :give("debris")
        :give("debrisVisual", flatPoints, color)
        :give("lifetime", (config.mining and config.mining.debrisLifetime) or 6)

    e.rotationSpeed = (math.random() - 0.5) * 2.2
    if e.lifetime then
        e.lifetimeTotal = e.lifetime.remaining
    end

    local impulseMin = (config.mining and config.mining.debrisImpulseMin) or 45
    local impulseMax = (config.mining and config.mining.debrisImpulseMax) or 120
    local impulse = impulseMin + (impulseMax - impulseMin) * math.random()

    local inheritVx = (asteroidEntity.velocity and asteroidEntity.velocity.vx) or 0
    local inheritVy = (asteroidEntity.velocity and asteroidEntity.velocity.vy) or 0

    local jitter = (config.mining and config.mining.debrisImpulseJitter) or 18
    local jx = (math.random() * 2 - 1) * jitter
    local jy = (math.random() * 2 - 1) * jitter

    if e.velocity then
        e.velocity.vx = inheritVx + nx * impulse + jx
        e.velocity.vy = inheritVy + ny * impulse + jy
    end
end

local function spawnDrop(world, asteroidEntity, hitX, hitY, nx, ny)
    if not (world and world.spawnItem) then
        return
    end

    if not (asteroidEntity and asteroidEntity.resourceYield) then
        return
    end

    local resourceType = pickResourceTypeAndDecrement(asteroidEntity.resourceYield)
    if not resourceType then
        return
    end

    local e = world:spawnItem(hitX, hitY, resourceType, 1)
    if e and e.velocity then
        local impulseMin = (config.mining and config.mining.dropImpulseMin) or 35
        local impulseMax = (config.mining and config.mining.dropImpulseMax) or 85
        local impulse = impulseMin + (impulseMax - impulseMin) * math.random()

        e.velocity.vx = nx * impulse + (math.random() * 2 - 1) * 10
        e.velocity.vy = ny * impulse + (math.random() * 2 - 1) * 10
    end
end

function AsteroidSurfaceDamageSystem:onAsteroidHit(asteroidEntity, projectileEntity, hitX, hitY, hullDamage)
    if not (asteroidEntity and asteroidEntity.position) then
        return
    end

    hullDamage = tonumber(hullDamage) or 0
    if hullDamage <= 0 then
        return
    end

    local px = asteroidEntity.position.x
    local py = asteroidEntity.position.y

    hitX = tonumber(hitX) or px
    hitY = tonumber(hitY) or py

    local dx = hitX - px
    local dy = hitY - py
    local distSq = dx * dx + dy * dy
    if distSq <= 0 then
        return
    end

    local dist = math.sqrt(distSq)
    local nx = dx / dist
    local ny = dy / dist

    local angle = (asteroidEntity.rotation and asteroidEntity.rotation.angle) or 0
    local lx, ly = rotateToLocal(dx, dy, angle)

    local surface = asteroidEntity.asteroidSurfaceDamage
    if not surface then
        asteroidEntity:give("asteroidSurfaceDamage", (config.mining and config.mining.surfaceCells) or 16)
        surface = asteroidEntity.asteroidSurfaceDamage
    end

    local cellCount = tonumber(surface.cellCount) or 16
    if cellCount < 4 then
        cellCount = 4
    end

    local a = math.atan2(ly, lx)
    local t = (a + math.pi) / (math.pi * 2)
    t = clamp01(t)

    local idx = math.floor(t * cellCount) + 1
    if idx < 1 then idx = 1 end
    if idx > cellCount then idx = cellCount end

    surface.cells[idx] = (surface.cells[idx] or 0) + hullDamage

    local radius = getAsteroidRadius(asteroidEntity)
    local markRadius = math.max(2, radius * ((config.mining and config.mining.markRadiusFactor) or 0.08))
    local markDuration = (config.mining and config.mining.markDuration) or 3.5

    local marks = surface.marks or {}
    surface.marks = marks

    marks[#marks + 1] = {
        x = lx,
        y = ly,
        r = markRadius,
        age = 0,
        duration = markDuration,
    }

    local maxMarks = (config.mining and config.mining.maxMarks) or 22
    while #marks > maxMarks do
        table.remove(marks, 1)
    end

    local thresholdBase = (config.mining and config.mining.chunkDamageThreshold) or 10
    local thresholdScale = (config.mining and config.mining.chunkDamageThresholdPerSize) or 0.08
    local asteroidSize = (asteroidEntity.size and asteroidEntity.size.value) or radius
    local threshold = thresholdBase + thresholdScale * asteroidSize

    if surface.cells[idx] >= threshold then
        surface.cells[idx] = surface.cells[idx] - threshold

        local world = self:getWorld()
        spawnDebris(world, asteroidEntity, hitX, hitY, nx, ny)

        local dropChance = (config.mining and config.mining.chunkDropChance) or 0.18
        if dropChance > 0 and math.random() < dropChance then
            spawnDrop(world, asteroidEntity, hitX, hitY, nx, ny)
        end
    end
end

function AsteroidSurfaceDamageSystem:prePhysics(dt)
    if not isNumber(dt) then
        return
    end

    for i = 1, self.asteroids.size do
        local a = self.asteroids[i]
        local surface = a.asteroidSurfaceDamage
        if surface and surface.marks then
            local marks = surface.marks
            for j = #marks, 1, -1 do
                local m = marks[j]
                m.age = (m.age or 0) + dt
                local duration = tonumber(m.duration) or 0
                if duration > 0 and m.age >= duration then
                    table.remove(marks, j)
                end
            end
        end
    end
end

function AsteroidSurfaceDamageSystem:update(dt)
    self:prePhysics(dt)
end

return AsteroidSurfaceDamageSystem
