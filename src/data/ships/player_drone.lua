local player_drone = {
    ---------------------------------------------------------------------------
    -- Core identification / sizing
    ---------------------------------------------------------------------------
    id = "player_drone",

    -- Semantic role and class so shared systems can tell how to treat this
    -- ship without hard-coding file names.
    role = "player",
    class = "drone",

    -- Optional tags for UI / spawning / future progression systems.
    tags = {"player", "starter", "light_combat"},

    -- Free-form metadata for debug tools or codex-style UIs.
    metadata = {
        displayName = "Xeno-Link Drone",
        description = "Compact combat drone built around an alien-derived core lattice, with bifurcated sensor prongs and luminous node arrays.",
    },

    -- Design-time base size for the drone. The actual in-game size comes from
    -- config.player.size, but keeping this here makes the data self-contained
    -- if we ever want to preview / reuse the shape at a different scale.
    baseSize = 11,

    ---------------------------------------------------------------------------
    -- High-level gameplay stats (used by higher-level systems, not enforced
    -- directly by the ship template).
    --
    -- These intentionally mirror the generic schema documented in
    -- src.core.ship so we can eventually drive player/enemy tuning directly
    -- from ship data instead of scattering values across config files.
    ---------------------------------------------------------------------------
    stats = {
        hull = {
            base  = 100,   -- Nominal hull value for this chassis
            armor = 0.10,  -- Fractional damage reduction hint (0–1)
        },
        shield = {
            base   = 30,   -- Nominal shield capacity
            regen  = 0.0,  -- Shield regen per second (hint only)
            delay  = 3.0,  -- Seconds after taking damage before regen (hint)
        },
        mobility = {
            thrust    = 1.0, -- Relative thrust vs baseline
            maxSpeed  = 1.0, -- Relative max speed vs baseline
            turnRate  = 1.0, -- Relative turn speed vs baseline
        },
    },

    ---------------------------------------------------------------------------
    -- Hull shape (primary solid body of the drone)
    --
    -- All coordinates below are expressed in *normalized* units relative to the
    -- final ship size. The render code multiplies these by the requested size
    -- (e.g., config.player.size) to get world-space vertex positions.
    --
    -- Coordinate space conventions:
    --   * +X points toward the nose of the ship (forward)
    --   * +Y points "down" (screen space)
    --   * (0, 0) is the center of mass of the drone
    ---------------------------------------------------------------------------
    hull = {
        -- Futuristic combat drone hull with a dual-prong sensor nose,
        -- angular central body, and compact rear engine block. Vertices
        -- are ordered clockwise starting at the upper front prong tip.
        -- The silhouette stays fairly compact but feels more "high-tech"
        -- than a simple diamond.
        points = {
            {  1.18, -0.22 },  -- Front upper prong tip
            {  0.90, -0.40 },  -- Upper prong inner corner
            {  0.60, -0.55 },  -- Upper nose shoulder
            {  0.25, -0.72 },  -- Upper mid edge
            { -0.25, -0.84 },  -- Upper rear sweep into engine block
            { -0.95, -0.72 },  -- Rear upper corner of engine block
            { -1.18, -0.36 },  -- Rear upper notch
            { -1.24,  0.00 },  -- Rear center spine
            { -1.18,  0.36 },  -- Rear lower notch
            { -0.95,  0.72 },  -- Rear lower corner of engine block
            { -0.25,  0.84 },  -- Lower rear sweep into body
            {  0.25,  0.72 },  -- Lower mid edge
            {  0.60,  0.55 },  -- Lower nose shoulder
            {  0.90,  0.40 },  -- Lower prong inner corner
            {  1.18,  0.22 },  -- Front lower prong tip
        },
    },

    ---------------------------------------------------------------------------
    -- Greebles / micro surface detail
    --
    -- These are small panels and lights that sit on top of the hull/armor to
    -- make the drone feel more mechanical and grounded without changing the
    -- collision profile.
    ---------------------------------------------------------------------------
    greebles = {
        -- Long dorsal alien lattice panel along the upper hull spine
        {
            type   = "panel",
            x      = 0.05,
            y      = -0.18,
            length = 1.30,
            width  = 0.16,
            angle  = 0.10,
        },
        -- Angled upper side plate, gives the hull a faceted alien contour
        {
            type   = "panel",
            x      = -0.20,
            y      = -0.52,
            length = 0.88,
            width  = 0.18,
            angle  = -0.25,
        },
        -- Angled lower side plate (mirrored)
        {
            type   = "panel",
            x      = -0.20,
            y      =  0.52,
            length = 0.88,
            width  = 0.18,
            angle  = 0.25,
        },
        -- Small diagonal panel near the nose (upper)
        {
            type   = "panel",
            x      = 0.55,
            y      = -0.30,
            length = 0.55,
            width  = 0.14,
            angle  = -0.35,
        },
        -- Small diagonal panel near the nose (lower)
        {
            type   = "panel",
            x      = 0.55,
            y      =  0.30,
            length = 0.55,
            width  = 0.14,
            angle  = 0.35,
        },

        -- Forward sensor node cluster along the prongs (upper)
        {
            type   = "light",
            x      = 0.95,
            y      = -0.18,
            radius = 0.14,
        },
        {
            type   = "light",
            x      = 0.70,
            y      = -0.26,
            radius = 0.11,
        },
        -- Forward sensor node cluster (lower)
        {
            type   = "light",
            x      = 0.95,
            y      =  0.18,
            radius = 0.14,
        },
        {
            type   = "light",
            x      = 0.70,
            y      =  0.26,
            radius = 0.11,
        },

        -- Spine lights along the mid-body
        {
            type   = "light",
            x      = -0.10,
            y      = -0.08,
            radius = 0.10,
        },
        {
            type   = "light",
            x      = -0.40,
            y      =  0.00,
            radius = 0.10,
        },
        {
            type   = "light",
            x      = -0.70,
            y      =  0.08,
            radius = 0.10,
        },

        -- Rear status light centered between engines
        {
            type   = "light",
            x      = -0.95,
            y      =  0.00,
            radius = 0.18,
        },
    },

    ---------------------------------------------------------------------------
    -- Wing geometry (solid side fins)
    ---------------------------------------------------------------------------
    wings = {
        -- Upper wing: slim stabilizer / hover strut, more like a side pod
        -- than a huge fin so the drone feels compact and agile.
        {
            role = "primary",
            points = {
                {  0.32, -0.60 },  -- Root front
                { -0.10, -1.02 },  -- Outer front
                { -0.85, -0.96 },  -- Outer rear
                { -0.58, -0.60 },  -- Root rear
            },
        },
        -- Lower wing: mirrored counterpart for vertical symmetry
        {
            role = "primary",
            points = {
                {  0.32,  0.60 },  -- Root front
                { -0.10,  1.02 },  -- Outer front
                { -0.85,  0.96 },  -- Outer rear
                { -0.58,  0.60 },  -- Root rear
            },
        },
    },

    ---------------------------------------------------------------------------
    -- Armor plates / surface detail
    --
    -- These are small rectangular panels that sit on top of the hull to make
    -- the drone feel more mechanical and solid (vents, armor strips, etc.).
    -- Each entry defines a rectangle in normalized units:
    --   x, y   -> center position relative to ship center
    --   w, h   -> width / height factors relative to ship size
    --   angle  -> rotation in radians
    ---------------------------------------------------------------------------
    armorPlates = {
        -- Central dorsal plate broken into two segments to feel more grown
        -- than manufactured.
        {
            x = -0.05,
            y = -0.06,
            w = 0.80,
            h = 0.26,
            angle = 0.10,
        },
        {
            x = 0.40,
            y =  0.06,
            w = 0.70,
            h = 0.22,
            angle = -0.12,
        },
        -- Upper side armor plate, slightly skewed for alien asymmetry
        {
            x = -0.35,
            y = -0.42,
            w = 0.95,
            h = 0.24,
            angle = -0.18,
        },
        -- Lower side armor plate (mirrored skew)
        {
            x = -0.35,
            y =  0.42,
            w = 0.95,
            h = 0.24,
            angle = 0.18,
        },
        -- Front armor cluster hugging the cockpit
        {
            x = 0.65,
            y = 0.00,
            w = 0.45,
            h = 0.44,
            angle = 0.0,
        },
    },

    ---------------------------------------------------------------------------
    -- Cockpit / sensor dome
    ---------------------------------------------------------------------------
    cockpit = {
        -- Rectangular sensor window toward the front
        x = 0.50,
        y = 0.00,
        radius = 0.28,
    },

    ---------------------------------------------------------------------------
    -- Engine cluster positions
    ---------------------------------------------------------------------------
    engines = {
        -- Dual rectangular thruster ports at the rear
        {
            x = -1.10,
            y = -0.35,
            radius = 0.30,
        },
        {
            x = -1.10,
            y =  0.35,
            radius = 0.30,
        },
    },

    ---------------------------------------------------------------------------
    -- Collision shape
    --
    -- For now we reuse the main hull outline as the collision polygon so the
    -- physics profile closely matches the visual silhouette. If we ever want a
    -- looser collision hull (e.g., without wings), we can override vertices
    -- here with a dedicated set.
    ---------------------------------------------------------------------------
    collision = {
        -- When nil, the runtime will fall back to hull.points.
        vertices = nil,
    },
}

return player_drone
