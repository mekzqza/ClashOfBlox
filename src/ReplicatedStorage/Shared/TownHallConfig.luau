--!strict

export type BuildingLimit = {
	Max: number,
	MaxLevel: number,
}

export type TownHallConfigType = { [number]: { [string]: BuildingLimit } }

local TownHallConfig = {}

local TownHallLevels: TownHallConfigType = {
	[1] = {
		["Builinghut"] = { Max = 1, MaxLevel = 2 },
		["Cannon"] = { Max = 1, MaxLevel = 2 },

		["GoldStorage"] = { Max = 1, MaxLevel = 2 },
		["GoldMine"] = { Max = 1, MaxLevel = 2 },
		["ElixirStorage"] = { Max = 1, MaxLevel = 2 },
		["ElixirCollector"] = { Max = 1, MaxLevel = 2 },

		["Campfire"] = { Max = 1, MaxLevel = 1 },
		["Barrack"] = { Max = 1, MaxLevel = 1 },
	},
	[2] = {
		["Builinghut"] = { Max = 1, MaxLevel = 3 },
		["Cannon"] = { Max = 2, MaxLevel = 3 },
		["ArcherTower"] = { Max = 1, MaxLevel = 2 },

		["GoldStorage"] = { Max = 2, MaxLevel = 3 },
		["GoldMine"] = { Max = 2, MaxLevel = 3 },
		["ElixirStorage"] = { Max = 2, MaxLevel = 3 },
		["ElixirCollector"] = { Max = 2, MaxLevel = 3 },

		["Campfire"] = { Max = 1, MaxLevel = 1 },
		["Barrack"] = { Max = 1, MaxLevel = 1 },
	},
	[3] = {
		["Builinghut"] = { Max = 1, MaxLevel = 4 },
		["Cannon"] = { Max = 3, MaxLevel = 4 },
		["Wall"] = { Max = 10, MaxLevel = 3 },

		["GoldStorage"] = { Max = 3, MaxLevel = 4 },
		["GoldMine"] = { Max = 3, MaxLevel = 4 },
		["ElixirStorage"] = { Max = 3, MaxLevel = 4 },
		["ElixirCollector"] = { Max = 3, MaxLevel = 4 },

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
