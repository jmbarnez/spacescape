--------------------------------------------------------------------------------
-- LOOT PANEL HUD
-- Side-by-side inventory view for looting wrecks
--------------------------------------------------------------------------------

local loot_panel = {}

local ui_theme = require("src.core.ui_theme")
local window_frame = require("src.render.hud.window_frame")
local playerModule = require("src.entities.player")
local wreckModule = require("src.entities.wreck")
local itemDefs = require("src.data.items")
local icon_renderer = require("src.render.icon_renderer")
local hud_cargo = require("src.render.hud.cargo")

-- Keep the wreck loot panel aligned with the player's cargo window footprint.
local SLOT_SIZE = 72
local SLOT_PADDING = 6
local COLS = 4
local ROWS = 4
local PANEL_PADDING = 14
local TOP_BAR_HEIGHT = 28
local BOTTOM_BAR_HEIGHT = 24
local GRID_WIDTH = COLS * SLOT_SIZE + (COLS - 1) * SLOT_PADDING
local GRID_HEIGHT = ROWS * SLOT_SIZE + (ROWS - 1) * SLOT_PADDING
local PANEL_WIDTH = GRID_WIDTH + PANEL_PADDING * 2
local PANEL_HEIGHT = TOP_BAR_HEIGHT + GRID_HEIGHT + PANEL_PADDING * 2 + BOTTOM_BAR_HEIGHT
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

local currentHudPalette = nil
local cargoDockedForLootSession = false

--------------------------------------------------------------------------------
-- ICON HELPER
--------------------------------------------------------------------------------

local function drawResourceIcon(id, cx, cy, size)
    if not id then
        return
    end
    icon_renderer.draw(id, {
        x = cx,
        y = cy,
        size = size,
        context = "ui",
    })
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
    -- Keep the grid vertically aligned with cargo: no extra label padding that
    -- would cause the last row to drift into the bottom bar.
    local gridStartY = layout.contentY + PANEL_PADDING

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
-- WRECK CONTENT HELPERS
--------------------------------------------------------------------------------

local function wreckHasCargoSlots(wreck)
    if not wreck then
        return false
    end

    -- Wreck cargo is ECS-backed but the HUD historically expects a plain
    -- `wreck.cargo` table. Support both layouts and keep them aliased.
    local cargo = wreck.cargo
    if not cargo and wreck.loot and wreck.loot.cargo then
        cargo = wreck.loot.cargo
        wreck.cargo = cargo
    end

    if not cargo then
        return false
    end

    for _, slot in pairs(cargo) do
        if slot and slot.id and slot.quantity and slot.quantity > 0 then
            return true
        end
    end

    return false
end

--------------------------------------------------------------------------------
-- DRAWING
--------------------------------------------------------------------------------

local getLootAllButtonRect

local function drawSlot(x, y, slot, isHovered)
    -- Slot background
    love.graphics.setColor(1, 1, 1, 0.06)
    love.graphics.rectangle("fill", x, y, SLOT_SIZE, SLOT_SIZE)

    -- Slot border
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, SLOT_SIZE, SLOT_SIZE)

    -- Draw item if present
    if slot and slot.id and slot.quantity and slot.quantity > 0 then
        local font = love.graphics.getFont()
        local slotCenterX = x + SLOT_SIZE / 2
        local slotCenterY = y + SLOT_SIZE / 2
        local iconSize = math.floor(SLOT_SIZE * 0.25 + 0.5)
        drawResourceIcon(slot.id, slotCenterX, slotCenterY - 4, iconSize)

        love.graphics.setColor(1, 1, 1, 1)
        local qtyText = tostring(slot.quantity)
        local qtyWidth = font:getWidth(qtyText)
        love.graphics.print(qtyText, slotCenterX - qtyWidth / 2, y + 4)

        local def = itemDefs[slot.id]
        local label = (def and (def.displayName or def.id)) or tostring(slot.id)
        local labelWidth = font:getWidth(label)
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.print(label, slotCenterX - labelWidth / 2, y + SLOT_SIZE - font:getHeight() - 4)
    end

    if isHovered then
        love.graphics.setColor(0.2, 0.9, 1.0, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, SLOT_SIZE, SLOT_SIZE)
    end
end

