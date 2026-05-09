--!strict
local Workspace = game:GetService("Workspace")
local GridPart: BasePart = nil
local validCells: { [string]: true } = {}
local occupiedCells: { [string]: true } = {}
local gridOriginX: number = 0
local gridOriginZ: number = 0

local CONFIG = {
	CELL_SIZE = 4,
	BASE_DEBUG = "Base1",
	GRID_PART = "LogicPart",
}

local GridController = {}

local function gridKeyfromCoords(gridx: number, gridz: number): string
	return `{gridx},{gridz}`
end

local function RegisterZone(part: BasePart)
	gridOriginX = part.Position.X - part.Size.X / 2
	gridOriginZ = part.Position.Z - part.Size.Z / 2
	local xCells = math.ceil(part.Size.X / CONFIG.CELL_SIZE)
	local zCells = math.ceil(part.Size.Z / CONFIG.CELL_SIZE)

	for x = 0, xCells - 1 do
		for z = 0, zCells - 1 do
			validCells[gridKeyfromCoords(x, z)] = true
		end
	end
end

-- sizeX, sizeZ are in cell counts; returns the top-left cell (local grid coords) of the footprint
local function getFootPrintStart(position: Vector3, sizeX: number?, sizeZ: number?)
	local halfX = (sizeX or 1) * CONFIG.CELL_SIZE / 2
	local halfZ = (sizeZ or 1) * CONFIG.CELL_SIZE / 2
	local startX = math.floor((position.X - gridOriginX - halfX) / CONFIG.CELL_SIZE)
	local startZ = math.floor((position.Z - gridOriginZ - halfZ) / CONFIG.CELL_SIZE)
	return startX, startZ
end

function GridController:Canplace(position: Vector3, sizeX: number?, sizeZ: number?): boolean
	local sx = sizeX or 1
	local sz = sizeZ or 1
	local startX, startZ = getFootPrintStart(position, sx, sz)

	for x = 0, sx - 1 do
		for z = 0, sz - 1 do
			local key = gridKeyfromCoords(startX + x, startZ + z)
			if not validCells[key] then
				return false
			end
			if occupiedCells[key] then
				return false
			end
		end
	end

	return true
end

function GridController:occupyCell(position: Vector3, sizeX: number?, sizeZ: number?)
	local sx = sizeX or 1
	local sz = sizeZ or 1
	local startX, startZ = getFootPrintStart(position, sx, sz)

	for x = 0, sx - 1 do
		for z = 0, sz - 1 do
			local key = gridKeyfromCoords(startX + x, startZ + z)
			if validCells[key] then
				occupiedCells[key] = true
			end
		end
	end
end

function GridController:freeCell(position: Vector3, sizeX: number?, sizeZ: number?)
	local sx = sizeX or 1
	local sz = sizeZ or 1
	local startX, startZ = getFootPrintStart(position, sx, sz)

	for x = 0, sx - 1 do
		for z = 0, sz - 1 do
			local key = gridKeyfromCoords(startX + x, startZ + z)
			if validCells[key] then
				occupiedCells[key] = nil
			end
		end
	end
end

function GridController:SnapToGrid(position: Vector3, sizeX: number?, sizeZ: number?): Vector3
	local sx = sizeX or 1
	local sz = sizeZ or 1

	local gridx = math.floor((position.X - gridOriginX) / CONFIG.CELL_SIZE)
	local gridz = math.floor((position.Z - gridOriginZ) / CONFIG.CELL_SIZE)

	local snapX = gridOriginX + gridx * CONFIG.CELL_SIZE + sx * CONFIG.CELL_SIZE / 2
	local snapZ = gridOriginZ + gridz * CONFIG.CELL_SIZE + sz * CONFIG.CELL_SIZE / 2

	return Vector3.new(snapX, position.Y, snapZ)
end

function GridController:Init()
	--[[ In production
	    wait for Server Send Folder that no owner for player to render Grid
	--]]

	local Structure = Workspace:WaitForChild("Map"):WaitForChild("Structure")
	if not Structure then
		warn("[GridController] Structure folder not found in Workspace.Map")
		return
	end

	GridPart = Structure:WaitForChild("Base1"):WaitForChild("GridPart"):WaitForChild("LogicPart")
	if not GridPart or not GridPart:IsA("BasePart") then
		warn(`[GridController] Grid part not found in Structure.{CONFIG.GRID_PART}`)
		return
	end
	RegisterZone(GridPart)
end

function GridController:Start() end

return GridController
