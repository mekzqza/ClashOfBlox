--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)

local idempotentGuard = IdempotentGuard.new("GridService")

local CONFIG = {
	CELL_SIZE = 4,
	GRID_PART = "LogicPart",
}

local GridService = {}
GridService.__index = GridService
function GridService.new()
	local self = setmetatable({}, GridService)
	self._Structure = nil :: Folder?
	self._PlayerStore = {} :: { [Player]: string }
	self._GridStore = {} :: { [string]: { gridPart: BasePart, owner: Player? } }
	self._validCells = {} :: { [string]: { [string]: true } }
	self._occupiedCells = {} :: { [string]: { [string]: true } }
	return self
end

function GridService:_AssignOwner(folderName: string, player: Player)
	if not self._GridStore[folderName] then
		warn(`[GridService] ❌ Invalid folderName: {folderName}`)
		return
	end
	self._GridStore[folderName].owner = player
	self._PlayerStore[player] = folderName
	EventBus:Emit(Events.S2C_ASSING_ZONE_OWNER, { Player = player, FolderName = folderName })
end

function GridService:_worldToGrid(position: Vector3): string
	local gridx = math.floor(position.X / CONFIG.CELL_SIZE)
	local gridz = math.floor(position.Z / CONFIG.CELL_SIZE)
	return `{gridx},{gridz}`
end

function GridService:_RegisterZone(folderName: string, part: BasePart)
	self._validCells[folderName] = {}
	self._occupiedCells[folderName] = {}

	local origin = part.Position - (part.Size / 2)
	local xCells = math.ceil(part.Size.X / CONFIG.CELL_SIZE)
	local zCells = math.ceil(part.Size.Z / CONFIG.CELL_SIZE)

	for x = 0, xCells - 1 do
		for z = 0, zCells - 1 do
			local cellPos =
				Vector3.new(origin.X + x * CONFIG.CELL_SIZE, part.Position.Y, origin.Z + z * CONFIG.CELL_SIZE)
			local cellKey = self:_worldToGrid(cellPos)
			self._validCells[folderName][cellKey] = true
		end
	end
end

function GridService:CanPlace(folderName: string, position: Vector3): boolean
	local cellKey = self:_worldToGrid(position)
	if not self._validCells[folderName][cellKey] then
		return false
	end
	if self._occupiedCells[folderName][cellKey] then
		return false
	end
	return true
end

function GridService:_updateOccupy(position: Vector3, occupied: boolean)
	local data = {
		position = position,
		occupied = occupied,
	}
	EventBus:Emit(Events.S2C_GRIDCELL_UPDATE, data)
end

function GridService:OccupyCell(folderName: string, position: Vector3)
	local cellKey = self:_worldToGrid(position)
	if not self._validCells[folderName][cellKey] then
		return
	end

	self._occupiedCells[folderName][cellKey] = true
	self:_updateOccupy(position, true)
end

function GridService:FreeCell(folderName: string, position: Vector3)
	local cellKey = self:_worldToGrid(position)
	self._occupiedCells[folderName][cellKey] = nil
	self:_updateOccupy(position, false)
end

function GridService:SnapTogrid(gridPart: BasePart, position: Vector3): Vector3
	local gridx = math.floor(position.X / CONFIG.CELL_SIZE)
	local gridz = math.floor(position.Z / CONFIG.CELL_SIZE)
	local snappedX = (gridx + 0.5) * CONFIG.CELL_SIZE
	local snappedZ = (gridz + 0.5) * CONFIG.CELL_SIZE
	local surfaceY = gridPart.Position.Y + gridPart.Size.Y / 2
	return Vector3.new(snappedX, surfaceY, snappedZ)
end

function GridService:Init()
	if not idempotentGuard:MarkInitialized() then
		return
	end

	self._Structure = Workspace:WaitForChild("Map"):WaitForChild("Structure")
	if not self._Structure then
		warn("Structure folder not found in Workspace")
		return
	end

	for _, folders in pairs(self._Structure:GetChildren()) do
		local part = folders:FindFirstChild(CONFIG.GRID_PART, true)
		if not part or not part:IsA("BasePart") then
			warn(`Grid part not found in {folders.Name}`)
			continue
		end
		self:_RegisterZone(folders.Name, part)
		self._GridStore[folders.Name] = { gridPart = part, owner = nil }
	end
end

function GridService:Start()
	if not idempotentGuard:MarkStarted() then
		return
	end

	-- Players.PlayerAdded:Connect(function(player: Player) end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local folderName = self._PlayerStore[player]
		if folderName then
			self._GridStore[folderName].owner = nil
			self._PlayerStore[player] = nil
		end
	end)

	--[[
	    Inproduction User SnapShotService
	]]
	EventBus:On(Events.LOCAL_CLIENT_READY, function(player: Player)
		for folderName, data in pairs(self._GridStore) do
			if not data.owner then
				self:_AssignOwner(folderName, player)
				warn(`[GridService] Assigned folder {folderName} to player {player.Name}`)
				break
			end
		end
	end)
end

return GridService
