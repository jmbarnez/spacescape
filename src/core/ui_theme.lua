local colors = require("src.core.colors")

local ui_theme = {}

--------------------------------------------------------------------------------
-- WINDOW-STYLE PANELS
-- Shared styling for larger HUD windows such as cargo and the galaxy map.
-- Minimal sci-fi aesthetic: near-black backgrounds with subtle cyan accents.
--------------------------------------------------------------------------------

ui_theme.window = {
    -- Main panel background: deep space black with hint of blue
    background = {0.02, 0.02, 0.02, 0.95},
    -- Top bar: barely visible separation
    topBar = {0.05, 0.05, 0.05, 0.95},
    -- Bottom bar: matches top for symmetry
    bottomBar = {0.03, 0.03, 0.03, 0.95},
    -- Shared corner radius (0 for sharp, squared-off panels)
    radius = 0,
    -- Slightly more compact bars for a tighter HUD footprint
    topBarHeight = 28,
    bottomBarHeight = 24,
    -- Border: thin cyan accent line
    border = {0.60, 0.60, 0.60, 0.6},
    -- Close button: minimal, appears on hover
    closeButtonBg = {0.12, 0.12, 0.12, 0.8},
    closeButtonBgHover = {0.30, 0.30, 0.30, 0.9},
    closeButtonX = {0.80, 0.80, 0.80, 0.8},
    closeButtonXHover = {1.00, 1.00, 1.00, 1.0},
}

--------------------------------------------------------------------------------
-- COMPACT HUD PANELS
-- Status HUD, minimap frame, target panel share this minimal framing.
--------------------------------------------------------------------------------

ui_theme.hudPanel = {
    -- Semi-transparent dark panel
    background = {0.02, 0.02, 0.02, 0.85},
    border = {0.60, 0.60, 0.60, 0.4},
    -- Bar elements
    barBackground = {0.01, 0.01, 0.01, 0.9},
    barOutline = {0.30, 0.30, 0.30, 0.5},
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
    slotBackground = {0.02, 0.02, 0.02, 0.85},
    slotBorderInactive = {0.50, 0.50, 0.50, 0.5},
}

--------------------------------------------------------------------------------
-- DEBUG / OVERLAY TEXT
--------------------------------------------------------------------------------

ui_theme.debug = {
    -- Minimal, low-contrast debug text
    fps = {1.0, 1.0, 0.0, 0.9},
    hint = {1.0, 1.0, 1.0, 0.3},
}

return ui_theme
