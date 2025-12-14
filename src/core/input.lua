local baton = require("lib.baton")

local input = {}

--------------------------------------------------------------------------------
-- INPUT WRAPPER (BATON)
--
-- This module is the single source of truth for *gameplay-relevant* input.
--
-- Goals:
--   - Centralize key/mouse bindings (action-based) using Baton.
--   - Provide tiny helpers for mouse position + wheel delta since Baton only
--     tracks mouse buttons (not cursor movement / wheel).
--   - Let the rest of the codebase ask "is action pressed?" instead of doing
--     `if key == ...` or `love.mouse.isDown(...)` everywhere.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- DEFAULT BINDINGS
--------------------------------------------------------------------------------

-- NOTE:
-- Baton sources:
--   - Keyboard: "key:<love-key>"
--   - Mouse buttons: "mouse:<button-number>"  (1=left, 2=right, 3=middle)
--
-- We keep these names stable so consumers can be refactored safely.
local DEFAULT_CONTROLS = {
    -- Global / UI-ish actions
    pause = { "key:escape" },
    toggle_cargo = { "key:tab" },
    toggle_map = { "key:m" },

    -- Abilities
    ability_overcharge = { "key:q" },
    ability_vector_dash = { "key:e" },

    -- Modifiers (used by HUD drag/drop logic)
    modifier_shift = { "key:lshift", "key:rshift" },

    -- Mouse buttons
    mouse_primary = { "mouse:1" },
    mouse_secondary = { "mouse:2" },
    mouse_middle = { "mouse:3" },
}

local function buildDefaultConfig()
    return {
        controls = DEFAULT_CONTROLS,
        pairs = {},
        deadzone = 0.5,
        squareDeadzone = false,
    }
end

--------------------------------------------------------------------------------
-- INTERNAL STATE
--------------------------------------------------------------------------------

local player = nil

-- Mouse wheel is event-driven in LOVE, so we record it in wheelmoved() and
-- expose it as a per-frame delta after update() consumes it.
local wheelAccumX, wheelAccumY = 0, 0
local wheelFrameX, wheelFrameY = 0, 0

-- Cursor delta is useful for drag/pan UI. We compute it once per frame.
local lastMouseX, lastMouseY = nil, nil
local mouseDx, mouseDy = 0, 0

local function ensurePlayer()
    if player then
        return
    end

    player = baton.new(buildDefaultConfig())
end

--------------------------------------------------------------------------------
-- LIFECYCLE
--------------------------------------------------------------------------------

-- Call once per frame (ideally early in your update loop).
function input.update(dt)
    ensurePlayer()

    -- Promote wheel delta for this frame.
    wheelFrameX, wheelFrameY = wheelAccumX, wheelAccumY
    wheelAccumX, wheelAccumY = 0, 0

    -- Track mouse cursor movement.
    local mx, my = love.mouse.getPosition()
    if lastMouseX == nil or lastMouseY == nil then
        mouseDx, mouseDy = 0, 0
    else
        mouseDx, mouseDy = mx - lastMouseX, my - lastMouseY
    end
    lastMouseX, lastMouseY = mx, my

    -- Let Baton compute pressed/released transitions.
    player:update()
end

--------------------------------------------------------------------------------
-- LOVE CALLBACK HOOKS (EVENT INPUT)
--------------------------------------------------------------------------------

-- LOVE reports wheel movement via callbacks; Baton doesn't track this.
function input.wheelmoved(x, y)
    wheelAccumX = wheelAccumX + (x or 0)
    wheelAccumY = wheelAccumY + (y or 0)
end

--------------------------------------------------------------------------------
-- ACTION API (BATON)
--------------------------------------------------------------------------------

function input.down(action)
    ensurePlayer()
    return player:down(action)
end

function input.pressed(action)
    ensurePlayer()
    return player:pressed(action)
end

function input.released(action)
    ensurePlayer()
    return player:released(action)
end

function input.get(action)
    ensurePlayer()
    return player:get(action)
end

function input.getRaw(action)
    ensurePlayer()
    return player:getRaw(action)
end

function input.getActiveDevice()
    ensurePlayer()
    return player:getActiveDevice()
end

--------------------------------------------------------------------------------
-- MOUSE HELPERS
--------------------------------------------------------------------------------

function input.getMousePosition()
    return love.mouse.getPosition()
end

function input.getMouseDelta()
    return mouseDx, mouseDy
end

function input.getWheelDelta()
    return wheelFrameX, wheelFrameY
end

function input.getMouseWorld(camera)
    local mx, my = input.getMousePosition()

    if camera and camera.screenToWorld then
        return camera.screenToWorld(mx, my)
    end

    return mx, my
end

--------------------------------------------------------------------------------
-- OPTIONAL EXTENSIONS (FOR FUTURE)
--------------------------------------------------------------------------------

-- Assign a LOVE joystick/gamepad to the Baton player config.
--
-- We don't currently use joystick input in Spacescape, but this hook keeps the
-- wrapper ready for later.
function input.setJoystick(joystick)
    ensurePlayer()
    player.config.joystick = joystick
end

return input
