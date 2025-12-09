local item = {}

-- Central registry for all active items floating in the game world. Each
-- entry in this list is a small table describing a single pickup (position,
-- velocity, type, value, etc.). The update and draw functions iterate over
-- this list every frame.
item.list = {}

local config = require("src.core.config")
local playerModule = require("src.entities.player")
local floatingText = require("src.entities.floating_text")
local colors = require("src.core.colors")
local resourceDefs = require("src.data.mining.resources")
local item_icons = require("src.render.item_icons")

--------------------------------------------------------------------------------
-- INTERNAL CONFIG HELPERS
--------------------------------------------------------------------------------

-- Small helpers so we can read item / magnet tuning values from config with
-- sensible fallbacks. This keeps the behaviour tweakable from a single place
-- (config.lua) without scattering magic numbers through the logic below.
local function getItemsConfig()
    return config.items or {}
end

local function getPlayerConfig()
    return config.player or {}
end

-- Resolve a resource definition table for the given resource id. This keeps
-- all hard data (names, colours, rarity, icon hints) in the dedicated data
-- module so gameplay/render code can stay generic.
local function getResourceDef(resourceType)
    if not resourceType then
        return resourceDefs.default or resourceDefs.stone or {}
    end

    return resourceDefs[resourceType] or resourceDefs.default or resourceDefs.stone or {}
end

--------------------------------------------------------------------------------
-- SPAWNING HELPERS
--------------------------------------------------------------------------------

--- Spawn a single XP shard pickup at the given world position.
--- XP shards are small orbs that get pulled toward the player by the ship's
--- magnet and award bonus experience when collected.
---
--- @param x number World X position
--- @param y number World Y position
--- @param amount number Amount of XP granted on pickup
--- @return table The spawned item instance
function item.spawnXpShard(x, y, amount)
    local itemsCfg = getItemsConfig()

    -- Base visual radius for all items; individual instances can override
    -- this if you later introduce multiple pickup sizes.
    local baseRadius = itemsCfg.baseRadius or 6

    local newItem = {
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        -- Visual/interaction radius of this pickup
        radius = baseRadius,
        -- Type tag so future systems can add more pickup kinds
        itemType = "xp",
        -- XP payload this pickup awards to the player when collected
        amount = amount or 0,
        -- Age timer used for lifetime clamping and visual effects
        age = 0,
    }

    table.insert(item.list, newItem)
    return newItem
end

function item.spawnResourceChunk(x, y, resourceType, amount)
    local itemsCfg = getItemsConfig()

    local baseRadius = itemsCfg.baseRadius or 6

    local newItem = {
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        radius = baseRadius,
        itemType = "resource",
        resourceType = resourceType or "stone",
        amount = amount or 0,
        age = 0,
    }

    table.insert(item.list, newItem)
    return newItem
end

--------------------------------------------------------------------------------
-- PICKUP RESOLUTION
--------------------------------------------------------------------------------

-- Centralised handler for applying a pickup's gameplay effect to the player
-- and spawning any associated feedback (floating text, sounds, etc.).
local function applyPickupEffect(pickup, player)
    if not pickup or not player then
        return
    end

    if pickup.itemType == "resource" then
        local amount = pickup.amount or 0
        local resourceType = pickup.resourceType or "resource"
        if amount > 0 and playerModule.addCargoResource then
            local added = playerModule.addCargoResource(resourceType, amount)
            if added and added > 0 then
                -- Resolve display name from the resource data so future resources do
                -- not require changes here.
                local def = getResourceDef(resourceType)
                local label = def.displayName or def.name or tostring(resourceType)
                local text = string.format("+%d %s", math.floor(added + 0.5), label)
                local textColor = colors.health or colors.white
                floatingText.spawn(text, player.x, player.y, nil, {
                    duration = 1.1,
                    riseSpeed = 26,
                    scale = 0.8,
                    alpha = 1.0,
                    bgColor = {0, 0, 0, 0},
                    textColor = textColor,
                })
            end
        end
    elseif pickup.itemType == "xp" then
        local amount = pickup.amount or 0
        if amount > 0 and playerModule.addExperience then
            local leveledUp = playerModule.addExperience(amount)

            -- Visual feedback: small floating "+XP" text where the item was
            -- collected so the player can immediately see that the pickup was
            -- meaningful.
            local text = string.format("+%d XP", math.floor(amount + 0.5))
            local textColor = colors.health or colors.white

            floatingText.spawn(text, player.x, player.y, nil, {
                duration = 1.1,
                riseSpeed = 26,
                scale = leveledUp and 0.95 or 0.8,
                alpha = 1.0,
                bgColor = {0, 0, 0, 0},
                textColor = textColor,
            })
        end
    end
end

--------------------------------------------------------------------------------
-- UPDATE: MAGNET + PICKUP LOGIC
--------------------------------------------------------------------------------

