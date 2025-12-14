local hud_world_map = {}

local ui_theme = require("src.core.ui_theme")
local window_frame = require("src.render.hud.window_frame")
local coreInput = require("src.core.input")

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

local viewState = {
    centerX = nil,
    centerY = nil,
    zoom = 1.0,
    isPanning = false,
    lastMouseX = 0,
    lastMouseY = 0,
    lastIndicatorPulseAt = nil,
    lastDrawTime = nil,
}

-- Full-screen world map overlay (rendered inside a HUD window frame)
--
-- This HUD widget renders a large world map window when the player presses
-- the M key. It reuses the same world / camera data as the minimap but scales
-- everything up to occupy most of the screen, showing the player, enemies and
-- asteroids.

local world = require("src.core.world")

local function isPointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function getLayoutOpts()
    return {
        minWidth = 600,
        minHeight = 420,
        screenMargin = 40,
    }
end

local function getDrawOpts()
    local opts = getLayoutOpts()
    opts.title = "GALAXY MAP"
    return opts
end

local function computeMapRect(layout)
    local mapPadding = 24
    local mapX = layout.contentX + mapPadding
    local mapY = layout.contentY + mapPadding
    local mapWidth = layout.contentWidth - mapPadding * 2
    local mapHeight = layout.contentHeight - mapPadding * 2
    return mapX, mapY, mapWidth, mapHeight
end

local function clampViewCenter(centerX, centerY, mapWidth, mapHeight, pixelsPerUnit, worldMinX, worldMinY, worldMaxX, worldMaxY)
    if not centerX or not centerY then
        return centerX, centerY
    end

    local halfViewW = (mapWidth / 2) / pixelsPerUnit
    local halfViewH = (mapHeight / 2) / pixelsPerUnit

    local minCX = worldMinX + halfViewW
    local maxCX = worldMaxX - halfViewW
    local minCY = worldMinY + halfViewH
    local maxCY = worldMaxY - halfViewH

    if minCX > maxCX then
        centerX = (worldMinX + worldMaxX) / 2
    else
        centerX = math.max(minCX, math.min(maxCX, centerX))
    end

    if minCY > maxCY then
        centerY = (worldMinY + worldMaxY) / 2
    else
        centerY = math.max(minCY, math.min(maxCY, centerY))
    end

    return centerX, centerY
