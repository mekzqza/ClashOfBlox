local GameEnum = {}
-- Enum maps
local BuildingTypeById: { [number]: string } = {
	[1] = "TownHall_1",
	[2] = "Cannon_1",
	[3] = "ArcherTower",
	[4] = "Tree_1",
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
