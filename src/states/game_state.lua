--------------------------------------------------------------------------------
-- HUMP GAMESTATE WRAPPER
--
-- This project originally shipped with a tiny custom state machine
-- (`src.core.state_machine`) and a single gameplay state module
-- (`src.states.game`).
--
-- We are introducing HUMP's `Gamestate` for more robust state management
-- (menus, pause overlays, transitions, stacked states, etc.). To keep the
-- migration low-risk, this module adapts the existing legacy `game` state to
-- HUMP's expected callback signatures.
--
-- Notes:
--   - HUMP calls state callbacks with `self` as the first argument.
--   - The legacy `game` module defines callbacks as plain functions
--     (e.g. `game.update(dt)`), so we forward without passing `self`.
--   - We call `game.load()` once via `init()`, matching the old boot flow.
--------------------------------------------------------------------------------

local game = require("src.states.game")

local gameState = {}

--------------------------------------------------------------------------------
-- LIFECYCLE
--------------------------------------------------------------------------------

function gameState:init()
	-- Called once when the state is first used.
	if game.load then
		game.load()
	end
end

--------------------------------------------------------------------------------
-- LOVE CALLBACK FORWARDS
--------------------------------------------------------------------------------

function gameState:update(dt)
	if game.update then
		return game.update(dt)
	end
end

function gameState:draw()
	if game.draw then
		return game.draw()
	end
end

function gameState:keypressed(key)
	if game.keypressed then
		return game.keypressed(key)
	end
end

function gameState:keyreleased(key)
	if game.keyreleased then
		return game.keyreleased(key)
	end
end

function gameState:mousepressed(x, y, button)
	if game.mousepressed then
		return game.mousepressed(x, y, button)
	end
end

function gameState:mousereleased(x, y, button)
	if game.mousereleased then
		return game.mousereleased(x, y, button)
	end
end

function gameState:mousemoved(x, y, dx, dy)
	if game.mousemoved then
		return game.mousemoved(x, y, dx, dy)
	end
end

function gameState:wheelmoved(x, y)
	if game.wheelmoved then
		return game.wheelmoved(x, y)
	end
end

function gameState:resize(w, h)
	if game.resize then
		return game.resize(w, h)
	end
end

return gameState
