-- !strict

local BuildingConfig = {}

export type BuildingData = { [string]: { Width: number, Length: number, [number]: BuildingLevelData } }

export type BuildingLevelData = {
	UpgradeCost: number,
	UpgradeTime: number,
	MaxHp: number,

	FireRange: number?,
	Damage: number?,
}

local Buildings: BuildingData = {
	["TownHall_1"] = {
		Width = 4,
		Length = 4,
		[1] = {
			UpgradeCost = 0,
			UpgradeTime = 0,
			MaxHp = 1000,
		},
		[2] = {
			UpgradeCost = 100,
			UpgradeTime = 60,
			MaxHp = 1200,
		},
	},

	["Cannon"] = {
		Width = 2,
		Length = 2,
		[1] = {
			UpgradeCost = 50,
			UpgradeTime = 30,
			MaxHp = 500,
			FireRange = 10,
			Damage = 50,
		},
	},
}

function BuildingConfig:GetBuildingDimensions(buildingType: string): { Width: number, Length: number }?
	local building = Buildings[buildingType]
	if not building then
		return nil
	end

	return {
		Width = building.Width,
		Length = building.Length,
	}
end

function BuildingConfig:GetBuildingData(buildingType: string, level: number): BuildingLevelData?
	return Buildings[buildingType][level] or nil
end

return BuildingConfig
