local systems = {
    updateSystems = {},
    sorted = false,
}

local function sortUpdateSystems()
    if systems.sorted then
        return
    end
    table.sort(systems.updateSystems, function(a, b)
        if a.order == b.order then
            return a.name < b.name
        end
        return a.order < b.order
    end)
    systems.sorted = true
end

function systems.registerUpdate(name, fn, order)
    table.insert(systems.updateSystems, {
        name = name,
        fn = fn,
        order = order or 0,
    })
    systems.sorted = false
end

function systems.runUpdate(dt, ctx)
    sortUpdateSystems()
    for _, entry in ipairs(systems.updateSystems) do
        entry.fn(dt, ctx)
    end
end

function systems.clear()
    systems.updateSystems = {}
    systems.sorted = false
end

return systems
