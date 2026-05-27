--!strict

--[[
    @ Building Config Eack Level
    - UpgradeCost: Cost to upgrade to the next level
    - UpgradeTime: Time in seconds to upgrade to the next level
    - MaxHp: Maximum health points of the building at this level
]]

local BuildingConfig = {}
export type Category = |"Army" |"Resources"| "Defrens"| "Trap"
export type ResourceType = "Golds" | "Elixirs"

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
	["TownHall"] = {
		Width = 4,
		Length = 4,
	},

	["Cannon"] = {
		Width = 3,
		Length = 3,
	},

	["ElixirStorage"] = {
		Width = 3,
		Length = 3,
	},
	["ElixirCollector"] = {
		Width = 3,
		Length = 3,
		[1] = {
			UpgradeCost = 150,
			UpgradeTime = 60,
			MaxHp = 400,

			Category = "Resources",
			ProductionRate = 200,
			Capacity = 2000,
			ResourceType = "Elixirs",

		},
	},

	["GoldMine"] = {
		Width = 3,
		Length = 3,
		[1] = {
			UpgradeCost = 150,
			UpgradeTime = 60,
			MaxHp = 400,

			Category = "Resources",
			ProductionRate = 200,
			Capacity = 2000,
			ResourceType = "Golds",
		},
	},
	["GoldStorage"] = {
		Width = 3,
		Length = 3,
	},

	["Tree"] = {
		Width = 2,
		Length = 2,
		[1] = {
		    UpgradeCost = 0,
            UpgradeTime = 0,
            MaxHp = 100,

            Category = "Defrens",
            Description = "A tree that can be cut down for resources.",
		}
	},
	["Barrack"] = {
		Width = 3,
		Length = 3,
	},
	["Campfire"] = {
		Width = 4,
		Length = 4,
	},
	["Builinghall"] = {
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
