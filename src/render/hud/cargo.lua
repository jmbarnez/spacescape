local hud_cargo = {}

local ui_theme = require("src.core.ui_theme")

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
}

-- Layout constants (4x4 grid)
local SLOT_SIZE = 90
local SLOT_PADDING = 8
local COLS = 4
local ROWS = 4
local PANEL_PADDING = 20
local TOP_BAR_HEIGHT = 40
local BOTTOM_BAR_HEIGHT = 36
local CLOSE_BUTTON_SIZE = 24

-- Calculate panel dimensions
local GRID_WIDTH = COLS * SLOT_SIZE + (COLS - 1) * SLOT_PADDING
local GRID_HEIGHT = ROWS * SLOT_SIZE + (ROWS - 1) * SLOT_PADDING
local PANEL_WIDTH = GRID_WIDTH + PANEL_PADDING * 2
local PANEL_HEIGHT = TOP_BAR_HEIGHT + GRID_HEIGHT + PANEL_PADDING * 2 + BOTTOM_BAR_HEIGHT

--------------------------------------------------------------------------------
-- RESOURCE ICON DRAWERS
--------------------------------------------------------------------------------

local function drawStoneIcon(cx, cy, size)
    local segments = 6
    local points = {}
    for i = 0, segments - 1 do
        local t = i / segments
        local angle = t * math.pi * 2
        local noise = 1 + math.sin(i * 2.1) * 0.3
        local pr = size * (0.7 + 0.3 * noise)
        points[#points + 1] = cx + math.cos(angle) * pr
        points[#points + 1] = cy + math.sin(angle) * pr
    end
    love.graphics.setColor(0.55, 0.50, 0.44, 1.0)
    love.graphics.polygon("fill", points)
    love.graphics.setColor(0.25, 0.22, 0.18, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", points)
end

local function drawIceIcon(cx, cy, size)
    local segments = 6
    local points = {}
    for i = 0, segments - 1 do
        local t = i / segments
        local angle = t * math.pi * 2
        local noise = 1 + math.sin(i * 2.7) * 0.2
        local pr = size * (0.75 + 0.25 * noise)
        points[#points + 1] = cx + math.cos(angle) * pr
        points[#points + 1] = cy + math.sin(angle) * pr
    end
    love.graphics.setColor(0.78, 0.86, 0.96, 1.0)
    love.graphics.polygon("fill", points)
    love.graphics.setColor(0.30, 0.40, 0.55, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", points)
end

local function drawMithrilIcon(cx, cy, size)
    local topX, topY = cx, cy - size
    local rightX, rightY = cx + size * 0.75, cy
    local bottomX, bottomY = cx, cy + size * 1.1
    local leftX, leftY = cx - size * 0.75, cy

    love.graphics.setColor(0.86, 0.98, 1.00, 1.0)
    love.graphics.polygon("fill", topX, topY, rightX, rightY, bottomX, bottomY, leftX, leftY)
    love.graphics.setColor(1.0, 1.0, 1.0, 0.4)
    local glowSize = size * 0.5
    love.graphics.polygon("fill", cx, cy - glowSize, cx + glowSize * 0.5, cy, cx, cy + glowSize * 0.7,
        cx - glowSize * 0.5, cy)
    love.graphics.setColor(0.18, 0.35, 0.42, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", topX, topY, rightX, rightY, bottomX, bottomY, leftX, leftY)
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

--------------------------------------------------------------------------------
-- MOUSE HANDLING
--------------------------------------------------------------------------------

function hud_cargo.mousepressed(x, y, button)
    if button ~= 1 then return false end

    local panelX, panelY = getPanelPosition()

    -- Check close button
    local closeX = panelX + PANEL_WIDTH - CLOSE_BUTTON_SIZE - 4
    local closeY = panelY + 4
    if isPointInRect(x, y, closeX, closeY, CLOSE_BUTTON_SIZE, CLOSE_BUTTON_SIZE) then
        return "close"
    end

    -- Check top bar for dragging
    if isPointInRect(x, y, panelX, panelY, PANEL_WIDTH, TOP_BAR_HEIGHT) then
        windowState.isDragging = true
        windowState.dragOffsetX = x - panelX
        windowState.dragOffsetY = y - panelY
        return "drag"
    end

    return false
end

function hud_cargo.mousereleased(x, y, button)
    if button == 1 then
        windowState.isDragging = false
    end
end

function hud_cargo.mousemoved(x, y)
    if windowState.isDragging then
        windowState.x = x - windowState.dragOffsetX
        windowState.y = y - windowState.dragOffsetY

        -- Clamp to screen bounds
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()
        windowState.x = math.max(0, math.min(w - PANEL_WIDTH, windowState.x))
        windowState.y = math.max(0, math.min(h - PANEL_HEIGHT, windowState.y))
    end
end

function hud_cargo.reset()
    windowState.x = nil
    windowState.y = nil
    windowState.isDragging = false
end

--------------------------------------------------------------------------------
-- MAIN DRAW FUNCTION
--------------------------------------------------------------------------------

function hud_cargo.draw(player, colors)
    local font = love.graphics.getFont()
    local mx, my = love.mouse.getPosition()

    -- Resolve the shared window style once so all cargo visuals stay aligned
    -- with the global UI theme (same palette used by the world map window).
    local windowStyle = ui_theme.window

    local panelX, panelY = getPanelPosition()

    -- Main panel background
    love.graphics.setColor(
        windowStyle.background[1],
        windowStyle.background[2],
        windowStyle.background[3],
        windowStyle.background[4]
    )
    love.graphics.rectangle("fill", panelX, panelY, PANEL_WIDTH, PANEL_HEIGHT, 8, 8)

    -- Top bar
    love.graphics.setColor(
        windowStyle.topBar[1],
        windowStyle.topBar[2],
        windowStyle.topBar[3],
        windowStyle.topBar[4]
    )
    love.graphics.rectangle("fill", panelX, panelY, PANEL_WIDTH, TOP_BAR_HEIGHT, 8, 8)
    -- Fill the bottom corners of the top bar
    love.graphics.rectangle("fill", panelX, panelY + TOP_BAR_HEIGHT - 8, PANEL_WIDTH, 8)

    -- Bottom bar
    love.graphics.setColor(
        windowStyle.bottomBar[1],
        windowStyle.bottomBar[2],
        windowStyle.bottomBar[3],
        windowStyle.bottomBar[4]
    )
    love.graphics.rectangle("fill", panelX, panelY + PANEL_HEIGHT - BOTTOM_BAR_HEIGHT, PANEL_WIDTH, BOTTOM_BAR_HEIGHT, 8,
        8)
    love.graphics.rectangle("fill", panelX, panelY + PANEL_HEIGHT - BOTTOM_BAR_HEIGHT, PANEL_WIDTH, 8)

    -- Border
    local borderColor = windowStyle.border or colors.uiPanelBorder or { 1, 1, 1, 0.5 }
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, PANEL_WIDTH, PANEL_HEIGHT, 8, 8)

    -- Title in top bar
    local title = "CARGO"
    local titleWidth = font:getWidth(title)
    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 1.0)
    love.graphics.print(title, panelX + 12, panelY + (TOP_BAR_HEIGHT - font:getHeight()) / 2)

    -- Close button
    local closeX = panelX + PANEL_WIDTH - CLOSE_BUTTON_SIZE - 4
    local closeY = panelY + 4
    local closeHovered = isPointInRect(mx, my, closeX, closeY, CLOSE_BUTTON_SIZE, CLOSE_BUTTON_SIZE)

    if closeHovered then
        love.graphics.setColor(
            windowStyle.closeButtonBgHover[1],
            windowStyle.closeButtonBgHover[2],
            windowStyle.closeButtonBgHover[3],
            windowStyle.closeButtonBgHover[4]
        )
    else
        love.graphics.setColor(
            windowStyle.closeButtonBg[1],
            windowStyle.closeButtonBg[2],
            windowStyle.closeButtonBg[3],
            windowStyle.closeButtonBg[4]
        )
    end
    love.graphics.rectangle("fill", closeX, closeY, CLOSE_BUTTON_SIZE, CLOSE_BUTTON_SIZE, 4, 4)

    -- X icon
    if closeHovered then
        love.graphics.setColor(
            windowStyle.closeButtonXHover[1],
            windowStyle.closeButtonXHover[2],
            windowStyle.closeButtonXHover[3],
            windowStyle.closeButtonXHover[4]
        )
    else
        love.graphics.setColor(
            windowStyle.closeButtonX[1],
            windowStyle.closeButtonX[2],
            windowStyle.closeButtonX[3],
            windowStyle.closeButtonX[4]
        )
    end
    love.graphics.setLineWidth(2)
    local padding = 6
    love.graphics.line(closeX + padding, closeY + padding, closeX + CLOSE_BUTTON_SIZE - padding,
        closeY + CLOSE_BUTTON_SIZE - padding)
    love.graphics.line(closeX + CLOSE_BUTTON_SIZE - padding, closeY + padding, closeX + padding,
        closeY + CLOSE_BUTTON_SIZE - padding)

    -- Grid area
    local gridStartX = panelX + PANEL_PADDING
    local gridStartY = panelY + TOP_BAR_HEIGHT + PANEL_PADDING

    -- Cargo contents
    local cargo = player.cargo or {}
    -- 4x4 grid = 16 slots; only the defined resources will render icons/labels
    local resources = {
        { id = "stone",   label = "Stone",   drawIcon = drawStoneIcon },
        { id = "ice",     label = "Ice",     drawIcon = drawIceIcon },
        { id = "mithril", label = "Mithril", drawIcon = drawMithrilIcon },

        -- remaining slots are empty placeholders (show slot frame only)
        { id = nil, label = nil, drawIcon = nil },
        { id = nil, label = nil, drawIcon = nil },
        { id = nil, label = nil, drawIcon = nil },
        { id = nil, label = nil, drawIcon = nil },
        { id = nil, label = nil, drawIcon = nil },
        { id = nil, label = nil, drawIcon = nil },
        { id = nil, label = nil, drawIcon = nil },
        { id = nil, label = nil, drawIcon = nil },
        { id = nil, label = nil, drawIcon = nil },
        { id = nil, label = nil, drawIcon = nil },
        { id = nil, label = nil, drawIcon = nil },
        { id = nil, label = nil, drawIcon = nil },
        { id = nil, label = nil, drawIcon = nil },
    }

    for i, res in ipairs(resources) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)

        local slotX = gridStartX + col * (SLOT_SIZE + SLOT_PADDING)
        local slotY = gridStartY + row * (SLOT_SIZE + SLOT_PADDING)

        -- Slot background
        love.graphics.setColor(1, 1, 1, 0.06)
        love.graphics.rectangle("fill", slotX, slotY, SLOT_SIZE, SLOT_SIZE, 6, 6)
        love.graphics.setColor(1, 1, 1, 0.12)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", slotX, slotY, SLOT_SIZE, SLOT_SIZE, 6, 6)

        if res.id then
            local qty = cargo[res.id] or 0
            local slotCenterX = slotX + SLOT_SIZE / 2
            local slotCenterY = slotY + SLOT_SIZE / 2

            -- Draw resource icon
            local iconSize = 18
            res.drawIcon(slotCenterX, slotCenterY - 4, iconSize)

            -- Quantity at top-center
            local qtyText = tostring(math.floor(qty))
            local qtyWidth = font:getWidth(qtyText)
            love.graphics.setColor(1, 1, 1, 1.0)
            love.graphics.print(qtyText, slotCenterX - qtyWidth / 2, slotY + 4)

            -- Item name at bottom
            local labelWidth = font:getWidth(res.label)
            love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.8)
            love.graphics.print(res.label, slotCenterX - labelWidth / 2, slotY + SLOT_SIZE - font:getHeight() - 4)
        end
    end

    -- Bottom bar hint
    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.4)
    local hint = "TAB to close  •  Drag title bar to move"
    local hintWidth = font:getWidth(hint)
    love.graphics.print(hint, panelX + (PANEL_WIDTH - hintWidth) / 2,
        panelY + PANEL_HEIGHT - BOTTOM_BAR_HEIGHT + (BOTTOM_BAR_HEIGHT - font:getHeight()) / 2)
end

return hud_cargo
