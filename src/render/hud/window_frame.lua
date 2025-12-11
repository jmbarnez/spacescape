local window_frame = {}

-- Shared HUD window frame helper
--
-- This module centralizes the drawing and mouse handling for window-style HUD
-- overlays (cargo, world map, future dialogs). Individual windows provide
-- their own layout options and content rendering, while this helper ensures
-- consistent framing and behavior.

local ui_theme = require("src.core.ui_theme")

--------------------------------------------------------------------------------
-- INTERNAL LAYOUT HELPERS
--------------------------------------------------------------------------------

--- Compute the panel rectangle for a window.
--
-- @param state table  Per-window state table { x, y, ... } used to store the
--                     window's anchored position when dragged.
-- @param opts  table  Layout options:
--                     - fixedWidth, fixedHeight: explicit panel size
--                     - minWidth, minHeight: minimum size when auto-scaling
--                     - screenMargin: margin from screen edge (for auto size)
-- @return number panelX, panelY, panelWidth, panelHeight
local function computePanelRect(state, opts)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    local fixedWidth = opts.fixedWidth
    local fixedHeight = opts.fixedHeight
    local panelWidth, panelHeight

    if fixedWidth and fixedHeight then
        panelWidth = fixedWidth
        panelHeight = fixedHeight
    else
        local margin = opts.screenMargin or 40
        local minWidth = opts.minWidth or 600
        local minHeight = opts.minHeight or 420
        panelWidth = math.max(minWidth, screenW - margin * 2)
        panelHeight = math.max(minHeight, screenH - margin * 2)
    end

    local px = state.x or (screenW - panelWidth) / 2
    local py = state.y or (screenH - panelHeight) / 2

    return px, py, panelWidth, panelHeight
end

--- Compute the core layout metrics (panel, content, bottom bar) for a window.
-- This is shared between drawing and mouse handling so that all operations
-- stay perfectly in sync.
local function computeLayout(state, opts)
    local windowStyle = ui_theme.window
    local topBarHeight = windowStyle.topBarHeight or 40
    local bottomBarHeight = windowStyle.bottomBarHeight or 36

    local panelX, panelY, panelWidth, panelHeight = computePanelRect(state, opts)

    local contentX = panelX
    local contentY = panelY + topBarHeight
    local contentWidth = panelWidth
    local contentHeight = panelHeight - topBarHeight - bottomBarHeight

    local bottomBarY = panelY + panelHeight - bottomBarHeight

    return {
        panelX = panelX,
        panelY = panelY,
        panelWidth = panelWidth,
        panelHeight = panelHeight,
        contentX = contentX,
        contentY = contentY,
        contentWidth = contentWidth,
        contentHeight = contentHeight,
        bottomBarY = bottomBarY,
        bottomBarHeight = bottomBarHeight,
        topBarHeight = topBarHeight,
    }
end

function window_frame.getLayout(state, opts)
    return computeLayout(state, opts)
end

--- Return the rectangle of the close button for a given layout.
local function getCloseButtonRect(layout)
    local windowStyle = ui_theme.window
    local size = windowStyle.closeButtonSize or 24
    local padding = 4

    local x = layout.panelX + layout.panelWidth - size - padding
    local y = layout.panelY + padding
    return x, y, size, size
end

