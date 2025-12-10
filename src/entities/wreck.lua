--------------------------------------------------------------------------------
-- WRECK ENTITY
-- Cargo containers spawned from destroyed ships for player looting
--------------------------------------------------------------------------------

local wreck = {}

wreck.list = {}

local config = require("src.core.config")

-- Wreck configuration defaults
local LIFETIME = 180  -- 3 minutes decay time
local LOOT_RANGE = 90 -- Distance player must be within to open loot panel
local DRIFT_SPEED = 8 -- Slow drift velocity

--------------------------------------------------------------------------------
-- SPAWNING
--------------------------------------------------------------------------------

--- Spawn a wreck at the given position with generated loot
--- @param x number World X position
--- @param y number World Y position
--- @param cargo table Cargo slots table { [slotIndex] = { id = "...", quantity = N } }
--- @param coins number Amount of galactic coins in the wreck
--- @return table The spawned wreck
function wreck.spawn(x, y, cargo, coins)
    -- Random drift direction
    local driftAngle = math.random() * math.pi * 2
    local driftVx = math.cos(driftAngle) * DRIFT_SPEED
    local driftVy = math.sin(driftAngle) * DRIFT_SPEED

    local newWreck = {
        x = x,
        y = y,
        vx = driftVx,
        vy = driftVy,
        angle = math.random() * math.pi * 2,
        rotationSpeed = (math.random() - 0.5) * 0.3,
        size = 24,
        age = 0,
        lifetime = LIFETIME,
        cargo = cargo or {},
        coins = coins or 0,
    }

    table.insert(wreck.list, newWreck)
    return newWreck
end

--------------------------------------------------------------------------------
-- UPDATE
--------------------------------------------------------------------------------

--- Update all active wrecks
--- @param dt number Delta time
--- @param world table World bounds (optional)
function wreck.update(dt, world)
    for i = #wreck.list, 1, -1 do
        local w = wreck.list[i]

        -- Age tracking
        w.age = (w.age or 0) + dt

        -- Remove if expired
        if w.age >= w.lifetime then
            table.remove(wreck.list, i)
        else
            -- Slow drift
            w.x = w.x + w.vx * dt
            w.y = w.y + w.vy * dt

            -- Slow rotation
            w.angle = w.angle + w.rotationSpeed * dt

            -- Clamp to world bounds if provided
            if world and world.clampToWorld then
                w.x, w.y = world.clampToWorld(w.x, w.y, w.size)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- HIT DETECTION
--------------------------------------------------------------------------------

--- Find a wreck at the given position
--- @param x number World X position
--- @param y number World Y position
--- @param radius number Search radius padding
--- @return table|nil The wreck at position, or nil
function wreck.findAtPosition(x, y, radius)
    local padding = radius or 20
    local closestWreck = nil
    local closestDistSq = nil

    for _, w in ipairs(wreck.list) do
        local dx = w.x - x
        local dy = w.y - y
        local distSq = dx * dx + dy * dy
        local hitRadius = (w.size or 24) + padding
        local hitRadiusSq = hitRadius * hitRadius

        if distSq <= hitRadiusSq then
            if not closestDistSq or distSq < closestDistSq then
                closestDistSq = distSq
                closestWreck = w
            end
        end
    end

    return closestWreck
end

--- Get the loot interaction range
--- @return number The range within which player can open loot panel
function wreck.getLootRange()
    return LOOT_RANGE
end

--- Check if a wreck is empty (no cargo and no coins)
--- @param w table The wreck entity
--- @return boolean True if wreck has no loot
function wreck.isEmpty(w)
    if not w then return true end
    if w.coins and w.coins > 0 then return false end
    if w.cargo then
        for _, slot in pairs(w.cargo) do
            if slot and slot.id and slot.quantity and slot.quantity > 0 then
                return false
            end
        end
    end
    return true
end

--- Remove a wreck from the list
--- @param w table The wreck to remove
function wreck.remove(w)
    for i = #wreck.list, 1, -1 do
        if wreck.list[i] == w then
            table.remove(wreck.list, i)
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- DRAWING
--------------------------------------------------------------------------------

--- Draw all wrecks
function wreck.draw()
    for _, w in ipairs(wreck.list) do
        love.graphics.push()
        love.graphics.translate(w.x, w.y)
        love.graphics.rotate(w.angle)

        -- Fade out in last 20% of life
        local fadeStart = w.lifetime * 0.8
        local alpha = 1.0
        if w.age > fadeStart then
            alpha = 1.0 - ((w.age - fadeStart) / (w.lifetime - fadeStart))
        end

        -- Draw cargo container shape (crate/casing)
        local size = w.size
        local halfSize = size / 2

        -- Outer box
        love.graphics.setColor(0.45, 0.35, 0.25, alpha * 0.9)
        love.graphics.rectangle("fill", -halfSize, -halfSize, size, size, 3, 3)

        -- Inner panel
        love.graphics.setColor(0.55, 0.45, 0.35, alpha * 0.8)
        local inset = 4
        love.graphics.rectangle("fill", -halfSize + inset, -halfSize + inset,
            size - inset * 2, size - inset * 2, 2, 2)

        -- Cross detail
        love.graphics.setColor(0.35, 0.28, 0.18, alpha * 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.line(-halfSize + 2, 0, halfSize - 2, 0)
        love.graphics.line(0, -halfSize + 2, 0, halfSize - 2)

        -- Border
        love.graphics.setColor(0.65, 0.55, 0.40, alpha * 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", -halfSize, -halfSize, size, size, 3, 3)

        love.graphics.pop()
    end
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

--- Clear all wrecks
function wreck.clear()
    wreck.list = {}
end

return wreck
