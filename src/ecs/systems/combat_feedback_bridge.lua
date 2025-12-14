--------------------------------------------------------------------------------
-- COMBAT FEEDBACK BRIDGE SYSTEM (ECS)
--
-- Purpose:
--   Listens to ECS combat + reward events and forwards them into the existing
--   presentation modules (floating text + shield impact shader FX).
--
-- Notes:
--   This keeps gameplay authority (damage, death, rewards) inside ECS, while
--   UI/VFX remains in the current legacy render modules.
--------------------------------------------------------------------------------

local Concord = require("lib.concord")

local colors = require("src.core.colors")
local floatingText = require("src.entities.floating_text")
local shieldImpactFx = require("src.entities.shield_impact_fx")

local CombatFeedbackBridgeSystem = Concord.system({})

local function getPlayerEntity(world)
    if not world or not world.query then
        return nil
    end
    local players = world:query({ "playerControlled", "position" }) or {}
    return players[1]
end

local function getRadius(e)
    if not e then
        return 10
    end

    if e.collisionRadius then
        return e.collisionRadius.radius or 10
    end

    if e.size then
        return e.size.value or 10
    end

    return 10
end

function CombatFeedbackBridgeSystem:onAsteroidBump(ship, impactX, impactY)
    if not (ship and ship.position) then
        return
    end

    if not (shieldImpactFx and shieldImpactFx.spawn) then
        return
    end

    local radius = getRadius(ship)
    local cx = ship.position.x
    local cy = ship.position.y
    local ix = impactX or cx
    local iy = impactY or cy

    shieldImpactFx.spawn(cx, cy, ix, iy, radius * 1.15, colors.shieldDamage, ship)
end

local function spawnDamageText(amount, x, y, radius, color)
    if not amount or amount <= 0 then
        return
    end

    local textY = y - radius - 10

    floatingText.spawn(tostring(math.floor(amount + 0.5)), x, textY, nil, {
        bgColor = { 0, 0, 0, 0 },
        textColor = color,
    })
end

function CombatFeedbackBridgeSystem:onDamage(target, damage, shieldDamage, hullDamage, contactX, contactY)
    if not (target and target.position) then
        return
    end

    local x = target.position.x
    local y = target.position.y
    local radius = getRadius(target)

    if shieldDamage and shieldDamage > 0 then
        spawnDamageText(shieldDamage, x, y, radius, colors.shieldDamage)

        local ix = contactX or x
        local iy = contactY or y
        if shieldImpactFx and shieldImpactFx.spawn then
            shieldImpactFx.spawn(x, y, ix, iy, radius * 1.15, colors.shieldDamage, target)
        end
    end

    if hullDamage and hullDamage > 0 then
        local faction = target.faction and target.faction.name
        local hullColor = (faction == "player") and colors.damagePlayer or colors.damageEnemy
        spawnDamageText(hullDamage, x, y, radius, hullColor)
    end
end

function CombatFeedbackBridgeSystem:awardXp(amount)
    if type(amount) ~= "number" or amount <= 0 then
        return
    end

    local world = self:getWorld()
    local player = getPlayerEntity(world)
    if not (player and player.position) then
        return
    end

    local value = math.floor(amount + 0.5)
    local baseText = "XP"

    floatingText.spawn(baseText, player.position.x, player.position.y - 22, nil, {
        duration = 1.1,
        riseSpeed = 26,
        scale = 0.8,
        alpha = 1.0,
        bgColor = { 0, 0, 0, 0 },
        textColor = colors.health or colors.white,
        stackKey = "xp_total",
        stackValueIncrement = value,
        stackBaseText = baseText,
        iconPreset = "xp_only",
    })
end

function CombatFeedbackBridgeSystem:awardTokens(amount)
    if type(amount) ~= "number" or amount <= 0 then
        return
    end

    local world = self:getWorld()
    local player = getPlayerEntity(world)
    if not (player and player.position) then
        return
    end

    local value = math.floor(amount + 0.5)
    local baseText = "Tokens"

    floatingText.spawn(baseText, player.position.x, player.position.y - 8, nil, {
        duration = 1.1,
        riseSpeed = 26,
        scale = 0.8,
        alpha = 1.0,
        bgColor = { 0, 0, 0, 0 },
        textColor = colors.uiText or colors.white,
        stackKey = "tokens_total",
        stackValueIncrement = value,
        stackBaseText = baseText,
        iconPreset = "token_only",
    })
end

return CombatFeedbackBridgeSystem
