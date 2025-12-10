local hud_pause = {}

local ui_theme = require("src.core.ui_theme")
local window_frame = require("src.render.hud.window_frame")

-- Pause menu uses the shared window_frame helper so it visually matches other
-- HUD windows while remaining simple (no dragging / close button logic at the
-- game state level).

local windowState = {
	x = nil,
	y = nil,
	isDragging = false,
	dragOffsetX = 0,
	dragOffsetY = 0,
}

-- Layout / presentation options for the pause window.
local WINDOW_OPTS = {
	minWidth = 360,
	minHeight = 220,
	screenMargin = 80,
	title = "PAUSED",
	hint = "Esc: Resume  |  Click a button",
}

-- Menu layout constants inside the pause window content area.
local MENU_TOP_PADDING = 32
local MENU_SPACING = 34
local BUTTON_PADDING_X = 18
local BUTTON_PADDING_Y = 6

local function computeWindowOptionsForMenu(menu)
	local font = love.graphics.getFont()
	local windowStyle = ui_theme.window
	local topBarHeight = windowStyle.topBarHeight or 40
	local bottomBarHeight = windowStyle.bottomBarHeight or 36

	local panelWidth = WINDOW_OPTS.minWidth
	local panelHeight = WINDOW_OPTS.minHeight
	local maxItemWidth = 0
	local itemCount = 0

	if menu and menu.items then
		itemCount = #menu.items
		for _, item in ipairs(menu.items) do
			local w = font:getWidth(item.label)
			if w > maxItemWidth then
				maxItemWidth = w
			end
		end
	end

	if itemCount > 0 and maxItemWidth > 0 then
		local fontHeight = font:getHeight()
		local rectW = maxItemWidth + BUTTON_PADDING_X * 2
		local rectH = fontHeight + BUTTON_PADDING_Y * 2
		local groupHeight = rectH + (itemCount - 1) * MENU_SPACING
		local marginTop = MENU_TOP_PADDING - BUTTON_PADDING_Y
		if marginTop < 0 then
			marginTop = 0
		end
		local contentHeight = marginTop * 2 + groupHeight
		local contentWidth = rectW + 32

		panelWidth = math.max(panelWidth, contentWidth)
		panelHeight = math.max(panelHeight, topBarHeight + contentHeight + bottomBarHeight)
	end

	local opts = {
		fixedWidth = panelWidth,
		fixedHeight = panelHeight,
		screenMargin = WINDOW_OPTS.screenMargin,
		title = WINDOW_OPTS.title,
		hint = WINDOW_OPTS.hint,
	}

	return opts, maxItemWidth
end

function hud_pause.draw(player, colors, menu)
	local font = love.graphics.getFont()
	local hudPanelStyle = ui_theme.hudPanel
	local mx, my = love.mouse.getPosition()

	if not colors then
		return
	end

	local drawOpts, maxItemWidth = computeWindowOptionsForMenu(menu)
	local layout = window_frame.draw(windowState, drawOpts, colors)

	local contentCenterX = layout.contentX + layout.contentWidth / 2
	local baseY = layout.contentY + MENU_TOP_PADDING

	if menu and menu.items and maxItemWidth > 0 then
		local selectedIndex = menu.selected or 1
		for i, item in ipairs(menu.items) do
			local label = item.label
			local itemWidth = font:getWidth(label)
			local itemHeight = font:getHeight()
			local x = contentCenterX - itemWidth / 2
			local y = baseY + (i - 1) * MENU_SPACING

			local rectW = maxItemWidth + BUTTON_PADDING_X * 2
			local rectH = itemHeight + BUTTON_PADDING_Y * 2
			local rectX = contentCenterX - rectW / 2
			local rectY = y - BUTTON_PADDING_Y

			local hovered = mx >= rectX and mx <= rectX + rectW and my >= rectY and my <= rectY + rectH
			local selected = (i == selectedIndex)

			-- Button background: soft panel tint, slightly brighter on hover or when selected.
			if hovered or selected then
				love.graphics.setColor(
					hudPanelStyle.background[1] + 0.02,
					hudPanelStyle.background[2] + 0.02,
					hudPanelStyle.background[3] + 0.03,
					hudPanelStyle.background[4]
				)
			else
				love.graphics.setColor(
					hudPanelStyle.background[1],
					hudPanelStyle.background[2],
					hudPanelStyle.background[3],
					hudPanelStyle.background[4]
				)
			end
			love.graphics.rectangle("fill", rectX, rectY, rectW, rectH, 4, 4)

			-- Button outline: subtle when idle, stronger when hovered/selected.
			if hovered or selected then
				love.graphics.setColor(0, 0, 0, 0.9)
				love.graphics.setLineWidth(2)
			else
				love.graphics.setColor(hudPanelStyle.barOutline[1], hudPanelStyle.barOutline[2], hudPanelStyle.barOutline[3],
					0.8)
				love.graphics.setLineWidth(1)
			end
			love.graphics.rectangle("line", rectX, rectY, rectW, rectH, 4, 4)

			-- Label text
			if hovered or selected then
				love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 1.0)
			else
				love.graphics.setColor(colors.uiText[1], colors.uiText[2], colors.uiText[3], 0.9)
			end
			love.graphics.print(label, x, y)
		end
	end
end

function hud_pause.hitTestPauseMenu(menu, mx, my)
	if not menu or not menu.items then
		return nil
	end

	local font = love.graphics.getFont()
	local layoutOpts, maxItemWidth = computeWindowOptionsForMenu(menu)
	local layout = window_frame.getLayout(windowState, layoutOpts)
	local contentCenterX = layout.contentX + layout.contentWidth / 2
	local baseY = layout.contentY + MENU_TOP_PADDING
	if maxItemWidth <= 0 then
		return nil
	end

	for i, item in ipairs(menu.items) do
		local label = item.label
		local itemWidth = font:getWidth(label)
		local itemHeight = font:getHeight()
		local x = contentCenterX - itemWidth / 2
		local y = baseY + (i - 1) * MENU_SPACING

		local rectW = maxItemWidth + BUTTON_PADDING_X * 2
		local rectH = itemHeight + BUTTON_PADDING_Y * 2
		local rectX = contentCenterX - rectW / 2
		local rectY = y - BUTTON_PADDING_Y

		if mx >= rectX and mx <= rectX + rectW and my >= rectY and my <= rectY + rectH then
			return i, item
		end
	end

	return nil
end

function hud_pause.mousepressed(menu, x, y, button)
	local opts = computeWindowOptionsForMenu(menu)
	return window_frame.mousepressed(windowState, opts, x, y, button)
end

function hud_pause.mousereleased(menu, x, y, button)
	local opts = computeWindowOptionsForMenu(menu)
	window_frame.mousereleased(windowState, opts, x, y, button)
end

function hud_pause.mousemoved(menu, x, y)
	local opts = computeWindowOptionsForMenu(menu)
	window_frame.mousemoved(windowState, opts, x, y)
end

function hud_pause.reset()
	window_frame.reset(windowState)
end

return hud_pause