end

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

    local now = love.timer.getTime()

    local font = love.graphics.getFont()
    local windowStyle = ui_theme.window
    local minimapStyle = ui_theme.minimap

    -- Draw the shared window frame and obtain the layout rects for placing the
    -- actual galaxy map content.
    local layout = window_frame.draw(windowState, getDrawOpts(), colors)

    -- Pulse the zoom indicator the first frame after the map is opened.
    if (not viewState.lastDrawTime) or (now - viewState.lastDrawTime > 0.25) then
        viewState.lastIndicatorPulseAt = now
    end
    viewState.lastDrawTime = now

    local panelX = layout.panelX
    local panelY = layout.panelY
    local panelWidth = layout.panelWidth
    local panelHeight = layout.panelHeight

    --------------------------------------------------------------------------
    -- Map content area (inside the panel, below the title)
    --------------------------------------------------------------------------
    local mapX, mapY, mapWidth, mapHeight = computeMapRect(layout)

    -- Draw a subtle background for the map area
    love.graphics.setColor(0.05, 0.05, 0.05, 1.0)
    love.graphics.rectangle("fill", mapX, mapY, mapWidth, mapHeight, windowStyle.radius or 6, windowStyle.radius or 6)

    --------------------------------------------------------------------------
    -- World-to-map projection (similar to minimap but scaled up)
    --------------------------------------------------------------------------
    local worldWidth = world.width or 1
    local worldHeight = world.height or 1
    if worldWidth <= 0 then worldWidth = 1 end
    if worldHeight <= 0 then worldHeight = 1 end

    local worldMinX = world.minX or 0
    local worldMinY = world.minY or 0
    local worldMaxX = world.maxX or (worldMinX + worldWidth)
    local worldMaxY = world.maxY or (worldMinY + worldHeight)

    local baseScaleX = mapWidth / worldWidth
    local baseScaleY = mapHeight / worldHeight
    local basePixelsPerUnit = math.min(baseScaleX, baseScaleY)

    local MIN_ZOOM = 0.5
    local MAX_ZOOM = 6.0
    viewState.zoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, viewState.zoom or 1.0))
    local pixelsPerUnit = basePixelsPerUnit * viewState.zoom

    local px = player.position and player.position.x or player.x
    local py = player.position and player.position.y or player.y

    if viewState.centerX == nil or viewState.centerY == nil then
        if px and py then
            viewState.centerX = px
            viewState.centerY = py
        else
            viewState.centerX = world.centerX or (worldMinX + worldMaxX) / 2
            viewState.centerY = world.centerY or (worldMinY + worldMaxY) / 2
        end
    end

    local mapCenterX = mapX + mapWidth / 2
    local mapCenterY = mapY + mapHeight / 2

    viewState.centerX, viewState.centerY = clampViewCenter(
        viewState.centerX,
        viewState.centerY,
        mapWidth,
        mapHeight,
        pixelsPerUnit,
        worldMinX,
        worldMinY,
        worldMaxX,
        worldMaxY
    )

    local function worldToMap(wx, wy)
        local dx = (wx - viewState.centerX) * pixelsPerUnit
        local dy = (wy - viewState.centerY) * pixelsPerUnit
        return mapCenterX + dx, mapCenterY + dy
    end

    love.graphics.setScissor(mapX, mapY, mapWidth, mapHeight)

    -- World bounds (reuse minimap-style boundary color for consistency)
    local boundsX1, boundsY1 = worldToMap(worldMinX, worldMinY)
    local boundsX2, boundsY2 = worldToMap(worldMaxX, worldMaxY)
    local boundsX = math.min(boundsX1, boundsX2)
    local boundsY = math.min(boundsY1, boundsY2)
    local boundsW = math.abs(boundsX2 - boundsX1)
    local boundsH = math.abs(boundsY2 - boundsY1)

    love.graphics.setColor(
        minimapStyle.worldBounds[1],
        minimapStyle.worldBounds[2],
        minimapStyle.worldBounds[3],
        minimapStyle.worldBounds[4] or 1.0
    )
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", boundsX, boundsY, boundsW, boundsH)

    --------------------------------------------------------------------------
    -- Entities: player, enemies, asteroids
    --------------------------------------------------------------------------
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
            local ex = e and (e.position and e.position.x or e.x)
            local ey = e and (e.position and e.position.y or e.y)
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
            local ax = a and (a.position and a.position.x or a.x)
            local ay = a and (a.position and a.position.y or a.y)
            if ax and ay then
                local mx, my = worldToMap(ax, ay)
                love.graphics.setColor(0.7, 0.7, 0.7, 0.9)
                love.graphics.circle("fill", mx, my, 2.5, 10)
            end
        end
    end

    love.graphics.setScissor()

    --------------------------------------------------------------------------
    -- Zoom indicator (anchored to window frame, fades out)
    --------------------------------------------------------------------------
    local indicatorAlpha = 0
    local pulseAt = viewState.lastIndicatorPulseAt
    if pulseAt then
        local HOLD_SECONDS = 1.0
        local FADE_SECONDS = 0.4
        local age = now - pulseAt
        local baseAlpha = 0.7

        if age <= HOLD_SECONDS then
            indicatorAlpha = baseAlpha
        elseif age <= HOLD_SECONDS + FADE_SECONDS then
            local t = (age - HOLD_SECONDS) / FADE_SECONDS
            indicatorAlpha = baseAlpha * (1 - t)
        end
    end

    if indicatorAlpha > 0.01 then
        local zoomValue = viewState.zoom or 1.0
        local zoomText = string.format("Zoom: %.1fx", zoomValue)

        local zoomPadX = 10
        local zoomPadY = 4
        local zoomTextW = font:getWidth(zoomText)
        local zoomTextH = font:getHeight()
        local zoomBoxW = zoomTextW + zoomPadX * 2
        local zoomBoxH = zoomTextH + zoomPadY * 2

        local closeSize = windowStyle.closeButtonSize or 24
        local closePadding = 4
        local closeX = layout.panelX + layout.panelWidth - closeSize - closePadding

        local zoomBoxX = closeX - 10 - zoomBoxW
        local zoomBoxY = layout.panelY + (layout.topBarHeight - zoomBoxH) / 2

        -- Avoid drifting left into the title.
        local minX = layout.panelX + 160
        if zoomBoxX < minX then
            zoomBoxX = minX
        end

        love.graphics.setColor(0, 0, 0, 0.35 * indicatorAlpha)
        love.graphics.rectangle("fill", zoomBoxX, zoomBoxY, zoomBoxW, zoomBoxH)
        love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], indicatorAlpha)
        love.graphics.print(zoomText, zoomBoxX + zoomPadX, zoomBoxY + zoomPadY)
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
    local result = window_frame.mousepressed(windowState, getLayoutOpts(), x, y, button)

    if button ~= 1 then
        return result
    end

    if result == "close" or result == "drag" then
        return result
    end

    if result == true then
        local layout = window_frame.getLayout(windowState, getLayoutOpts())
        local mapX, mapY, mapW, mapH = computeMapRect(layout)
        if isPointInRect(x, y, mapX, mapY, mapW, mapH) then
            viewState.isPanning = true
            viewState.lastMouseX = x
            viewState.lastMouseY = y
            return true
        end
    end

    return result
end

function hud_world_map.mousereleased(x, y, button)
    window_frame.mousereleased(windowState, getLayoutOpts(), x, y, button)
    if button == 1 then
        viewState.isPanning = false
    end
end

