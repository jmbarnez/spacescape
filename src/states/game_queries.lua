local ecsWorld = require("src.ecs.world")

local game_queries = {}

function game_queries.getEnemyEntities()
	local ships = ecsWorld:query({ "ship", "faction", "position" }) or {}
	local enemies = {}
	for _, e in ipairs(ships) do
		if e.faction and e.faction.name == "enemy" and not e._removed and not e.removed then
			table.insert(enemies, e)
		end
	end
	return enemies
end

return game_queries
