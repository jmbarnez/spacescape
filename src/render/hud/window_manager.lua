local window_manager = {}

-- Centralized HUD window input manager
--
-- This module routes mouse events for all window-frame-based HUD overlays
-- (pause menu, cargo window, world map, and future dialogs) through a single
-- place. The actual visual appearance and per-window behavior remain in their
-- own modules; this manager just coordinates who gets input and how that input
-- is translated into high-level actions for the game state.
--
-- Goals:
--   - One entrypoint for all window-style HUD input.
--   - Minimal coupling between game state and individual windows.
--   - Easy to extend with new windows by adding small, well-documented blocks
--     instead of duplicating logic in the game state.

local hud_pause = require("src.render.hud.pause")
local hud_cargo = require("src.render.hud.cargo")
local hud_world_map = require("src.render.hud.world_map")
local hud_loot_panel = require("src.render.hud.loot_panel")

--------------------------------------------------------------------------------
-- INTERNAL HELPERS / REGISTRY
--------------------------------------------------------------------------------

--- Small helper to check if a mouse button is the primary (left) button.
-- We currently only treat left clicks as window interactions; right / middle
-- clicks are left for world / gameplay input.
local function isLeftClick(button)
    return button == 1
end

-- Registry of in-game HUD windows that behave like overlays while the game is
-- still simulating (cargo, world map, and future dialogs). Each entry owns its
-- own open/closed state and basic event forwarding logic.
--
-- Windows are keyed by a stable id ("cargo", "map", etc.) and also carry a
-- z-index so that input can be dispatched from the top-most window down.
local windows = {
    map = {
        id = "map",
        zIndex = 200,
        isOpen = false,
        mousepressed = function(x, y, button)
            return hud_world_map.mousepressed(x, y, button)
        end,
        mousereleased = function(x, y, button)
            hud_world_map.mousereleased(x, y, button)
        end,
        mousemoved = function(x, y)
            hud_world_map.mousemoved(x, y)
        end,
        wheelmoved = function(x, y)
            return hud_world_map.wheelmoved(x, y)
        end,
    },

    cargo = {
        id = "cargo",
        zIndex = 100,
        isOpen = false,
        mousepressed = function(x, y, button)
            return hud_cargo.mousepressed(x, y, button)
        end,
        mousereleased = function(x, y, button)
            hud_cargo.mousereleased(x, y, button)
        end,
        mousemoved = function(x, y)
            hud_cargo.mousemoved(x, y)
        end,
    },

    loot = {
        id = "loot",
        zIndex = 150, -- Above cargo, below map
        -- isOpen is dynamically determined by player.isLooting
        isOpen = false,
        mousepressed = function(x, y, button)
            return hud_loot_panel.mousepressed(x, y, button)
        end,
        mousereleased = function(x, y, button)
            hud_loot_panel.mousereleased(x, y, button)
        end,
        mousemoved = function(x, y)
            hud_loot_panel.mousemoved(x, y)
        end,
    },
}

