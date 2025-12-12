--------------------------------------------------------------------------------
-- REWARD BRIDGE SYSTEM (ECS)
--
-- Purpose:
--   The ECS RewardSystem emits abstract reward + VFX events:
--     - awardXp(amount)
--     - awardTokens(amount)
--     - spawnResources(x, y, resourcesTable)
--     - spawnWreck(x, y, cargo, coins)
--     - spawnExplosion(x, y, factionName, radius)
--
--   This bridge implements those event handlers and routes them into the
--   currently-existing runtime modules (player progression + VFX + pickups).
--
-- Migration notes:
--   - This is a temporary bridge while the player/items/VFX are migrated to ECS.
--   - The goal is to keep all reward decisions in ECS (RewardSystem), and only
--     have presentation + legacy state updates here.
--------------------------------------------------------------------------------

local Concord = require("lib.concord")

local colors = require("src.core.colors")

local playerModule = require("src.entities.player")
local itemModule = require("src.entities.item")
local explosionFx = require("src.entities.explosion_fx")

local RewardBridgeSystem = Concord.system({})

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function isNumber(n)
    return type(n) == "number" and n == n
end

-- Convert a composition table (0..1 fractions) into integer chunk amounts.
--
-- Examples:
--   { stone = 0.6, ice = 0.4 } -> { stone = 3, ice = 2 } (for baseChunks=5)
local function normalizeResourceYield(resources, baseChunks)
    resources = resources or {}
    baseChunks = baseChunks or 1

    local stone = tonumber(resources.stone) or 0
    local ice = tonumber(resources.ice) or 0
    local mithril = tonumber(resources.mithril) or 0

    local total = stone + ice + mithril

    -- If the table already looks like integer yields (e.g. { stone = 3 }),
    -- treat it as authoritative.
    if total > 0 and stone >= 1 or ice >= 1 or mithril >= 1 then
        return {
            stone = math.floor(stone + 0.5),
            ice = math.floor(ice + 0.5),
            mithril = math.floor(mithril + 0.5),
        }
    end

    -- Otherwise interpret as weights/fractions.
    if total <= 0 then
        return { stone = baseChunks }
    end

    local function roundShare(share)
        return math.max(0, math.floor((share / total) * baseChunks + 0.5))
    end

    local out = {
        stone = roundShare(stone),
        ice = roundShare(ice),
        mithril = roundShare(mithril),
    }

    if (out.stone + out.ice + out.mithril) <= 0 then
        out.stone = baseChunks
    end

    return out
end

--------------------------------------------------------------------------------
-- EVENT HANDLERS
--------------------------------------------------------------------------------

function RewardBridgeSystem:awardXp(amount)
    if not isNumber(amount) or amount <= 0 then
        return
    end

    -- Legacy player progression is still authoritative until the player is ECS.
    if playerModule and playerModule.addExperience then
        playerModule.addExperience(amount)
    end
end

function RewardBridgeSystem:awardTokens(amount)
    if not isNumber(amount) or amount <= 0 then
        return
    end

    if playerModule and playerModule.addCurrency then
        playerModule.addCurrency(amount)
    end
end

function RewardBridgeSystem:spawnResources(x, y, resources)
    if not isNumber(x) or not isNumber(y) then
        return
    end

    -- Derive a simple chunk count. If this system is called from asteroid death
    -- the resource table is usually a composition (fractions), so we choose a
    -- deterministic chunk count and split by weights.
    local baseChunks = 4
    local normalized = normalizeResourceYield(resources, baseChunks)

    -- Spawn one pickup per resource type (amount stored on pickup).
    if normalized.stone and normalized.stone > 0 then
        itemModule.spawnResourceChunk(x, y, "stone", normalized.stone)
    end
    if normalized.ice and normalized.ice > 0 then
        itemModule.spawnResourceChunk(x, y, "ice", normalized.ice)
    end
    if normalized.mithril and normalized.mithril > 0 then
        itemModule.spawnResourceChunk(x, y, "mithril", normalized.mithril)
    end
end

function RewardBridgeSystem:spawnWreck(x, y, cargo, coins)
    if not isNumber(x) or not isNumber(y) then
        return
    end

    local world = self:getWorld()
    if world and world.spawnWreck then
        world:spawnWreck(x, y, cargo, coins)
    end
end

function RewardBridgeSystem:spawnExplosion(x, y, factionName, radius)
    if not isNumber(x) or not isNumber(y) then
        return
    end

    local faction = tostring(factionName or "neutral")

    local color = colors.explosion
    if faction == "enemy" then
        color = colors.enemy
    elseif faction == "player" then
        color = colors.ship
    end

    explosionFx.spawn(x, y, color, radius)
end

return RewardBridgeSystem
