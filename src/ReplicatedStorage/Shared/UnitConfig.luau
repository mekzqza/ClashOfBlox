--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)

local UnitConfig = {}

export type UnitLevelData = {
	UpgradeCost: number,
	UpgradeTime: number,
	MaxHp: number,

	Damage: number,
	WalkSpeed: number,
	Range: number,
	AttackCooldown: number,
}

export type UnitData = { [string]: { UnitLevelData } }

local Units = {
	["Goblin"] = {
		[1] = {
			UpgradeCost = 50,
			UpgradeTime = 5,
			MaxHp = 100,

			Damage = 10,
			WalkSpeed = 10,
			Range = 1,
			AttackCooldown = 1,
		},
	},
	["Barbarian"] = {
		[1] = {
			UpgradeCost = 100,
			UpgradeTime = 10,
			MaxHp = 200,

			Damage = 20,
			WalkSpeed = 5,
			Range = 1,
			AttackCooldown = 1.5,
		},
	},
}

function UnitConfig:GetUnitLevelData(unitType: string, level: number): UnitLevelData?
	local unitData = Units[unitType]
	if unitData then
		return unitData[level]
	end
	return nil
end

function UnitConfig:GetUnitLevelDataByEnum(unitId: number, level: number): UnitLevelData?
	local unitType = GameEnum:GetUnitTypeById(unitId)
	if unitType then
		return self:GetUnitLevelData(unitType, level)
	end
	return nil
end

function UnitConfig:GetUnitData(unitType: string): UnitData?
	return Units[unitType]
end

return UnitConfig
