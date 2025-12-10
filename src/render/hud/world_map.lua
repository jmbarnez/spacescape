local hud_world_map = {}

local ui_theme = require("src.core.ui_theme")

--------------------------------------------------------------------------------
-- WINDOW STATE / LAYOUT
-- Shared window-style frame for the world map so it visually matches the
-- cargo window (top + bottom bars, draggable title bar, close button).
--------------------------------------------------------------------------------

local windowState = {
    x = nil, -- nil = center on screen
    y = nil,
    isDragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
}

-- Layout constants mirroring the cargo window so the map feels like part of
-- the same HUD family.
local TOP_BAR_HEIGHT = 40
local BOTTOM_BAR_HEIGHT = 36
local CLOSE_BUTTON_SIZE = 24
local PANEL_SCREEN_MARGIN = 40 -- Minimum distance from screen edge to panel

local function getPanelSize()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Make the map window large but still leave a margin around the edges.
    local panelWidth = math.max(600, screenW - PANEL_SCREEN_MARGIN * 2)
    local panelHeight = math.max(420, screenH - PANEL_SCREEN_MARGIN * 2)

    return panelWidth, panelHeight
end

local function getPanelPosition()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local panelWidth, panelHeight = getPanelSize()

    local px = windowState.x or (screenW - panelWidth) / 2
    local py = windowState.y or (screenH - panelHeight) / 2
    return px, py, panelWidth, panelHeight
end

local function isPointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- Full-screen world map overlay (rendered inside a HUD window frame)
--
-- This HUD widget renders a large world map window when the player presses
-- the M key. It reuses the same world / camera data as the minimap but scales
-- everything up to occupy most of the screen, showing the player, enemies and
-- asteroids.

local world = require("src.core.world")
local camera = require("src.core.camera")

