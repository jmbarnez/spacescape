local hud_cargo = {}

local ui_theme = require("src.core.ui_theme")
local window_frame = require("src.render.hud.window_frame")
local camera = require("src.core.camera")
local coreInput = require("src.core.input")
local worldRef = require("src.ecs.world_ref")
local itemDefs = require("src.data.items")
local icon_renderer = require("src.render.icon_renderer")

--------------------------------------------------------------------------------
-- WINDOW STATE
-- Position and drag state for the cargo window.
--------------------------------------------------------------------------------

local windowState = {
    x = nil, -- nil = center on screen
    y = nil,
    isDragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
    userAnchored = false,
}

-- SLOT_SIZE controls the on-screen size of each cargo tile. Keeping this
-- shared between layout math and draw logic ensures the window always hugs
-- the grid tightly. This value is tuned so the cargo window footprint stays
-- compact while keeping items readable.
local SLOT_SIZE = 72
local SLOT_PADDING = 6
local COLS = 4
local ROWS = 4
local PANEL_PADDING = 14
local TOP_BAR_HEIGHT = 28
local BOTTOM_BAR_HEIGHT = 24
local CLOSE_BUTTON_SIZE = 24

-- Calculate panel dimensions
local GRID_WIDTH = COLS * SLOT_SIZE + (COLS - 1) * SLOT_PADDING
local GRID_HEIGHT = ROWS * SLOT_SIZE + (ROWS - 1) * SLOT_PADDING
local PANEL_WIDTH = GRID_WIDTH + PANEL_PADDING * 2
local PANEL_HEIGHT = TOP_BAR_HEIGHT + GRID_HEIGHT + PANEL_PADDING * 2 + BOTTOM_BAR_HEIGHT

--------------------------------------------------------------------------------
-- CARGO / SLOT HELPERS
--------------------------------------------------------------------------------

-- Last player reference seen during draw; used by mouse handlers so they can
-- work with the same cargo component without threading the player object
-- through every call.
local lastPlayerForDraw = nil

-- Centralised helper to obtain a sane cargo component from the current player.
-- Always returns a table with maxSlots and slots fields when possible.
local function getCargoComponent()
    if not lastPlayerForDraw then
        return nil
    end

    local cargo = lastPlayerForDraw.cargo
    if not cargo or type(cargo) ~= "table" then
        return nil
    end

    cargo.maxSlots = cargo.maxSlots or (COLS * ROWS)
    cargo.slots = cargo.slots or {}

    return cargo
end

local function drawHudItemIcon(id, cx, cy, size, palette)
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
-- SLOT LAYOUT HELPERS
--------------------------------------------------------------------------------

-- Compute the rectangle for a given slot index within the current panel
-- layout.
local function getSlotRect(layout, index)
    local col = (index - 1) % COLS
    local row = math.floor((index - 1) / COLS)

    local gridStartX = layout.panelX + PANEL_PADDING
    local gridStartY = layout.contentY + PANEL_PADDING

    local slotX = gridStartX + col * (SLOT_SIZE + SLOT_PADDING)
    local slotY = gridStartY + row * (SLOT_SIZE + SLOT_PADDING)

    return slotX, slotY, SLOT_SIZE, SLOT_SIZE
end

-- Find the slot index under the given mouse coordinates, or nil when the
-- cursor is not over any slot.
local function hitTestSlot(layout, mx, my, maxSlots)
    if not layout then
        return nil
    end

    local totalSlots = math.min(maxSlots or (COLS * ROWS), COLS * ROWS)

    for index = 1, totalSlots do
        local slotX, slotY, slotW, slotH = getSlotRect(layout, index)
        if mx >= slotX and mx <= slotX + slotW and my >= slotY and my <= slotY + slotH then
            return index
        end
    end

    return nil
end

--------------------------------------------------------------------------------
-- DRAG STATE
--------------------------------------------------------------------------------