function hud_world_map.mousemoved(x, y)
    window_frame.mousemoved(windowState, getLayoutOpts(), x, y)

    if not viewState.isPanning then
        return
    end

    local layout = window_frame.getLayout(windowState, getLayoutOpts())
    local mapX, mapY, mapW, mapH = computeMapRect(layout)
    if mapW <= 0 or mapH <= 0 then
        return
    end

    local worldWidth = world.width or 1
    local worldHeight = world.height or 1
    if worldWidth <= 0 then worldWidth = 1 end
    if worldHeight <= 0 then worldHeight = 1 end

    local worldMinX = world.minX or 0
    local worldMinY = world.minY or 0
    local worldMaxX = world.maxX or (worldMinX + worldWidth)
    local worldMaxY = world.maxY or (worldMinY + worldHeight)

    local baseScaleX = mapW / worldWidth
    local baseScaleY = mapH / worldHeight
    local basePixelsPerUnit = math.min(baseScaleX, baseScaleY)
    local pixelsPerUnit = basePixelsPerUnit * (viewState.zoom or 1.0)
    if pixelsPerUnit <= 0 then
        return
    end

    local dx = x - (viewState.lastMouseX or x)
    local dy = y - (viewState.lastMouseY or y)
    viewState.lastMouseX = x
    viewState.lastMouseY = y

    viewState.centerX = (viewState.centerX or (worldMinX + worldMaxX) / 2) - dx / pixelsPerUnit
    viewState.centerY = (viewState.centerY or (worldMinY + worldMaxY) / 2) - dy / pixelsPerUnit

    viewState.centerX, viewState.centerY = clampViewCenter(
        viewState.centerX,
        viewState.centerY,
        mapW,
        mapH,
        pixelsPerUnit,
        worldMinX,
        worldMinY,
        worldMaxX,
        worldMaxY
    )
end

function hud_world_map.wheelmoved(x, y)
    if not y or y == 0 then
        return false
    end

    viewState.lastIndicatorPulseAt = love.timer.getTime()

    local layout = window_frame.getLayout(windowState, getLayoutOpts())
    local mapX, mapY, mapW, mapH = computeMapRect(layout)
    if mapW <= 0 or mapH <= 0 then
        return false
    end

    local mx, my = coreInput.getMousePosition()
    local mouseOverMap = isPointInRect(mx, my, mapX, mapY, mapW, mapH)

    local worldWidth = world.width or 1
    local worldHeight = world.height or 1
    if worldWidth <= 0 then worldWidth = 1 end
    if worldHeight <= 0 then worldHeight = 1 end

    local worldMinX = world.minX or 0
    local worldMinY = world.minY or 0
    local worldMaxX = world.maxX or (worldMinX + worldWidth)
    local worldMaxY = world.maxY or (worldMinY + worldHeight)

    local baseScaleX = mapW / worldWidth
    local baseScaleY = mapH / worldHeight
    local basePixelsPerUnit = math.min(baseScaleX, baseScaleY)

    local MIN_ZOOM = 0.5
    local MAX_ZOOM = 6.0
    local prevZoom = viewState.zoom or 1.0
    local zoomFactor = 1.15 ^ y
    local newZoom = prevZoom * zoomFactor
    newZoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, newZoom))

    if newZoom == prevZoom then
        return true
    end

    local prevPixelsPerUnit = basePixelsPerUnit * prevZoom
    local newPixelsPerUnit = basePixelsPerUnit * newZoom
    if prevPixelsPerUnit <= 0 or newPixelsPerUnit <= 0 then
        return true
    end

    local mapCenterX = mapX + mapW / 2
    local mapCenterY = mapY + mapH / 2

    if viewState.centerX == nil or viewState.centerY == nil then
        viewState.centerX = world.centerX or (worldMinX + worldMaxX) / 2
        viewState.centerY = world.centerY or (worldMinY + worldMaxY) / 2
    end

    local anchorWorldX = viewState.centerX
    local anchorWorldY = viewState.centerY
    if mouseOverMap then
        anchorWorldX = viewState.centerX + (mx - mapCenterX) / prevPixelsPerUnit
        anchorWorldY = viewState.centerY + (my - mapCenterY) / prevPixelsPerUnit
    end

    viewState.zoom = newZoom

    if mouseOverMap then
        viewState.centerX = anchorWorldX - (mx - mapCenterX) / newPixelsPerUnit
        viewState.centerY = anchorWorldY - (my - mapCenterY) / newPixelsPerUnit
    end

    viewState.centerX, viewState.centerY = clampViewCenter(
        viewState.centerX,
        viewState.centerY,
        mapW,
        mapH,
        newPixelsPerUnit,
        worldMinX,
        worldMinY,
        worldMaxX,
        worldMaxY
    )

    return true
end

function hud_world_map.reset()
    window_frame.reset(windowState)
    viewState.centerX = nil
    viewState.centerY = nil
    viewState.zoom = 1.0
    viewState.isPanning = false
    viewState.lastMouseX = 0
    viewState.lastMouseY = 0
end

return hud_world_map
