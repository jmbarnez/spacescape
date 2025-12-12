--------------------------------------------------------------------------------
-- WRECK ENTITY
-- Cargo containers spawned from destroyed ships for player looting
--------------------------------------------------------------------------------

local wreck = {}

local ecsWorld = require("src.ecs.world")
local assemblages = require("src.ecs.assemblages")
local Concord = require("lib.concord")
local physics = require("src.core.physics")
local config = require("src.core.config")

-- Wreck configuration defaults
local LIFETIME = 180  -- 3 minutes decay time
local LOOT_RANGE = 90 -- Distance player must be within to open loot panel
local DRIFT_SPEED = 8 -- Slow drift velocity

--------------------------------------------------------------------------------
-- LEGACY LIST (computed from ECS world)
--------------------------------------------------------------------------------

local function isBodyDestroyed(body)
    if not body then
        return true
    end
    local ok, destroyed = pcall(function()
        return body:isDestroyed()
    end)
    if not ok then
        return true
    end
    return destroyed
end

local function getWreckCargo(w)
    if not w then
        return nil
    end
    if w.cargo then
        return w.cargo
    end
    if w.loot and w.loot.cargo then
        return w.loot.cargo
    end
    return nil
end

--- Get all active wreck entities from the ECS world.
function wreck.getList()
    local all = ecsWorld:query({ "wreck", "position" }) or {}
    local wrecks = {}

    for _, e in ipairs(all) do
        if not e._removed and not e.removed then
            -- Provide legacy fields so older UI code can interact with wreck
            -- cargo without needing to know about ECS components.
            if not e.cargo and e.loot and e.loot.cargo then
                e.cargo = e.loot.cargo
            end
            if e.coins == nil and e.loot and e.loot.coins ~= nil then
                e.coins = e.loot.coins
            end
            table.insert(wrecks, e)
        end
    end

    return wrecks
end

-- Legacy .list property
setmetatable(wreck, {
    __index = function(t, k)
        if k == "list" then
            return wreck.getList()
        end
        return rawget(t, k)
    end
})

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
    local e = Concord.entity(ecsWorld):assemble(assemblages.wreck, x, y, cargo, coins)
    if not e then
        return nil
    end

    -- Backward-compatible fields used by HUD code.
    if e.loot and e.loot.cargo then
        e.cargo = e.loot.cargo
    end
    e.coins = coins or 0

    -- Keep an age counter for fade-out and UI consistency.
    e.age = 0
    if not e.lifetimeTotal then
        e.lifetimeTotal = LIFETIME
    end

    return e
end

--------------------------------------------------------------------------------
-- UPDATE
--------------------------------------------------------------------------------

--- Update all active wrecks
--- @param dt number Delta time
--- @param world table World bounds (optional)
function wreck.update(dt, world)
    local wrecks = wreck.getList()

    for i = #wrecks, 1, -1 do
        local w = wrecks[i]

        -- Age tracking (purely for visuals)
        w.age = (w.age or 0) + dt

        -- Lifetime countdown (authoritative expiry)
        if w.lifetime and w.lifetime.remaining then
            w.lifetime.remaining = w.lifetime.remaining - dt
            if w.lifetime.remaining <= 0 then
                wreck.remove(w)
                goto continue
            end
        end

        -- Rotate
        if w.rotation and w.rotationSpeed then
            w.rotation.angle = w.rotation.angle + w.rotationSpeed * dt
            -- Wrecks rotate freely (debris-like). Keep targetAngle in sync so
            -- the generic ECS RotationSystem does not try to "correct" this
            -- rotation back to an old target.
            w.rotation.targetAngle = w.rotation.angle
        end

        -- Drift
        if w.position then
            local vx = w.vx
            local vy = w.vy

            -- Legacy/ECS compatibility: allow drift stored as velocity component.
            if (vx == nil or vy == nil) and w.velocity then
                vx = w.velocity.vx
                vy = w.velocity.vy
            end

            vx = vx or 0
            vy = vy or 0

            w.position.x = w.position.x + vx * dt
            w.position.y = w.position.y + vy * dt

            -- Clamp to world bounds if provided
            if world and world.clampToWorld then
                local radius = 0
                if w.collisionRadius then
                    radius = type(w.collisionRadius) == "table" and w.collisionRadius.radius or w.collisionRadius
                elseif w.size then
                    radius = type(w.size) == "table" and w.size.value or w.size
                end

                w.position.x, w.position.y = world.clampToWorld(w.position.x, w.position.y, radius)
            end
        end

        -- Sync physics body
        if w.physics and w.physics.body then
            if isBodyDestroyed(w.physics.body) then
                w.physics.body = nil
            elseif w.position then
                pcall(function()
                    w.physics.body:setPosition(w.position.x, w.position.y)
                end)
            end
        end

        ::continue::
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

    for _, w in ipairs(wreck.getList()) do
        local wx = w.position and w.position.x or w.x
        local wy = w.position and w.position.y or w.y
        if not wx or not wy then
            goto continue
        end

        local dx = wx - x
        local dy = wy - y
        local distSq = dx * dx + dy * dy

        local baseRadius = 0
        if w.collisionRadius then
            baseRadius = type(w.collisionRadius) == "table" and w.collisionRadius.radius or w.collisionRadius
        elseif w.size then
            baseRadius = type(w.size) == "table" and w.size.value or w.size
        else
            baseRadius = 24
        end

        local hitRadius = baseRadius + padding
        local hitRadiusSq = hitRadius * hitRadius

        if distSq <= hitRadiusSq then
            if not closestDistSq or distSq < closestDistSq then
                closestDistSq = distSq
                closestWreck = w
            end
        end

        ::continue::
    end

    return closestWreck
