--!strict
-- [[
-- ภาพโดยรวมของ เกมในช่วงเวลาหนึ่ง
-- ทหารแต่ละตัวอยู่ตำแหน่งไหน, เลือดเท่าไหร่, กำลังตีใคร
-- ตึกแต่ละหลังเลือดเหลือเท่าไหร่
-- ]]
--[[
    @ TODO:
    -- เปลี่ยน Vector type เป็น GridPosition เพื่อให้ deterministic
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)
local UnitConfig = require(ReplicatedStorage.Shared.UnitConfig)
local Pathfinding = require(ReplicatedStorage.Shared.Pathfinding)

export type GridPosition = {
	GridX: number,
	GridZ: number,
}

export type BuildingState = {
	BuildingId: string,
	Position: GridPosition,
	BuildingEnum: number,
	BuildingLevel: number,
	EndTime: number,
	LastCollectedTime: number,

	MaxHp: number,
	Hp: number,

	state: number?, -- "IDLE", "DIED"

	Dimensions: { Width: number, Length: number },
}

export type UnitState = {
	UnitId: string,
	MaxHp: number,
	Hp: number,
	Damage: number,
	WalkSpeed: number,
	Range: number, -- ระยะตี (ช่อง); ประชิด = 1, ยิงไกล = มากกว่า
	AttackCooldown: number, -- กี่ tick ต่อการตี 1 ครั้ง (fire rate)
	CooldownLeft: number, -- runtime: นับถอยหลังถึงยิงครั้งถัดไป
	Position: GridPosition,

	-- 1-10 เพื่อสะสมกำลังในการเดิน ถึง10 ให้เดิน 1 ช่อง (ถ้า WalkSpeed=1) → deterministic
	MoveProgress: number,
	--@TODO State Enum 1 = "IDLE", 2 = "MOVING", 3 = "ATTACKING", 4 = "DIED"
	state: number?,

	TargetId: string?,
}

export type SpellState = {
	SpellId: string,
	Duration: number,

	Position: GridPosition,
	Radius: number,
}

export type State = {
	Tick: number,
	Units: { UnitState },
	Buildings: { BuildingState },
	Spells: { SpellState },
}

export type SimEvent = {
	Type: number, --State Enum
	UnitId: string?,
	TargetId: string?,
	BuildingId: string?,
	Damage: number?,
}

local Simulation = {}

function Simulation.RegisterBuilding(
	buildingId: string,
	gridx: number,
	gridz: number,
	buildingEnum: number,
	buildingLevel: number,
	endTime: number,
	lastCollectedTime: number
): BuildingState?
	local buildingData = BuildingConfig:GetBuildingDataByEnum(buildingEnum, buildingLevel)
	if not buildingData then
		warn("Building data not found for buildingEnum: " .. buildingEnum .. ", level: " .. buildingLevel)
		return nil
	end
	local dimensions = BuildingConfig:GetBuildingDimensionByEnum(buildingEnum)
	if not dimensions then
		warn("Building dimensions not found for buildingEnum: " .. buildingEnum)
		return nil
	end

	return {
		BuildingId = buildingId,
		Position = {
			GridX = gridx,
			GridZ = gridz,
		},
		BuildingEnum = buildingEnum,
		BuildingLevel = buildingLevel,
		EndTime = endTime,
		LastCollectedTime = lastCollectedTime,

		MaxHp = buildingData.MaxHp,
		Hp = buildingData.MaxHp,
		state = 1, -- "IDLE"

		Dimensions = {
			Width = dimensions.Width,
			Length = dimensions.Length,
		},
	}
end
function Simulation.RegisterUnit(
	unitId: string,
	unitEnum: number,
	unitLevel: number,
	position: GridPosition
): UnitState?
	local unitData = UnitConfig:GetUnitLevelDataByEnum(unitEnum, unitLevel)
	if not unitData then
		warn("[Simulation] Unit data not found for unitId: " .. unitId)
		return nil
	end
	return {
		UnitId = unitId,
		MaxHp = unitData.MaxHp,
		Hp = unitData.MaxHp,
		Damage = unitData.Damage,
		WalkSpeed = unitData.WalkSpeed,
		MoveProgress = 0,
		state = 1, -- "IDLE"
		Range = unitData.Range,
		AttackCooldown = unitData.AttackCooldown,
		CooldownLeft = 0,
		Position = position,
	}
end

-- ระยะกำลังสองถึงจุดที่ใกล้สุดบน footprint ของตึก
-- (clamp พิกัดเข้ากรอบตึก → ได้ระยะถึงขอบด้านใกล้สุด, integer ล้วน ไม่ sqrt → deterministic)
local function distanceSqToBuilding(pos: GridPosition, building: BuildingState): number
	local nearestX =
		math.clamp(pos.GridX, building.Position.GridX, building.Position.GridX + building.Dimensions.Width - 1)
	local nearestZ =
		math.clamp(pos.GridZ, building.Position.GridZ, building.Position.GridZ + building.Dimensions.Length - 1)
	local dx = pos.GridX - nearestX
	local dz = pos.GridZ - nearestZ
	return dx * dx + dz * dz
end

local function findBuilding(buildings: { BuildingState }, id: string): BuildingState?
	for _, b in buildings do
		if b.BuildingId == id then
			return b
		end
	end
	return nil
end

local function nearestBuilding(unit: UnitState, buildings: { BuildingState }): string?
	local bestId: string? = nil
	local bestDist = math.huge
	for _, b in buildings do
		if b.Hp > 0 then
			local d = distanceSqToBuilding(unit.Position, b)
			if d < bestDist then
				bestDist = d
				bestId = b.BuildingId
			end
		end
	end
	return bestId
end

function Simulation.stepTick(state: State, flowFields: { [string]: Pathfinding.FlowField }): (State, { SimEvent })
	state.Tick += 1
	local stateEvents: { SimEvent } = {}

	for _, unit in state.Units do
		if unit.state == 4 then
			continue
		end
		if unit.Hp <= 0 then
			unit.state = 4 -- "DIED"
			unit.state = table.insert(stateEvents, {
				Type = 3, -- 3 = "UNIT_DIED"
				UnitId = unit.UnitId,
			})
			continue
		end

		local target = if unit.TargetId then findBuilding(state.Buildings, unit.TargetId) else nil
		if not target or target.Hp <= 0 then
			unit.TargetId = nearestBuilding(unit, state.Buildings)
			target = if unit.TargetId then findBuilding(state.Buildings, unit.TargetId) else nil
		end
		if not target then
			continue
		end

		if distanceSqToBuilding(unit.Position, target) <= unit.Range * unit.Range then
			-- เข้าระยะ → หยุดเดิน แล้วตีตามจังหวะ cooldown
			unit.CooldownLeft -= 1
			if unit.CooldownLeft <= 0 then
				table.insert(stateEvents, {
					Type = 1, --1 = "UNIT_ATTACK"
					UnitId = unit.UnitId,
					TargetId = target.BuildingId,
					Damage = unit.Damage,
				})
				target.Hp = math.max(0, target.Hp - unit.Damage)
				if target.Hp <= 0 then
					table.insert(stateEvents, {
						Type = 2, -- 2 = "BUILDING_DESTROY"
						BuildingId = target.BuildingId,
					})
				end
				unit.CooldownLeft = unit.AttackCooldown
			end
		else
			local flow = flowFields[target.BuildingId]

			unit.MoveProgress += unit.WalkSpeed
			if unit.MoveProgress >= 10 then
				unit.MoveProgress -= 10
				local nxt = if flow then Pathfinding.nextStep(flow, unit.Position) else nil
				if nxt then
					unit.Position = nxt
				end
			else
			end
		end
	end

	return state, stateEvents
end

-- loop เรียก stepTick ตั้งแต่เริ่ม จนจบ → finalState
function Simulation.runMathc() end

return Simulation
