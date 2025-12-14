--------------------------------------------------------------------------------
-- COLLISION DAMAGE
-- Damage application, XP/token rewards, resource drops, and visual effects
--------------------------------------------------------------------------------

local baseColors = require("src.core.colors")
local config = require("src.core.config")
local floatingText = require("src.entities.floating_text")
local playerModule = require("src.entities.player")
local worldRef = require("src.ecs.world_ref")
local projectileShards = require("src.entities.projectile_shards")
local shieldImpactFx = require("src.entities.shield_impact_fx")
local physics = require("src.core.physics")
local itemModule = require("src.entities.item")
local wreckModule = require("src.entities.wreck")
local utils = require("src.systems.collision.utils")

local damage = {}

--------------------------------------------------------------------------------
-- DAMAGE APPLICATION
--------------------------------------------------------------------------------

--- Apply damage to an entity and check for death
--- @param entity table The entity to damage
--- @param damageAmount number Amount of damage
--- @return boolean True if entity died, shieldDamage, hullDamage
function damage.applyDamage(entity, damageAmount)
    if not entity or not damageAmount or damageAmount <= 0 then
        return false, 0, 0
    end

    local shieldDamage = 0
    local hullDamage = 0

    local shield = utils.getShield(entity)
    if shield > 0 then
        if damageAmount <= shield then
            utils.setShield(entity, shield - damageAmount)
            shieldDamage = damageAmount
            return false, shieldDamage, hullDamage
        else
            utils.setShield(entity, 0)
            shieldDamage = shield
            damageAmount = damageAmount - shield
        end
    end

    local health = utils.getHealth(entity)
    utils.setHealth(entity, health - damageAmount)
    hullDamage = damageAmount
    return utils.getHealth(entity) <= 0, shieldDamage, hullDamage
end

--------------------------------------------------------------------------------
-- FLOATING TEXT
--------------------------------------------------------------------------------

--- Spawn floating damage text above an entity
--- @param amount number Damage amount to display
--- @param x number X position
--- @param y number Y position
--- @param radius number Entity radius (text appears above)
--- @param color table RGB color for the text (hull/shield)
--- @param options table Optional settings (duration, etc.)
function damage.spawnDamageText(amount, x, y, radius, color, options)
    local textY = y - radius - 10

    -- Configure floating text to use colored text only (no background box)
    options = options or {}
    if color then
        options.textColor = color
    end
    -- Transparent background so only glyphs are visible
    options.bgColor = options.bgColor or { 0, 0, 0, 0 }

    floatingText.spawn(tostring(math.floor(amount + 0.5)), x, textY, nil, options)
end

--------------------------------------------------------------------------------
-- XP AND TOKEN REWARDS
--------------------------------------------------------------------------------

--- Award XP and tokens to the player on kill
--- @param xp number XP amount
--- @param tokens number Token amount
function damage.awardXpAndTokensOnKill(xp, tokens)
    local playerState = playerModule and playerModule.state or nil
    if not playerState then
        return
    end

    local ecsWorld = worldRef.get()

    if ecsWorld and ecsWorld.emit and xp and xp > 0 then
        ecsWorld:emit("awardXp", xp)
        local value = math.floor(xp + 0.5)
        local baseText = "XP"
        floatingText.spawn(baseText, playerState.x, playerState.y - 22, nil, {
            duration = 1.1,
            riseSpeed = 26,
            scale = 0.8,
            alpha = 1.0,
            bgColor = { 0, 0, 0, 0 },
            textColor = baseColors.health or baseColors.white,
            stackKey = "xp_total",
            stackValueIncrement = value,
            stackBaseText = baseText,
            iconPreset = "xp_only",
        })
    end

    if ecsWorld and ecsWorld.emit and tokens and tokens > 0 then
        ecsWorld:emit("awardTokens", tokens)
        local value = math.floor(tokens + 0.5)
        local baseText = "Tokens"
        floatingText.spawn(baseText, playerState.x, playerState.y - 8, nil, {
            duration = 1.1,
            riseSpeed = 26,
            scale = 0.8,
            alpha = 1.0,
            bgColor = { 0, 0, 0, 0 },
            textColor = baseColors.uiText or baseColors.white,
            stackKey = "tokens_total",
            stackValueIncrement = value,
            stackBaseText = baseText,
            iconPreset = "token_only",
        })
    end
