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

    -- Spawn loot wreck for ships.
    --
    -- Loot is data-driven via enemy definitions. We keep the drop chance on the
    -- loot component (or resolve it from enemyDef) so this system does not
    -- depend on any legacy collision reward code.
    if entity.ship and entity.loot and entity.position then
        local chance = nil
        if entity.loot and entity.loot.dropChance ~= nil then
            chance = entity.loot.dropChance
        elseif entity.enemyDef and entity.enemyDef.rewards and entity.enemyDef.rewards.loot then
            chance = entity.enemyDef.rewards.loot.dropChance
        end

        chance = clampDropChance(chance)

        if chance and chance > 0 and math.random() < chance then
            world:emit("spawnWreck",
                entity.position.x,
                entity.position.y,
                entity.loot.cargo,
                entity.loot.coins)
        end
    end

    -- Spawn explosion VFX
    if entity.position then
        local radius = entity.collisionRadius and entity.collisionRadius.radius or 20
        world:emit("spawnExplosion",
            entity.position.x,
            entity.position.y,
            (entity.faction and entity.faction.name) or "neutral",
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
