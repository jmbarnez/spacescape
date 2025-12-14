local target_panel = {}

local combatSystem = require("src.systems.combat")
local ui_theme = require("src.core.ui_theme")

-- Draws a target information panel at the top center of the screen.
-- This panel shows information about the currently locked/targeted entity.
-- For asteroids, this includes their composition.
function target_panel.draw(colors)
    -- Query combat system for the current visual target (enemy or asteroid)
    local target, isLocked, isLocking, progress = combatSystem.getCurrentHudTarget()

    -- If there is no active target at all, do not draw the panel
    if not target then
        return
    end

    -- Resolve screen size for positioning
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Panel layout constants (tweak as desired)
    local panelWidth = math.min(screenW - 40, 480)
    local panelHeight = 64
    local panelX = (screenW - panelWidth) / 2
    local panelY = 18

    local hudPanelStyle = ui_theme.hudPanel

    -- Background
    love.graphics.setColor(
        hudPanelStyle.background[1],
        hudPanelStyle.background[2],
        hudPanelStyle.background[3],
        hudPanelStyle.background[4]
    )
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 8, 8)

    -- Border
    local borderColor = hudPanelStyle.border or colors.uiPanelBorder or { 1, 1, 1, 0.6 }
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 8, 8)

    -- Choose label / type based on entity
    local primaryLabel = "TARGET"
    local typeLabel = "Unknown"

    -- Distinguish enemies vs asteroids using simple heuristics
    -- Handle ECS faction component (table with .name) or legacy string
    local factionName = nil
    if target.faction then
        factionName = type(target.faction) == "table" and target.faction.name or target.faction
    end

    -- Get ship data from ECS component or legacy property
    local shipData = target.shipVisual and target.shipVisual.ship or target.ship

    if factionName == "enemy" then
        typeLabel = "Enemy Ship"
    elseif target.wreck or (target.loot and target.loot.cargo) then
        typeLabel = "Loot Container"
    elseif target.collisionRadius and not shipData then
        -- Asteroids have collisionRadius and no ship field in this project
        typeLabel = "Asteroid"
    end

    -- Name / description line
    local nameParts = {}

    -- Level
    local level = target.level or (target.enemyLevel and target.enemyLevel.level)
    if level then
        table.insert(nameParts, string.format("Lv.%d", level))
    end


    -- Basic size info for flavor (use radius or size)
    -- Handle ECS components (tables) or legacy number values
    local radius = 0
    if target.collisionRadius then
        radius = type(target.collisionRadius) == "table" and target.collisionRadius.radius or target.collisionRadius
    elseif target.size then
        radius = type(target.size) == "table" and target.size.value or target.size
    end
    if radius > 0 then
        table.insert(nameParts, string.format("R%.0f", radius))
    end

    -- Append asteroid composition if available
    local compositionText = nil
    if typeLabel == "Asteroid" and target.composition then
        compositionText = target.composition
    end

    local font = love.graphics.getFont()
    local lineY = panelY + 10

    -- Draw primary label (left side)
    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.9)
    love.graphics.print(primaryLabel, panelX + 12, lineY)

    -- Draw type and basic stats (center)
    local typeText = typeLabel
    if #nameParts > 0 then
        typeText = typeText .. "  " .. table.concat(nameParts, "  ")
    end

    local typeWidth = font:getWidth(typeText)
    local typeX = panelX + panelWidth / 2 - typeWidth / 2
    love.graphics.print(typeText, typeX, lineY)

    -- Second line: composition or hint text
    local secondY = lineY + font:getHeight() + 4
    local secondaryText = nil

    if compositionText then
        secondaryText = "Composition: " .. compositionText
    elseif typeLabel == "Enemy Ship" then
        secondaryText = "Hostile vessel locked"
    elseif typeLabel == "Loot Container" then
        secondaryText = "Salvage available"
    else
        secondaryText = nil
    end

    if secondaryText then
        local secWidth = font:getWidth(secondaryText)
        local secX = panelX + panelWidth / 2 - secWidth / 2
        love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.8)
        love.graphics.print(secondaryText, secX, secondY)
    end

    -- Right side: lock status indicator (text only, ring is in world-space already)
    local statusText = nil

    if isLocking then
        statusText = string.format("LOCKING %.0f%%", (progress or 0) * 100)
    elseif isLocked then
        statusText = "LOCKED"
    end

    if statusText then
        local statusWidth = font:getWidth(statusText)
        local statusX = panelX + panelWidth - statusWidth - 12
        love.graphics.setColor(colors.targetRingLocked or colors.targetRing or { 1, 0, 0, 0.9 })
        love.graphics.print(statusText, statusX, lineY)
    end
end

return target_panel
