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

-- Precompute a lookup table so Love callbacks (keypressed/mousepressed/etc.)
-- can quickly mark actions as pressed/released without duplicating bindings.
local function buildSourceActionMap(controls)
    local map = {}

    for action, sources in pairs(controls or {}) do
        for _, source in ipairs(sources or {}) do
            if type(source) == "string" then
                map[source] = map[source] or {}
                map[source][#map[source] + 1] = action
            end
        end
    end

    return map
end

local SOURCE_TO_ACTIONS = buildSourceActionMap(DEFAULT_CONTROLS)

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

-- Event-driven pressed/released flags.
--
-- Baton is polling-based (love.keyboard.isDown/love.mouse.isDown). That is
-- great for "held" states, but it can theoretically miss extremely fast
-- press+release taps between frames.
--
-- To make UI clicks and toggles feel rock-solid, we also record Love callbacks
-- into these per-frame tables. input.update() snapshots + clears them.
local pendingPressed = {}
local pendingReleased = {}
local framePressed = {}
local frameReleased = {}

-- Mouse event positions (screen-space), captured at callback-time so we can
-- pass the exact click coordinate through to HUD/gameplay systems.
local pendingMousePressedPos = {}
local pendingMouseReleasedPos = {}
local frameMousePressedPos = {}
local frameMouseReleasedPos = {}

local function ensurePlayer()
    if player then
        return player
    end

    player = baton.new(buildDefaultConfig())
    return player
end

--------------------------------------------------------------------------------
-- LIFECYCLE
--------------------------------------------------------------------------------

-- Call once per frame (ideally early in your update loop).
function input.update(dt)
    local p = ensurePlayer()

    -- Snapshot and clear event-driven input.
    framePressed = pendingPressed
    frameReleased = pendingReleased
    frameMousePressedPos = pendingMousePressedPos
    frameMouseReleasedPos = pendingMouseReleasedPos

    pendingPressed = {}
    pendingReleased = {}
    pendingMousePressedPos = {}
    pendingMouseReleasedPos = {}

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
    p:update()
end

--------------------------------------------------------------------------------
-- LOVE CALLBACK HOOKS (EVENT INPUT)
--------------------------------------------------------------------------------

-- LOVE reports wheel movement via callbacks; Baton doesn't track this.
function input.wheelmoved(x, y)
    wheelAccumX = wheelAccumX + (x or 0)
    wheelAccumY = wheelAccumY + (y or 0)
end

-- Record key presses/releases via Love callbacks.
-- These are optional but strongly recommended for "tap" inputs.
local function markActionsForSource(source, dest)
    local actions = SOURCE_TO_ACTIONS[source]
    if not actions then
        return
    end

    for i = 1, #actions do
        dest[actions[i]] = true
    end
end

function input.keypressed(key)
    if not key then
        return
    end

    markActionsForSource("key:" .. key, pendingPressed)
end

function input.keyreleased(key)
    if not key then
        return
    end

    markActionsForSource("key:" .. key, pendingReleased)
end

function input.mousepressed(x, y, button)
    if not button then
        return
    end

    local source = "mouse:" .. tostring(button)
    markActionsForSource(source, pendingPressed)
    pendingMousePressedPos[button] = { x = x, y = y }
end

function input.mousereleased(x, y, button)
    if not button then
        return
    end

    local source = "mouse:" .. tostring(button)
    markActionsForSource(source, pendingReleased)
    pendingMouseReleasedPos[button] = { x = x, y = y }
end

--------------------------------------------------------------------------------
-- ACTION API (BATON)
--------------------------------------------------------------------------------

function input.down(action)
    local p = ensurePlayer()
    return p:down(action)
end

function input.pressed(action)
    local p = ensurePlayer()
    if framePressed and framePressed[action] then
        return true
    end
    return p:pressed(action)
end

function input.released(action)
    local p = ensurePlayer()
    if frameReleased and frameReleased[action] then
        return true
    end
    return p:released(action)
end

function input.get(action)
    local p = ensurePlayer()
    return p:get(action)
end

function input.getRaw(action)
    local p = ensurePlayer()
    return p:getRaw(action)
end

function input.getActiveDevice()
    local p = ensurePlayer()
    return p:getActiveDevice()
end

--------------------------------------------------------------------------------
-- MOUSE HELPERS
--------------------------------------------------------------------------------

function input.getMousePosition()
    return love.mouse.getPosition()
end

function input.getMousePressedPosition(button)
    local pos = frameMousePressedPos and frameMousePressedPos[button]
    if not pos then
        return nil, nil
    end

    return pos.x, pos.y
end

function input.getMouseReleasedPosition(button)
    local pos = frameMouseReleasedPos and frameMouseReleasedPos[button]
    if not pos then
        return nil, nil
    end

    return pos.x, pos.y
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
    local p = ensurePlayer()
    p.config.joystick = joystick
end

return input
