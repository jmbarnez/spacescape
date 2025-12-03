local abilitiesData = require("src.core.abilities")

local abilities = {}

local instances = {}

local function initIfNeeded()
    if next(instances) ~= nil then
        return
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
            if inst.activeTime == 0 and id == "q_attack_speed" then
                player.attackSpeedBonus = 0
            end
        end
    end
end

local function tryCastQ(player)
    local inst = instances["q_attack_speed"]
    if not inst or inst.cooldown > 0 then
        return
    end

    inst.cooldown = inst.def.cooldown or 0
    inst.activeTime = inst.def.duration or 0
    player.attackSpeedBonus = inst.def.attackSpeedBonus or 0.25
end

local function tryCastE(player, world, camera)
    local inst = instances["e_dash"]
    if not inst or inst.cooldown > 0 then
        return
    end

    inst.cooldown = inst.def.cooldown or 0

    local mx, my = love.mouse.getPosition()
    local wx, wy = camera.screenToWorld(mx, my)

    local dx = wx - player.x
    local dy = wy - player.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist == 0 then
        return
    end

    local dashDistance = inst.def.dashDistance or 260
    local moveDist = math.min(dist, dashDistance)

    local nx = player.x + (dx / dist) * moveDist
    local ny = player.y + (dy / dist) * moveDist

    if world and world.clampToWorld then
        nx, ny = world.clampToWorld(nx, ny, player.size)
    end

    player.x = nx
    player.y = ny
    player.targetX = nx
    player.targetY = ny

    if player.body then
        player.body:setPosition(nx, ny)
    end
end

function abilities.keypressed(key, player, world, camera)
    initIfNeeded()

    if key == "q" then
        tryCastQ(player)
    elseif key == "e" then
        tryCastE(player, world, camera)
    end
end

function abilities.getUiState()
    initIfNeeded()

    local ordered = { "q_attack_speed", "e_dash" }
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
