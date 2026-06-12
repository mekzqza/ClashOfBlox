local GameEnum = {}
-- Enum maps
local BuildingTypeById: { [number]: string } = {
	[1] = "Nexus",
	[2] = "ArcaneTurret",
	[3] = "ArcherTower",
	[4] = "CrystalTree",
	[5] = "ArtificerHut",
	[6] = "SummonAltar",
	[7] = "HeroCamp",
	[8] = "AetherWell",
	[9] = "AetherSiphon",
	[10] = "CrystalMine",
	[11] = "CrystalVault",
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
