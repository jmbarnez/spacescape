local Gamestate = require("lib.hump.gamestate")
local GameState = require("src.states.game_state")

function love.load()
	-- Register all Love callbacks (update/draw/keypressed/etc) so they forward
	-- into the currently active HUMP state.
	Gamestate.registerEvents()

	-- Start directly in gameplay for now (matching the previous boot flow).
	Gamestate.switch(GameState)
end
