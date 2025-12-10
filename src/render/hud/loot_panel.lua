--------------------------------------------------------------------------------
-- LOOT PANEL HUD
-- Side-by-side inventory view for looting wrecks
--------------------------------------------------------------------------------

local loot_panel = {}

local ui_theme = require("src.core.ui_theme")
local window_frame = require("src.render.hud.window_frame")
local playerModule = require("src.entities.player")
local wreckModule = require("src.entities.wreck")

-- Panel configuration
local PANEL_WIDTH = 380
local PANEL_HEIGHT = 280
local SLOT_SIZE = 40
local SLOT_PADDING = 4
local COLS = 4
local ROWS = 2
local PANEL_PADDING = 12
local GRID_GAP = 20

-- Window state
local windowState = {
    x = nil,
    y = nil,
    isDragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
}

-- Drag state for item transfers
local dragState = {
    active = false,
    sourceGrid = nil, -- "wreck" or "player"
    sourceSlot = nil,
    item = nil,
    mouseX = 0,
    mouseY = 0,
}

--------------------------------------------------------------------------------
-- RESOURCE ICONS (simplified versions)
--------------------------------------------------------------------------------

local function drawScrapIcon(cx, cy, size)
    love.graphics.setColor(0.6, 0.55, 0.5, 1.0)
    love.graphics.rectangle("fill", cx - size * 0.6, cy - size * 0.3, size * 1.2, size * 0.6, 2, 2)
    love.graphics.setColor(0.4, 0.35, 0.3, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.line(cx - size * 0.3, cy - size * 0.3, cx - size * 0.3, cy + size * 0.3)
    love.graphics.line(cx + size * 0.3, cy - size * 0.3, cx + size * 0.3, cy + size * 0.3)
end

local function drawCoinIcon(cx, cy, size)
    love.graphics.setColor(1.0, 0.85, 0.3, 1.0)
    love.graphics.circle("fill", cx, cy, size * 0.5)
    love.graphics.setColor(0.8, 0.65, 0.1, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, size * 0.5)
    love.graphics.setColor(0.9, 0.7, 0.2, 1.0)
    love.graphics.print("$", cx - 4, cy - 6)
end

local function drawResourceIcon(id, cx, cy, size)
    if id == "scrap" then
        drawScrapIcon(cx, cy, size)
    else
        -- Generic fallback
        love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
        love.graphics.rectangle("fill", cx - size * 0.4, cy - size * 0.4, size * 0.8, size * 0.8, 2, 2)
    end
end

--------------------------------------------------------------------------------
-- LAYOUT HELPERS
--------------------------------------------------------------------------------

local function getPanelPosition()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local px = windowState.x or (w - PANEL_WIDTH) / 2
    local py = windowState.y or (h - PANEL_HEIGHT) / 2
    return px, py
end

local function getSlotBounds(gridX, row, col)
    local px, py = getPanelPosition()
    local layout = window_frame.getLayout(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
    })

    local gridStartX = layout.contentX + PANEL_PADDING + gridX
    local gridStartY = layout.contentY + PANEL_PADDING + 20 -- Space for label

    local slotX = gridStartX + col * (SLOT_SIZE + SLOT_PADDING)
    local slotY = gridStartY + row * (SLOT_SIZE + SLOT_PADDING)

    return slotX, slotY, SLOT_SIZE, SLOT_SIZE
end

local function clearDragState()
    dragState.active = false
    dragState.sourceGrid = nil
    dragState.sourceSlot = nil
    dragState.item = nil
end

--------------------------------------------------------------------------------
-- DRAWING
--------------------------------------------------------------------------------