end

--------------------------------------------------------------------------------
-- RESOURCE YIELD COMPUTATION
--------------------------------------------------------------------------------

--- Compute a simple resource yield table for an asteroid based on its
--- procedural stone/ice/mithril composition and size.
--- @param asteroid table The asteroid entity
--- @param radius number Approximate asteroid radius (for scaling yield)
--- @return table Resource amounts { stone = n, ice = n, mithril = n }
function damage.computeAsteroidResourceYield(asteroid, radius)
    -- Handle ECS size component (table with .value) or legacy number
    local size = radius or 20
    if asteroid and asteroid.size then
        size = type(asteroid.size) == "table" and asteroid.size.value or asteroid.size
    end
    local baseChunks = math.max(1, math.floor((size or 20) / 10))
    local data = asteroid and asteroid.data
    local comp = data and data.composition

    if not comp then
        return { stone = baseChunks }
    end

    local stone = comp.stone or 0
    local ice = comp.ice or 0
    local mithril = comp.mithril or 0
    local total = stone + ice + mithril
    if total <= 0 then
        return { stone = baseChunks }
    end

    local scale = baseChunks / total
    local stoneAmt = math.max(0, math.floor(stone * scale + 0.5))
    local iceAmt = math.max(0, math.floor(ice * scale + 0.5))
    local mithrilAmt = math.max(0, math.floor(mithril * scale + 0.5))

    -- Ensure at least one chunk of something so every destroyed asteroid feels
    -- tangibly rewarding.
    if stoneAmt + iceAmt + mithrilAmt <= 0 then
        stoneAmt = baseChunks
    end

    return {
        stone = stoneAmt,
        ice = iceAmt,
        mithril = mithrilAmt,
    }
end

--- Enemies do not drop raw resource chunks on death.
---
--- Enemy kills are rewarded via XP/tokens and (optionally) a loot container
--- wreck. Asteroids are the source of raw materials like stone.
--- @param enemy table The enemy entity
--- @param radius number Approximate enemy radius
--- @return table Resource amounts (always empty)
function damage.computeEnemyResourceYield(enemy, radius)
    return {}
end

--- Compute cargo contents for an enemy wreck
--- @param enemy table The enemy entity
--- @param radius number Approximate enemy radius
--- @return table Cargo slots, number Coins (always 0; tokens are awarded on kill)
function damage.computeEnemyWreckCargo(enemy, radius)
    local r = radius or utils.getBoundingRadius(enemy)
    local sizeFactor = math.max(1, math.floor((r or 12) / 10))

    -- Build cargo using slot-based format matching player cargo
    local cargo = {}
    local slotIndex = 1

    -- Scrap metal amount based on enemy size
    local scrapAmount = sizeFactor + math.random(1, 3)
    cargo[slotIndex] = {
        id = "scrap",
        quantity = scrapAmount,
    }
    slotIndex = slotIndex + 1

    -- Coins/tokens are now granted directly on kill via
    -- damage.awardXpAndTokensOnKill, so wrecks no longer carry a separate
    -- coin payout. We keep the second return value for API compatibility.
    local coinAmount = 0

    return cargo, coinAmount
end

local function clampDropChance(value)
    if value == nil then
        return nil
    end

    local chance = tonumber(value)
    if not chance then
        return nil
    end

    -- Support either 0..1 or 0..100 style values.
    if chance > 1 then
        chance = chance / 100
    end

    if chance < 0 then
        chance = 0
    elseif chance > 1 then
        chance = 1
    end

    return chance
end

