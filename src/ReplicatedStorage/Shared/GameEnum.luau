local GameEnum = {}
-- Enum maps
local BuildingTypeById: { [number]: string } = {
	[1] = "TownHall",
	[2] = "Cannon",
	[3] = "ArcherTower",
	[4] = "Tree",
	[5] = "Builinghut",
	[6] = "Barrack",
	[7] = "Campfire",
	[8] = "ElixirStorage",
	[9] = "ElixirCollector",
	[10] = "GoldMine",
	[11] = "GoldStorage",
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
