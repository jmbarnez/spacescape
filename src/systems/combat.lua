local config = require("src.core.config")
local ecsWorld = require("src.ecs.world")

local combat = {}

local targetEnemy = nil
local lockedTarget = nil
local fireTimer = 0
local fireInterval = config.combat.fireInterval
local lockTarget = nil
local lockTimer = 0
local lockDuration = config.combat.lockDuration

local function getEntityPosition(e)
    if not e then
        return nil, nil
    end

    if e.position and e.position.x and e.position.y then
        return e.position.x, e.position.y
    end

    return e.x, e.y
end

-- Helper to get current enemy/asteroid lists dynamically
local function getEnemies()
    local ships = ecsWorld:query({ "ship", "faction", "position" }) or {}
    local enemies = {}
    for _, e in ipairs(ships) do
        if e.faction and e.faction.name == "enemy" and not e._removed and not e.removed then
            table.insert(enemies, e)
        end
    end
    return enemies
end

local function getAsteroids()
    local asteroids = ecsWorld:query({ "asteroid", "position" }) or {}
    local out = {}
    for _, a in ipairs(asteroids) do
        if not a._removed and not a.removed then
            out[#out + 1] = a
        end
    end
    return out
end

local function getWrecks()
    local wrecks = ecsWorld:query({ "wreck", "position" }) or {}
    local out = {}
    for _, w in ipairs(wrecks) do
        if not w._removed and not w.removed then
            out[#out + 1] = w
        end
    end
    return out
end

local function isEnemyValid(e)
    if not e then
        return false
    end

    local enemies = getEnemies()
    for i = 1, #enemies do
        if enemies[i] == e then
            return true
        end
    end

    local asteroids = getAsteroids()
    for i = 1, #asteroids do
        if asteroids[i] == e then
            return true
        end
    end

    return false
end

local function isWreckValid(e)
    if not e then
        return false
    end

    local wrecks = getWrecks()
    for i = 1, #wrecks do
        if wrecks[i] == e then
            return true
        end
    end

    return false
end

local function isLockTargetValid(e)
    return isEnemyValid(e) or isWreckValid(e)
end

local function findEnemyAtPosition(x, y, maxRadius)
    -- NOTE: "maxRadius" here is treated as a *padding* value around the
    --       natural size of the entity. The effective click radius is:
    --          entityRadius + maxRadius
    --       where entityRadius comes from collisionRadius/size. This means
    --       you no longer have to click the exact center of an enemy or
    --       asteroid; clicking anywhere within its visible body (plus a
    --       small buffer) will select it.

    local closestEnemy = nil
    local closestDistSq = nil

    local function considerEntity(e)
        -- Get position from ECS component or legacy property
        local ex = e.position and e.position.x or e.x
        local ey = e.position and e.position.y or e.y
        if not ex or not ey then return end

        local dx = ex - x
        local dy = ey - y
        local distSq = dx * dx + dy * dy

        -- Derive an approximate radius for the entity. This prefers
        -- collisionRadius (physics / hitbox) but falls back to size if
        -- needed. If both are nil/zero we will only use the padding radius.
        local entityRadius = 0
        if e.collisionRadius then
            entityRadius = type(e.collisionRadius) == "table" and e.collisionRadius.radius or e.collisionRadius
        elseif e.size then
            entityRadius = type(e.size) == "table" and e.size.value or e.size
        end

        -- Config-driven padding radius. This is the "selectionRadius" that
        -- input.lua passes in, used as a buffer so you don't have to click
        -- pixel-perfect on small targets.
        local paddingRadius = maxRadius or 0

        -- Effective hit radius for this entity. Large objects (big
        -- asteroids, capital ships) get a correspondingly large clickable
        -- area; tiny objects still get at least the padding radius.
        local hitRadius = entityRadius + paddingRadius
        if hitRadius <= 0 then
            hitRadius = paddingRadius
        end

        if hitRadius > 0 then
            local hitRadiusSq = hitRadius * hitRadius
            if distSq <= hitRadiusSq and (not closestDistSq or distSq < closestDistSq) then
                closestDistSq = distSq
                closestEnemy = e
            end
        end
    end

    for _, e in ipairs(getEnemies()) do
        considerEntity(e)
    end

    for _, a in ipairs(getAsteroids()) do
        considerEntity(a)
    end

    return closestEnemy
end

--- Find a wreck at the given position for loot interaction
--- @param x number World X position
--- @param y number World Y position
--- @param maxRadius number Selection padding radius
--- @return table|nil The wreck at position, or nil
local function findWreckAtPosition(x, y, maxRadius)
    local paddingRadius = maxRadius or 0
    local closest = nil
    local closestDistSq = nil

    local function considerWreck(w)
        if not w then
            return
        end
        local wx = w.position and w.position.x or w.x
        local wy = w.position and w.position.y or w.y
        if not wx or not wy then
            return
        end

        local dx = wx - x
        local dy = wy - y
        local distSq = dx * dx + dy * dy

        local entityRadius = 0
        if w.collisionRadius then
            entityRadius = type(w.collisionRadius) == "table" and w.collisionRadius.radius or w.collisionRadius
        elseif w.size then
            entityRadius = type(w.size) == "table" and w.size.value or w.size
        else
            entityRadius = 24
        end

        local hitRadius = entityRadius + paddingRadius
        if hitRadius <= 0 then
            hitRadius = paddingRadius
        end

        local hitRadiusSq = hitRadius * hitRadius
        if distSq <= hitRadiusSq and (not closestDistSq or distSq < closestDistSq) then
            closestDistSq = distSq
            closest = w
        end
    end

    for _, w in ipairs(getWrecks()) do
        considerWreck(w)
    end

    return closest
end

--- Public function to check for wreck at position (used by input system)
function combat.findWreckAtPosition(x, y, maxRadius)
    return findWreckAtPosition(x, y, maxRadius)
end

function combat.updateAutoShoot(dt, player)
    -- Validate lock and active target; if either becomes invalid we clear the
    -- reference so we never try to fire at destroyed entities.
    if lockTarget and not isLockTargetValid(lockTarget) then
        lockTarget = nil
        lockTimer = 0
    end

    if lockedTarget and not isLockTargetValid(lockedTarget) then
        lockedTarget = nil
    end

    if targetEnemy and not isEnemyValid(targetEnemy) then
        targetEnemy = nil
        -- NOTE: we intentionally do NOT reset fireTimer here so the global
        -- weapon cooldown continues counting from the last shot, even if the
        -- target disappears mid-fight.
    end

    -- Resolve the effective fire interval for the current weapon, including
    -- any attack-speed bonuses the player might have.
    local interval = fireInterval
    if player.weapon then
        -- Handle both direct component fields (ECS) and legacy table data
        interval = player.weapon.fireInterval or (player.weapon.data and player.weapon.data.fireInterval) or interval
    end


    local bonus = player.attackSpeedBonus or 0
    if bonus > 0 then
        interval = interval / (1 + bonus)
    end

    -- Always advance the weapon cooldown timer, even when we do not currently
    -- have a locked target. This allows us to know, at the precise moment a
    -- lock completes, whether the weapon is already off cooldown and can fire
    -- instantly.
    fireTimer = fireTimer + dt

    -- Handle lock-on progression. Once the lock duration is reached we
    -- promote the lock target to the active target and, if the cooldown has
    -- finished, immediately fire the first shot.
    if lockTarget and (not lockedTarget or lockTarget ~= lockedTarget) then
        lockTimer = lockTimer + dt

        if lockDuration > 0 and lockTimer >= lockDuration then
            lockTimer = lockDuration
            lockedTarget = lockTarget

            if isEnemyValid(lockTarget) then
                targetEnemy = lockTarget
            else
                targetEnemy = nil
            end

            -- Auto-fire a shot as soon as the player is fully locked-on,
            -- unless the weapon is still on cooldown.
            if isEnemyValid(targetEnemy) and fireTimer >= interval then
                fireTimer = 0
                local tx, ty = getEntityPosition(targetEnemy)
                if tx and ty then
                    ecsWorld:emit("combat.fire_projectile", player, tx, ty, targetEnemy)
                end
                -- We fired this frame; skip the generic auto-fire logic below
                -- to avoid double shots.
                return
            end
        end
    end

    -- If there is no active target yet, there is nothing left to do this
    -- frame. The cooldown timer will continue to tick in the background.
    if not targetEnemy then
        return
    end

    -- Standard auto-fire loop: once the cooldown reaches the required
    -- interval, fire and reset the timer.
    if isEnemyValid(targetEnemy) and fireTimer >= interval then
        fireTimer = 0
        local tx, ty = getEntityPosition(targetEnemy)
        if tx and ty then
            ecsWorld:emit("combat.fire_projectile", player, tx, ty, targetEnemy)
        end
    end
end

function combat.handleLeftClick(worldX, worldY, selectionRadius)
    local enemy = findEnemyAtPosition(worldX, worldY, selectionRadius)

    if enemy then
        if enemy ~= targetEnemy then
            -- Begin locking onto a new target. We deliberately keep the global
            -- fireTimer intact so that the weapon cooldown carries across
            -- target changes; this lets us fire immediately on lock
            -- completion when the weapon is already ready.
            lockTarget = enemy
            lockTimer = 0
            targetEnemy = nil
            lockedTarget = nil
        end
    else
        -- Clearing the current target/lock should also leave the cooldown
        -- untouched; the timer is driven solely by time since the last
        -- projectile was fired.
        targetEnemy = nil
        lockTarget = nil
        lockTimer = 0
        lockedTarget = nil
    end
end

function combat.lockEntity(entity)
    if not entity then
        return
    end

    lockTarget = entity
    lockTimer = 0
    targetEnemy = nil
    lockedTarget = nil
end

function combat.getTargetEnemy()
    if isEnemyValid(targetEnemy) then
        return targetEnemy
    end

    return nil
end

function combat.getLockStatus()
    if lockTarget and isLockTargetValid(lockTarget) then
        return lockTarget, lockTimer, lockDuration, lockedTarget
    end

    return nil
end

-- Returns the entity that should be considered the "current HUD target",
-- along with lock state flags so UI code can present targeting information.
-- This mirrors the logic used by the world-space lock indicator in
-- states/game_render.lua (drawTargetIndicator).
--
-- Returns:
--   targetEntity or nil,
--   isLocked (boolean),
--   isLocking (boolean),
--   progress (0..1 lock progress)
function combat.getCurrentHudTarget()
    local currentTarget = nil
    local isLocking = false
    local isLocked = false
    local progress = 0

    -- First, resolve which entity we are visually focusing on
    if lockTarget and isLockTargetValid(lockTarget) and (not lockedTarget or lockTarget ~= lockedTarget) then
        currentTarget = lockTarget
        if lockDuration and lockDuration > 0 then
            progress = math.max(0, math.min(1, lockTimer / lockDuration))
            isLocking = true
        end
    elseif lockedTarget and isLockTargetValid(lockedTarget) then
        currentTarget = lockedTarget
    end

    -- Determine locked state
    if currentTarget and not isLocking and lockedTarget and currentTarget == lockedTarget then
        isLocked = true
        progress = 1
    end

    return currentTarget, isLocked, isLocking, progress
end

-- Returns the current primary weapon cooldown state so HUD code can render a
-- simple progress bar. This mirrors the interval logic used in
-- updateAutoShoot(), but is read-only and side-effect free.
--
-- Returns:
--   progress  : 0..1, how "ready" the weapon is (0 = just fired, 1 = fully ready)
--   remaining : time relative to the weapon being ready, in seconds.
--               > 0  : seconds left until the weapon is ready (still cooling)
--               <= 0 : seconds since the weapon became ready (idle/ready time)
--   interval  : the effective cooldown duration in seconds for the current weapon
function combat.getWeaponCooldownState(player)
    -- Derive the same effective interval that updateAutoShoot() uses, taking
    -- the base config, the equipped weapon, and any temporary attack-speed
    -- bonuses into account.
    local interval = fireInterval

    if player and player.weapon then
        interval = player.weapon.fireInterval or (player.weapon.data and player.weapon.data.fireInterval) or interval
    end


    local bonus = 0
    if player and player.attackSpeedBonus then
        bonus = player.attackSpeedBonus
    end

    if bonus > 0 then
        interval = interval / (1 + bonus)
    end

    -- A non-positive interval would mean "no cooldown"; treat this as always
    -- ready so the HUD does not try to draw anything misleading.
    if not interval or interval <= 0 then
        return 1, 0, 0
    end

    -- fireTimer measures time since the last projectile was fired. Clamp it to
    -- the interval so we always hand 0..1 to the UI for progress, but keep the
    -- raw timing for the HUD so it can fade the bar out after a short period
    -- of inactivity.
    local clampedTimer = math.max(0, math.min(fireTimer, interval))
    local progress = clampedTimer / interval
    -- Remaining is intentionally *not* clamped at 0 here: once the weapon is
    -- ready, this value becomes negative and effectively represents "time
    -- since ready" so HUD code can implement an idle fade-out.
    local remaining = interval - fireTimer

    return progress, remaining, interval
end

-- Instantly fire one or more basic shots at the current target. Used by
-- instant-cast abilities such as the Q extra-shot without applying any
-- timed buff to the player.
function combat.castExtraShot(player, extraShots)
    if not player then
        return
    end

    extraShots = extraShots or 1
    if extraShots <= 0 then
        return
    end

    if not targetEnemy or not isEnemyValid(targetEnemy) then
        return
    end

    local tx, ty = getEntityPosition(targetEnemy)
    if not tx or not ty then
        return
    end

    -- Treat this as a normal shot for cooldown purposes so the global
    -- fire rate remains consistent after the extra attack.
    fireTimer = 0

    for i = 1, extraShots do
        ecsWorld:emit("combat.fire_projectile", player, tx, ty, targetEnemy)
    end
end

function combat.reset()
    targetEnemy = nil
    fireTimer = 0
    lockTarget = nil
    lockTimer = 0
    lockedTarget = nil
end

return combat
