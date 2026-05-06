--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)

local GridService = {}
local idempotentGuard = IdempotentGuard.new("GridService")

local GridStore: { [string]: { gridPart: BasePart, owner: Player? } } = {}
local PlayerStore: { [Player]: string } = {}

local validCells: { [string]: { [string]: true } } = {}
local occupiedCells: { [string]: { [string]: true } } = {}

local Structure: Folder = nil
local CONFIG = {
	CELL_SIZE = 4,
	GRID_PART = "LogicPart",
}

local function AssignOwner(folderName: string, player: Player)
	if GridStore[folderName] then
		GridStore[folderName].owner = player
		PlayerStore[player] = folderName
	end
end

local function worldToGrid(position: Vector3): string
	local gridx = math.floor(position.x / CONFIG.CELL_SIZE)
	local gridz = math.floor(position.z / CONFIG.CELL_SIZE)
	return `{gridx},{gridz}`
end

local function RegisterZone(folderName: string, part: BasePart)
	validCells[folderName] = {}
	occupiedCells[folderName] = {}

	local origin = part.Position - (part.Size / 2)
	local xCells = math.ceil(part.Size.X / CONFIG.CELL_SIZE)
	local zCells = math.ceil(part.Size.Z / CONFIG.CELL_SIZE)

	for x = 0, xCells - 1 do
		for z = 0, zCells - 1 do
			local cellPos =
				Vector3.new(origin.X + x * CONFIG.CELL_SIZE, part.Position.Y, origin.Z + z * CONFIG.CELL_SIZE)
			local cellKey = worldToGrid(cellPos)
			validCells[folderName][cellKey] = true
		end
	end
end

function GridService:CanPlace(folderName: string, position: Vector3): boolean
	local cellKey = worldToGrid(position)
	if not validCells[folderName][cellKey] then
		return false
	end
	if occupiedCells[folderName][cellKey] then
		return false
	end
	return true
end

local function updateOccupy(position: Vector3, occupied: boolean)
	local data = {
		position = position,
		occupied = occupied,
	}
	EventBus:Emit(Events.S2C_GRIDCELL_UPDATE, data)
end

function GridService:OccupyCell(folderName: string, position: Vector3)
	local cellKey = worldToGrid(position)
	if not validCells[folderName][cellKey] then
		return
	end

	occupiedCells[folderName][cellKey] = true
	updateOccupy(position, true)
end

function GridService:FreeCell(folderName: string, position: Vector3)
	local cellKey = worldToGrid(position)
	occupiedCells[folderName][cellKey] = nil
	updateOccupy(position, false)
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

	Structure = Workspace:WaitForChild("Map"):WaitForChild("Structure")
	if not Structure then
		warn("Structure folder not found in Workspace")
		return
	end

	for _, folders in pairs(Structure:GetChildren()) do
		local part = folders:FindFirstChild(CONFIG.GRID_PART, true)
		if not part or not part:IsA("BasePart") then
			warn(`Grid part not found in {folders.Name}`)
			continue
		end
		RegisterZone(folders.Name, part)
		GridStore[folders.Name] = { gridPart = part, owner = nil }
	end
end

function GridService:Start()
	if not idempotentGuard:MarkStarted() then
		return
	end

	Players.PlayerAdded:Connect(function(player: Player)
		for folderName, data in pairs(GridStore) do
			if not data.owner then
				AssignOwner(folderName, player)
				break
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local folderName = PlayerStore[player]
		if folderName then
			GridStore[folderName].owner = nil
			PlayerStore[player] = nil
		end
	end)
end

return GridService
