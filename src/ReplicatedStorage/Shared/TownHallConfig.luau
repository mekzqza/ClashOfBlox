--!strict

export type BuildingLimit = {
	Max: number,
	MaxLevel: number,
}

export type TownHallConfigType = { [number]: { [string]: BuildingLimit } }

local TownHallConfig = {}

local TownHallLevels: TownHallConfigType = {
	[1] = {
		["Buildinghut"] = { Max = 1, MaxLevel = 2 },
		["Cannon"] = { Max = 1, MaxLevel = 2 },

		["CrystalVault"] = { Max = 1, MaxLevel = 2 },
		["CrystalMine"] = { Max = 1, MaxLevel = 2 },
		["AetherWell"] = { Max = 1, MaxLevel = 2 },
		["AetherSiphon"] = { Max = 1, MaxLevel = 2 },

		["Campfire"] = { Max = 1, MaxLevel = 1 },
		["Barrack"] = { Max = 1, MaxLevel = 1 },
	},
	[2] = {
		["Buildinghut"] = { Max = 1, MaxLevel = 3 },
		["Cannon"] = { Max = 2, MaxLevel = 3 },
		["ArcherTower"] = { Max = 1, MaxLevel = 2 },

		["CrystalVault"] = { Max = 2, MaxLevel = 3 },
		["CrystalMine"] = { Max = 2, MaxLevel = 3 },
		["AetherWell"] = { Max = 2, MaxLevel = 3 },
		["AetherSiphon"] = { Max = 2, MaxLevel = 3 },

		["Campfire"] = { Max = 1, MaxLevel = 1 },
		["Barrack"] = { Max = 1, MaxLevel = 1 },
	},
	[3] = {
		["Buildinghut"] = { Max = 1, MaxLevel = 4 },
		["Cannon"] = { Max = 3, MaxLevel = 4 },
		["Wall"] = { Max = 10, MaxLevel = 3 },

		["CrystalVault"] = { Max = 3, MaxLevel = 4 },
		["CrystalMine"] = { Max = 3, MaxLevel = 4 },
		["AetherWell"] = { Max = 3, MaxLevel = 4 },
		["AetherSiphon"] = { Max = 3, MaxLevel = 4 },

		["Campfire"] = { Max = 1, MaxLevel = 1 },
		["Barrack"] = { Max = 1, MaxLevel = 1 },
	},
}

function TownHallConfig.GetConfig(level: number)
	return TownHallLevels[level]
end

function TownHallConfig:GetConfigBuilding(buildingType: string, level: number): BuildingLimit
	if not TownHallLevels[level][buildingType] then
		warn(`[TownHallConfig] ❌ No config for buildingType: {buildingType} at TownHall level: {level}`)
		return { Max = 0, MaxLevel = 0 }
	end
	return TownHallLevels[level][buildingType] or { Max = 0, MaxLevel = 0 }
end

return TownHallConfig
