local enemyModule = require("src.entities.enemy")
local asteroidModule = require("src.entities.asteroid")
local projectileModule = require("src.entities.projectile")
local wreckModule = require("src.entities.wreck")
local config = require("src.core.config")

local combat = {}

local targetEnemy = nil
local fireTimer = 0
local fireInterval = config.combat.fireInterval
local lockTarget = nil
local lockTimer = 0
local lockDuration = config.combat.lockDuration

-- Helper to get current enemy/asteroid lists dynamically
local function getEnemies()
    return enemyModule.getList and enemyModule.getList() or enemyModule.list or {}
end

local function getAsteroids()
    return asteroidModule.getList and asteroidModule.getList() or asteroidModule.list or {}
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
    return wreckModule.findAtPosition(x, y, maxRadius)
end

--- Public function to check for wreck at position (used by input system)
function combat.findWreckAtPosition(x, y, maxRadius)
    return findWreckAtPosition(x, y, maxRadius)
end

function combat.updateAutoShoot(dt, player)
    -- Validate lock and active target; if either becomes invalid we clear the
    -- reference so we never try to fire at destroyed entities.
    if lockTarget and not isEnemyValid(lockTarget) then
        lockTarget = nil
        lockTimer = 0
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
    if player.weapon and player.weapon.fireInterval then
        interval = player.weapon.fireInterval
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
    if lockTarget and not targetEnemy then
        lockTimer = lockTimer + dt

        if lockDuration > 0 and lockTimer >= lockDuration then
            lockTimer = lockDuration
            targetEnemy = lockTarget

            -- Auto-fire a shot as soon as the player is fully locked-on,
            -- unless the weapon is still on cooldown.
            if isEnemyValid(targetEnemy) and fireTimer >= interval then
                fireTimer = 0
                local tx = targetEnemy.position and targetEnemy.position.x or targetEnemy.x
                local ty = targetEnemy.position and targetEnemy.position.y or targetEnemy.y
                projectileModule.spawn(player, tx, ty, targetEnemy)
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
    if fireTimer >= interval then
        fireTimer = 0
        local tx = targetEnemy.position and targetEnemy.position.x or targetEnemy.x
        local ty = targetEnemy.position and targetEnemy.position.y or targetEnemy.y
        projectileModule.spawn(player, tx, ty, targetEnemy)
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
        end
    else
        -- Clearing the current target/lock should also leave the cooldown
        -- untouched; the timer is driven solely by time since the last
        -- projectile was fired.
        targetEnemy = nil
        lockTarget = nil
        lockTimer = 0
    end
end

function combat.getTargetEnemy()
    if isEnemyValid(targetEnemy) then
        return targetEnemy
    end

    return nil
end

function combat.getLockStatus()
    if lockTarget and isEnemyValid(lockTarget) then
        return lockTarget, lockTimer, lockDuration, targetEnemy
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
    if lockTarget and isEnemyValid(lockTarget) and (not targetEnemy or lockTarget ~= targetEnemy) then
        currentTarget = lockTarget
        if lockDuration and lockDuration > 0 then
            progress = math.max(0, math.min(1, lockTimer / lockDuration))
            isLocking = true
        end
    elseif targetEnemy and isEnemyValid(targetEnemy) then
        currentTarget = targetEnemy
    end

    -- Determine locked state
    if currentTarget and not isLocking and targetEnemy and currentTarget == targetEnemy then
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

    if player and player.weapon and player.weapon.fireInterval then
        interval = player.weapon.fireInterval
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

function combat.reset()
    targetEnemy = nil
    fireTimer = 0
    lockTarget = nil
    lockTimer = 0
end

return combat
