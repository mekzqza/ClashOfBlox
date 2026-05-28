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
	UpgradeResourceType: number?,
	MaxHp: number,

	FireRange: number?,
	Damage: number?,
	Description: string?,
	ProductionRate: number?,
	MaxStorage: number?,
}

export type BuildingData = { [string]: { Width: number, Length: number, Category: Category?,ResourceType:string?,
    CollectorType:string?,
    [number]: BuildingLevelData } }

local Category = {
    Army      = 1,
    Resources = 2,
    Defense   = 3,
    Trap      = 4,
}

local UpgradeResourceType = {
    Golds = 1,
    Elixirs = 2,
}

local Buildings: BuildingData = {
	["TownHall"] = {
		Width = 4,
		Length = 4,
		UpgradeResourceType = UpgradeResourceType.Golds,

	},

	["Cannon"] = {
		Width = 3,
		Length = 3,
		UpgradeResourceType = UpgradeResourceType.Golds,

	},

	["ElixirStorage"] = {
		Width = 3,
		Length = 3,
		UpgradeResourceType = UpgradeResourceType.Golds,

	},
	["ElixirCollector"] = {
		Width = 3,
		Length = 3,
		UpgradeResourceType = UpgradeResourceType.Golds,
		CollectorType = "ElixirCollector",
		[1] = {
			UpgradeCost = 150,
			UpgradeTime = 60,
			MaxHp = 400,

			ProductionRate = 200,
			Capacity = 2000,

		},
	},

	["GoldMine"] = {
		Width = 3,
		Length = 3,
		UpgradeResourceType = UpgradeResourceType.Elixirs,
		CollectorType = "GoldCollector",
		[1] = {
			UpgradeCost = 150,
			UpgradeTime = 60,
			MaxHp = 400,

			ProductionRate = 200,
			Capacity = 2000,
		},
	},
	["GoldStorage"] = {
		Width = 3,
		Length = 3,
		UpgradeResourceType = UpgradeResourceType.Elixirs,
	},

	["Tree"] = {
		Width = 2,
		Length = 2,

		[1] = {
		    UpgradeCost = 0,
            UpgradeTime = 0,
            MaxHp = 100,

            Description = "A tree that can be cut down for resources.",
		}
	},
	["Barrack"] = {
		Width = 3,
		Length = 3,
		UpgradeResourceType = UpgradeResourceType.Elixirs,

	},
	["Campfire"] = {
		Width = 4,
		Length = 4,
		UpgradeResourceType = UpgradeResourceType.Elixirs,


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

function BuildingConfig:IsSameCategory(buildingType1: number, buildingType2: number): boolean?
    if buildingType1 == buildingType2 then
        return true
    end
    return
end

function BuildingConfig:GetBuildingData(buildingType: string, level: number): BuildingLevelData?
	local building = Buildings[buildingType]
	if not building then
		return nil
	end
	return building[level] or nil
end

function BuildingConfig:GetCollectorType(buildingType: string): string?
    local building = Buildings[buildingType]
    if not building then
        return nil
    end
    return building.CollectorType or nil
end

return BuildingConfig