end

--- Get the loot interaction range
--- @return number The range within which player can open loot panel
function wreck.getLootRange()
    return LOOT_RANGE
end

--- Check if a wreck is empty (no cargo). Coins are awarded on kill and
--- are no longer considered part of loot, so emptiness only cares about
--- item slots.
--- @param w table The wreck entity
--- @return boolean True if wreck has no loot
function wreck.isEmpty(w)
    if not w then return true end
    local cargo = getWreckCargo(w)
    if cargo then
        for _, slot in pairs(cargo) do
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
    if not w then
        return false
    end

    -- ECS-backed wreck entity
    if w.destroy and type(w.destroy) == "function" then
        w._removed = true

        -- IMPORTANT:
        -- Do NOT destroy the physics body here. The ECS CleanupSystem already
        -- destroys any physics body during the removal pass.
        -- Destroying it twice can crash Box2D.
        if w.physics and w.physics.body and isBodyDestroyed(w.physics.body) then
            w.physics.body = nil
        end

        -- Prefer ECS cleanup pass; the entity will be destroyed next frame.
        if w.give and not w.removed then
            w:give("removed")
        end

        return true
    end

    -- Legacy fallback (should not normally be reached after ECS migration)
    if wreck.list then
        for i = #wreck.list, 1, -1 do
            if wreck.list[i] == w then
                table.remove(wreck.list, i)
                return true
            end
        end
    end

    return false
end

--------------------------------------------------------------------------------
-- DRAWING
--------------------------------------------------------------------------------

--- Draw all wrecks
function wreck.draw()
    for _, w in ipairs(wreck.getList()) do
        local wx = w.position and w.position.x or w.x
        local wy = w.position and w.position.y or w.y
        if not wx or not wy then
            goto continue
        end

        local angle = 0
        if w.rotation and w.rotation.angle then
            angle = w.rotation.angle
        else
            angle = w.angle or 0
        end

        local size = 24
        if w.size then
            size = type(w.size) == "table" and w.size.value or w.size
        end

        local lifetimeTotal = w.lifetimeTotal or LIFETIME
        local age = w.age or 0
        if w.lifetime and w.lifetime.remaining and lifetimeTotal > 0 then
            age = lifetimeTotal - w.lifetime.remaining
            if age < 0 then
                age = 0
            end
        end

        love.graphics.push()
        love.graphics.translate(wx, wy)
        love.graphics.rotate(angle)

        -- Fade out in last 20% of life
        local fadeStart = lifetimeTotal * 0.8
        local alpha = 1.0
        if age > fadeStart and lifetimeTotal > fadeStart then
            alpha = 1.0 - ((age - fadeStart) / (lifetimeTotal - fadeStart))
        end

        -- Draw cargo container shape (crate/casing)
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

        ::continue::
    end
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

--- Clear all wrecks
function wreck.clear()
    local wrecks = wreck.getList()
    for i = #wrecks, 1, -1 do
        wreck.remove(wrecks[i])
    end
end

return wreck
