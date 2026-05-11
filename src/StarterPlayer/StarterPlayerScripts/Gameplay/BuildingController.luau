--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)
local Player = Players.LocalPlayer

local BuildingController = {}
local renderConnection = nil
local indicatorModel: Model = nil
local mouseConnettion
local BuildingTemplate = nil
local isPlacing = false
local GridController = nil

local CONFIG = {
	BUILDING_DEBUG = "TownHall_1",
}

function BuildingController:SetDependencies(locator)
	GridController = locator:Get("GridController")
end

local function CreateBuilding(buildingType: string, snapPosition: Vector3)
	local Template = BuildingTemplate:FindFirstChild(buildingType, true)
	if not Template then
		warn(`[BuildingController] Building model with id {buildingType} not found in BuildingTemplate`)
		return
	end

	if not Template:IsA("Model") then
		return
	end

	local newBuilding = Template:Clone()
	newBuilding.Parent = Workspace
	local primaryPart = newBuilding.PrimaryPart
	if not primaryPart then
		warn(`[BuildingController] Building model with id {buildingType} does not have a PrimaryPart`)
		return
	end
	local halfHeight = primaryPart.Size.Y / 2
	newBuilding:PivotTo(CFrame.new(snapPosition.X, snapPosition.Y + halfHeight, snapPosition.Z))
end

local function requestPlaceBuilding(buildingType: string, position: Vector3)
	EventBus:Emit(Events.C2S_PLAYER_REQUEST_PLACE, {
		BuildingType = buildingType,
		Position = position,
	})
end

local function startPlacement(buildType: string)
	local Template = BuildingTemplate:FindFirstChild(buildType, true)
	if not Template then
		warn(`[BuildingController] Building model with id {buildType} not found in BuildingTemplate`)
		return
	end

	local dimention = BuildingConfig:GetBuildingDimensions(buildType)
	if not dimention then
		warn(`[BuildingController] Building config with id {buildType} not found in BuildingConfig`)
		return
	end

	if not Template:IsA("Model") then
		return
	end
	indicatorModel = Template:Clone()

	local templateRotation = Template:GetPivot().Rotation

	indicatorModel.Parent = Workspace
	isPlacing = true

	renderConnection = RunService.RenderStepped:Connect(function()
		local mouse = Player:GetMouse()
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

		local snapPos = GridController:SnapToGrid(mouse.Hit.Position, dimention.Length, dimention.Width) :: Vector3

		local halfHeight = primaryPart.Size.Y / 2

		local canPlace = GridController:Canplace(snapPos, dimention.Length, dimention.Width)
		local color = if canPlace then Color3.new(0, 1, 0) else Color3.new(1, 0, 0)
		for _, child in ipairs(indicatorModel:GetDescendants()) do
			if child:IsA("BasePart") then
				if child:IsA("UnionOperation") then
					child.UsePartColor = true
				end
				child.Color = color
			end
		end
		indicatorModel:SetPrimaryPartCFrame(CFrame.new(snapPos.X, snapPos.Y + halfHeight, snapPos.Z) * templateRotation)
	end)

	local mouse = Player:GetMouse()
	mouseConnettion = mouse.Button1Down:Connect(function()
		local snapPos = GridController:SnapToGrid(mouse.Hit.Position, dimention.Length, dimention.Width) :: Vector3
		if GridController:Canplace(snapPos, dimention.Length, dimention.Width) then
			requestPlaceBuilding(buildType, snapPos)
			CreateBuilding(buildType, snapPos)
			GridController:occupyCell(snapPos, dimention.Length, dimention.Width)
		end
	end)
end

local function stopPlacement()
	isPlacing = false
	if renderConnection then
		renderConnection:Disconnect()
	end

	if mouseConnettion then
		mouseConnettion:Disconnect()
		mouseConnettion = nil
	end

	if indicatorModel then
		indicatorModel:Destroy()
	end
end

function BuildingController:Init()
	BuildingTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Structure")
	if not BuildingTemplate then
		warn("[BuildingController] Building template folder not found in ReplicatedStorage.Assets")
		return
	end
end

function BuildingController:Start()
	task.wait(3)
	startPlacement(CONFIG.BUILDING_DEBUG)

	-- EventBus:On(Events.LOCAL_CREATE_BUILDING, function(data)
	-- end)
end

return BuildingController