--- Update all active items, applying magnet attraction toward the player and
--- resolving pickups when items reach the ship.
---
--- This function is intentionally self-contained: it takes the current player
--- and world state as parameters so that it stays easy to call from the
--- systems scheduler in states/game.lua.
---
--- @param dt number Delta time
--- @param player table Player state (player.state)
--- @param world table|nil World bounds; if provided, items are kept inside
---        the playable area with a small margin.
function item.update(dt, player, world)
    if not player then
        return
    end

    local itemsCfg = getItemsConfig()
    local playerCfg = getPlayerConfig()

    -- Magnet tuning: radius controls how far away pickups begin to feel the
    -- pull, pickupRadius controls how close they have to get before they
    -- instantly collect.
    local magnetRadius = player.magnetRadius or playerCfg.magnetRadius or 220
    local pickupRadius = player.magnetPickupRadius or playerCfg.magnetPickupRadius or 32

    -- Movement tuning for how strongly items accelerate toward the player and
    -- how quickly their velocity is damped when outside the magnet radius.
    local magnetForce = itemsCfg.magnetForce or 220
    local magnetMaxSpeed = itemsCfg.magnetMaxSpeed or 260
    local idleDamping = itemsCfg.magnetDamping or 3.0

    -- Lifetime clamp so the world never fills up with forgotten pickups.
    local maxLifetime = itemsCfg.maxLifetime or 20

    for i = #item.list, 1, -1 do
        local it = item.list[i]

        -- Age tracking for lifetime and subtle visual effects.
        it.age = (it.age or 0) + dt
        if maxLifetime > 0 and it.age >= maxLifetime then
            table.remove(item.list, i)
            goto continue
        end

        local dx = player.x - it.x
        local dy = player.y - it.y
        local distanceSq = dx * dx + dy * dy
        local distance = math.sqrt(distanceSq)

        -- Effective pickup radius: ship pickup radius plus a bit of padding so
        -- orbs are collected just before they visually overlap the hull.
        local effectivePickupRadius = pickupRadius + (it.radius or 0)

        -- Immediate pickup when the item reaches the ship.
        if distance <= effectivePickupRadius then
            applyPickupEffect(it, player)
            table.remove(item.list, i)
            goto continue
        end

        -- Apply magnet attraction when within radius.
        if distance > 0 and distance <= magnetRadius then
            local invDist = 1.0 / distance
            local dirX = dx * invDist
            local dirY = dy * invDist

            -- Falloff curve: items accelerate more strongly when closer to the
            -- ship, making the final approach feel snappy while distant
            -- pickups drift in more gently.
            local t = 1.0 - (distance / magnetRadius)
            if t < 0 then t = 0 end
            local accel = magnetForce * (t * t)

            local ax = dirX * accel
            local ay = dirY * accel

            it.vx = (it.vx or 0) + ax * dt
            it.vy = (it.vy or 0) + ay * dt

            -- Clamp overall speed so items do not streak past the ship.
            local vx = it.vx or 0
            local vy = it.vy or 0
            local speedSq = vx * vx + vy * vy
            local maxSpeedSq = magnetMaxSpeed * magnetMaxSpeed
            if speedSq > maxSpeedSq and speedSq > 0 then
                local factor = magnetMaxSpeed / math.sqrt(speedSq)
                it.vx = vx * factor
                it.vy = vy * factor
            end
        else
            -- Outside magnet radius: apply gentle damping so items eventually
            -- slow down instead of drifting forever with full speed.
            local vx = it.vx or 0
            local vy = it.vy or 0
            if vx ~= 0 or vy ~= 0 then
                local factor = 1.0 - idleDamping * dt
                if factor < 0 then factor = 0 end
                it.vx = vx * factor
                it.vy = vy * factor
            end
        end

        -- Integrate velocity to update position.
        it.x = it.x + (it.vx or 0) * dt
        it.y = it.y + (it.vy or 0) * dt

        -- Keep items inside the playable world so they do not disappear beyond
        -- the camera. We use a small margin based on the item radius.
        if world then
            local margin = (it.radius or 0) + 4
            if world.minX and world.maxX then
                if it.x < world.minX + margin then
                    it.x = world.minX + margin
                    it.vx = 0
                elseif it.x > world.maxX - margin then
                    it.x = world.maxX - margin
                    it.vx = 0
                end
            end

            if world.minY and world.maxY then
                if it.y < world.minY + margin then
                    it.y = world.minY + margin
                    it.vy = 0
                elseif it.y > world.maxY - margin then
                    it.y = world.maxY - margin
                    it.vy = 0
                end
            end
        end

        ::continue::
    end
end

--------------------------------------------------------------------------------
-- DRAWING
--------------------------------------------------------------------------------

function item.draw(palette)
    if #item.list == 0 then
        return
    end

    local col = palette or colors

    local prevLineWidth = love.graphics.getLineWidth()

    for _, it in ipairs(item.list) do
        local baseRadius = it.radius or (getItemsConfig().baseRadius or 6)

        -- Simple pulsing based on age for a bit of life.
        local age = it.age or 0
        local pulse = (math.sin(age * 3.2) + 1) * 0.5

        if it.itemType == "resource" then
            local def = getResourceDef(it.resourceType)
            item_icons.drawResource(it, def, col, baseRadius, pulse)
        else
            -- Legacy / fallback path (e.g. XP shards if they are ever reused).
            -- We simply use the generic resource icon when no specific
            -- definition is available.
            item_icons.drawResource(it, nil, col, baseRadius, pulse)
        end
    end

    love.graphics.setLineWidth(prevLineWidth)
    love.graphics.setColor(colors.white)
end

--------------------------------------------------------------------------------
-- CLEARING
--------------------------------------------------------------------------------

--- Remove all active items and reset the list.
function item.clear()
    item.list = {}
end

return item
