--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local Promise = require(ReplicatedStorage.Packages.Promise)

local CONFIG = {
	CELL_SIZE = 4,
	BASE_DEBUG = "Base1",
	GRID_PART = "LogicPart",
	READY_TIMEOUT = 10,
}

local GridController = {}
GridController.__index = GridController
function GridController.new()
	local self = setmetatable({}, GridController)
	self._isReady = false
	self._onReadyCallback = nil :: ((BasePart) -> ())?
	self._Structure = nil :: Folder?
	self._GridPart = nil
	self._PlayerFolder = nil :: Folder?
	self._validCells = {} :: { [string]: true }
	self._occupiedCells = {} :: { [string]: true }
	self._gridOriginX = 0 :: number
	self._gridOriginZ = 0 :: number
	self._gridSurfaceY = 0 :: number

	self._BuildingController = nil
	return self
end

function GridController:SetDependencies(locator)
	self._BuildingController = locator:Get("BuildingController")
end

function GridController:_gridKeyfromCoords(gridx: number, gridz: number): string
	return `{gridx},{gridz}`
end

function GridController:GridCoordsToWorld(startX: number, startZ: number, sizeX: number, sizeZ: number): Vector3
	local x = self._gridOriginX + startX * CONFIG.CELL_SIZE + sizeX * CONFIG.CELL_SIZE / 2
	local z = self._gridOriginZ + startZ * CONFIG.CELL_SIZE + sizeZ * CONFIG.CELL_SIZE / 2
	return Vector3.new(x, self._gridSurfaceY, z)
end

function GridController:RegisterZone(part: BasePart)
	self._gridOriginX = part.Position.X - part.Size.X / 2
	self._gridOriginZ = part.Position.Z - part.Size.Z / 2
	self._gridSurfaceY = part.Position.Y + part.Size.Y / 2
	local xCells = math.ceil(part.Size.X / CONFIG.CELL_SIZE)
	local zCells = math.ceil(part.Size.Z / CONFIG.CELL_SIZE)

	for x = 0, xCells - 1 do
		for z = 0, zCells - 1 do
			self._validCells[self:_gridKeyfromCoords(x, z)] = true
		end
	end

	self._isReady = true
	if self._onReadyCallback then
		self._onReadyCallback(part)
		self._onReadyCallback = nil
	end
end

function GridController:GetFootPrintStart(position: Vector3, sizeX: number?, sizeZ: number?): (number, number)
	local halfX = (sizeX or 1) * CONFIG.CELL_SIZE / 2
	local halfZ = (sizeZ or 1) * CONFIG.CELL_SIZE / 2
	local startX = math.floor((position.X - self._gridOriginX - halfX) / CONFIG.CELL_SIZE)
	local startZ = math.floor((position.Z - self._gridOriginZ - halfZ) / CONFIG.CELL_SIZE)
	return startX, startZ
end

function GridController:GetFootPrintCells(position: Vector3, sizeX: number?, sizeZ: number?): { [string]: true }
	local sx = sizeX or 1
	local sz = sizeZ or 1
	local startX, startZ = self:GetFootPrintStart(position, sx, sz)

	local cells: { [string]: true } = {}
	for x = 0, sx - 1 do
		for z = 0, sz - 1 do
			cells[self:_gridKeyfromCoords(startX + x, startZ + z)] = true
		end
	end
	return cells
end

function GridController:CanPlace(
	position: Vector3,
	sizeX: number?,
	sizeZ: number?,
	ignoreCells: { [string]: true }?
): boolean
	local sx = sizeX or 1
	local sz = sizeZ or 1
	local startX, startZ = self:GetFootPrintStart(position, sx, sz)

	for x = 0, sx - 1 do
		for z = 0, sz - 1 do
			local key = self:_gridKeyfromCoords(startX + x, startZ + z)
			if not self._validCells[key] then
				return false
			end
			if self._occupiedCells[key] and not (ignoreCells and ignoreCells[key]) then
				return false
			end
		end
	end

	return true
end

function GridController:occupyCell(position: Vector3, sizeX: number?, sizeZ: number?)
	local sx = sizeX or 1
	local sz = sizeZ or 1
	local startX, startZ = self:GetFootPrintStart(position, sx, sz)

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
	local startX, startZ = self:GetFootPrintStart(position, sx, sz)

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

--Api
function GridController:GetPlayerFolder()
	return self._PlayerFolder
end

function GridController:Init()
	--[[ In production
	    wait for Server Send Folder that no owner for player to render Grid
	--]]

	self._Structure = Workspace:WaitForChild("Map", 30):WaitForChild("Structure", 30)
	if not self._Structure then
		warn("[GridController] Structure folder not found in Workspace.Map")
		return
	end
end

function GridController:WaitForGridPartReady(timeout: number?): any
	timeout = timeout or CONFIG.READY_TIMEOUT

	return Promise.new(function(resolve, reject)
		if self._isReady and self._GridPart then
			resolve(self._GridPart)
			return
		end

		self._onReadyCallback = resolve
	end)
		:timeout(timeout)
		:catch(function(err)
			if Promise.Error.isKind(err, Promise.Error.Kind.TimedOut) then
				warn(`[PlayerDataController] ⏱️ TIMEOUT: Data not received in {timeout}s`)
				return nil
			end
			error(err)
		end)
end

function GridController:Start()
	EventBus:On(Events.LOCAL_ASSING_ZONE_OWNER, function(data)
		self._PlayerFolder = self._Structure:WaitForChild(data.FolderName, 30)
		if not self._PlayerFolder or not self._PlayerFolder:IsA("Folder") then
			warn(`[GridController] Player folder not found for folder: {data.FolderName}`)
			return
		end
		self._GridPart = self._PlayerFolder:WaitForChild("GridPart", 30):WaitForChild(CONFIG.GRID_PART, 30)
		if not self._GridPart or not self._GridPart:IsA("BasePart") then
			warn(`[GridController] Grid part not found for folder: {data.FolderName}`)
			return
		end
		self._BuildingController:SetPlayerFolder(self._PlayerFolder)
		self:RegisterZone(self._GridPart)
	end)
end

return GridController.new()
