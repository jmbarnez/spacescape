--------------------------------------------------------------------------------
-- REWARD SYSTEM (ECS)
-- Handles XP, tokens, and loot spawning on entity death
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local config = require("src.core.config")

local RewardSystem = Concord.system({
    -- Entities that give rewards when killed
    rewardable = { "xpReward" },
})

--- Handle entity death - award XP and tokens to killer
--- Called via world:emit("onDeath", entity, killerFaction)
function RewardSystem:onDeath(entity, killerFaction)
    -- Only award to player faction
    if killerFaction ~= "player" then return end

    local world = self:getWorld()

    -- Award XP
    if entity.xpReward and entity.xpReward.amount > 0 then
        world:emit("awardXp", entity.xpReward.amount)
    end

    -- Award tokens
    if entity.tokenReward and entity.tokenReward.amount > 0 then
        world:emit("awardTokens", entity.tokenReward.amount)
    end

    -- Spawn resource drops
    if entity.resourceYield and entity.position then
        world:emit("spawnResources",
            entity.position.x,
            entity.position.y,
            entity.resourceYield.resources)
    end

    -- Spawn loot wreck for ships
    if entity.ship and entity.loot and entity.position then
        world:emit("spawnWreck",
            entity.position.x,
            entity.position.y,
            entity.loot.cargo,
            entity.loot.coins)
    end

    -- Spawn explosion VFX
    if entity.position then
        local radius = entity.collisionRadius and entity.collisionRadius.radius or 20
        world:emit("spawnExplosion",
            entity.position.x,
            entity.position.y,
            entity.faction and entity.faction.name or "enemy",
            radius)
    end

    -- Trigger Respawn
    if entity.respawnOnDeath then
        local delay = entity.respawnOnDeath.delay
        local def = entity.respawnOnDeath.enemyDef
        local x = entity.spawnPosition and entity.spawnPosition.x or entity.position.x
        local y = entity.spawnPosition and entity.spawnPosition.y or entity.position.y

        local timer = Concord.entity(world)
        timer:give("respawnTimer", delay, def, x, y)
    end

    -- Mark for removal
    entity:give("removed")
end

return RewardSystem
