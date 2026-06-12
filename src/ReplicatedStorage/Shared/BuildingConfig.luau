--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)

--[[
    @ Building Config Eack Level
    - UpgradeCost: Cost to upgrade to the next level
    - UpgradeTime: Time in seconds to upgrade to the next level
    - MaxHp: Maximum health points of the building at this level
]]

local BuildingConfig = {}
export type Category = |"Army" |"Resources"| "Defrens"| "Trap"| "Obstacle"
export type ResourceType = "Crystals" | "Aethers"

export type BuildingLevelData = {
	UpgradeCost: number,
	UpgradeTime: number,
	UpgradeResourceType: number?,
	MaxHp: number,

	FireRange: number?,
	Damage: number?,
	Description: string?,
	ProductionRate: number?,
	Capacity: number?,
}

export type BuildingData = { [string]: { Width: number, Length: number, Category: Category?,ResourceType:string?,
    CollectorType:string?,
    [number]: BuildingLevelData } }


local UpgradeResourceType = {
    Crystals = 1,
    Aethers = 2,
}

local Buildings: BuildingData = {
	["Nexus"] = {
		Width = 4,
		Length = 4,
		UpgradeResourceType = UpgradeResourceType.Crystals,
		[1] = {
			UpgradeCost = 150,
			UpgradeTime = 60,
			MaxHp = 400,

			Capacity = 2000,
		}
	},

	["ArcaneTurret"] = {
		Width = 3,
		Length = 3,
		UpgradeResourceType = UpgradeResourceType.Crystals,
		[1]= {
            UpgradeCost = 150,
            UpgradeTime = 10,
            MaxHp = 400,

            FireRange = 5,
            Damage = 50,
        }
	},

	["AetherSiphon"] = {
		Width = 3,
		Length = 3,
		UpgradeResourceType = UpgradeResourceType.Crystals,
		CollectorType = "AetherCollector",
		[1] = {
			UpgradeCost = 150,
			UpgradeTime = 10,
			MaxHp = 400,

			ProductionRate = 1,
			Capacity = 100,

		},
	},

	["CrystalMine"] = {
		Width = 3,
		Length = 3,
		UpgradeResourceType = UpgradeResourceType.Aethers,
		CollectorType = "CrystalCollector",
		[1] = {
			UpgradeCost = 150,
			UpgradeTime = 10,
			MaxHp = 400,

			ProductionRate = 1,
			Capacity = 100,
		},
	},

	["AetherWell"] = {
		Width = 3,
		Length = 3,
		UpgradeResourceType = UpgradeResourceType.Crystals,
		[1] = {
            UpgradeCost = 150,
            UpgradeTime = 10,
            MaxHp = 400,

            Capacity = 2000,
        }
	},

	["CrystalVault"] = {
		Width = 3,
		Length = 3,
		UpgradeResourceType = UpgradeResourceType.Aethers,
		[1] ={
		    UpgradeCost = 150,
            UpgradeTime = 10,
            MaxHp = 400,

            Capacity = 2000,
		}
	},

	["CrystalTree"] = {
		Width = 2,
		Length = 2,

		[1] = {
		    UpgradeCost = 0,
            UpgradeTime = 0,
            MaxHp = 100,

            Description = "A tree that can be cut down for resources.",
		}
	},
	["SummonAltar"] = {
		Width = 3,
		Length = 3,
		UpgradeResourceType = UpgradeResourceType.Aethers,

		[1] = {
            UpgradeCost = 150,
            UpgradeTime = 10,
            MaxHp = 400,

            Description = "A barrack that can be used to train troops.",
        }

	},
	["HeroCamp"] = {
		Width = 4,
		Length = 4,
		UpgradeResourceType = UpgradeResourceType.Aethers,
		[1] = {
            UpgradeCost = 150,
            UpgradeTime = 10,
            MaxHp = 400,

            Description = "A campfire that can be used to train troops.",
        }

	},
	["ArtificerHut"] = {
		Width = 2,
		Length = 2,
		[1] = {
            UpgradeCost = 150,
            UpgradeTime = 10,
            MaxHp = 400,

            Description = "A building hall that serves as the main hub for the base.",
        }
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

function BuildingConfig:GetCollectorType(buildingType: string): string?
    local building = Buildings[buildingType]
    if not building then
        return nil
    end
    return building.CollectorType or nil
end

function BuildingConfig:GetBuildingDataByEnum(buildingEnum:number,level:number):any
    local buildingType = GameEnum:GetBuildingTypeById(buildingEnum)
    if not buildingType then
        return nil
    end
    return BuildingConfig:GetBuildingData(buildingType,level)
end

function BuildingConfig:GetBuildingMaxDataByEnum(buildingEnum:number)
    local buildingType = GameEnum:GetBuildingTypeById(buildingEnum)
    if not buildingType then
        return nil
    end
    local building = Buildings[buildingType]
    if not building then
        return nil
    end
    local maxLevel = math.max(table.unpack(table.keys(building)))
    return BuildingConfig:GetBuildingData(buildingType, maxLevel)
end

return BuildingConfig