-- Local drag state for click-and-drag interactions inside the cargo grid.
local dragState = {
    active = false,
    fromIndex = nil,
    item = nil,     -- { id = "stone", quantity = 12 }
    mouseX = 0,
    mouseY = 0,
    mode = nil,     -- "move" for full-stack drag, "split" for Shift-click half-stack drag
}

local function clearDragState()
    dragState.active = false
    dragState.fromIndex = nil
    dragState.item = nil
    dragState.mouseX = 0
    dragState.mouseY = 0
    dragState.mode = nil
end

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

local function getPanelPosition()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local px = windowState.x or (w - PANEL_WIDTH) / 2
    local py = windowState.y or (h - PANEL_HEIGHT) / 2
    return px, py
end

local function isPointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function findExistingStack(slots, maxSlots, id)
    for i = 1, maxSlots do
        local slot = slots[i]
        if slot and slot.id == id then
            return i
        end
    end
    return nil
end

local function findEmptySlot(slots, maxSlots)
    for i = 1, maxSlots do
        local slot = slots[i]
        if not slot or slot.id == nil then
            return i
        end
    end
    return nil
end

function hud_cargo.tryAcceptExternalResourceStack(resourceId, quantity, x, y)
    if not resourceId or not quantity or quantity <= 0 then
        return 0
    end

    local cargo = getCargoComponent()
    if not cargo then
        return 0
    end

    local layout = window_frame.getLayout(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
    })

    local panelX = layout.panelX
    local panelY = layout.panelY
    local panelW = layout.panelWidth
    local panelH = layout.panelHeight

    if x < panelX or x > panelX + panelW or y < panelY or y > panelY + panelH then
        return 0
    end

    local slots = cargo.slots or {}
    cargo.slots = slots
    local maxSlots = cargo.maxSlots or (COLS * ROWS)

    local destIndex = hitTestSlot(layout, x, y, maxSlots)
    local targetIndex = nil

    if destIndex and destIndex >= 1 and destIndex <= maxSlots then
        local destSlot = slots[destIndex]
        if not destSlot or not destSlot.id or destSlot.id == resourceId then
            targetIndex = destIndex
        end
    end

    if not targetIndex then
        targetIndex = findExistingStack(slots, maxSlots, resourceId)
    end

    if not targetIndex then
        targetIndex = findEmptySlot(slots, maxSlots)
    end

    if not targetIndex then
        return 0
    end

    local slot = slots[targetIndex]
    if not slot or not slot.id then
        slot = {
            id = resourceId,
            quantity = 0,
        }
        slots[targetIndex] = slot
    end

    slot.quantity = (slot.quantity or 0) + quantity

    return quantity
end

function hud_cargo.dockNextToLoot(lootLayout)
    if not lootLayout or windowState.userAnchored then
        return
    end

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local margin = 16

    -- Position cargo to the LEFT of the loot panel
    local desiredX = lootLayout.panelX - margin - PANEL_WIDTH
    local desiredY = lootLayout.panelY

    -- Fallback: if it doesn't fit on the left, try the right side
    if desiredX < 0 then
        local rightX = lootLayout.panelX + lootLayout.panelWidth + margin
        if rightX + PANEL_WIDTH <= screenW then
            desiredX = rightX
        else
            desiredX = math.max(0, math.min(screenW - PANEL_WIDTH, desiredX))
        end
    end

    windowState.x = math.max(0, math.min(screenW - PANEL_WIDTH, desiredX))
    windowState.y = math.max(0, math.min(screenH - PANEL_HEIGHT, desiredY))
end

--------------------------------------------------------------------------------
-- MOUSE HANDLING
--------------------------------------------------------------------------------