--- Build a temporary array of registered windows sorted by descending z-index
-- so that input is always offered to the visually top-most window first.
local function getWindowsInZOrderDescending()
    -- Sync loot window isOpen with player looting state
    local lootWin = windows.loot
    if lootWin then
        lootWin.isOpen = hud_loot_panel.isOpen()
    end

    local ordered = {}
    for _, win in pairs(windows) do
        ordered[#ordered + 1] = win
    end

    table.sort(ordered, function(a, b)
        local za = a.zIndex or 0
        local zb = b.zIndex or 0
        return za > zb
    end)

    return ordered
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--[[

uiCtx is a small table that mirrors the parts of the game state the HUD cares
about for window management. It is passed *by reference* so this module can
update it in-place.

    uiCtx = {
        gameState = "playing" | "paused" | "gameover",
        pauseMenu = table,   -- pause menu state / items
        --
        -- Open / closed state for in-play overlays (cargo, map, etc.) is tracked
        -- inside this module via the window registry above. The game state can
        -- query or mutate that state via helper functions such as
        -- window_manager.setWindowOpen / isWindowOpen / toggleWindow.
    }

Each function in this module may mutate uiCtx and returns:

    handled, action

Where:
    handled : boolean  - true if some HUD window consumed the event.
    action  : string?  - optional high-level intent for the game state:
                         * "restart"          -> restart current run
                         * "quit_to_desktop" -> exit to desktop

The game state module decides how to react to these actions; this manager only
reports what the UI is asking for.
]]

--- Mark a registered HUD window ("cargo", "map", etc.) as open or closed.
function window_manager.setWindowOpen(id, isOpen)
    local win = windows[id]
    if not win then
        return
    end

    win.isOpen = not not isOpen
end

--- Toggle a registered HUD window's open/closed state.
function window_manager.toggleWindow(id)
    local win = windows[id]
    if not win then
        return
    end

    win.isOpen = not win.isOpen
end

--- Check whether a registered HUD window is currently open.
function window_manager.isWindowOpen(id)
    local win = windows[id]
    if not win then
        return false
    end

    return win.isOpen and true or false
end

--- Handle mouse press for all HUD windows.
-- This is intended to be called from game.mousepressed before any gameplay
-- input is processed.
function window_manager.mousepressed(uiCtx, x, y, button)
    -- Game-over mouse handling stays in the game state module for now so that
    -- it remains obvious how to restart after death.
    if uiCtx.gameState == "gameover" then
        return false, nil
    end

    -- Right / middle clicks bypass the HUD windows; they go straight to
    -- gameplay input.
    if not isLeftClick(button) then
        return false, nil
    end

    --------------------------------------------------------------------------
    -- Modal pause menu
    --
    -- When the game is paused, the pause menu behaves like a traditional
    -- modal dialog: it swallows mouse clicks until it is closed. We let the
    -- pause HUD module deal with the low-level frame hit-testing and then
    -- interpret the result here in terms of game-level actions.
    --------------------------------------------------------------------------
    if uiCtx.gameState == "paused" then
        -- If the frame did not consume the click, see if it landed on one of
        -- the pause menu buttons (Resume / Restart / Quit).
        local index, item = hud_pause.hitTestPauseMenu(uiCtx.pauseMenu, x, y)
        if item then
            if item.id == "resume" then
                uiCtx.gameState = "playing"
                return true, nil
            elseif item.id == "restart" then
                -- Signal to the game state that the player requested a
                -- restart. The game module will decide how to perform the
                -- reset and which systems to touch.
                return true, "restart"
            elseif item.id == "quit" then
                -- Same idea: the actual quit call (love.event.quit) stays out
                -- of the HUD layer.
                return true, "quit_to_desktop"
            end
        end

        -- First, delegate to the pause window_frame hit test. This handles the
        -- close button, top-bar dragging, and generic "inside window" hits.
        local result = hud_pause.mousepressed(uiCtx.pauseMenu, x, y, button)

        if result == "close" then
            -- Clicking the pause window close button is equivalent to pressing
            -- Esc: resume gameplay but otherwise leave the run untouched.
            uiCtx.gameState = "playing"
            return true, nil
        elseif result == "drag" or result == true then
            -- Either a drag started on the title bar or the click landed
            -- somewhere in the window content area. In both cases we fully
            -- consume the click so it does not affect gameplay.
            return true, nil
        end

        -- Click was somewhere outside the pause window and its buttons. We do
        -- not automatically unpause in this case; the player must press Esc or
        -- use the Resume button / close button.
        return false, nil
    end

    --------------------------------------------------------------------------
    -- In-play overlays (cargo window, world map)
    --
    -- These are drawn while the core game is still ticking. They act like
    -- standard HUD windows on top of gameplay. We walk the registry in
    -- z-order, from top-most to bottom-most, so that the window visually on
    -- top gets first chance to consume clicks.
    --------------------------------------------------------------------------
    if uiCtx.gameState ~= "playing" then
        return false, nil
    end

    for _, win in ipairs(getWindowsInZOrderDescending()) do
        if win.isOpen then
            local result = win.mousepressed(x, y, button)
            if result == "close" then
                win.isOpen = false
                return true, nil
            elseif result then
                return true, nil
            end
        end
    end

    -- No HUD window handled this mouse press.
    return false, nil
end

--- Handle mouse release for all HUD windows.
-- This mirrors the pressed handler but only cares about drag / press state.
function window_manager.mousereleased(uiCtx, x, y, button)
    if uiCtx.gameState == "gameover" then
        return false
    end

    if uiCtx.gameState == "paused" then
        -- Let the pause window_frame clean up any drag state.
        hud_pause.mousereleased(uiCtx.pauseMenu, x, y, button)
        return true
    end

    if uiCtx.gameState ~= "playing" then
        return false
    end

    local handled = false
    for _, win in ipairs(getWindowsInZOrderDescending()) do
        if win.isOpen then
            win.mousereleased(x, y, button)
            handled = true
        end
    end

    return handled
end

--- Handle mouse wheel events for HUD windows.
--
-- This is intended to be called from game.wheelmoved before any gameplay
-- camera zoom is applied. When the world map is open, the wheel should zoom
-- the map instead of the gameplay camera.
function window_manager.wheelmoved(uiCtx, x, y)
    if uiCtx.gameState == "gameover" then
        return false
    end

    if uiCtx.gameState ~= "playing" then
        return false
    end

    for _, win in ipairs(getWindowsInZOrderDescending()) do
        if win.isOpen and win.wheelmoved then
            local handled = win.wheelmoved(x, y)
            if handled then
                return true
            end
        end
    end

    return false
end

--- Handle mouse move for all HUD windows.
-- Used primarily for window dragging; hover visuals stay in the individual
-- window modules (they read the current mouse position directly).
function window_manager.mousemoved(uiCtx, x, y, dx, dy)
    if uiCtx.gameState == "gameover" then
        return false
    end

    if uiCtx.gameState == "paused" then
        -- Pause window drag / hover. We ignore dx / dy here because the pause
        -- module passes the absolute coordinates down into window_frame.
        hud_pause.mousemoved(uiCtx.pauseMenu, x, y)
        return true
    end

    if uiCtx.gameState ~= "playing" then
        return false
    end

    local handled = false
    for _, win in ipairs(getWindowsInZOrderDescending()) do
        if win.isOpen then
            win.mousemoved(x, y)
            handled = true
        end
    end

    return handled
end

--- Reset a registered window's position and drag state.
-- This centralizes the position reset so that callers do not need to reach
-- into individual HUD modules.
function window_manager.resetWindow(id)
    if id == "cargo" then
        require("src.render.hud.cargo").reset()
    elseif id == "map" then
        require("src.render.hud.world_map").reset()
    elseif id == "pause" then
        require("src.render.hud.pause").reset()
    end
end

--- Handle key press for all HUD windows.
-- This is intended to be called from game.keypressed before the game state
-- performs its own key handling. The primary purpose is to allow Escape to
-- close in-play overlay windows (cargo, map) before toggling the pause menu.
--
-- @param uiCtx table  The UI context (must include gameState at minimum).
-- @param key   string The key that was pressed.
-- @return boolean handled  True if the key was consumed by a HUD window.
-- @return string? action   Optional high-level intent (e.g., "close_window").
function window_manager.keypressed(uiCtx, key)
    -- Only intercept Escape while playing (not paused, not gameover)
    if key ~= "escape" then
        return false, nil
    end

    if uiCtx.gameState ~= "playing" then
        return false, nil
    end

    -- Close the topmost open in-play window (by z-index order) instead of
    -- pausing the game. This gives players intuitive Escape behavior: the
    -- window they are currently looking at closes first.
    for _, win in ipairs(getWindowsInZOrderDescending()) do
        if win.isOpen then
            win.isOpen = false
            -- Reset the window position when closing via Escape for a clean
            -- slate next time the player opens it.
            window_manager.resetWindow(win.id)
            return true, "close_window"
        end
    end

    -- No in-play window was open; let the game state handle Escape normally
    -- (which will toggle the pause menu).
    return false, nil
end

return window_manager
