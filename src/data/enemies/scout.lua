local enemy_scout_ship = require("src.data.ships.enemy_scout")

local scout = {
    ---------------------------------------------------------------------------
    -- Core identification
    ---------------------------------------------------------------------------
    id = "scout",

    ---------------------------------------------------------------------------
    -- Ship design
    --
    -- shipBlueprint must be a normalized ship layout table (src.data.ships.*)
    -- that core.ship can convert into a world-space instance.
    ---------------------------------------------------------------------------
    shipBlueprint = enemy_scout_ship,

    ---------------------------------------------------------------------------
    -- Spawn / tuning knobs
    ---------------------------------------------------------------------------
    levelRange = { min = 1, max = 3 },

    -- If omitted, code falls back to config.enemy.sizeMin/sizeMax.
    sizeRange = { min = 16, max = 24 },

    ai = {
        -- Keep these separate from scaling so enemy behavior stays predictable.
        detectionRange = 650,
        attackRange = 350,

        -- Fire gating is handled in the FiringSystem via attackRange.
        -- detectionRange only controls when they wake up / chase.
    },

    ---------------------------------------------------------------------------
    -- Combat stats
    ---------------------------------------------------------------------------
    health = {
        base = 12,
        perLevel = 0.8,
    },

    weapon = {
        -- Name corresponds to src.core.weapons.* entries.
        id = "enemyPulseLaser",

        -- Optional override (if nil, weapon damage is taken from the base weapon).
        -- damage = 1,

        -- Optional scaling by level above 1.
        damagePerLevel = 0.6,
    },

    ---------------------------------------------------------------------------
    -- Rewards / loot
    ---------------------------------------------------------------------------
    rewards = {
        xp = 25,
        tokens = 1,

        -- Optional wreck loot; RewardSystem will spawn a wreck only if the
        -- entity has BOTH: ship tag AND loot component.
        loot = {
            -- Chance (0..1 or 0..100) to spawn a loot container when this enemy
            -- is destroyed.
            dropChance = 25,
            cargo = {},
            coins = 0,
        },
    },

    respawn = {
        delay = 30,
    },
}

return scout
