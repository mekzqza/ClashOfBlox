local GameEnum = {}
-- Enum maps
local BuildingTypeById: { [number]: string } = {
	[1] = "TownHall_1",
	[2] = "Cannon_1",
	[3] = "ArcherTower",
	[4] = "Tree_1",
	[5] = "Builinghall_1",
	[6] = "Barrack_1",
	[7] = "Campfire_1",
	[8] = "ElixirStorage_1",
	[9] = "ElixirCollector_1",
	[10] = "GoldMine_1",
	[11] = "GoldStorage_1",
}

local BuildingTypeIdByName: { [string]: number } = {}
for id, name in BuildingTypeById do
	BuildingTypeIdByName[name] = id
end

function GameEnum:GetBuildingTypeById(id: number): string
	return BuildingTypeById[id] or "Unknown"
end

function GameEnum:GetBuildingTypeIdByName(name: string): number
	return BuildingTypeIdByName[name]
end

return GameEnum
