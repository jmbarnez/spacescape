local colors = {
    ship = {0.2, 0.6, 1.0},
    projectile = {0.3, 0.7, 1.0},
    enemy = {1.0, 0.3, 0.3},
    enemyOutline = {1.0, 0.5, 0.5},
    health = {0.3, 1.0, 0.3},
    healthBg = {0.3, 0.3, 0.3},
    movementIndicator = {0.3, 1.0, 0.3, 0.5},
    star = {1.0, 1.0, 1.0},
    targetRing = {1.0, 0.0, 0.0, 0.9},
    targetRingLocking = {1.0, 1.0, 0.0, 0.9},
    targetRingLocked = {0.9, 0.1, 0.1, 0.95},

    white = {1.0, 1.0, 1.0, 1.0},

    -- UI colors
    uiPanelBorder = {1.0, 1.0, 1.0, 0.5},
    uiText = {1.0, 1.0, 1.0, 1.0},
    uiFps = {1.0, 1.0, 0.0, 0.7},
    uiInstruction = {1.0, 1.0, 1.0, 0.5},
    uiAbilitySlotBg = {0.0, 0.0, 0.0, 0.6},
    uiAbilityActive = {0.3, 0.8, 1.0, 1.0},
    uiAbilityInactive = {1.0, 1.0, 1.0, 0.5},
    uiCooldownBg = {0.0, 0.0, 0.0, 0.6},
    uiCooldownText = {1.0, 1.0, 1.0, 1.0},
    uiGameOverBg = {0.0, 0.0, 0.0, 0.7},
    uiGameOverText = {1.0, 0.3, 0.3, 1.0},
    uiGameOverSubText = {0.7, 0.7, 0.7, 1.0},

    -- Background / environment
    backgroundSpace = {0.02, 0.01, 0.05, 1.0},

    -- FX colors
    velocityVector = {0.5, 0.8, 1.0, 0.4},
    explosion = {1.0, 0.8, 0.4},
    particleImpact = {1.0, 1.0, 1.0},
    particleSpark = {1.0, 1.0, 0.8},
    engineTrailA = {0.10, 0.95, 1.0},
    engineTrailB = {0.55, 1.0, 1.0},
    -- Cyan outline color used when hovering entities with the mouse cursor
    hoverOutline = {0.3, 0.95, 1.0, 0.95},

    -- Damage / combat feedback
    damageEnemy = {1.0, 0.9, 0.4},
    damagePlayer = {1.0, 0.4, 0.4},
    shieldDamage = {0.55, 0.9, 1.0},
    missBg = {0.3, 0.6, 1.0},
    asteroidSpark = {0.9, 0.85, 0.7},

    -- Asteroid UI
    asteroidHealthBg = {0.2, 0.2, 0.2, 0.9},
    asteroidHealth = {1.0, 1.0, 0.3, 1.0},

    -- Floating text defaults
    floatingBg = {1.0, 0.0, 0.0},
    floatingText = {1.0, 1.0, 1.0},

    -- Item / pickup visuals (XP shards, resources, etc.)
    itemCore = {0.35, 1.0, 0.8, 1.0},
    itemGlow = {0.15, 0.7, 0.6, 0.45},
}

return colors
