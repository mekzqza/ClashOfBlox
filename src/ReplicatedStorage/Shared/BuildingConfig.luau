--!strict

--[[
    @ Building Config Eack Level
    - UpgradeCost: Cost to upgrade to the next level
    - UpgradeTime: Time in seconds to upgrade to the next level
    - MaxHp: Maximum health points of the building at this level
]]

local BuildingConfig = {}
export type Category = |"Army" |"Resources"| "Defrens"| "Trap"
export type ResourceType = "Gold" | "Elixir"

export type BuildingLevelData = {
	UpgradeCost: number,
	UpgradeTime: number,
	MaxHp: number,
	Category: Category,

	FireRange: number?,
	Damage: number?,
	Description: string?,
	ProductionRate: number?,
	MaxStorage: number?,
	ResourceType: ResourceType?,
}

export type BuildingData = { [string]: { Width: number, Length: number, [number]: BuildingLevelData } }

local Buildings: BuildingData = {
	["TownHall_1"] = {
		Width = 4,
		Length = 4,
	},

	["Cannon_1"] = {
		Width = 3,
		Length = 3,
	},

	["ElixirStorage_1"] = {
		Width = 3,
		Length = 3,
	},
	["ElixirCollector_1"] = {
		Width = 3,
		Length = 3,
		[1] = {
			UpgradeCost = 150,
			UpgradeTime = 60,
			MaxHp = 400,
			Category = "Resources",
			ProductionRate = 200,
			MaxStorage = 2000,
			ResourceType = "Elixir",
		},
	},

	["GoldMine_1"] = {
		Width = 3,
		Length = 3,
		[1] = {
			UpgradeCost = 150,
			UpgradeTime = 60,
			MaxHp = 400,
			Category = "Resources",
			ProductionRate = 200,
			MaxStorage = 2000,
			ResourceType = "Gold",
		},
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
	local building = Buildings[buildingType]
	if not building then
		return nil
	end
	return building[level] or nil
end

return BuildingConfig
