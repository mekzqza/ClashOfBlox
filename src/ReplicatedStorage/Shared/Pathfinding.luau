--!strict

export type GridPosition = {
	GridX: number,
	GridZ: number,
}

export type FlowField = {
	[number]: number,
}

--ขอบสนาม
export type Bounds = {
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
}

--ช่องที่เดินไม่ได้
export type Occupied = {
	[number]: boolean,
}

local Pathfinding = {}

-- ใช้สร้าง field (BFS 4 ทิศ → เลขคือจำนวนก้าวแนวตรง, ห้ามใส่ทแยงไม่งั้นน้ำทะลุมุมกำแพง)
local NEIGHBORS = {
	{ GridX = 0, GridZ = -1 }, -- Up
	{ GridX = 0, GridZ = 1 }, -- Down
	{ GridX = -1, GridZ = 0 }, -- Left
	{ GridX = 1, GridZ = 0 }, -- Right
}

-- ใช้ตอนเดิน (8 ทิศ) ลำดับคือ tie-breaker ห้ามสลับ → deterministic
local MOVE_NEIGHBORS = {
	{ GridX = 0, GridZ = -1 }, -- Up
	{ GridX = 0, GridZ = 1 }, -- Down
	{ GridX = -1, GridZ = 0 }, -- Left
	{ GridX = 1, GridZ = 0 }, -- Right
	{ GridX = -1, GridZ = -1 }, -- UpLeft
	{ GridX = 1, GridZ = -1 }, -- UpRight
	{ GridX = -1, GridZ = 1 }, -- DownLeft
	{ GridX = 1, GridZ = 1 }, -- DownRight
}

local STRIDE = 100 -- ponytail: bounds เป็น 0-based (พิกัด 0..99/แกน) เลยไม่ต้อง offset; ถ้าวันไหน Min ติดลบ ใช้ (x-MinX)

function Pathfinding.key(gridX: number, gridZ: number): number
	return gridX * STRIDE + gridZ
end

function Pathfinding.decode(hash: number): (number, number)
	return math.floor(hash / STRIDE), hash % STRIDE
end

local function key(position: GridPosition): number
	return Pathfinding.key(position.GridX, position.GridZ)
end

--สร้างสนามจากเป้าหมาย คือนค่าสนามที่มี Gridx, Girdz ที่มีค่าของตัวเลขติดกำกับ
function Pathfinding.buildFlowField(goals: { GridPosition }, bounds: Bounds, occupied: Occupied): FlowField
	local flow: FlowField = {}

	local queue: { GridPosition } = {}
	for _, goal in goals do
		flow[key(goal)] = 0 -- 0 = target
		table.insert(queue, goal)
	end

	local head = 1

	while head <= #queue do
		local cur = queue[head]
		head += 1
		for _, dir in NEIGHBORS do
			local Gx = cur.GridX + dir.GridX
			local Gz = cur.GridZ + dir.GridZ
			local N = { GridX = Gx, GridZ = Gz }
			local Nkey = key(N)
			if
				flow[Nkey] == nil
				and not occupied[Nkey]
				and bounds.MinX <= Gx
				and bounds.MaxX >= Gx
				and bounds.MaxZ >= Gz
				and bounds.MinZ <= Gz
			then
				flow[Nkey] = flow[key(cur)] + 1
				table.insert(queue, N)
			end
		end
	end

	return flow
end

-- ดึงตำแหน่งปัจจุบันของตัวเอง และสนามระยะทางของเป้าหมาย คืนค่าตำแหน่งที่ตัวเองต้องเดินถัดไป
-- (ไหลลงเขา: ก้าวไปเพื่อนบ้าน 8 ทิศที่เลขต่ำกว่าตัวเองและต่ำที่สุด)
function Pathfinding.nextStep(flow: FlowField, currentPosition: GridPosition): GridPosition?
	local currentDist = flow[key(currentPosition)]
	-- เดินไม่ได้ อยู่นอกสนาม/โดนล้อม
	if currentDist == nil then
		return nil
	end

	-- ยืนบนเป้าหมายแล้ว ไม่ต้องเดินต่อ
	if currentDist == 0 then
		return nil
	end

	local bestDist = currentDist
	local bestPosition: GridPosition? = nil

	for _, step in MOVE_NEIGHBORS do
		local Gx = currentPosition.GridX + step.GridX
		local Gz = currentPosition.GridZ + step.GridZ
		local nextValue = flow[Pathfinding.key(Gx, Gz)]
		if nextValue == nil then
			continue
		end

		-- กัน corner-cutting: ก้าวทแยงได้ต่อเมื่อช่องแนวตรงข้างตัวทั้งคู่เดินได้
		if step.GridX ~= 0 and step.GridZ ~= 0 then
			local sideA = flow[Pathfinding.key(Gx, currentPosition.GridZ)]
			local sideB = flow[Pathfinding.key(currentPosition.GridX, Gz)]
			if sideA == nil or sideB == nil then
				continue
			end
		end

		-- strict < : เจอเลขเท่ากันตัวแรกในลำดับชนะ → deterministic
		if nextValue < bestDist then
			bestDist = nextValue
			bestPosition = { GridX = Gx, GridZ = Gz }
		end
	end

	return bestPosition
end

return Pathfinding
