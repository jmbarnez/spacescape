local hud_world_map = {}

local ui_theme = require("src.core.ui_theme")
local window_frame = require("src.render.hud.window_frame")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- WINDOW STATE / LAYOUT
-- Position / drag state for the galaxy map window. The shared window_frame
-- helper uses this table to compute placement and handle dragging.
--------------------------------------------------------------------------------

local windowState = {
    x = nil, -- nil = center on screen
    y = nil,
    isDragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
}

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
    local windowStyle = ui_theme.window
    local minimapStyle = ui_theme.minimap

    -- Draw the shared window frame and obtain the layout rects for placing the
    -- actual galaxy map content.
    local layout = window_frame.draw(windowState, {
        minWidth = 600,
        minHeight = 420,
        screenMargin = 40,
        title = "GALAXY MAP",
        hint = "M to close  •  Drag title bar to move",
    }, colors)

    local panelX = layout.panelX
    local panelY = layout.panelY
    local panelWidth = layout.panelWidth
    local panelHeight = layout.panelHeight

    --------------------------------------------------------------------------
    -- Map content area (inside the panel, below the title)
    --------------------------------------------------------------------------
    local mapPadding = 24
    local mapX = layout.contentX + mapPadding
    local mapY = layout.contentY + mapPadding
    local mapWidth = layout.contentWidth - mapPadding * 2
    local mapHeight = layout.contentHeight - mapPadding * 2

    -- Draw a subtle background for the map area
    love.graphics.setColor(0.05, 0.08, 0.15, 1.0)
    love.graphics.rectangle("fill", mapX, mapY, mapWidth, mapHeight, windowStyle.radius or 6, windowStyle.radius or 6)

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

    -- World bounds (reuse minimap-style boundary color for consistency)
    love.graphics.setColor(
        minimapStyle.worldBounds[1],
        minimapStyle.worldBounds[2],
        minimapStyle.worldBounds[3],
        minimapStyle.worldBounds[4] or 1.0
    )
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
    local coordY = (layout.bottomBarY or (panelY + panelHeight)) - font:getHeight() - 8
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
-- HUD window (draggable title bar, clickable close button). All heavy lifting
-- is delegated to the shared window_frame helper.
--------------------------------------------------------------------------------

function hud_world_map.mousepressed(x, y, button)
    return window_frame.mousepressed(windowState, {
        minWidth = 600,
        minHeight = 420,
        screenMargin = 40,
    }, x, y, button)
end

function hud_world_map.mousereleased(x, y, button)
    window_frame.mousereleased(windowState, {
        minWidth = 600,
        minHeight = 420,
        screenMargin = 40,
    }, x, y, button)
end

function hud_world_map.mousemoved(x, y)
    window_frame.mousemoved(windowState, {
        minWidth = 600,
        minHeight = 420,
        screenMargin = 40,
    }, x, y)
end

function hud_world_map.reset()
    window_frame.reset(windowState)
end

return hud_world_map
