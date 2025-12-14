--------------------------------------------------------------------------------
-- ECS WORLD REF
--
-- Purpose:
--   Provide an acyclic way for legacy (non-ECS) modules to *use* the current
--   ECS world without directly requiring `src.ecs.world`.
--
-- Why:
--   Requiring `src.ecs.world` from gameplay modules can easily create require()
--   cycles because the ECS world itself loads systems which may (directly or
--   indirectly) load legacy modules.
--
-- Pattern:
--   - `src.ecs.world` sets itself once via `worldRef.set(world)`.
--   - Other modules call `worldRef.get()` / `worldRef.query(...)`.
--
-- Notes:
--   This is intentionally tiny and dependency-free so it is always safe to
--   require.
--------------------------------------------------------------------------------

local worldRef = {
    _world = nil,
}

--------------------------------------------------------------------------------
-- SET / GET
--------------------------------------------------------------------------------

function worldRef.set(world)
    worldRef._world = world
end

function worldRef.get()
    return worldRef._world
end

--------------------------------------------------------------------------------
-- CONVENIENCE HELPERS
--------------------------------------------------------------------------------

function worldRef.query(componentList)
    local world = worldRef._world
    if not world or not world.query then
        return {}
    end

    return world:query(componentList) or {}
end

function worldRef.getPlayerProgressEntity()
    local world = worldRef._world
    if not world or not world.query then
        return nil
    end

    local players = world:query({ "playerControlled" }) or {}

    for i = 1, #players do
        local e = players[i]
        if e and (e.experience or e.currency) then
            return e
        end
    end

    return players[1] or nil
end

return worldRef