local function drawSlot(x, y, slot, isHovered)
    -- Slot background
    if isHovered then
        love.graphics.setColor(0.3, 0.35, 0.4, 0.9)
    else
        love.graphics.setColor(0.15, 0.18, 0.22, 0.85)
    end
    love.graphics.rectangle("fill", x, y, SLOT_SIZE, SLOT_SIZE, 4, 4)

    -- Slot border
    love.graphics.setColor(0.4, 0.45, 0.5, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, SLOT_SIZE, SLOT_SIZE, 4, 4)

    -- Draw item if present
    if slot and slot.id and slot.quantity and slot.quantity > 0 then
        local cx = x + SLOT_SIZE / 2
        local cy = y + SLOT_SIZE / 2
        drawResourceIcon(slot.id, cx, cy - 4, SLOT_SIZE * 0.4)

        -- Quantity
        love.graphics.setColor(1, 1, 1, 1)
        local qtyText = tostring(slot.quantity)
        local font = love.graphics.getFont()
        local tw = font:getWidth(qtyText)
        love.graphics.print(qtyText, x + SLOT_SIZE - tw - 3, y + SLOT_SIZE - 14)
    end
end

local function drawGrid(gridX, label, slots, maxSlots, gridId)
    local px, py = getPanelPosition()
    local layout = window_frame.getLayout(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
    })

    local labelX = layout.contentX + PANEL_PADDING + gridX
    local labelY = layout.contentY + PANEL_PADDING

    -- Grid label
    love.graphics.setColor(0.8, 0.85, 0.9, 1.0)
    love.graphics.print(label, labelX, labelY)

    -- Draw slots
    local mx, my = love.mouse.getPosition()
    for row = 0, ROWS - 1 do
        for col = 0, COLS - 1 do
            local slotIndex = row * COLS + col + 1
            if slotIndex <= maxSlots then
                local sx, sy = getSlotBounds(gridX, row, col)
                local slot = slots and slots[slotIndex]
                local isHovered = mx >= sx and mx <= sx + SLOT_SIZE and my >= sy and my <= sy + SLOT_SIZE
                drawSlot(sx, sy, slot, isHovered)
            end
        end
    end
end

