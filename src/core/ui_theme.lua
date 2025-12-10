local colors = require("src.core.colors")

local ui_theme = {}

--------------------------------------------------------------------------------
-- WINDOW-STYLE PANELS
-- Shared styling for larger HUD windows such as cargo and the galaxy map.
-- The palette aims for a minimal, sleek sci-fi look: deep blue-black glass
-- backgrounds with thin cyan accents and subtle highlights.
--------------------------------------------------------------------------------

ui_theme.window = {
    -- Main panel background: dark, opaque, slightly blue-grey for a minimal
    -- sci-fi feel without bright neon.
    background = {0.06, 0.07, 0.10, 1.0},
    -- Top bar: a touch brighter than the body so it still reads as a title
    -- strip, but stays muted.
    topBar = {0.09, 0.11, 0.16, 1.0},
    -- Bottom bar: slightly darker band framing footer text.
    bottomBar = {0.05, 0.06, 0.09, 1.0},
    -- Shared rounded corner radius so all windows feel related.
    radius = 8,
    -- Border: soft steel-blue edge, not neon.
    border = {0.45, 0.55, 0.70, 1.0},
    -- Close button base / hover colors and X glyph; restrained reds and
    -- off-whites instead of saturated neon.
    closeButtonBg = {0.22, 0.25, 0.32, 1.0},
    closeButtonBgHover = {0.75, 0.30, 0.34, 1.0},
    closeButtonX = {0.90, 0.93, 0.98, 1.0},
    closeButtonXHover = {1.00, 1.00, 1.00, 1.0},
}

--------------------------------------------------------------------------------
-- COMPACT HUD PANELS
-- Status HUD, minimap frame, target panel, etc. share this framing so they
-- visually match the larger windows while remaining lighter-weight.
--------------------------------------------------------------------------------

ui_theme.hudPanel = {
    -- Compact HUD panels share a similar opaque background, slightly darker
    -- than the main window body so they sit cleanly over gameplay.
    background = {0.05, 0.06, 0.10, 1.0},
    border = ui_theme.window.border,
    -- Bar elements (health, shield, etc.).
    barBackground = {0.04, 0.05, 0.08, 1.0},
    barOutline = {0.18, 0.22, 0.30, 1.0},
}

--------------------------------------------------------------------------------
-- MINIMAP ACCENTS
--------------------------------------------------------------------------------

ui_theme.minimap = {
    -- World bounds outline and camera viewport colors inside the minimap:
    -- both use muted blue-grey so they are visible but not glowing.
    worldBounds = {0.60, 0.68, 0.80, 1.0},
    viewport = {0.55, 0.65, 0.78, 0.9},
}

--------------------------------------------------------------------------------
-- ABILITY BAR
--------------------------------------------------------------------------------

ui_theme.abilityBar = {
    slotBackground = {0.05, 0.06, 0.10, 1.0},
    slotBorderInactive = {0.55, 0.65, 0.80, 1.0},
}

--------------------------------------------------------------------------------
-- DEBUG / OVERLAY TEXT
--------------------------------------------------------------------------------

ui_theme.debug = {
    -- Debug overlays are subtle, avoiding harsh neon while remaining legible.
    fps = {0.75, 0.80, 0.90, 0.85},
    hint = {0.75, 0.80, 0.90, 0.40},
}

return ui_theme
