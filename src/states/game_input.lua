local game_input = {}

local function createUiContext(deps)
	return {
		gameState = deps.getGameState(),
		pauseMenu = deps.getPauseMenu(),
	}
end

local function applyUiContext(deps, uiCtx)
	deps.setGameState(uiCtx.gameState)
	deps.setPauseMenu(uiCtx.pauseMenu)
end

local function processUiMouseMove(deps)
	local input = deps.input
	local windowManager = deps.windowManager

	local mx, my = input.getMousePosition()
	local dx, dy = input.getMouseDelta()

	local uiCtx = createUiContext(deps)
	windowManager.mousemoved(uiCtx, mx, my, dx, dy)
	applyUiContext(deps, uiCtx)
end

local function processUiMouseButtons(deps)
	local input = deps.input
	local windowManager = deps.windowManager
	local inputSystem = deps.inputSystem
	local playerModule = deps.playerModule
	local world = deps.world
	local camera = deps.camera

	local mx, my = input.getMousePosition()
	local pressX, pressY = input.getMousePressedPosition(1)
	local releaseX, releaseY = input.getMouseReleasedPosition(1)
	local rightPressX, rightPressY = input.getMousePressedPosition(2)
	if not pressX then
		pressX, pressY = mx, my
	end
	if not releaseX then
		releaseX, releaseY = mx, my
	end
	if not rightPressX then
		rightPressX, rightPressY = mx, my
	end

	if input.pressed("mouse_primary") then
		local gameState = deps.getGameState()
		if gameState == "dead" then
			deps.respawn()
			return
		end

		local uiCtx = createUiContext(deps)
		local handled, action = windowManager.mousepressed(uiCtx, pressX, pressY, 1)
		applyUiContext(deps, uiCtx)

		if action == "quit_to_desktop" then
			deps.onQuit()
			return
		end

		if handled then
			return
		end

		gameState = deps.getGameState()
		if gameState ~= "playing" then
			return
		end

		inputSystem.mousepressed(pressX, pressY, 1, playerModule.getEntity(), world, camera)
	end

	if input.released("mouse_primary") then
		local uiCtx = createUiContext(deps)
		windowManager.mousereleased(uiCtx, releaseX, releaseY, 1)
		applyUiContext(deps, uiCtx)
	end

	if input.pressed("mouse_secondary") and deps.getGameState() == "playing" then
		inputSystem.mousepressed(rightPressX, rightPressY, 2, playerModule.getEntity(), world, camera)
	end
end

local function processUiMouseWheel(deps)
	local input = deps.input
	local windowManager = deps.windowManager
	local camera = deps.camera
	local config = deps.config

	local wx, wy = input.getWheelDelta()
	if (not wy) or wy == 0 then
		return
	end

	local uiCtx = createUiContext(deps)
	local handled = windowManager.wheelmoved(uiCtx, wx, wy)
	applyUiContext(deps, uiCtx)

	if not handled and deps.getGameState() == "playing" then
		camera.zoom(wy * config.camera.zoomWheelScale)
	end
end

local function processUiKeyboardActions(deps)
	local input = deps.input
	local windowManager = deps.windowManager

	if input.pressed("toggle_fullscreen") then
		local isFullscreen = love.window.getFullscreen()
		love.window.setFullscreen(not isFullscreen, "desktop")
		return
	end

	if input.pressed("pause") then
		local gameState = deps.getGameState()
		if gameState == "dead" then
			deps.onQuit()
			return
		end
		if gameState == "playing" then
			local uiCtx = createUiContext(deps)
			local handled = windowManager.keypressed(uiCtx, "escape")
			applyUiContext(deps, uiCtx)

			if handled then
				return
			end

			deps.setGameState("paused")
			windowManager.setWindowOpen("cargo", false)
			return
		elseif gameState == "paused" then
			deps.setGameState("playing")
			return
		end
	end

	if input.pressed("toggle_cargo") and deps.getGameState() == "playing" then
		local nowOpen = not windowManager.isWindowOpen("cargo")
		windowManager.setWindowOpen("cargo", nowOpen)
		if not nowOpen then
			windowManager.resetWindow("cargo")
		end
		return
	end

	if input.pressed("toggle_map") and deps.getGameState() == "playing" then
		windowManager.toggleWindow("map")
		return
	end

	if input.pressed("toggle_skills") and deps.getGameState() == "playing" then
		windowManager.toggleWindow("skills")
		return
	end
end

function game_input.process(deps)
	processUiMouseMove(deps)
	processUiMouseButtons(deps)
	processUiMouseWheel(deps)
	processUiKeyboardActions(deps)
end

return game_input