--- Draw the full-screen world map overlay.
--
-- @param player       table       Player state table (x / y required).
-- @param colors       table       Shared color palette.
-- @param enemyList    table|nil   Optional list of enemies (each with x / y).
-- @param asteroidList table|nil   Optional list of asteroids (each with x / y).
function hud_world_map.draw(player, colors, enemyList, asteroidList)
    if not player then
        return
    end

    local font = love.graphics.getFont()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Mouse position is used for close button hover feedback.
    local mx, my = love.mouse.getPosition()

    -- Resolve window rect in screen-space using the shared window state.
    local panelX, panelY, panelWidth, panelHeight = getPanelPosition()

    -- Pull the shared window style so the galaxy map frame visually matches
    -- other HUD windows (cargo, future dialogs, etc.).
    local windowStyle = ui_theme.window

    --------------------------------------------------------------------------
    -- Dim the gameplay behind the map for clarity (subtle glass overlay)
    --------------------------------------------------------------------------
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    --------------------------------------------------------------------------
    -- Main map window frame (matches cargo window theme)
    --------------------------------------------------------------------------
    -- Main panel background
    love.graphics.setColor(
        windowStyle.background[1],
        windowStyle.background[2],
        windowStyle.background[3],
        windowStyle.background[4]
    )
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 8, 8)

    -- Top bar
    love.graphics.setColor(
        windowStyle.topBar[1],
        windowStyle.topBar[2],
        windowStyle.topBar[3],
        windowStyle.topBar[4]
    )
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, TOP_BAR_HEIGHT, 8, 8)
    -- Fill the bottom corners of the top bar
    love.graphics.rectangle("fill", panelX, panelY + TOP_BAR_HEIGHT - 8, panelWidth, 8)

    -- Bottom bar
    love.graphics.setColor(
        windowStyle.bottomBar[1],
        windowStyle.bottomBar[2],
        windowStyle.bottomBar[3],
        windowStyle.bottomBar[4]
    )
    love.graphics.rectangle(
        "fill",
        panelX,
        panelY + panelHeight - BOTTOM_BAR_HEIGHT,
        panelWidth,
        BOTTOM_BAR_HEIGHT,
        8,
        8
    )
    love.graphics.rectangle(
        "fill",
        panelX,
        panelY + panelHeight - BOTTOM_BAR_HEIGHT,
        panelWidth,
        8
    )

    -- Border
    local borderColor = windowStyle.border or colors.uiPanelBorder or { 1, 1, 1, 0.5 }
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 8, 8)

    --------------------------------------------------------------------------
    -- Title + close button in the top bar; hint text in the bottom bar
    --------------------------------------------------------------------------
    local titleText = "GALAXY MAP"
    local hintText = "M to close  •  Drag title bar to move"

    -- Title (left side of top bar)
    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 1.0)
    local titleWidth = font:getWidth(titleText)
    local titleX = panelX + 12
    local titleY = panelY + (TOP_BAR_HEIGHT - font:getHeight()) / 2
    love.graphics.print(titleText, titleX, titleY)

    -- Close button (top-right)
    local closeX = panelX + panelWidth - CLOSE_BUTTON_SIZE - 4
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
    love.graphics.line(
        closeX + padding,
        closeY + padding,
        closeX + CLOSE_BUTTON_SIZE - padding,
        closeY + CLOSE_BUTTON_SIZE - padding
    )
    love.graphics.line(
        closeX + CLOSE_BUTTON_SIZE - padding,
        closeY + padding,
        closeX + padding,
        closeY + CLOSE_BUTTON_SIZE - padding
    )

    -- Hint text centered in the bottom bar
    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.5)
    local hintWidth = font:getWidth(hintText)
    local hintX = panelX + (panelWidth - hintWidth) / 2
    local hintY = panelY + panelHeight - BOTTOM_BAR_HEIGHT + (BOTTOM_BAR_HEIGHT - font:getHeight()) / 2
    love.graphics.print(hintText, hintX, hintY)

    --------------------------------------------------------------------------
    -- Map content area (inside the panel, below the title)
    --------------------------------------------------------------------------
    local mapMarginTop = TOP_BAR_HEIGHT + 12
    local mapPadding = 24
    local mapX = panelX + mapPadding
    local mapY = panelY + mapMarginTop
    local mapWidth = panelWidth - mapPadding * 2
    local mapHeight = panelHeight - mapMarginTop - BOTTOM_BAR_HEIGHT - mapPadding

    -- Draw a subtle background for the map area
    love.graphics.setColor(0.05, 0.08, 0.15, 1.0)
    love.graphics.rectangle("fill", mapX, mapY, mapWidth, mapHeight, 8, 8)

    --------------------------------------------------------------------------
    -- World-to-map projection (similar to minimap but scaled up)
    --------------------------------------------------------------------------
    local worldWidth = world.width or 1
    local worldHeight = world.height or 1
    if worldWidth <= 0 then worldWidth = 1 end
    if worldHeight <= 0 then worldHeight = 1 end

    local scaleX = mapWidth / worldWidth
    local scaleY = mapHeight / worldHeight
    local scale = math.min(scaleX, scaleY)

    local scaledWorldWidth = worldWidth * scale
    local scaledWorldHeight = worldHeight * scale

    local worldMinX = world.minX or 0
    local worldMinY = world.minY or 0

    -- Center the world rectangle in the map region
    local worldRectX = mapX + (mapWidth - scaledWorldWidth) * 0.5
    local worldRectY = mapY + (mapHeight - scaledWorldHeight) * 0.5

    local function worldToMap(wx, wy)
        local nx = (wx - worldMinX) * scale
        local ny = (wy - worldMinY) * scale
        return worldRectX + nx, worldRectY + ny
    end

    -- World bounds
    love.graphics.setColor(0.3, 0.45, 0.85, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", worldRectX, worldRectY, scaledWorldWidth, scaledWorldHeight)

    --------------------------------------------------------------------------
    -- Entities: player, enemies, asteroids
    --------------------------------------------------------------------------
    local px = player.x
    local py = player.y

    if px and py then
        local mx, my = worldToMap(px, py)
        love.graphics.setColor(colors.ship[1], colors.ship[2], colors.ship[3], 1.0)
        love.graphics.circle("fill", mx, my, 4, 20)
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", mx, my, 4.8, 20)
    end

    if enemyList and #enemyList > 0 then
        love.graphics.setLineWidth(1)
        for i = 1, #enemyList do
            local e = enemyList[i]
            local ex = e and e.x
            local ey = e and e.y
            if ex and ey then
                local mx, my = worldToMap(ex, ey)
                love.graphics.setColor(colors.enemy[1], colors.enemy[2], colors.enemy[3], 0.95)
                love.graphics.circle("fill", mx, my, 3, 12)
            end
        end
    end

    if asteroidList and #asteroidList > 0 then
        love.graphics.setLineWidth(1)
        for i = 1, #asteroidList do
            local a = asteroidList[i]
            local ax = a and a.x
            local ay = a and a.y
            if ax and ay then
                local mx, my = worldToMap(ax, ay)
                love.graphics.setColor(0.7, 0.7, 0.7, 0.9)
                love.graphics.circle("fill", mx, my, 2.5, 10)
            end
        end
    end

    --------------------------------------------------------------------------
    -- Coordinate readout (bottom-left of the panel)
    --------------------------------------------------------------------------
    local coordText
    if px and py then
        coordText = string.format("X: %d   Y: %d", math.floor(px + 0.5), math.floor(py + 0.5))
    else
        coordText = "X: --   Y: --"
    end

    local coordX = panelX + 20
    local coordY = panelY + panelHeight - BOTTOM_BAR_HEIGHT - font:getHeight() - 8
    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.9)
    love.graphics.print(coordText, coordX, coordY)

    --------------------------------------------------------------------------
    -- Legend (bottom-right)
    --------------------------------------------------------------------------
    local legendLines = {
        "Legend:",
        "  Player",
        "  Enemy",
        "  Asteroid",
    }

    local legendX = panelX + panelWidth - 180
    local legendY = coordY - (#legendLines * font:getHeight()) - 8

    for i = 1, #legendLines do
        local line = legendLines[i]
        local y = legendY + (i - 1) * font:getHeight()

        if line == "  Player" then
            love.graphics.setColor(colors.ship[1], colors.ship[2], colors.ship[3], 1.0)
        elseif line == "  Enemy" then
            love.graphics.setColor(colors.enemy[1], colors.enemy[2], colors.enemy[3], 1.0)
        elseif line == "  Asteroid" then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.9)
        else
            love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.9)
        end

        love.graphics.print(line, legendX, y)
    end
