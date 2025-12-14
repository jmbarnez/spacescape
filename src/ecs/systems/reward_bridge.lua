--------------------------------------------------------------------------------
-- REWARD BRIDGE SYSTEM (ECS)
--
-- Purpose:
--   The ECS RewardSystem emits abstract reward + VFX events:
--     - spawnResources(x, y, resourcesTable)
--     - spawnWreck(x, y, cargo, coins)
--     - spawnExplosion(x, y, factionName, radius)
--
--   This bridge implements the *presentation* handlers (VFX + legacy pickups)
--   and routes them into the currently-existing runtime modules.
--
-- Migration notes:
--   - This is a temporary bridge while the player/items/VFX are migrated to ECS.
--   - The goal is to keep all reward decisions in ECS (RewardSystem), and only
--     have presentation + legacy state updates here.
--------------------------------------------------------------------------------

local Concord = require("lib.concord")

local colors = require("src.core.colors")

--------------------------------------------------------------------------------
-- LAZY REQUIRES (CIRCULAR DEPENDENCY GUARD)
--
-- Why this exists:
--   The legacy player module can depend (indirectly) on ECS-facing modules.
--
--   Historically this chain included a hard require on the ECS world:
--     player -> movement -> wreck -> ecs.world -> reward_bridge
--
--   Wreck now uses `src.ecs.world_ref` instead of requiring `src.ecs.world`
--   directly, which breaks that particular cycle. We still keep lazy requires
--   here to make ECS bootstrap resilient to future legacy dependencies.
--
--   If reward_bridge eagerly requires player (or anything that requires player)
--   during ecs.world construction, Lua's module loader detects a loop and
--   errors.
--
--   To keep the bridge small and to avoid a bigger refactor, we load legacy
--   modules on-demand inside handler calls.
--------------------------------------------------------------------------------

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

function RewardBridgeSystem:spawnResources(x, y, resources)
    if not isNumber(x) or not isNumber(y) then
        return
    end

    local world = self:getWorld()
    if not (world and world.spawnItem) then
        return
    end

    -- Derive a simple chunk count. If this system is called from asteroid death
    -- the resource table is usually a composition (fractions), so we choose a
    -- deterministic chunk count and split by weights.
    local baseChunks = 4
    local normalized = normalizeResourceYield(resources, baseChunks)

    -- Spawn one ECS item per resource type (amount stored on resourceYield).
    if normalized.stone and normalized.stone > 0 then
        world:spawnItem(x, y, "stone", normalized.stone)
    end
    if normalized.ice and normalized.ice > 0 then
        world:spawnItem(x, y, "ice", normalized.ice)
    end
    if normalized.mithril and normalized.mithril > 0 then
        world:spawnItem(x, y, "mithril", normalized.mithril)
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