function hud_cargo.mousepressed(x, y, button)
    -- First let the shared window_frame handle close button, title bar dragging
    -- and generic "inside window" hit testing.
    local result = window_frame.mousepressed(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
    }, x, y, button)

    if button ~= 1 then
        return result
    end

    -- If the click initiated a frame drag or closed the window, we do not
    -- start an inventory drag.
    if result == "close" or result == "drag" then
        if result == "drag" then
            windowState.userAnchored = true
        end
        clearDragState()
        return result
    end

    -- Only consider starting an item drag for clicks that landed inside the
    -- cargo window.
    if result == true then
        local cargo = getCargoComponent()
        if cargo then
            local layout = window_frame.getLayout(windowState, {
                fixedWidth = PANEL_WIDTH,
                fixedHeight = PANEL_HEIGHT,
            })

            local slotIndex = hitTestSlot(layout, x, y, cargo.maxSlots)
            if slotIndex then
                local slots = cargo.slots or {}
                local slot = slots[slotIndex]

                if slot and slot.id and slot.quantity and slot.quantity > 0 then
                    -- Support Shift-click stack splitting: when Shift is held and the
                    -- stack has more than one unit, we begin a drag with half the
                    -- stack (rounded down, minimum 1) and leave the remainder in the
                    -- origin slot.
                    local isShift = coreInput.down("modifier_shift")
                    local quantity = slot.quantity or 0

                    if isShift and quantity > 1 then
                        local take = math.floor(quantity / 2)
                        if take < 1 then
                            take = 1
                        end
                        local remaining = quantity - take
                        if remaining > 0 then
                            slot.quantity = remaining
                        else
                            slots[slotIndex] = nil
                        end

                        dragState.active = true
                        dragState.fromIndex = slotIndex
                        dragState.item = {
                            id = slot.id,
                            quantity = take,
                        }
                        dragState.mouseX = x
                        dragState.mouseY = y
                        dragState.mode = "split"
                    else
                        -- Full-stack drag: remove the stack from the origin slot and
                        -- carry the entire quantity.
                        dragState.active = true
                        dragState.fromIndex = slotIndex
                        dragState.item = {
                            id = slot.id,
                            quantity = quantity,
                        }
                        dragState.mouseX = x
                        dragState.mouseY = y
                        dragState.mode = "move"

                        slots[slotIndex] = nil
                    end

                    return true
                end
            end
        end
    end

    return result
end

