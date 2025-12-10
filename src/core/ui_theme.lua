local colors = require("src.core.colors")

local ui_theme = {}

--------------------------------------------------------------------------------
-- WINDOW-STYLE PANELS
-- Shared styling for larger HUD windows such as cargo and the galaxy map.
-- Minimal sci-fi aesthetic: near-black backgrounds with subtle cyan accents.
--------------------------------------------------------------------------------

ui_theme.window = {
    -- Main panel background: deep space black with hint of blue
    background = {0.02, 0.03, 0.05, 0.95},
    -- Top bar: barely visible separation
    topBar = {0.04, 0.05, 0.08, 0.95},
    -- Bottom bar: matches top for symmetry
    bottomBar = {0.03, 0.04, 0.06, 0.95},
    -- Shared rounded corner radius
    radius = 6,
    -- Border: thin cyan accent line
    border = {0.20, 0.60, 0.70, 0.6},
    -- Close button: minimal, appears on hover
    closeButtonBg = {0.10, 0.12, 0.15, 0.8},
    closeButtonBgHover = {0.50, 0.15, 0.18, 0.9},
    closeButtonX = {0.70, 0.75, 0.80, 0.8},
    closeButtonXHover = {1.00, 1.00, 1.00, 1.0},
}

--------------------------------------------------------------------------------
-- COMPACT HUD PANELS
-- Status HUD, minimap frame, target panel share this minimal framing.
--------------------------------------------------------------------------------

ui_theme.hudPanel = {
    -- Semi-transparent dark panel
    background = {0.02, 0.03, 0.05, 0.85},
    border = {0.20, 0.60, 0.70, 0.4},
    -- Bar elements
    barBackground = {0.01, 0.02, 0.04, 0.9},
    barOutline = {0.15, 0.20, 0.25, 0.5},
}

--------------------------------------------------------------------------------
-- MINIMAP ACCENTS
--------------------------------------------------------------------------------

ui_theme.minimap = {
    -- Subtle boundary indicators
    worldBounds = {0.25, 0.55, 0.65, 0.6},
    viewport = {0.30, 0.60, 0.70, 0.5},
}

--------------------------------------------------------------------------------
-- ABILITY BAR
--------------------------------------------------------------------------------

ui_theme.abilityBar = {
    slotBackground = {0.02, 0.03, 0.05, 0.85},
    slotBorderInactive = {0.20, 0.50, 0.60, 0.5},
}

--------------------------------------------------------------------------------
-- DEBUG / OVERLAY TEXT
--------------------------------------------------------------------------------

ui_theme.debug = {
    -- Minimal, low-contrast debug text
    fps = {0.50, 0.60, 0.70, 0.6},
    hint = {0.40, 0.50, 0.60, 0.3},
}

return ui_theme