local function drawGrid(gridX, slots, maxSlots, gridId)
    local px, py = getPanelPosition()
    local layout = window_frame.getLayout(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
    })

    -- Draw slots
    local mx, my = love.mouse.getPosition()
    for row = 0, ROWS - 1 do
        for col = 0, COLS - 1 do
            local slotIndex = row * COLS + col + 1
            if slotIndex <= maxSlots then
                local sx, sy = getSlotBounds(gridX, row, col)
                local slot = slots and slots[slotIndex]
                if dragState.active and dragState.sourceGrid == gridId and dragState.sourceSlot == slotIndex then
                    slot = nil
                end
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

    -- If the wreck was removed (emptied/expired), close the panel cleanly.
    if wreck and (wreck._removed or wreck.removed) then
        playerModule.clearLootTarget()
        clearDragState()
        return
    end

    currentHudPalette = colors

    -- Draw window frame
    local layout = window_frame.draw(windowState, {
        title = "Salvage Wreck",
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
        showCloseButton = true,
    }, colors)

    -- Position loot panel and cargo window side-by-side, centered on screen.
    -- Cargo on the left, Loot on the right.
    if not cargoDockedForLootSession then
        local screenW = love.graphics.getWidth()
        local screenH = love.graphics.getHeight()
        local margin = 16
        local totalWidth = PANEL_WIDTH * 2 + margin
        local startX = (screenW - totalWidth) / 2

        -- Loot panel goes on the right
        windowState.x = math.max(0, math.min(screenW - PANEL_WIDTH, startX + PANEL_WIDTH + margin))
        windowState.y = math.max(0, (screenH - PANEL_HEIGHT) / 2)

        -- Dock cargo to the left of loot
        if hud_cargo and hud_cargo.dockNextToLoot then
            hud_cargo.dockNextToLoot(window_frame.getLayout(windowState, {
                fixedWidth = PANEL_WIDTH,
                fixedHeight = PANEL_HEIGHT,
            }))
        end
        cargoDockedForLootSession = true
    end

    -- Single 4x4 wreck grid, centered in the window content area so the
    -- wreck inventory feels like a dedicated panel separate from player cargo.
    local innerWidth = layout.contentWidth - PANEL_PADDING * 2
    local totalSlotWidth = COLS * (SLOT_SIZE + SLOT_PADDING) - SLOT_PADDING
    local gridOffsetX = 0
    if totalSlotWidth < innerWidth then
        gridOffsetX = (innerWidth - totalSlotWidth) / 2
    end

    local cargo = wreck.cargo
    if not cargo and wreck.loot and wreck.loot.cargo then
        cargo = wreck.loot.cargo
        wreck.cargo = cargo
    end

    drawGrid(gridOffsetX, cargo, COLS * ROWS, "wreck")

    -- Loot All button (no token display): appears only when the wreck still
    -- has cargo so the action is always meaningful.
    if wreckHasCargoSlots(wreck) then
        local btnX, btnY, btnW, btnH = getLootAllButtonRect(layout)
        local mx, my = love.mouse.getPosition()
        local btnHovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

        if btnHovered then
            love.graphics.setColor(0.3, 0.5, 0.3, 0.9)
        else
            love.graphics.setColor(0.2, 0.4, 0.2, 0.85)
        end
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH)
        love.graphics.setColor(0.5, 0.8, 0.5, 0.8)
        love.graphics.rectangle("line", btnX, btnY, btnW, btnH)
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        local label = "Loot All"
        local textX = btnX + (btnW - font:getWidth(label)) / 2
        local textY = btnY + (btnH - font:getHeight()) / 2
        love.graphics.print(label, textX, textY)
    end

    -- Draw dragged item
    if dragState.active and dragState.item then
        local mx = dragState.mouseX or 0
        local my = dragState.mouseY or 0
        love.graphics.setColor(0.2, 0.25, 0.3, 0.9)
        love.graphics.rectangle("fill", mx - SLOT_SIZE / 2, my - SLOT_SIZE / 2, SLOT_SIZE, SLOT_SIZE)
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

function getLootAllButtonRect(layout)
    -- Bottom bar button geometry (kept inside the bottom bar region).
    -- Extra padding keeps the button from "hanging" over the window border.
    local pad = 3
    local btnW = 110
    local btnH = math.max(16, (layout.bottomBarHeight or 0) - pad * 2)
    local btnX = layout.panelX + layout.panelWidth - PANEL_PADDING - pad - btnW
    local btnY = layout.bottomBarY + pad
    return btnX, btnY, btnW, btnH
end

local function hitTestLootAllButton(layout)
    if not layout then return false end
    local btnX, btnY, btnW, btnH = getLootAllButtonRect(layout)
    local mx, my = love.mouse.getPosition()
    return mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
