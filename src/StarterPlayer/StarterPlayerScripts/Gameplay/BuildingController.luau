--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)
local Player = Players.LocalPlayer

local GridController = nil
local BuildingTemplate = nil
local CONFIG = {
	FOOTPRINTS_TEMPLATE = "FootPrints",
	HARD_CODE_HIGHT = 1,
	FOOTPRINTS = {
		[1] = "1*1Grid",
		[4] = "2*2Grid",
		[9] = "3*3Grid",
		[16] = "4*4Grid",
	},
}

local BuildingController = {}
BuildingController.__index = BuildingController
function BuildingController.new()
	local self = setmetatable({}, BuildingController)
	self._buildings = {} :: { [string]: string }
	self._isPlacing = false
	self._renderConnection = nil
	self._indicatorModel = nil
	self._mouseConnettion = nil
	self._footPrintindicator = nil
	return self
end

function BuildingController:SetDependencies(locator)
	GridController = locator:Get("GridController")
end

function BuildingController:_createFootPrints(position: Vector3, size: number)
	local template = BuildingTemplate:FindFirstChild(CONFIG.FOOTPRINTS_TEMPLATE, true)
	if not template then
		warn(`[BuildingController] Footprints template not found in BuildingTemplate`)
		return
	end

	local newFootPrint: BasePart = template:FindFirstChild(CONFIG.FOOTPRINTS[size], true):Clone()
	if not newFootPrint then
		warn(`[BuildingController] Footprints model with size {size} not found in BuildingTemplate`)
		return
	end

	local haffHeight = newFootPrint.Size.Y / 2
	newFootPrint.Parent = Workspace
	newFootPrint.CFrame = CFrame.new(position.X, position.Y + haffHeight + CONFIG.HARD_CODE_HIGHT, position.Z)
end

function BuildingController:_createBuilding(buildingType: string, snapPosition: Vector3)
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
	local primaryPart: BasePart? = newBuilding.PrimaryPart
	if not primaryPart then
		warn(`[BuildingController] Building model with id {buildingType} does not have a PrimaryPart`)
		return
	end
	local templateRotation = Template:GetPivot().Rotation
	local halfHeight = primaryPart.Size.Y / 2
	newBuilding:PivotTo(
		CFrame.new(snapPosition.X, snapPosition.Y + halfHeight + CONFIG.HARD_CODE_HIGHT, snapPosition.Z)
			* templateRotation
	)
end

function BuildingController:_requestPlaceBuilding(snapToString: string, buildingType: string, position: Vector3)
	EventBus:Emit(Events.C2S_PLAYER_REQUEST_PLACE, {
		SnapToString = snapToString,
		BuildingType = buildingType,
		Position = position,
	})
end

function BuildingController:_startPlacement(buildType: string)
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
	self._indicatorModel = Template:Clone()
	self._footPrintindicator = BuildingTemplate:FindFirstChild(CONFIG.FOOTPRINTS_TEMPLATE, true)
		:FindFirstChild(CONFIG.FOOTPRINTS[dimention.Length * dimention.Width], true)
		:Clone()
	self._footPrintindicator.Parent = self._indicatorModel
	local templateRotation = Template:GetPivot().Rotation

	self._indicatorModel.Parent = Workspace
	self._isPlacing = true

	local primaryPart: BasePart? = self._indicatorModel.PrimaryPart
	if not primaryPart then
		return
	end

	local indicatorModelhalfHeight = primaryPart.Size.Y / 2
	local footPrintindicatorhalfHeight = self._footPrintindicator.Size.Y / 2

	self._renderConnection = RunService.RenderStepped:Connect(function()
		local mouse = Player:GetMouse()
		local traget = mouse.Target
		if not traget then
			return
		end

		if not self._indicatorModel then
			return
		end

		local snapPos = GridController:SnapToGrid(mouse.Hit.Position, dimention.Length, dimention.Width) :: Vector3

		local canPlace = GridController:Canplace(snapPos, dimention.Length, dimention.Width)
		local color = if canPlace then Color3.new(0, 1, 0) else Color3.new(1, 0, 0)
		for _, child in ipairs(self._indicatorModel:GetDescendants()) do
			if child:IsA("BasePart") then
				if child:IsA("UnionOperation") then
					child.UsePartColor = true
				end
				child.Color = color
			end
		end
		self._indicatorModel:SetPrimaryPartCFrame(
			CFrame.new(snapPos.X, snapPos.Y + indicatorModelhalfHeight, snapPos.Z) * templateRotation
		)
		self._footPrintindicator.CFrame = CFrame.new(snapPos.X, snapPos.Y + footPrintindicatorhalfHeight, snapPos.Z)
	end)

	local mouse = Player:GetMouse()
	self._mouseConnettion = mouse.Button1Down:Connect(function()
		local snapPos = GridController:SnapToGrid(mouse.Hit.Position, dimention.Length, dimention.Width) :: Vector3
		if GridController:Canplace(snapPos, dimention.Length, dimention.Width) then
			local startX, startZ = GridController:GetFootPrintStart(snapPos, dimention.Length, dimention.Width)
			self:_requestPlaceBuilding(`{startX}_{startZ}`, buildType, snapPos)
			self:_createBuilding(buildType, snapPos)
			self:_createFootPrints(snapPos, dimention.Length * dimention.Width)
			GridController:occupyCell(snapPos, dimention.Length, dimention.Width)

			self._buildings[`{startX}_{startZ}`] = buildType
		end
	end)
end

function BuildingController:RecreateBuildings(snapPosition: string, buildingType: string)
	local startX, startZ = string.match(snapPosition, "(-?%d+)_(-?%d+)")
	local dimention = BuildingConfig:GetBuildingDimensions(buildingType)
	if not dimention then
		warn(`[BuildingController] Building config with id {buildingType} not found in BuildingConfig`)
		return
	end

	local worldPos =
		GridController:GridCoordsToWorld(tonumber(startX), tonumber(startZ), dimention.Length, dimention.Width)

	self:_createBuilding(buildingType, worldPos)
	self:_createFootPrints(worldPos, dimention.Length * dimention.Width)
	GridController:occupyCell(worldPos, dimention.Length, dimention.Width)
end

function BuildingController:_stopPlacement()
	self._isPlacing = false
	if self._renderConnection then
		self._renderConnection:Disconnect()
		self._renderConnection = nil
	end

	if self._mouseConnettion then
		self._mouseConnettion:Disconnect()
		self._mouseConnettion = nil
	end

	if self._indicatorModel then
		self._indicatorModel:Destroy()
		self._indicatorModel = nil
	end

	if self._footPrintindicator then
		self._footPrintindicator:Destroy()
		self._footPrintindicator = nil
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
	-- EventBus:On(Events.LOCAL_CREATE_BUILDING, function(data)
	-- end)

	EventBus:On(Events.LOCAL_TEST_BUILDING, function(building: string)
		warn(`[BuildingController] Test building: {building}`)
		self:_stopPlacement()
		self:_startPlacement(building)
	end)

	EventBus:On(Events.LOCAL_SNAPSHOT_BUILDING, function(data)
		for snapPosition, buildingType in data.Buildings do
			self:RecreateBuildings(snapPosition, buildingType)
		end
	end)

	GridController:WaitForGridPartReady():andThen(function(GridPart)
		-- self:RecreateBuildings("5_5", "TownHall_1")
	end)
end

return BuildingController.new()
