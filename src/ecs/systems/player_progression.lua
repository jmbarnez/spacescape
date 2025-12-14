--------------------------------------------------------------------------------
-- PLAYER PROGRESSION SYSTEM (ECS)
-- Owns XP/level progression + currency/tokens for the player.
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local config = require("src.core.config")

local PlayerProgressionSystem = Concord.system({})

local function isNumber(n)
    return type(n) == "number" and n == n
end

local function recalcXpProgress(exp)
    local base = (config.player and config.player.xpBase) or 100
    local growth = (config.player and config.player.xpGrowth) or 0

    local level = exp.level or 1
    local xp = exp.xp or exp.current or 0

    local xpToNext = base + growth * (level - 1)
    if xpToNext <= 0 then
        xpToNext = 1
    end

    exp.xpToNext = xpToNext
    exp.xpRatio = math.max(0, math.min(1, xp / xpToNext))
end

local function addExperience(exp, amount)
    if not amount or amount <= 0 then
        return false
    end

    exp.totalXp = (exp.totalXp or 0) + amount

    exp.xp = (exp.xp or exp.current or 0) + amount
    exp.current = exp.xp

    local leveledUp = false

    while true do
        local base = (config.player and config.player.xpBase) or 100
        local growth = (config.player and config.player.xpGrowth) or 0
        local level = exp.level or 1

        local xpToNext = base + growth * (level - 1)
        if xpToNext <= 0 then
            xpToNext = 1
        end

        if exp.xp >= xpToNext then
            exp.xp = 0
            exp.current = 0
            exp.level = level + 1
            leveledUp = true
        else
            break
        end
    end

    recalcXpProgress(exp)
    return leveledUp
end

local function addCurrency(currency, amount)
    if not amount or amount <= 0 then
        return 0
    end

    currency.tokens = (currency.tokens or 0) + amount
    return amount
end

local function ensurePlayerProgressEntity(world)
    if not world or not world.query then
        return nil
    end

    local players = world:query({ "playerControlled" }) or {}

    local chosen = nil
    for i = 1, #players do
        local p = players[i]
        if p and (p.experience or p.currency) then
            chosen = p
            break
        end
    end

    chosen = chosen or players[1] or nil

    if chosen then
        if not chosen.experience then
            chosen:give("experience", 0, 1, 0)
        end
        if not chosen.currency then
            chosen:give("currency", 0)
        end
        if not chosen.position then
            chosen:give("position", 0, 0)
        end
        return chosen
    end

    local player = Concord.entity(world)
    player:give("playerControlled")
    player:give("position", 0, 0)
    player:give("experience", 0, 1, 0)
    player:give("currency", 0)

    return player
end

function PlayerProgressionSystem:ensurePlayerProgress()
    local world = self:getWorld()
    ensurePlayerProgressEntity(world)
end

function PlayerProgressionSystem:prePhysics(dt, playerProxy)
    local world = self:getWorld()
    local player = ensurePlayerProgressEntity(world)
    if not player then
        return
    end

    if playerProxy and playerProxy.position and player.position then
        player.position.x = playerProxy.position.x
        player.position.y = playerProxy.position.y
    end

    if player.experience then
        -- Keep derived fields fresh even if other systems mutate experience.
        player.experience.xp = player.experience.xp or player.experience.current or 0
        player.experience.current = player.experience.xp
        recalcXpProgress(player.experience)
    end
end

function PlayerProgressionSystem:update(dt, playerProxy)
    self:prePhysics(dt, playerProxy)
end

function PlayerProgressionSystem:awardXp(amount)
    if not isNumber(amount) or amount <= 0 then
        return
    end

    local world = self:getWorld()
    local player = ensurePlayerProgressEntity(world)
    if not player or not player.experience then
        return
    end

    addExperience(player.experience, amount)
end

function PlayerProgressionSystem:awardTokens(amount)
    if not isNumber(amount) or amount <= 0 then
        return
    end

    local world = self:getWorld()
    local player = ensurePlayerProgressEntity(world)
    if not player or not player.currency then
        return
    end

    addCurrency(player.currency, amount)
end

function PlayerProgressionSystem:resetPlayerProgress()
    local world = self:getWorld()
    local player = ensurePlayerProgressEntity(world)
    if not player then
        return
    end

    if player.experience then
        player.experience.level = 1
        player.experience.xp = 0
        player.experience.current = 0
        player.experience.totalXp = 0
        recalcXpProgress(player.experience)
    end

    if player.currency then
        player.currency.tokens = 0
    end
end

return PlayerProgressionSystem
