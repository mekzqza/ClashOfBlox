--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)

local CONFIG = {
	CELL_SIZE = 4,
	BASE_DEBUG = "Base1",
	GRID_PART = "LogicPart",
}

local GridController = {}
GridController.__index = GridController
function GridController.new()
	local self = setmetatable({}, GridController)
	self._Structure = nil :: Folder?
	self._PlayerFolder = nil :: Folder?
	self._GridPart = nil
	self._validCells = {} :: { [string]: true }
	self._occupiedCells = {} :: { [string]: true }
	self._gridOriginX = 0
	self._gridOriginZ = 0
	return self
end

function GridController:_gridKeyfromCoords(gridx: number, gridz: number): string
	return `{gridx},{gridz}`
end

function GridController:RegisterZone(part: BasePart)
	self._gridOriginX = part.Position.X - part.Size.X / 2
	self._gridOriginZ = part.Position.Z - part.Size.Z / 2
	local xCells = math.ceil(part.Size.X / CONFIG.CELL_SIZE)
	local zCells = math.ceil(part.Size.Z / CONFIG.CELL_SIZE)

	for x = 0, xCells - 1 do
		for z = 0, zCells - 1 do
			self._validCells[self:_gridKeyfromCoords(x, z)] = true
		end
	end
end

function GridController:_getFootPrintStart(position: Vector3, sizeX: number?, sizeZ: number?)
	local halfX = (sizeX or 1) * CONFIG.CELL_SIZE / 2
	local halfZ = (sizeZ or 1) * CONFIG.CELL_SIZE / 2
	local startX = math.floor((position.X - self._gridOriginX - halfX) / CONFIG.CELL_SIZE)
	local startZ = math.floor((position.Z - self._gridOriginZ - halfZ) / CONFIG.CELL_SIZE)
	return startX, startZ
end

function GridController:Canplace(position: Vector3, sizeX: number?, sizeZ: number?): boolean
	local sx = sizeX or 1
	local sz = sizeZ or 1
	local startX, startZ = self:_getFootPrintStart(position, sx, sz)

	for x = 0, sx - 1 do
		for z = 0, sz - 1 do
			local key = self:_gridKeyfromCoords(startX + x, startZ + z)
			if not self._validCells[key] then
				return false
			end
			if self._occupiedCells[key] then
				return false
			end
		end
	end

	return true
end

function GridController:occupyCell(position: Vector3, sizeX: number?, sizeZ: number?)
	local sx = sizeX or 1
	local sz = sizeZ or 1
	local startX, startZ = self:_getFootPrintStart(position, sx, sz)

	for x = 0, sx - 1 do
		for z = 0, sz - 1 do
			local key = self:_gridKeyfromCoords(startX + x, startZ + z)
			if self._validCells[key] then
				self._occupiedCells[key] = true
			end
		end
	end
end

function GridController:freeCell(position: Vector3, sizeX: number?, sizeZ: number?)
	local sx = sizeX or 1
	local sz = sizeZ or 1
	local startX, startZ = self:_getFootPrintStart(position, sx, sz)

	for x = 0, sx - 1 do
		for z = 0, sz - 1 do
			local key = self:_gridKeyfromCoords(startX + x, startZ + z)
			if self._validCells[key] then
				self._occupiedCells[key] = nil
			end
		end
	end
end

function GridController:SnapToGrid(position: Vector3, sizeX: number?, sizeZ: number?): Vector3
	local sx = sizeX or 1
	local sz = sizeZ or 1

	local gridx = math.floor((position.X - self._gridOriginX) / CONFIG.CELL_SIZE)
	local gridz = math.floor((position.Z - self._gridOriginZ) / CONFIG.CELL_SIZE)

	local snapX = self._gridOriginX + gridx * CONFIG.CELL_SIZE + sx * CONFIG.CELL_SIZE / 2
	local snapZ = self._gridOriginZ + gridz * CONFIG.CELL_SIZE + sz * CONFIG.CELL_SIZE / 2

	return Vector3.new(snapX, position.Y, snapZ)
end

function GridController:Init()
	--[[ In production
	    wait for Server Send Folder that no owner for player to render Grid
	--]]

	self._Structure = Workspace:WaitForChild("Map"):WaitForChild("Structure")
	if not self._Structure then
		warn("[GridController] Structure folder not found in Workspace.Map")
		return
	end
end

function GridController:Start()
	EventBus:On(Events.LOCAL_ASSING_ZONE_OWNER, function(data)
		self._PlayerFolder = self._Structure:WaitForChild(data.FolderName)
		if not self._PlayerFolder or not self._PlayerFolder:IsA("Folder") then
			warn(`[GridController] Player folder not found for folder: {data.FolderName}`)
			return
		end
		self._GridPart = self._PlayerFolder:WaitForChild("GridPart"):WaitForChild(CONFIG.GRID_PART)
		if not self._GridPart or not self._GridPart:IsA("BasePart") then
			warn(`[GridController] Grid part not found for folder: {data.FolderName}`)
			return
		end
		self:RegisterZone(self._GridPart)
	end)
end

return GridController.new()
