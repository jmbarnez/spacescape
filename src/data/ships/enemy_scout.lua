local enemy_scout = {
    ---------------------------------------------------------------------------
    -- Core identification
    ---------------------------------------------------------------------------
    id = "enemy_scout",
    role = "enemy",
    class = "scout",

    tags = {"enemy", "scout", "starter"},

    metadata = {
        displayName = "Wasp Scout",
        description = "A lightweight raider chassis designed to harass targets at close range.",
    },

    ---------------------------------------------------------------------------
    -- Optional palette (used by ship_renderer.drawEnemy)
    ---------------------------------------------------------------------------
    palette = {
        primary = {0.20, 0.22, 0.28},
        secondary = {0.14, 0.16, 0.20},
        accent = {0.85, 0.25, 0.20},
        glow = {1.00, 0.45, 0.30},
    },

    -- Normalized blueprint base size. The instance builder will scale all
    -- geometry by the requested size at spawn time.
    baseSize = 12,

    ---------------------------------------------------------------------------
    -- Geometry (normalized coordinates)
    ---------------------------------------------------------------------------
    hull = {
        -- Simple aggressive arrow hull.
        points = {
            {  1.20,  0.00 },
            {  0.45, -0.55 },
            { -0.10, -0.45 },
            { -1.10, -0.20 },
            { -1.22,  0.00 },
            { -1.10,  0.20 },
            { -0.10,  0.45 },
            {  0.45,  0.55 },
        },
    },

    wings = {
        {
            role = "primary",
            points = {
                {  0.10, -0.35 },
                { -0.40, -0.95 },
                { -0.95, -0.70 },
                { -0.55, -0.25 },
            },
        },
        {
            role = "primary",
            points = {
                {  0.10,  0.35 },
                { -0.40,  0.95 },
                { -0.95,  0.70 },
                { -0.55,  0.25 },
            },
        },
    },

    engines = {
        { x = -0.95, y = -0.25, radius = 0.16 },
        { x = -0.95, y =  0.25, radius = 0.16 },
    },

    greebles = {
        { type = "panel", x = -0.10, y = -0.15, length = 0.75, width = 0.14, angle = -0.10 },
        { type = "panel", x = -0.10, y =  0.15, length = 0.75, width = 0.14, angle =  0.10 },
        { type = "light", x =  0.55, y =  0.00, radius = 0.12 },
    },

    ---------------------------------------------------------------------------
    -- Optional collision override
    -- If omitted, core.ship will compute a convex hull from hull + wings.
    ---------------------------------------------------------------------------
    -- collision = {
    --     vertices = {
    --         {  1.15,  0.00 },
    --         {  0.40, -0.50 },
    --         { -1.15, -0.18 },
    --         { -1.25,  0.00 },
    --         { -1.15,  0.18 },
    --         {  0.40,  0.50 },
    --     },
    -- },
}

return enemy_scout
