--------------------------------------------------------------------------------
-- COLLISION DAMAGE
-- Damage application, XP/token rewards, resource drops, and visual effects
--------------------------------------------------------------------------------

local baseColors = require("src.core.colors")
local floatingText = require("src.entities.floating_text")
local projectileShards = require("src.entities.projectile_shards")
local shieldImpactFx = require("src.entities.shield_impact_fx")
local physics = require("src.core.physics")
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