--- Resolve the chance that an enemy should spawn a loot container (wreck).
---
--- This is data-driven: enemy definitions can set:
---   def.rewards.loot.dropChance
---
--- @param enemy table|nil The enemy entity
--- @return number chance (0..1)
function damage.getEnemyLootContainerChance(enemy)
    local def = enemy and (enemy.enemyDef or (enemy.respawnOnDeath and enemy.respawnOnDeath.enemyDef)) or nil
    local loot = def and def.rewards and def.rewards.loot or nil
    local chance = loot and loot.dropChance or nil

    chance = clampDropChance(chance)

    -- Default to 0 so enemy definitions must explicitly opt in to dropping a
    -- loot container (wreck).
    if chance == nil then
        chance = 0
    end

    return chance
end

--------------------------------------------------------------------------------
-- WRECK SPAWNING
--------------------------------------------------------------------------------

--- Spawn a wreck with cargo at the given position from a destroyed enemy
--- @param x number World X position
--- @param y number World Y position
--- @param enemy table The enemy entity that was destroyed
--- @param radius number Approximate enemy radius
function damage.spawnEnemyWreck(x, y, enemy, radius)
    local chance = damage.getEnemyLootContainerChance(enemy)
    if not chance or chance <= 0 then
        return nil
    end
    if chance < 1 and math.random() > chance then
        return nil
    end

    local cargo, coins = damage.computeEnemyWreckCargo(enemy, radius)
    return wreckModule.spawn(x, y, cargo, coins)
end

--------------------------------------------------------------------------------
-- RESOURCE SPAWNING
--------------------------------------------------------------------------------

--- Spawn a bursting cluster of resource chunks at the given position.
--- The total resources for each type are distributed across a handful of
--- pickups so that collection still feels like a satisfying spray.
--- @param x number World X position
--- @param y number World Y position
--- @param resources table Map resourceType -> totalAmount
function damage.spawnResourceChunksAt(x, y, resources)
    if not itemModule or not itemModule.spawnResourceChunk then
        return
    end
    if not resources then
        return
    end

    for resourceType, totalAmount in pairs(resources) do
        local total = math.floor(totalAmount or 0)
        if total > 0 then
            -- Split into a small, visually pleasing number of chunks.
            local minChunks = 2
            local maxChunks = 5
            local chunkCount = math.min(maxChunks, math.max(minChunks, math.floor(total / 2)))
            if chunkCount <= 0 then
                chunkCount = 1
            end

            local baseAmount = math.floor(total / chunkCount)
            if baseAmount < 1 then
                baseAmount = 1
            end
            local remainder = total - baseAmount * chunkCount

            for i = 1, chunkCount do
                local amount = baseAmount
                if remainder > 0 then
                    amount = amount + 1
                    remainder = remainder - 1
                end

                local angle = math.random() * math.pi * 2
                local spawnRadius = (math.random() * 14) + 6
                local sx = x + math.cos(angle) * spawnRadius
                local sy = y + math.sin(angle) * spawnRadius

                itemModule.spawnResourceChunk(sx, sy, resourceType, amount)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- VISUAL EFFECTS
--------------------------------------------------------------------------------

