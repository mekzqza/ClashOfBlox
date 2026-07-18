local GameEnum = {}
-- Enum maps
local BuildingTypeById: { [number]: string } = {
	[1] = "Nexus",
	[2] = "ArcaneTurret",
	[3] = "ArcherTower",
	[4] = "Tree",
	[5] = "ArtificerHut",
	[6] = "SummonAltar",
	[7] = "HeroCamp",
	[8] = "AetherWell",
	[9] = "AetherSiphon",
	[10] = "CrystalMine",
	[11] = "CrystalVault",
	[12] = "Crystal",
	[13] = "Stump",
	[14] = "RockStone",
	[15] = "Mushroom",
	[16] = "Log",
}

local UnitTypeById: { [number]: string } = {
	[1] = "Goblin",
	[2] = "Barbarian",
}

local MapSkinById: { [number]: string } = {
	[1] = "Default",
	[2] = "Desert",
	[3] = "Snow",
	[4] = "Lava",
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

local UnitTypeIdByName: { [string]: number } = {}
for id, name in UnitTypeById do
	UnitTypeIdByName[name] = id
end

function GameEnum:GetUnitTypeById(id: number): string
	return UnitTypeById[id] or "Unknown"
end

function GameEnum:GetUnitTypeIdByName(name: string): number
	return UnitTypeIdByName[name]
end

local MapSkinNameByName: { [string]: number } = {}
for id, name in MapSkinById do
	MapSkinNameByName[name] = id
end

function GameEnum:GetMapSkinById(id: number): string
	return MapSkinById[id] or "Unknown"
end

function GameEnum:GetMapSkinIdByName(name: string): number
	return MapSkinNameByName[name]
end

return GameEnum
