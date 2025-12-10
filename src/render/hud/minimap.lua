local hud_minimap = {}

local ui_theme = require("src.core.ui_theme")

-- Minimap HUD widget
--
-- This module is responsible *only* for drawing a small world overview in the
-- top-right corner of the screen plus a coordinate readout directly beneath
-- it. Keeping this logic isolated here makes it easy to tweak layout or style
-- later without touching the rest of the HUD pipeline.

local world = require("src.core.world")
local camera = require("src.core.camera")

--- Draw the minimap and coordinate display.
--
-- @param player       table  Player state table; must at least expose x / y.
-- @param colors       table  Shared color palette from src.core.colors.
-- @param enemyList    table|nil Optional list of active enemies (each with x/y).
-- @param asteroidList table|nil Optional list of active asteroids (each with x/y).
function hud_minimap.draw(player, colors, enemyList, asteroidList)
    -- Defensive guard: if we have no player, there is nothing meaningful to
    -- show on the minimap, so we bail out early.
    if not player then
        return
    end

    local font = love.graphics.getFont()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    local hudPanelStyle = ui_theme.hudPanel
    local minimapStyle = ui_theme.minimap

    --------------------------------------------------------------------------
    -- Layout constants
    --
    -- The goal is "top-right" without colliding with the existing FPS text,
    -- which currently lives around (screenW - margin, 20). We start the panel
    -- a bit lower so both elements remain readable.
    --------------------------------------------------------------------------
    local panelMarginRight = 20   -- Distance from right screen edge
    local panelMarginTop = 52     -- Distance from top; > FPS Y so they do not overlap
    local panelWidth = 200        -- Overall minimap panel width (including padding)
    local panelHeight = 150       -- Overall minimap panel height (map only; coords sit below)

    local panelX = screenW - panelWidth - panelMarginRight
    local panelY = panelMarginTop

    --------------------------------------------------------------------------
    -- Panel background + border
    --------------------------------------------------------------------------
    love.graphics.setColor(
        hudPanelStyle.background[1],
        hudPanelStyle.background[2],
        hudPanelStyle.background[3],
        hudPanelStyle.background[4]
    )
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 8, 8)

    local borderColor = hudPanelStyle.border or colors.uiPanelBorder or { 1, 1, 1, 0.5 }
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 8, 8)

    --------------------------------------------------------------------------
    -- World-to-minimap projection setup
    --
    -- We reserve an inner rectangle inside the panel for the actual minimap
    -- content. The world extents (world.minX..world.maxX / minY..maxY) are
    -- projected into this area using a uniform scale so the aspect ratio of the
    -- world is preserved.
    --------------------------------------------------------------------------
    local mapPadding = 10
    local mapX = panelX + mapPadding
    local mapY = panelY + mapPadding
    local mapWidth = panelWidth - mapPadding * 2
    local mapHeight = panelHeight - mapPadding * 2

    local worldWidth = world.width or 1
    local worldHeight = world.height or 1
    if worldWidth <= 0 then worldWidth = 1 end
    if worldHeight <= 0 then worldHeight = 1 end

    local scaleX = mapWidth / worldWidth
    local scaleY = mapHeight / worldHeight
    local scale = math.min(scaleX, scaleY)

    local scaledWorldWidth = worldWidth * scale
    local scaledWorldHeight = worldHeight * scale

    -- World origin in minimap space: we use the authored world bounds so that
    -- (world.minX, world.minY) always maps to the same corner of the rectangle.
    local worldMinX = world.minX or 0
    local worldMinY = world.minY or 0

    -- Center the scaled world rectangle inside the map area.
    local worldRectX = mapX + (mapWidth - scaledWorldWidth) * 0.5
    local worldRectY = mapY + (mapHeight - scaledWorldHeight) * 0.5

    -- Helper: project a world-space point into minimap coordinates.
    local function worldToMinimap(wx, wy)
        local nx = (wx - worldMinX) * scale
        local ny = (wy - worldMinY) * scale
        return worldRectX + nx, worldRectY + ny
    end

    --------------------------------------------------------------------------
    -- Draw world bounds outline inside the panel
    --------------------------------------------------------------------------
    love.graphics.setColor(
        minimapStyle.worldBounds[1],
        minimapStyle.worldBounds[2],
        minimapStyle.worldBounds[3],
        minimapStyle.worldBounds[4]
    )
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", worldRectX, worldRectY, scaledWorldWidth, scaledWorldHeight)

    --------------------------------------------------------------------------
    -- Optional: camera viewport rectangle
    --
    -- This shows roughly which slice of the world the main camera is currently
    -- looking at. Because the camera is a shared module, we can read its
    -- position/scale directly without plumbed parameters.
    --------------------------------------------------------------------------
    if camera and camera.x and camera.y then
        local camScale = camera.scale or 1
        local halfViewW = (screenW / 2) / camScale
        local halfViewH = (screenH / 2) / camScale

        local camMinX = camera.x - halfViewW
        local camMaxX = camera.x + halfViewW
        local camMinY = camera.y - halfViewH
        local camMaxY = camera.y + halfViewH

        -- Clamp the viewport rectangle to the world bounds so we never draw
        -- outside the minimap world box.
        if world.minX then
            if camMinX < world.minX then camMinX = world.minX end
            if camMaxX > world.maxX then camMaxX = world.maxX end
        end
        if world.minY then
            if camMinY < world.minY then camMinY = world.minY end
            if camMaxY > world.maxY then camMaxY = world.maxY end
        end

        local vx1, vy1 = worldToMinimap(camMinX, camMinY)
        local vx2, vy2 = worldToMinimap(camMaxX, camMaxY)

        local viewX = math.min(vx1, vx2)
        local viewY = math.min(vy1, vy2)
        local viewW = math.abs(vx2 - vx1)
        local viewH = math.abs(vy2 - vy1)

        love.graphics.setColor(
            minimapStyle.viewport[1],
            minimapStyle.viewport[2],
            minimapStyle.viewport[3],
            minimapStyle.viewport[4]
        )
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", viewX, viewY, viewW, viewH)
    end

    --------------------------------------------------------------------------
    -- Player marker
    --------------------------------------------------------------------------
    local px = player.x
    local py = player.y

    if px and py then
        local mx, my = worldToMinimap(px, py)

        -- Core marker (filled circle)
        love.graphics.setColor(colors.ship[1], colors.ship[2], colors.ship[3], 1.0)
        local markerRadius = 3
        love.graphics.circle("fill", mx, my, markerRadius, 16)

        -- Thin outline for extra contrast on bright backgrounds
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", mx, my, markerRadius + 1, 16)
    end

    --------------------------------------------------------------------------
    -- Optional enemy / asteroid blips
    --
    -- These use small colored dots so they stay legible even when many
    -- entities are present. Lists are treated as optional; if nil, that
    -- category is simply skipped.
    --------------------------------------------------------------------------
    if enemyList and #enemyList > 0 then
        love.graphics.setLineWidth(1)
        for i = 1, #enemyList do
            local e = enemyList[i]
            local ex = e and e.x
            local ey = e and e.y
            if ex and ey then
                local mx, my = worldToMinimap(ex, ey)
                love.graphics.setColor(colors.enemy[1], colors.enemy[2], colors.enemy[3], 0.9)
                love.graphics.circle("fill", mx, my, 2, 8)
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
                local mx, my = worldToMinimap(ax, ay)
                -- Slightly dimmer, neutral tone so enemies remain visually
                -- dominant on the minimap.
                love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
                love.graphics.circle("fill", mx, my, 2, 8)
            end
        end
    end

    --------------------------------------------------------------------------
    -- Coordinate readout (directly underneath the minimap panel)
    --------------------------------------------------------------------------
    local coordText
    if px and py then
        -- Round to whole units so the numbers are stable and easy to read.
        coordText = string.format("X: %d   Y: %d", math.floor(px + 0.5), math.floor(py + 0.5))
    else
        coordText = "X: --   Y: --"
    end

    local textWidth = font:getWidth(coordText)
    local textX = panelX + panelWidth / 2 - textWidth / 2
    local textY = panelY + panelHeight + 6

    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.9)
    love.graphics.print(coordText, textX, textY)
end

return hud_minimap
