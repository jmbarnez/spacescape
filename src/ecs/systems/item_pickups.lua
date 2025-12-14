local Concord = require("lib.concord")

local config = require("src.core.config")
local colors = require("src.core.colors")

local floatingText = require("src.entities.floating_text")
local itemDefs = require("src.data.items")

local ItemPickupSystem = Concord.system({
    items = { "item", "position", "velocity", "collisionRadius" },
})

local function isNumber(n)
    return type(n) == "number" and n == n
end

local function getItemsConfig()
    return config.items or {}
end

local function getItemDef(itemType)
    if not itemType then
        return itemDefs.default or itemDefs.stone or {}
    end

    return itemDefs[itemType] or itemDefs.default or itemDefs.stone or {}
end

local function clampSpeed(vx, vy, maxSpeed)
    local speedSq = vx * vx + vy * vy
    local maxSpeedSq = maxSpeed * maxSpeed
    if speedSq > maxSpeedSq and speedSq > 0 then
        local factor = maxSpeed / math.sqrt(speedSq)
        return vx * factor, vy * factor
    end
    return vx, vy
end

local function addCargoResource(player, resourceType, amount)
    if not (player and player.cargo and resourceType and amount and amount > 0) then
        return 0
    end

    local cargoComp = player.cargo
    local slots = cargoComp.slots or {}
    cargoComp.slots = slots

    local maxSlots = cargoComp.maxSlots or 0
    local key = tostring(resourceType)

    for _, slot in ipairs(slots) do
        if slot.id == key then
            slot.quantity = (slot.quantity or 0) + amount
            return amount
        end
    end

    if #slots < maxSlots then
        table.insert(slots, { id = key, quantity = amount })
        return amount
    end

    return 0
end

local function tryGetSingleResourcePayload(itemEntity)
    if not (itemEntity and itemEntity.resourceYield and itemEntity.resourceYield.resources) then
        return nil, 0
    end

    local res = itemEntity.resourceYield.resources

    for resourceType, amount in pairs(res) do
        local n = tonumber(amount) or 0
        if n > 0 then
            return tostring(resourceType), n
        end
    end

    return nil, 0
end

local function spawnPickupText(player, text, opts)
    if not (player and player.position) then
        return
    end

    floatingText.spawn(text, player.position.x, player.position.y, nil, opts)
end

function ItemPickupSystem:prePhysics(dt)
    local world = self:getWorld()
    if not world then
        return
    end

    local players = world:query({ "playerControlled", "position", "magnet", "cargo" }) or {}
    local player = players[1]
    if not (player and player.position) then
        return
    end

    local itemsCfg = getItemsConfig()

    local magnetRadius = (player.magnet and player.magnet.radius) or 220
    local pickupRadius = (player.magnet and player.magnet.pickupRadius) or 32

    local magnetForce = itemsCfg.magnetForce or 220
    local magnetMaxSpeed = itemsCfg.magnetMaxSpeed or 260
    local idleDamping = itemsCfg.magnetDamping or 3.0

    for i = 1, self.items.size do
        local it = self.items[i]

        if it.lifetime and isNumber(dt) then
            it.lifetime.remaining = (it.lifetime.remaining or 0) - dt
            if it.lifetime.remaining <= 0 then
                it:give("removed")
                goto continue
            end
        end

        it.age = (it.age or 0) + (dt or 0)

        local dx = player.position.x - it.position.x
        local dy = player.position.y - it.position.y
        local distanceSq = dx * dx + dy * dy
        local distance = math.sqrt(distanceSq)

        local itRadius = (it.collisionRadius and it.collisionRadius.radius) or 0
        local effectivePickupRadius = pickupRadius + itRadius

        if distance <= effectivePickupRadius then
            local resourceType, amount = tryGetSingleResourcePayload(it)
            if resourceType and amount > 0 then
                local added = addCargoResource(player, resourceType, amount)
                if added > 0 then
                    local def = getItemDef(resourceType)
                    local label = def.displayName or def.name or tostring(resourceType)
                    spawnPickupText(player, label, {
                        duration = 1.1,
                        riseSpeed = 26,
                        scale = 0.8,
                        alpha = 1.0,
                        bgColor = { 0, 0, 0, 0 },
                        textColor = colors.health or colors.white,
                        stackKey = "resource:" .. tostring(resourceType),
                        stackValueIncrement = math.floor(added + 0.5),
                        stackBaseText = label,
                    })
                else
                    spawnPickupText(player, "Cargo Full", {
                        duration = 1.0,
                        riseSpeed = 20,
                        scale = 0.75,
                        alpha = 1.0,
                        bgColor = { 0, 0, 0, 0.4 },
                        textColor = colors.health or colors.white,
                    })
                end
            end

            it:give("removed")
            goto continue
        end

        if distance > 0 and distance <= magnetRadius then
            local invDist = 1.0 / distance
            local dirX = dx * invDist
            local dirY = dy * invDist

            local t = 1.0 - (distance / magnetRadius)
            if t < 0 then t = 0 end
            local accel = magnetForce * (t * t)

            local ax = dirX * accel
            local ay = dirY * accel

            it.velocity.vx = (it.velocity.vx or 0) + ax * dt
            it.velocity.vy = (it.velocity.vy or 0) + ay * dt

            it.velocity.vx, it.velocity.vy = clampSpeed(it.velocity.vx, it.velocity.vy, magnetMaxSpeed)
        else
            local vx = it.velocity.vx or 0
            local vy = it.velocity.vy or 0
            if vx ~= 0 or vy ~= 0 then
                local factor = 1.0 - idleDamping * dt
                if factor < 0 then factor = 0 end
                it.velocity.vx = vx * factor
                it.velocity.vy = vy * factor
            end
        end

        ::continue::
    end
end

function ItemPickupSystem:update(dt)
    self:prePhysics(dt)
end

return ItemPickupSystem
