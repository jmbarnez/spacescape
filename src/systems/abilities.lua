local abilitiesData = require("src.core.abilities")
local combatSystem = require("src.systems.combat")
local coreInput = require("src.core.input")

local abilities = {}

local instances = {}

local function initIfNeeded()
    if next(instances) ~= nil then
        return
    end

function abilities.castOvercharge(player)
    initIfNeeded()
    tryCastQ(player)
end

function abilities.castVectorDash(player, world, camera)
    initIfNeeded()
    tryCastE(player, world, camera)
end

    for id, def in pairs(abilitiesData) do
        instances[id] = {
            def = def,
            cooldown = 0,
            activeTime = 0
        }
    end
end

function abilities.load(player)
    initIfNeeded()
    for _, inst in pairs(instances) do
        inst.cooldown = 0
        inst.activeTime = 0
    end
    if player then
        player.attackSpeedBonus = 0
    end
end

function abilities.reset(player)
    for _, inst in pairs(instances) do
        inst.cooldown = 0
        inst.activeTime = 0
    end
    if player then
        player.attackSpeedBonus = 0
    end
end

function abilities.update(dt, player, world, camera)
    initIfNeeded()

    for id, inst in pairs(instances) do
        if inst.cooldown > 0 then
            inst.cooldown = math.max(0, inst.cooldown - dt)
        end
        if inst.activeTime > 0 then
            inst.activeTime = math.max(0, inst.activeTime - dt)
        end
    end
end

local function tryCastQ(player)
    if not player then
        return
    end

    local inst = instances["overcharge"]
    if not inst or inst.cooldown > 0 then
        return
    end

    inst.cooldown = inst.def.cooldown or 0
    inst.activeTime = 0

    local shots = inst.def.extraShots or 1
    if shots > 0 then
        combatSystem.castExtraShot(player, shots)
    end
end

local function tryCastE(player, world, camera)
    if not (player and camera) then
        return
    end

    local inst = instances["vector_dash"]
    if not inst or inst.cooldown > 0 then
        return
    end

    inst.cooldown = inst.def.cooldown or 0

    local wx, wy = coreInput.getMouseWorld(camera)

    local px = player.position and player.position.x or player.x
    local py = player.position and player.position.y or player.y

    local dx = wx - px
    local dy = wy - py
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist == 0 then
        return
    end

    local dashDistance = inst.def.dashDistance or 260
    local moveDist = math.min(dist, dashDistance)

    -- Normalize and scale
    local nx = px + (dx / dist) * moveDist
    local ny = py + (dy / dist) * moveDist

    -- Ensure we don't dash outside world bounds
    local radius = (player.collisionRadius and player.collisionRadius.value) or player.collisionRadius or
    (player.size and player.size.value) or 20
    if world.clampToWorld then
        nx, ny = world.clampToWorld(nx, ny, radius)
    end

    -- Teleport player ECS components
    if player.position then
        player.position.x = nx
        player.position.y = ny
    else
        player.x = nx
        player.y = ny
    end

    if player.destination then
        player.destination.x = nx
        player.destination.y = ny
        player.destination.active = false -- Stop moving after dash
    end

    -- Teleport Physics Body
    local body = player.physics and player.physics.body or player.body
    if body then
        body:setPosition(nx, ny)
    end
end

function abilities.keypressed(key, player, world, camera)
    initIfNeeded()

    if not player then
        return
    end

    if key == "q" then
        abilities.castOvercharge(player)
    elseif key == "e" then
        abilities.castVectorDash(player, world, camera)
    end
end

function abilities.getUiState()
    initIfNeeded()

    local ordered = { "overcharge", "vector_dash" }
    local result = {}

    for _, id in ipairs(ordered) do
        local inst = instances[id]
        if inst then
            table.insert(result, {
                id = inst.def.id,
                key = inst.def.key,
                cooldown = inst.cooldown,
                cooldownMax = inst.def.cooldown or 0,
                active = inst.activeTime > 0
            })
        end
    end

    return result
end

return abilities