local function isPointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Draw the full window frame (background, bars, border, title, close button,
--- and optional bottom hint) using the shared theme.
--
-- @param state table  Per-window state table { x, y, ... }.
-- @param opts  table  Layout + content options:
--                     - fixedWidth, fixedHeight OR minWidth, minHeight,
--                       screenMargin
--                     - title: string title shown in the top bar
--                     - hint:  string hint centered in the bottom bar
-- @param colors table Shared color palette (src.core.colors).
-- @return table layout { panelX, panelY, panelWidth, panelHeight,
--                        contentX, contentY, contentWidth, contentHeight,
--                        bottomBarY, bottomBarHeight, topBarHeight }
function window_frame.draw(state, opts, colors)
    local windowStyle = ui_theme.window
    local radius = windowStyle.radius or 6

    local layout = computeLayout(state, opts)

    local font = love.graphics.getFont()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Subtle dimmer behind the window so content stands out.
    local useDimmer = opts and opts.dimmer
    if useDimmer then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    end

    --------------------------------------------------------------------------
    -- Main panel body
    --------------------------------------------------------------------------
    love.graphics.setColor(
        windowStyle.background[1],
        windowStyle.background[2],
        windowStyle.background[3],
        windowStyle.background[4]
    )
    love.graphics.rectangle(
        "fill",
        layout.panelX,
        layout.panelY,
        layout.panelWidth,
        layout.panelHeight,
        radius,
        radius
    )

    -- Top bar
    love.graphics.setColor(
        windowStyle.topBar[1],
        windowStyle.topBar[2],
        windowStyle.topBar[3],
        windowStyle.topBar[4]
    )
    love.graphics.rectangle(
        "fill",
        layout.panelX,
        layout.panelY,
        layout.panelWidth,
        layout.topBarHeight,
        radius,
        radius
    )
    -- Fill the bottom corners of the top bar so the round rect blends into the
    -- main panel body.
    love.graphics.rectangle(
        "fill",
        layout.panelX,
        layout.panelY + layout.topBarHeight - radius,
        layout.panelWidth,
        radius
    )

    -- Bottom bar
    love.graphics.setColor(
        windowStyle.bottomBar[1],
        windowStyle.bottomBar[2],
        windowStyle.bottomBar[3],
        windowStyle.bottomBar[4]
    )
    love.graphics.rectangle(
        "fill",
        layout.panelX,
        layout.bottomBarY,
        layout.panelWidth,
        layout.bottomBarHeight,
        radius,
        radius
    )
    love.graphics.rectangle(
        "fill",
        layout.panelX,
        layout.bottomBarY,
        layout.panelWidth,
        radius
    )

    -- Border
    local borderColor = windowStyle.border or colors.uiPanelBorder or { 1, 1, 1, 0.5 }
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle(
        "line",
        layout.panelX,
        layout.panelY,
        layout.panelWidth,
        layout.panelHeight,
        radius,
        radius
    )

    --------------------------------------------------------------------------
    -- Title + close button + bottom hint
    --------------------------------------------------------------------------
    local title = opts.title or "WINDOW"
    local hint = opts.hint

    -- Title
    love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 1.0)
    local titleWidth = font:getWidth(title)
    local titleX = layout.panelX + 12
    local titleY = layout.panelY + (layout.topBarHeight - font:getHeight()) / 2
    love.graphics.print(title, titleX, titleY)

    -- Close button
    local closeX, closeY, closeW, closeH = getCloseButtonRect(layout)
    local mx, my = love.mouse.getPosition()
    local hovered = isPointInRect(mx, my, closeX, closeY, closeW, closeH)

    if hovered then
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
    love.graphics.rectangle("fill", closeX, closeY, closeW, closeH, 4, 4)

    love.graphics.setLineWidth(2)
    local xColor = hovered and windowStyle.closeButtonXHover or windowStyle.closeButtonX
    love.graphics.setColor(xColor[1], xColor[2], xColor[3], xColor[4] or 1.0)
    local pad = 6
    love.graphics.line(closeX + pad, closeY + pad, closeX + closeW - pad, closeY + closeH - pad)
    love.graphics.line(closeX + closeW - pad, closeY + pad, closeX + pad, closeY + closeH - pad)

    -- Bottom hint text, centered in the bottom bar
    if hint and hint ~= "" then
        local hintWidth = font:getWidth(hint)
        local hintX = layout.panelX + (layout.panelWidth - hintWidth) / 2
        local hintY = layout.bottomBarY + (layout.bottomBarHeight - font:getHeight()) / 2
        love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.45)
        love.graphics.print(hint, hintX, hintY)
    end

    return layout
end

--- Handle mouse press for a window frame.
-- Returns "close" when the close button is clicked, "drag" when the title
-- bar begins a drag, true when the click is inside the window but not on the
-- frame controls, or false when it did not hit the window at all.
function window_frame.mousepressed(state, opts, x, y, button)
    if button ~= 1 then
        return false
    end

    local layout = computeLayout(state, opts)
    local closeX, closeY, closeW, closeH = getCloseButtonRect(layout)

    -- Close
    if isPointInRect(x, y, closeX, closeY, closeW, closeH) then
        return "close"
    end

    -- Dragging via the top bar
    if isPointInRect(x, y, layout.panelX, layout.panelY, layout.panelWidth, layout.topBarHeight) then
        state.isDragging = true
        state.dragOffsetX = x - layout.panelX
        state.dragOffsetY = y - layout.panelY
        return "drag"
    end

    -- Swallow clicks inside the window so they do not reach gameplay
    if isPointInRect(x, y, layout.panelX, layout.panelY, layout.panelWidth, layout.panelHeight) then
        return true
    end

    return false
end

function window_frame.mousereleased(state, _opts, _x, _y, button)
    if button == 1 then
        state.isDragging = false
    end
end

function window_frame.mousemoved(state, opts, x, y)
    if not state.isDragging then
        return
    end

    local panelX, panelY, panelWidth, panelHeight = computePanelRect(state, opts)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Update anchored position based on drag offset, then clamp to screen
    -- bounds so the window cannot be lost off-screen.
    state.x = x - state.dragOffsetX
    state.y = y - state.dragOffsetY

    state.x = math.max(0, math.min(screenW - panelWidth, state.x))
    state.y = math.max(0, math.min(screenH - panelHeight, state.y))
end

function window_frame.reset(state)
    state.x = nil
    state.y = nil
    state.isDragging = false
    state.dragOffsetX = 0
    state.dragOffsetY = 0
end

return window_frame
