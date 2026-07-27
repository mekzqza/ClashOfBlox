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

-- 1 = Idle, 2 = Moving, 3 = Attacking, 4 = Dead
export type AnimationId = {
	number: string,
}

export type UnitData = { [string]: { UnitLevelData }, AnimationId: AnimationId }

local Units = {
	["Goblin"] = {
		AnimationId = {
			[2] = "rbxassetid://125749145", -- Moving
		},
		[1] = {
			UpgradeCost = 50,
			UpgradeTime = 5,
			MaxHp = 100,

			Damage = 10,
			WalkSpeed = 5,
			Range = 1,
			AttackCooldown = 1,
		},
	},
	["Barbarian"] = {
		AnimationId = {
			[2] = "rbxassetid://125749145", -- Moving
		},
		[1] = {
			UpgradeCost = 100,
			UpgradeTime = 10,
			MaxHp = 200,

			Damage = 20,
			WalkSpeed = 2,
			Range = 1,
			AttackCooldown = 1.5,
		},
	},
	["Zombie"] = {
		AnimationId = {
			[2] = "rbxassetid://125749145", -- Moving
		},
		[1] = {
			UpgradeCost = 150,
			UpgradeTime = 15,
			MaxHp = 300,

			Damage = 30,
			WalkSpeed = 1,
			Range = 1,
			AttackCooldown = 2,
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

function UnitConfig:GetAnimationId(unitType: string, state: number): string?
	local unitData = Units[unitType]
	if unitData and unitData.AnimationId then
		return unitData.AnimationId[state]
	end
	return nil
end

function UnitConfig:GetUnitData(unitType: string): UnitData?
	return Units[unitType]
end

return UnitConfig
