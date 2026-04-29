--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local GridPart: BasePart = nil

local validCells: { [string]: true } = {}
local occupiedCells: { [string]: true } = {}

local isPlacing = false
local indicatorModel: Model = nil
local renderConnection = nil
local mouseConnettion = nil
local BuldingTemplat = nil

local CONFIG = {
	CELL_SIZE = 4,
	BUILDING_DEBUG = "TownHall_1",
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

local function Canplace(position: Vector3): boolean
	local cellKey = worldToGrid(position)
	if not validCells[cellKey] then
		return false
	end
	if occupiedCells[cellKey] then
		return false
	end
	return true
end

local function occupyCell(position: Vector3)
	local cellKey = worldToGrid(position)
	if not validCells[cellKey] then
		return
	end

	occupiedCells[cellKey] = true
end

local function freeCell(position: Vector3)
	local cellKey = worldToGrid(position)
	if not validCells[cellKey] then
		return
	end

	occupiedCells[cellKey] = nil
end

local function SnapToGrid(position: Vector3): Vector3
	local gridx = math.floor(position.x / CONFIG.CELL_SIZE) * CONFIG.CELL_SIZE + 2
	local gridz = math.floor(position.z / CONFIG.CELL_SIZE) * CONFIG.CELL_SIZE + 2
	return Vector3.new(gridx, position.y, gridz)
end

local function startPlacement(bulidType: string)
	local Template = BuldingTemplat:FindFirstChild(bulidType, true)
	if not Template then
		warn(`[GridController] Turret model with id {bulidType} not found in TurretTemplate`)
		return
	end

	if not Template:IsA("Model") then
		return
	end

	indicatorModel = Template:Clone()

	local templateRotation = (Template :: Model):GetPivot().Rotation

	indicatorModel.Parent = workspace
	isPlacing = true

	renderConnection = RunService.RenderStepped:Connect(function()
		local mouse = player:GetMouse()
		local traget = mouse.Target

		if not traget then
			return
		end
		if not indicatorModel then
			return
		end

		local primaryPart = indicatorModel.PrimaryPart
		if not primaryPart then
			return
		end

		local snapPos = SnapToGrid(mouse.Hit.Position)

		local halfHeight = primaryPart.Size.Y / 2

		if Canplace(snapPos) then
			for _, child in ipairs(indicatorModel:GetChildren()) do
				if child:IsA("UnionOperation") then
					child.UsePartColor = true
					child.Color = Color3.new(0, 1, 0)
				end
			end
		else
			for _, child in ipairs(indicatorModel:GetChildren()) do
				if child:IsA("UnionOperation") then
					child.UsePartColor = true
					child.Color = Color3.new(1, 0, 0)
				end
			end
		end

		indicatorModel:SetPrimaryPartCFrame(CFrame.new(snapPos.X, snapPos.Y + halfHeight, snapPos.Z) * templateRotation)
	end)
end

local function stopPlacement()
	isPlacing = false
	if renderConnection then
		renderConnection:Disconnect()
	end
	if mouseConnettion then -- ← ไม่มีบรรทัดนี้
		mouseConnettion:Disconnect()
		mouseConnettion = nil
	end
	if indicatorModel then
		indicatorModel:Destroy()
	end
end

function GridController:Init()
	BuldingTemplat = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Structure")
	if not BuldingTemplat then
		warn("[GridController] Building template folder not found in ReplicatedStorage.Assets")
		return
	end

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

function GridController:Start()
	task.wait(10)
	startPlacement(CONFIG.BUILDING_DEBUG)
end

return GridController