--- Spawn projectile shard particles on impact
--- @param projectile table The projectile entity
--- @param target table The target entity
--- @param contactX number Contact point X
--- @param contactY number Contact point Y
--- @param radius number Target radius
--- @param countScale number Scale factor for shard count
--- @param currentColors table Current color palette
function damage.spawnProjectileShards(projectile, target, contactX, contactY, radius, countScale, currentColors)
    if not projectileShards then
        return
    end

    local px = utils.getX(projectile)
    local py = utils.getY(projectile)
    local tx = target and utils.getX(target) or contactX or px
    local ty = target and utils.getY(target) or contactY or py
    local ix = contactX or tx or px
    local iy = contactY or ty or py

    if not ix or not iy or not px or not py then
        return
    end

    local pvx = utils.getVX(projectile) or 0
    local pvy = utils.getVY(projectile) or 0
    local projSpeed = math.sqrt(pvx * pvx + pvy * pvy)

    local dirX = 0
    local dirY = 0

    if target and tx and ty and ix and iy then
        dirX = ix - tx
        dirY = iy - ty
    end

    if (dirX == 0 and dirY == 0) and projSpeed and projSpeed > 0 then
        dirX = pvx
        dirY = pvy
    end

    local angle = 0
    if projectile.rotation then
        angle = projectile.rotation.angle
    elseif projectile.angle then
        angle = projectile.angle
    end
    if dirX == 0 and dirY == 0 then
        dirX, dirY = math.cos(angle), math.sin(angle)
    end

    local baseSpeed = projSpeed or 0
    if not baseSpeed or baseSpeed <= 0 then
        baseSpeed = utils.getDamage(projectile) or (physics.constants and physics.constants.projectileSpeed) or 350
        if projectile.projectileData and projectile.projectileData.speed then
            baseSpeed = projectile.projectileData.speed
        elseif projectile.speed then
            baseSpeed = projectile.speed
        end
    end

    baseSpeed = baseSpeed * 0.85

    local projectileConfig = nil

    if projectile.projectileVisual and projectile.projectileVisual.config then
        projectileConfig = projectile.projectileVisual.config
    elseif projectile.projectileData and projectile.projectileData.weapon and projectile.projectileData.weapon.projectile then
        projectileConfig = projectile.projectileData.weapon.projectile
    else
        projectileConfig = projectile.projectileConfig
        if not projectileConfig and projectile.weapon then
            local weaponData = projectile.weapon
            if type(weaponData) == "table" and weaponData.data then
                weaponData = weaponData.data
            end
            if weaponData and weaponData.projectile then
                projectileConfig = weaponData.projectile
            end
        end
    end

    local projectileColor = (projectileConfig and projectileConfig.color)
        or (currentColors and currentColors.projectile)
        or baseColors.projectile
        or baseColors.white

    local projectileLength = projectileConfig and projectileConfig.length or nil
    local projectileWidth = projectileConfig and projectileConfig.width or nil

    local projectileRadius = 4
    if projectileWidth and projectileWidth > 0 then
        projectileRadius = projectileWidth * 0.5
    elseif projectileLength and projectileLength > 0 then
        projectileRadius = math.max(projectileRadius, projectileLength * 0.25)
    end

    local baseCount = math.max(2, math.min(5, math.floor(projectileRadius / 2) + 2))
    if countScale and countScale > 0 then
        baseCount = math.max(2, math.floor(baseCount * countScale))
    end

    projectileShards.spawn(ix, iy, dirX, dirY, baseSpeed, baseCount, projectileColor, projectileLength, projectileWidth)
end

--- Spawn shield impact visual effect
--- @param target table The target entity
--- @param projectile table The projectile entity
--- @param contactX number Contact point X
--- @param contactY number Contact point Y
--- @param radius number Shield radius
function damage.spawnShieldImpactVisual(target, projectile, contactX, contactY, radius)
    if not shieldImpactFx or not shieldImpactFx.spawn then
        return
    end
    if not target then
        return
    end

    local cx = utils.getX(target) or contactX or (projectile and utils.getX(projectile))
    local cy = utils.getY(target) or contactY or (projectile and utils.getY(projectile))
    local ix = contactX or cx
    local iy = contactY or cy
    local shieldRadius = radius or utils.getBoundingRadius(target)

    if not shieldRadius or shieldRadius <= 0 then
        return
    end
    if not cx or not cy or not ix or not iy then
        return
    end

    local color = baseColors.shieldDamage

    --------------------------------------------------------------------------
    -- Pass the target through to the FX so the shield ring can track the
    -- entity's live position instead of staying behind at the impact point.
    -- This is especially important for the player, who can still drift after
    -- being hit.
    --------------------------------------------------------------------------
    shieldImpactFx.spawn(cx, cy, ix, iy, shieldRadius * 1.15, color, target)
end

return damage