function hud_cargo.mousereleased(x, y, button)
    -- Always forward to the frame first so any drag state on the window itself
    -- is cleaned up.
    window_frame.mousereleased(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
    }, x, y, button)

    if button ~= 1 or not dragState.active then
        return
    end

    local cargo = getCargoComponent()
    if not cargo then
        clearDragState()
        return
    end

    local layout = window_frame.getLayout(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
    })

    local panelX = layout.panelX
    local panelY = layout.panelY
    local panelW = layout.panelWidth
    local panelH = layout.panelHeight

    local insidePanel = x >= panelX and x <= panelX + panelW and y >= panelY and y <= panelY + panelH

    local slots = cargo.slots or {}
    local maxSlots = cargo.maxSlots or (COLS * ROWS)
    local fromIndex = dragState.fromIndex
    local dragged = dragState.item
    local mode = dragState.mode or "move"

    if not dragged or not dragged.id or not dragged.quantity or dragged.quantity <= 0 then
        clearDragState()
        return
    end

    if not insidePanel then
        ----------------------------------------------------------------------
        -- Drop into space: convert the dragged stack back into a world item
        -- at the cursor's world position. For split drags this only jettisons
        -- the split-off portion; the remainder was already left in the origin
        -- slot when the drag began.
        ----------------------------------------------------------------------
        local worldX, worldY = camera.screenToWorld(x, y)
        local ecsWorld = worldRef.get and worldRef.get() or nil
        if ecsWorld and ecsWorld.spawnItem then
            ecsWorld:spawnItem(worldX, worldY, dragged.id, dragged.quantity)
        end

        clearDragState()
        return
    end

    ----------------------------------------------------------------------
    -- Drop back into the cargo window: move/swap stacks between slots.
    ----------------------------------------------------------------------
    local destIndex = hitTestSlot(layout, x, y, maxSlots)

    if mode == "move" then
        if destIndex and destIndex >= 1 and destIndex <= maxSlots and fromIndex and fromIndex >= 1 and fromIndex <= maxSlots then
            if destIndex == fromIndex then
                -- Dropped back on the origin: simply restore the stack.
                slots[destIndex] = dragged
            else
                local existing = slots[destIndex]
                -- When dropping onto a filled slot:
                --   - Same item id: stack quantities together.
                --   - Different item id: swap the two stacks.
                if existing and existing.id and existing.id == dragged.id then
                    existing.quantity = (existing.quantity or 0) + dragged.quantity
                else
                    slots[destIndex] = dragged

                    -- If the destination was occupied, move that stack back to the
                    -- origin so the interaction behaves like a swap.
                    if existing and existing.id then
                        slots[fromIndex] = existing
                    end
                end
            end
        elseif fromIndex and fromIndex >= 1 and fromIndex <= maxSlots then
            -- Not over any slot: restore stack to its origin.
            slots[fromIndex] = dragged
        end
    else
        -- Split-mode drag (Shift-click): we moved only part of the origin stack.
        if not (fromIndex and fromIndex >= 1 and fromIndex <= maxSlots) then
            clearDragState()
            return
        end

        if destIndex and destIndex >= 1 and destIndex <= maxSlots then
            if destIndex == fromIndex then
                -- Dropped back on the origin slot: merge the split-off stack back
                -- into whatever remainder is there.
                local origin = slots[fromIndex]
                if origin and origin.id == dragged.id then
                    origin.quantity = (origin.quantity or 0) + dragged.quantity
                else
                    slots[fromIndex] = dragged
                end
            else
                local destSlot = slots[destIndex]
                if not destSlot then
                    -- Empty destination: move the split stack there.
                    slots[destIndex] = dragged
                elseif destSlot.id == dragged.id then
                    -- Same type: merge stacks in the destination slot.
                    destSlot.quantity = (destSlot.quantity or 0) + dragged.quantity
                else
                    -- Different item in destination: cannot combine; restore the
                    -- split stack back into the origin slot.
                    local origin = slots[fromIndex]
                    if origin and origin.id == dragged.id then
                        origin.quantity = (origin.quantity or 0) + dragged.quantity
                    else
                        slots[fromIndex] = dragged
                    end
                end
            end
        else
            -- Inside window but not over any slot: merge back into origin.
            local origin = slots[fromIndex]
            if origin and origin.id == dragged.id then
                origin.quantity = (origin.quantity or 0) + dragged.quantity
            else
                slots[fromIndex] = dragged
            end
        end
    end

    clearDragState()
end

function hud_cargo.mousemoved(x, y)
    window_frame.mousemoved(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
    }, x, y)

    if dragState.active then
        dragState.mouseX = x
        dragState.mouseY = y
    end
end

function hud_cargo.reset()
    window_frame.reset(windowState)
    windowState.userAnchored = false
    clearDragState()
end

--------------------------------------------------------------------------------
-- MAIN DRAW FUNCTION
--------------------------------------------------------------------------------

