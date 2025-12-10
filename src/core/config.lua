local config = {
    world = {
        width = 6000,
        height = 6000,
    },
    spawn = {
        spawnInterval = 2,
        initialEnemyCount = 15,
        initialAsteroidCount = 80,
        safeEnemyRadius = 2500,
        maxEnemies = 40,
        enemiesPerSpawn = 1,
    },
    combat = {
        damagePerHit = 20,
        fireInterval = 0.3,
        lockDuration = 1.0,
        bulletRadius = 4,
    },
    player = {
        size = 16,
        maxHealth = 100,
        maxShield = 30,
        stopRadius = 5,
        slowRadius = 250,
        arrivalSpeedThreshold = 5,
        bounceFactor = 0.5,
        xpBase = 100,
        xpGrowth = 25,
        xpPerEnemy = 25,
        xpPerAsteroid = 5,
        -- Radius (in world units) around the player ship within which loose
        -- item pickups (XP shards, future resources) begin to feel the
        -- magnetic pull.
        magnetRadius = 260,
        -- Distance from the player at which a pickup is considered "collected"
        -- and its effect is applied immediately. This is generally a bit
        -- smaller than magnetRadius so items are sucked into the hull before
        -- they disappear.
        magnetPickupRadius = 30,
    },
    enemy = {
        spawnMargin = 50,
        sizeMin = 15,
        sizeMax = 25,
        maxHealth = 12,
        initialDriftSpeed = 20,
        detectionRange = 1000,
        attackRange = 350,
        attackTooFarFactor = 1.1,
        attackTooCloseFactor = 0.7,
        wanderIntervalBase = 3.0,
        wanderIntervalRandom = 4.0,
        wanderThrustThreshold = 2.5,
        -- Maximum radius (in world units) that an enemy is allowed to idle-wander
        -- away from its spawn point. This does not affect chase/attack behavior;
        -- it only keeps "idle" enemies loosely leashed to their home area.
        wanderRadius = 600,
        -- Obstacle avoidance steering settings
        avoidanceRadius = 180,    -- How far ahead to scan for obstacles
        avoidanceStrength = 1.5,  -- Multiplier for avoidance steering force
        avoidanceLookahead = 150, -- Look-ahead distance for velocity projection
    },
    input = {
        selectionRadius = 40,
    },
    camera = {
        minScale = 0.5,
        maxScale = 2.0,
        zoomWheelScale = 0.1,
    },
    ui = {
        hudPanelX = 24,
        hudPanelY = 20,
        hudPanelWidth = 280,
        hudPanelHeight = 120,
        hudRingOffsetX = 60,
        hudOuterRadius = 26,
        hudInnerRadius = 20,
        hudRightPadding = 18,
        hudContentGap = 24,
        hudDividerOffsetY = 30,
        hudBarHeight = 14,
        hudHullOffsetY = 12,
        hudShieldGapY = 12,
        fpsMarginX = 20,
        fpsMarginY = 20,
        hintMarginX = 20,
        hintMarginBottom = 30,
        abilitySize = 40,
        abilitySpacing = 10,
        abilityBottomMargin = 20,
    },
    physics = {
        shipThrust = 120,
        shipMaxSpeed = 200,
        shipRotationSpeed = 3.0,
        enemyThrust = 80,
        enemyMaxSpeed = 150,
        asteroidMaxDrift = 15,
        asteroidMinDrift = 2,
        projectileSpeed = 350,
        linearDamping = 0.1,
        angularDamping = 0.5,
    },
    -- Generic item / pickup tuning used by the XP shard + magnet system.
    items = {
        -- Visual base radius for item orbs; individual items can override.
        baseRadius = 6,

        -- Strength of the magnetic pull toward the player and maximum speed
        -- items are allowed to reach when being attracted.
        magnetForce = 220,
        magnetMaxSpeed = 260,
        magnetDamping = 3.0,

        -- Lifetime of loose pickups in seconds before they quietly fade out.
        maxLifetime = 20,

        -- XP shard spawn counts for enemies and asteroids. The total XP value
        -- for a death is distributed across this many shards.
        xpShardMinPerEnemy = 3,
        xpShardMaxPerEnemy = 5,
        xpShardMinPerAsteroid = 2,
        xpShardMaxPerAsteroid = 4,
    },
    engineTrail = {
        bubbleSizeMin = 3,
        bubbleSizeMax = 8,
        bubblesPerSpawn = 2,
        intensity = 1.0,
        spawnInterval = 0.035,
        maxPoints = 400,
        lifetime = 0.9,
    },
    asteroid = {
        minSize = 20,
        maxSize = 70,
        minHealth = 10,
        maxHealth = 40,
    },
}

return config
