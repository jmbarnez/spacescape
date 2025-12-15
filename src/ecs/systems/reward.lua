--------------------------------------------------------------------------------
-- REWARD SYSTEM (ECS)
-- Handles XP, tokens, and loot spawning on entity death
--------------------------------------------------------------------------------

local Concord = require("lib.concord")
local config = require("src.core.config")

local colors = require("src.core.colors")
local explosionFx = require("src.entities.explosion_fx")

local RewardSystem = Concord.system({
    -- Entities that give rewards when killed
    rewardable = { "xpReward" },
})

local function spawnScatteredResource(world, x, y, resourceType, totalAmount, itemsCfg)
    if not (world and world.spawnItem) then
        return
    end

    local maxItems = itemsCfg.dropScatterMaxItemsPerType or 0
    local scatterRadius = itemsCfg.dropScatterRadius or 14
    local impulseMin = itemsCfg.dropScatterImpulseMin or 40
    local impulseMax = itemsCfg.dropScatterImpulseMax or 110
    local jitter = itemsCfg.dropScatterImpulseJitter or 10

    local count = totalAmount
    if maxItems > 0 then
        count = math.min(count, maxItems)
    end

    if count <= 0 then
        return
    end

    local twoPi = math.pi * 2

    for _ = 1, count do
        local t = math.random()
        local speed = impulseMin + (impulseMax - impulseMin) * t
        local angle = math.random() * twoPi

        local offsetR = scatterRadius * math.sqrt(math.random())
        local ox = math.cos(angle) * offsetR
        local oy = math.sin(angle) * offsetR

        local e = world:spawnItem(x + ox, y + oy, tostring(resourceType), 1)
        if e and e.velocity then
            local jx = (math.random() * 2 - 1) * jitter
            local jy = (math.random() * 2 - 1) * jitter
            e.velocity.vx = (math.cos(angle) * speed) + jx
            e.velocity.vy = (math.sin(angle) * speed) + jy
        end
    end
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
    if entity.resourceYield and entity.position and world and world.spawnItem then
        local res = entity.resourceYield.resources or {}
        local x = entity.position.x
        local y = entity.position.y

        local itemsCfg = (config and config.items) or {}

        for resourceType, amount in pairs(res) do
            local n = tonumber(amount) or 0
            local total = math.floor(n + 0.5)
            if total > 0 then
                spawnScatteredResource(world, x, y, tostring(resourceType), total, itemsCfg)
            end
        end
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
            if world and world.spawnWreck then
                world:spawnWreck(
                    entity.position.x,
                    entity.position.y,
                    entity.loot.cargo,
                    entity.loot.coins)
            end
        end
    end

    -- Spawn explosion VFX
    if entity.position and not entity.asteroid then
        local radius = entity.collisionRadius and entity.collisionRadius.radius or 20
        local faction = (entity.faction and entity.faction.name) or "neutral"
        local color = colors.explosion
        if faction == "enemy" then
            color = colors.enemy
        elseif faction == "player" then
            color = colors.ship
        end

        explosionFx.spawn(entity.position.x, entity.position.y, color, radius)
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