function loot_panel.draw(player, colors)
    if not player or not player.isLooting or not player.lootTarget then
        return
    end

    local wreck = player.lootTarget

    -- Draw window frame
    window_frame.draw(windowState, {
        title = "Salvage Wreck",
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
        showCloseButton = true,
    })

    local layout = window_frame.getLayout(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
    })

    -- Left grid: Wreck cargo
    local leftGridX = 0
    drawGrid(leftGridX, "Wreck", wreck.cargo, COLS * ROWS, "wreck")

    -- Right grid: Player cargo
    local rightGridX = (COLS * (SLOT_SIZE + SLOT_PADDING)) + GRID_GAP
    local playerCargo = player.cargo and player.cargo.slots or {}
    local playerMaxSlots = player.cargo and player.cargo.maxSlots or 16
    drawGrid(rightGridX, "Your Cargo", playerCargo, math.min(playerMaxSlots, COLS * ROWS), "player")

    -- Draw coins if wreck has any
    if wreck.coins and wreck.coins > 0 then
        local coinX = layout.contentX + PANEL_PADDING
        local coinY = layout.contentY + PANEL_HEIGHT - 50
        drawCoinIcon(coinX + 12, coinY + 12, 20)
        love.graphics.setColor(1, 0.9, 0.4, 1)
        love.graphics.print(tostring(wreck.coins) .. " coins", coinX + 30, coinY + 5)

        -- Loot All button
        local btnX = layout.contentX + PANEL_WIDTH - 100
        local btnY = coinY
        local btnW, btnH = 80, 24

        local mx, my = love.mouse.getPosition()
        local btnHovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

        if btnHovered then
            love.graphics.setColor(0.3, 0.5, 0.3, 0.9)
        else
            love.graphics.setColor(0.2, 0.4, 0.2, 0.85)
        end
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 4, 4)
        love.graphics.setColor(0.5, 0.8, 0.5, 0.8)
        love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Loot All", btnX + 10, btnY + 5)
    end

    -- Draw dragged item
    if dragState.active and dragState.item then
        local mx, my = love.mouse.getPosition()
        love.graphics.setColor(0.2, 0.25, 0.3, 0.9)
        love.graphics.rectangle("fill", mx - SLOT_SIZE / 2, my - SLOT_SIZE / 2, SLOT_SIZE, SLOT_SIZE, 4, 4)
        drawResourceIcon(dragState.item.id, mx, my - 4, SLOT_SIZE * 0.4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(tostring(dragState.item.quantity), mx + SLOT_SIZE / 2 - 12, my + SLOT_SIZE / 2 - 14)
    end
end

--------------------------------------------------------------------------------
-- INPUT HANDLING
--------------------------------------------------------------------------------

local function hitTestSlot(gridX, maxSlots, mx, my)
    for row = 0, ROWS - 1 do
        for col = 0, COLS - 1 do
            local slotIndex = row * COLS + col + 1
            if slotIndex <= maxSlots then
                local sx, sy = getSlotBounds(gridX, row, col)
                if mx >= sx and mx <= sx + SLOT_SIZE and my >= sy and my <= sy + SLOT_SIZE then
                    return slotIndex
                end
            end
        end
    end
    return nil
end

local function hitTestLootAllButton(layout)
    if not layout then return false end
    local coinY = layout.contentY + PANEL_HEIGHT - 50
    local btnX = layout.contentX + PANEL_WIDTH - 100
    local btnY = coinY
    local btnW, btnH = 80, 24

    local mx, my = love.mouse.getPosition()
    return mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
end

local function lootAllFromWreck(player, wreck)
    if not wreck or not player then return end

    -- Transfer all cargo
    if wreck.cargo then
        for slotIndex, slot in pairs(wreck.cargo) do
            if slot and slot.id and slot.quantity and slot.quantity > 0 then
                local added = playerModule.addCargoResource(slot.id, slot.quantity)
                if added and added > 0 then
                    slot.quantity = slot.quantity - added
                    if slot.quantity <= 0 then
                        wreck.cargo[slotIndex] = nil
                    end
                end
            end
        end
    end

    -- Transfer coins
    if wreck.coins and wreck.coins > 0 then
        playerModule.addCurrency(wreck.coins)
        wreck.coins = 0
    end

    -- Check if wreck is empty and remove
    if wreckModule.isEmpty(wreck) then
        wreckModule.remove(wreck)
        playerModule.clearLootTarget()
    end
end

function loot_panel.mousepressed(x, y, button)
    local player = playerModule.state
    if not player or not player.isLooting or not player.lootTarget then
        return false
    end

    -- Let window frame handle close button and dragging
    local result = window_frame.mousepressed(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
        showCloseButton = true,
    }, x, y, button)

    if result == "close" then
        playerModule.clearLootTarget()
        clearDragState()
        return true
    elseif result == "drag" then
        return true
    end

    local layout = window_frame.getLayout(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
    })

    -- Check Loot All button
    local wreck = player.lootTarget
    if wreck and wreck.coins and wreck.coins > 0 then
        if hitTestLootAllButton(layout) then
            lootAllFromWreck(player, wreck)
            return true
        end
    end

    -- Check wreck grid clicks
    local leftGridX = 0
    local wreckSlot = hitTestSlot(leftGridX, COLS * ROWS, x, y)
    if wreckSlot then
        local slot = wreck.cargo and wreck.cargo[wreckSlot]
        if slot and slot.id and slot.quantity and slot.quantity > 0 then
            -- Transfer to player
            local added = playerModule.addCargoResource(slot.id, slot.quantity)
            if added and added > 0 then
                slot.quantity = slot.quantity - added
                if slot.quantity <= 0 then
                    wreck.cargo[wreckSlot] = nil
                end
            end

            -- Check if wreck is now empty
            if wreckModule.isEmpty(wreck) then
                wreckModule.remove(wreck)
                playerModule.clearLootTarget()
            end
            return true
        end
    end

    return result == true
end

function loot_panel.mousereleased(x, y, button)
    local player = playerModule.state
    if not player or not player.isLooting then
        return
    end

    window_frame.mousereleased(windowState, x, y, button)
    clearDragState()
end

function loot_panel.mousemoved(x, y)
    local player = playerModule.state
    if not player or not player.isLooting then
        return
    end

    window_frame.mousemoved(windowState, x, y)

    if dragState.active then
        dragState.mouseX = x
        dragState.mouseY = y
    end
end

function loot_panel.reset()
    windowState.x = nil
    windowState.y = nil
    windowState.isDragging = false
    clearDragState()
end

function loot_panel.isOpen()
    local player = playerModule.state
    return player and player.isLooting and player.lootTarget ~= nil
end

return loot_panel
