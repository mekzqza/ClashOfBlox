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

local CONFIG = {
	TICK_RATE = 1 / 30,

	-- Distance between each grid cell in studs
	GRID_DISTANCE_INSTUD = 1000,
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

		Dimensions = {
			Width = dimensions.Width,
			Length = dimensions.Length,
		},
	}
end
function Simulation.RegisterUnit(
	unitId: string,
	position: GridPosition,
	maxHp: number,
	damage: number,
	walkSpeed: number,
	range: number,
	attackCooldown: number
): UnitState
	return {
		UnitId = unitId,
		MaxHp = maxHp,
		Hp = maxHp,
		Damage = damage,
		WalkSpeed = walkSpeed,
		Range = range,
		AttackCooldown = attackCooldown,
		CooldownLeft = 0, -- 0 = ตีได้ทันทีที่เข้าระยะครั้งแรก
		Position = position,
	}
end

-- ระยะกำลังสอง (ไม่ sqrt → deterministic, ได้ range เป็นวงกลม)
local function distanceSq(a: GridPosition, b: GridPosition): number
	local dx = a.GridX - b.GridX
	local dz = a.GridZ - b.GridZ
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

-- เลือกตึก(ที่ยังไม่พัง)ที่ใกล้ที่สุด
local function nearestBuilding(unit: UnitState, buildings: { BuildingState }): string?
	local bestId: string? = nil
	local bestDist = math.huge
	for _, b in buildings do
		if b.Hp > 0 then
			local d = distanceSq(unit.Position, b.Position)
			if d < bestDist then
				bestDist = d
				bestId = b.BuildingId
			end
		end
	end
	return bestId
end

-- เดินทีละ tick → mutate state ในที่
-- ponytail: in-place mutation; ถ้าต้องการ replay/rollback ค่อย snapshot ก่อนเรียก
-- flowFields[buildingId] = สนามที่พาทหารวิ่งเข้าตึกนั้น
function Simulation.stepTick(state: State, flowFields: { [string]: Pathfinding.FlowField }): State
	state.Tick += 1

	for _, unit in state.Units do
		if unit.Hp <= 0 then
			continue
		end

		-- หาเป้าใหม่ถ้ายังไม่มี หรือเป้าเดิมพังไปแล้ว
		local target = if unit.TargetId then findBuilding(state.Buildings, unit.TargetId) else nil
		if not target or target.Hp <= 0 then
			unit.TargetId = nearestBuilding(unit, state.Buildings)
			target = if unit.TargetId then findBuilding(state.Buildings, unit.TargetId) else nil
		end
		if not target then
			continue -- ไม่มีตึกเหลือ = ทหารตัวนี้ไม่มีอะไรทำ
		end

		if distanceSq(unit.Position, target.Position) <= unit.Range * unit.Range then
			-- เข้าระยะ → หยุดเดิน แล้วตีตามจังหวะ cooldown
			unit.CooldownLeft -= 1
			if unit.CooldownLeft <= 0 then
				target.Hp = math.max(0, target.Hp - unit.Damage)
				unit.CooldownLeft = unit.AttackCooldown
			end
		else
			-- ยังไกล → เดิน 1 ก้าวตาม flow field ของเป้า
			-- ponytail: 1 ช่อง/tick; ผูก WalkSpeed กับความถี่ก้าวทีหลังถ้าอยากให้ความเร็วต่างกัน
			local flow = flowFields[target.BuildingId]
			local nxt = if flow then Pathfinding.nextStep(flow, unit.Position) else nil
			if nxt then
				unit.Position = nxt
			end
		end
	end

	return state
end

-- loop เรียก stepTick ตั้งแต่เริ่ม จนจบ → finalState
function Simulation.runMathc() end

return Simulation