function hud_cargo.draw(player, colors)
    local font = love.graphics.getFont()

    -- Remember the player reference for mouse handlers so they can query the
    -- same cargo component that this draw call used.
    lastPlayerForDraw = player

    -- Draw the shared window frame and obtain the layout rects for placing our
    -- inner cargo grid.
    local layout = window_frame.draw(windowState, {
        fixedWidth = PANEL_WIDTH,
        fixedHeight = PANEL_HEIGHT,
        title = "CARGO",
    }, colors)

    local panelX = layout.panelX
    local panelY = layout.panelY
    local panelW = layout.panelWidth
    local panelH = layout.panelHeight

    -- Grid area for the 4x4 slot layout.
    local gridStartX = panelX + PANEL_PADDING
    local gridStartY = layout.contentY + PANEL_PADDING

    -- Cargo contents are now driven by the slot-based inventory on the player.
    -- All slots begin empty and are populated as resources are collected via
    -- player.addCargoResource.
    local cargo = getCargoComponent() or {}
    local slots = cargo.slots or {}
    local maxSlots = cargo.maxSlots or (COLS * ROWS)
    local totalSlots = math.min(maxSlots, COLS * ROWS)

    -- Mouse position for hover feedback / jettison hints.
    local mouseX, mouseY = coreInput.getMousePosition()
    local mouseInsidePanel = mouseX >= panelX and mouseX <= panelX + panelW and mouseY >= panelY and mouseY <= panelY + panelH
    local hoveredIndex = hitTestSlot(layout, mouseX, mouseY, maxSlots)

    for index = 1, totalSlots do
        local col = (index - 1) % COLS
        local row = math.floor((index - 1) / COLS)

        local slotX = gridStartX + col * (SLOT_SIZE + SLOT_PADDING)
        local slotY = gridStartY + row * (SLOT_SIZE + SLOT_PADDING)

        -- Slot background is always drawn so the full 4x4 grid is visible even
        -- when the inventory is empty.
        love.graphics.setColor(1, 1, 1, 0.06)
        love.graphics.rectangle("fill", slotX, slotY, SLOT_SIZE, SLOT_SIZE)
        love.graphics.setColor(1, 1, 1, 0.12)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", slotX, slotY, SLOT_SIZE, SLOT_SIZE)

        local slot = slots[index]
        if slot and slot.id and slot.quantity and slot.quantity > 0 then
            local qty = slot.quantity or 0
            local slotCenterX = slotX + SLOT_SIZE / 2
            local slotCenterY = slotY + SLOT_SIZE / 2

            -- Resource icon (if a HUD icon drawer exists for this resource).
            local iconSize = 18
            drawHudItemIcon(slot.id, slotCenterX, slotCenterY - 4, iconSize, colors)

            -- Quantity at top-center
            local qtyText = tostring(math.floor(qty))
            local qtyWidth = font:getWidth(qtyText)
            love.graphics.setColor(1, 1, 1, 1.0)
            love.graphics.print(qtyText, slotCenterX - qtyWidth / 2, slotY + 4)

            -- Item name at bottom
            local def = itemDefs[slot.id]
            local label = (def and (def.displayName or def.id)) or tostring(slot.id)
            local labelWidth = font:getWidth(label)
            love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.8)
            love.graphics.print(label, slotCenterX - labelWidth / 2,
                slotY + SLOT_SIZE - font:getHeight() - 4)
        end

        -- Hover highlight: when the mouse is over a slot inside the panel,
        -- draw a subtle cyan border so the player can see the current drop
        -- target, both during normal hover and while dragging.
        if hoveredIndex == index and mouseInsidePanel then
            love.graphics.setColor(0.2, 0.9, 1.0, 0.9)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", slotX, slotY, SLOT_SIZE, SLOT_SIZE)
        end
    end

    -- If there is an active drag, render a floating preview of the dragged
    -- stack at the cursor position so it feels like the player is "holding"
    -- the item.
    if dragState.active and dragState.item and dragState.item.id then

        local qty = dragState.item.quantity or 0
        local mx = dragState.mouseX or 0
        local my = dragState.mouseY or 0

        local iconSize = 18
        drawHudItemIcon(dragState.item.id, mx, my - 4, iconSize, colors)

        local qtyText = tostring(math.floor(qty))
        local qtyWidth = font:getWidth(qtyText)
        love.graphics.setColor(1, 1, 1, 1.0)
        love.graphics.print(qtyText, mx - qtyWidth / 2, my - SLOT_SIZE / 2)

        -- When dragging outside the panel, add a warning border so it is clear
        -- that releasing here will jettison the stack into space.
        local dragInsidePanel = mx >= panelX and mx <= panelX + panelW and my >= panelY and my <= panelY + panelH
        if not dragInsidePanel then
            love.graphics.setColor(1.0, 0.35, 0.25, 0.95)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", panelX - 2, panelY - 2, panelW + 4, panelH + 4)
        end
    end

    -- Bottom bar hint is handled by window_frame.draw via the shared HUD theme.
end

return hud_cargo
