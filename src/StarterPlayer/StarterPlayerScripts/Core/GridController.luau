--!strict
local Workspace = game:GetService("Workspace")
local GridPart: BasePart = nil
local validCells: { [string]: true } = {}
local occupiedCells: { [string]: true } = {}

local CONFIG = {
	CELL_SIZE = 4,
	BASE_DEBUG = "Base1",
	GRID_PART = "LogicPart",
}

local GridController = {}

local function worldToGrid(position: Vector3): string
	local gridx = math.floor(position.x / CONFIG.CELL_SIZE)
	local gridz = math.floor(position.z / CONFIG.CELL_SIZE)
	return `{gridx},{gridz}`
end

local function RegisterZone(part: BasePart)
	local origin = part.Position - (part.Size / 2)
	local xCells = math.ceil(part.Size.X / CONFIG.CELL_SIZE)
	local zCells = math.ceil(part.Size.Z / CONFIG.CELL_SIZE)

	for x = 0, xCells - 1 do
		for z = 0, zCells - 1 do
			local cellPos =
				Vector3.new(origin.X + x * CONFIG.CELL_SIZE, part.Position.Y, origin.Z + z * CONFIG.CELL_SIZE)
			local cellKey = worldToGrid(cellPos)
			validCells[cellKey] = true
		end
	end
end

function GridController:Canplace(position: Vector3): boolean
	local cellKey = worldToGrid(position)
	if not validCells[cellKey] then
		return false
	end
	if occupiedCells[cellKey] then
		return false
	end
	return true
end

function GridController:occupyCell(position: Vector3)
	local cellKey = worldToGrid(position)
	if not validCells[cellKey] then
		return
	end

	occupiedCells[cellKey] = true
end

function GridController:freeCell(position: Vector3)
	local cellKey = worldToGrid(position)
	if not validCells[cellKey] then
		return
	end

	occupiedCells[cellKey] = nil
end

function GridController:SnapToGrid(position: Vector3): Vector3
	local gridx = math.floor(position.x / CONFIG.CELL_SIZE) * CONFIG.CELL_SIZE + 2
	local gridz = math.floor(position.z / CONFIG.CELL_SIZE) * CONFIG.CELL_SIZE + 2
	return Vector3.new(gridx, position.y, gridz)
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