end

--------------------------------------------------------------------------------
-- MOUSE HANDLING
-- Mouse helpers mirror the cargo window so the map behaves like a standard
-- HUD window (draggable title bar, clickable close button).
--------------------------------------------------------------------------------

function hud_world_map.mousepressed(x, y, button)
    if button ~= 1 then
        return false
    end

    local panelX, panelY, panelWidth, panelHeight = getPanelPosition()

    -- Close button hit-test
    local closeX = panelX + panelWidth - CLOSE_BUTTON_SIZE - 4
    local closeY = panelY + 4
    if isPointInRect(x, y, closeX, closeY, CLOSE_BUTTON_SIZE, CLOSE_BUTTON_SIZE) then
        return "close"
    end

    -- Dragging via the top bar
    if isPointInRect(x, y, panelX, panelY, panelWidth, TOP_BAR_HEIGHT) then
        windowState.isDragging = true
        windowState.dragOffsetX = x - panelX
        windowState.dragOffsetY = y - panelY
        return "drag"
    end

    -- Swallow clicks inside the window so they do not reach gameplay
    if isPointInRect(x, y, panelX, panelY, panelWidth, panelHeight) then
        return true
    end

    return false
end

function hud_world_map.mousereleased(x, y, button)
    if button == 1 then
        windowState.isDragging = false
    end
end

function hud_world_map.mousemoved(x, y)
    if not windowState.isDragging then
        return
    end

    local panelWidth, panelHeight = getPanelSize()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    windowState.x = x - windowState.dragOffsetX
    windowState.y = y - windowState.dragOffsetY

    -- Clamp to screen bounds so the window cannot be dragged completely off-
    -- screen (matching cargo window behavior).
    windowState.x = math.max(0, math.min(screenW - panelWidth, windowState.x))
    windowState.y = math.max(0, math.min(screenH - panelHeight, windowState.y))
end

function hud_world_map.reset()
    windowState.x = nil
    windowState.y = nil
    windowState.isDragging = false
    windowState.dragOffsetX = 0
    windowState.dragOffsetY = 0
end

return hud_world_map
