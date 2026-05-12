-- !strict

--[[
    @ Building Config Eack Level
    - UpgradeCost: Cost to upgrade to the next level
    - UpgradeTime: Time in seconds to upgrade to the next level
    - MaxHp: Maximum health points of the building at this level
]]
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

	["Cannon_1"] = {
		Width = 3,
		Length = 3,
		[1] = {
			UpgradeCost = 50,
			UpgradeTime = 30,
			MaxHp = 500,
			FireRange = 10,
			Damage = 50,
		},
	},

	["ElixirStorage_1"] = {
		Width = 3,
		Length = 3,
	},
	["ElixirCollector_1"] = {
		Width = 3,
		Length = 3,
	},

	["GoldMine_1"] = {
		Width = 3,
		Length = 3,
	},
	["GoldStorage_1"] = {
		Width = 3,
		Length = 3,
	},

	["Tree_1"] = {
		Width = 2,
		Length = 2,
	},
	["Barrack_1"] = {
		Width = 3,
		Length = 3,
	},
	["Campfire_1"] = {
		Width = 4,
		Length = 4,
	},
	["Builinghall_1"] = {
		Width = 2,
		Length = 2,
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