end

local function lootAllFromWreck(player, wreck)
    if not wreck or not player then return end

    -- Resolve authoritative cargo table (ECS or legacy).
    local cargo = wreck.cargo
    if not cargo and wreck.loot and wreck.loot.cargo then
        cargo = wreck.loot.cargo
        wreck.cargo = cargo
    end

    -- Transfer all cargo from the wreck into the player's cargo component.
    if cargo then
        for slotIndex, slot in pairs(cargo) do
            if slot and slot.id and slot.quantity and slot.quantity > 0 then
                local added = playerModule.addCargoResource(slot.id, slot.quantity)
                if added and added > 0 then
                    slot.quantity = slot.quantity - added
                    if slot.quantity <= 0 then
                        cargo[slotIndex] = nil
                    end
                end
            end
        end
    end

    -- Once the wreck no longer contains any items, remove it from the world
    -- and clear the current loot target.
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

    -- Check Loot All button (only active when the wreck still has cargo)
    local wreck = player.lootTarget
    if wreck and wreckHasCargoSlots(wreck) and hitTestLootAllButton(layout) then
        lootAllFromWreck(player, wreck)
        return true
    end

    -- Check wreck grid clicks
    local innerWidth = layout.contentWidth - PANEL_PADDING * 2
    local totalSlotWidth = COLS * (SLOT_SIZE + SLOT_PADDING) - SLOT_PADDING
    local gridOffsetX = 0
    if totalSlotWidth < innerWidth then
        gridOffsetX = (innerWidth - totalSlotWidth) / 2
    end

    local wreckSlot = hitTestSlot(gridOffsetX, COLS * ROWS, x, y)
    if wreckSlot then
        local cargo = wreck.cargo
        if not cargo and wreck.loot and wreck.loot.cargo then
            cargo = wreck.loot.cargo
            wreck.cargo = cargo
        end

        local slot = cargo and cargo[wreckSlot]
        if slot and slot.id and slot.quantity and slot.quantity > 0 then
            local isShift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
            if isShift then
                local added = playerModule.addCargoResource(slot.id, slot.quantity)
                if added and added > 0 then
                    slot.quantity = slot.quantity - added
                    if slot.quantity <= 0 then
                        cargo[wreckSlot] = nil
                    end
                end

                if wreckModule.isEmpty(wreck) then
                    wreckModule.remove(wreck)
                    playerModule.clearLootTarget()
                end
            else
                dragState.active = true
                dragState.sourceGrid = "wreck"
                dragState.sourceSlot = wreckSlot
                dragState.item = {
                    id = slot.id,
                    quantity = slot.quantity,
                }
                dragState.mouseX = x
                dragState.mouseY = y
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

    window_frame.mousereleased(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
        showCloseButton = true,
    }, x, y, button)

    if button == 1 and dragState.active and dragState.item then
        local accepted = 0
        if hud_cargo and hud_cargo.tryAcceptExternalResourceStack then
            accepted = hud_cargo.tryAcceptExternalResourceStack(dragState.item.id, dragState.item.quantity, x, y)
        end

        if accepted and accepted > 0 then
            local wreck = player.lootTarget
            local cargo = wreck and wreck.cargo
            if not cargo and wreck and wreck.loot and wreck.loot.cargo then
                cargo = wreck.loot.cargo
                wreck.cargo = cargo
            end

            if wreck and cargo and dragState.sourceGrid == "wreck" and dragState.sourceSlot then
                local sourceSlotIndex = dragState.sourceSlot
                local sourceSlot = cargo[sourceSlotIndex]
                if sourceSlot and sourceSlot.id == dragState.item.id and sourceSlot.quantity then
                    sourceSlot.quantity = sourceSlot.quantity - accepted
                    if sourceSlot.quantity <= 0 then
                        cargo[sourceSlotIndex] = nil
                    end
                end
            end

            local wreck = player.lootTarget
            if wreck and wreckModule.isEmpty(wreck) then
                wreckModule.remove(wreck)
                playerModule.clearLootTarget()
            end
        end
    end

    clearDragState()
end

function loot_panel.mousemoved(x, y)
    local player = playerModule.state
    if not player or not player.isLooting then
        return
    end

    window_frame.mousemoved(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
        showCloseButton = true,
    }, x, y)

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
    local open = player and player.isLooting and player.lootTarget ~= nil
    if not open then
        cargoDockedForLootSession = false
    end
    return open
end

return loot_panel
