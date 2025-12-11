local colors = require("src.core.colors")
local camera = require("src.core.camera")

local shield_impact_fx = {}

shield_impact_fx.list = {}
shield_impact_fx.shader = nil

function shield_impact_fx.load()
    local ok, shader = pcall(love.graphics.newShader, "assets/shaders/shield_impact.glsl")
    if ok then
        shield_impact_fx.shader = shader
    else
        shield_impact_fx.shader = nil
    end
end

function shield_impact_fx.spawn(centerX, centerY, impactX, impactY, radius, color, followEntity)
    -- Basic guard: all coordinates must be valid numbers for the effect to work.
    if not centerX or not centerY or not impactX or not impactY then
        return
    end

    -- Normalise radius so the shader always has a sensible falloff.
    radius = radius or 40
    if radius <= 0 then
        radius = 40
    end

    -- Fallback to standard shield color palette if nothing specific was provided.
    color = color or colors.shieldDamage or { 0, 1, 1 }

    --------------------------------------------------------------------------
    -- Precompute the impact direction relative to the shield center.
    --
    -- This lets us keep the visible "dent" in the ring on the same side of
    -- the shield even if the center later follows a moving entity (for
    -- example, the player ship sliding after a hit or ramming an enemy).
    --------------------------------------------------------------------------
    local dirX = (impactX or centerX) - centerX
    local dirY = (impactY or centerY) - centerY
    local impactDistance = math.sqrt(dirX * dirX + dirY * dirY)

    if impactDistance > 0 then
        dirX = dirX / impactDistance
        dirY = dirY / impactDistance
    else
        -- If the impact landed exactly at the center, choose an arbitrary
        -- direction; the shader only needs a stable offset, not the exact
        -- world-space point.
        dirX = 1
        dirY = 0
        impactDistance = radius
    end

    local hit = {
        -- World-space reference center at spawn time. When followEntity is
        -- provided, the draw step will resolve the *current* center from the
        -- entity and treat these as fallbacks.
        cx = centerX,
        cy = centerY,

        -- Original impact point in world space (kept as a fallback and for
        -- any legacy use that might rely on it).
        ix = impactX,
        iy = impactY,

        -- Visual parameters
        radius = radius,
        color = { color[1] or 1, color[2] or 1, color[3] or 1 },
        startTime = love.timer.getTime(),
        duration = 0.35,

        -- Tracking data so the shield ring can follow a moving entity while
        -- still remembering which side was hit.
        impactDirX = dirX,
        impactDirY = dirY,
        impactDistance = impactDistance,
        followEntity = followEntity,
    }

    table.insert(shield_impact_fx.list, hit)
end

function shield_impact_fx.update(dt)
    if #shield_impact_fx.list == 0 then
        return
    end

    local now = love.timer.getTime()

    for i = #shield_impact_fx.list, 1, -1 do
        local hit = shield_impact_fx.list[i]
        local duration = hit.duration or 0.35
        local elapsed = now - (hit.startTime or now)

        if elapsed >= duration then
            table.remove(shield_impact_fx.list, i)
        end
    end
end

function shield_impact_fx.draw()
    if #shield_impact_fx.list == 0 then
        return
    end

    local shader = shield_impact_fx.shader
    if not shader then
        return
    end

    local previousShader = love.graphics.getShader()
    local prevBlend, prevAlpha = love.graphics.getBlendMode()

    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.setShader(shader)

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local camScale = camera.scale or 1
    local camX = camera.x or 0
    local camY = camera.y or 0

    local now = love.timer.getTime()

    for i = #shield_impact_fx.list, 1, -1 do
        local hit = shield_impact_fx.list[i]
        local duration = hit.duration or 0.35
        local elapsed = now - (hit.startTime or now)
        local t = elapsed / duration

        if t >= 1.0 then
            table.remove(shield_impact_fx.list, i)
        else
            ------------------------------------------------------------------
            -- Resolve the current world-space center for this shield hit.
            --
            -- If followEntity is set (e.g., the player state), we use the
            -- entity's live position so the ring visually tracks the ship as
            -- it continues to move after being hit.
            ------------------------------------------------------------------
            local centerX = hit.cx
            local centerY = hit.cy

            local follower = hit.followEntity
            if follower and follower.x and follower.y then
                centerX = follower.x
                centerY = follower.y
            end

            ------------------------------------------------------------------
            -- Reconstruct the impact point based on the stored direction and
            -- distance so that the visible distortion remains on the same
            -- side of the shield relative to its center.
            ------------------------------------------------------------------
            local impactX = hit.ix
            local impactY = hit.iy

            if hit.impactDirX and hit.impactDirY and hit.impactDistance then
                impactX = centerX + hit.impactDirX * hit.impactDistance
                impactY = centerY + hit.impactDirY * hit.impactDistance
            end

            local screenCenterX = (centerX - camX) * camScale + width / 2
            local screenCenterY = (centerY - camY) * camScale + height / 2
            local screenImpactX = (impactX - camX) * camScale + width / 2
            local screenImpactY = (impactY - camY) * camScale + height / 2

            shader:send("center", { screenCenterX, screenCenterY })
            shader:send("impact", { screenImpactX, screenImpactY })
            shader:send("radius", hit.radius * camScale)
            shader:send("color", hit.color)
            shader:send("progress", t)

            love.graphics.setColor(1, 1, 1, 1)
            local r = hit.radius
            love.graphics.rectangle("fill", centerX - r, centerY - r, r * 2, r * 2)
        end
    end

    love.graphics.setBlendMode(prevBlend, prevAlpha)
    love.graphics.setShader(previousShader)
    love.graphics.setColor(1, 1, 1, 1)
end

function shield_impact_fx.clear()
    for i = #shield_impact_fx.list, 1, -1 do
        table.remove(shield_impact_fx.list, i)
    end
end

return shield_impact_fx
