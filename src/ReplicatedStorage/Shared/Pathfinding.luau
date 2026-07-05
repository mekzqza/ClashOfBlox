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

local NEIGHBORS = {
	{ GridX = 0, GridZ = -1 }, -- Up
	{ GridX = 0, GridZ = 1 }, -- Down
	{ GridX = -1, GridZ = 0 }, -- Left
	{ GridX = 1, GridZ = 0 }, -- Right
}

local OPPOSITE_DIRECTION = {
	[1] = 2,
	[2] = 1,
	[3] = 4,
	[4] = 3,
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
function Pathfinding.buildFlowField(goal: GridPosition, bounds: Bounds, occupied: Occupied): FlowField
	local flow: FlowField = {}
	flow[key(goal)] = 0

	local head = 1
	local queue: { GridPosition } = { goal }

	while head <= #queue do
		local cur = queue[head]
		head += 1
		for i, dir in NEIGHBORS do
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
				flow[Nkey] = OPPOSITE_DIRECTION[i]
				table.insert(queue, N)
			end
		end
	end

	return flow
end

-- ดึงต่ำแหน่งปัจจุบันของตัวเอง และสนามตัวเลขของเป้าหมาย คืนค่าตำแหน่งที่ตัวเองต้องเดินถัดไป
function Pathfinding.nextStep(flow: FlowField, currentPosition: GridPosition): GridPosition?
	local dir = flow[key(currentPosition)]
	-- เดินไม่ได้ อยู่ในจุดที่ไม่มีไดเรคชั่นให้เดินต่อ
	if dir == nil then
		return nil
	end

	-- ยืนบนเป้าหมายแล้ว ไม่ต้องเดินต่อ
	if dir == 0 then
		return nil
	end

	-- ดินต่อไป
	local cuurenStep = NEIGHBORS[dir]
	local nextPosition = {
		GridX = currentPosition.GridX + cuurenStep.GridX,
		GridZ = currentPosition.GridZ + cuurenStep.GridZ,
	}

	return nextPosition
end

return Pathfinding
