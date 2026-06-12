--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)
local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local Events = require(ReplicatedStorage.Shared.Events)

local CONFIG = {
	START_LEVEL = 1,
}

local ShopVisualize = {}
ShopVisualize.__index = ShopVisualize
function ShopVisualize.new()
	local self = setmetatable({}, ShopVisualize)
	-- Dependencies
	self._PlayerDataController = nil
	self._StructureModel = nil

	--Cache
	self._CardConn = {} :: { [string]: RBXScriptConnection }

	-- Ui
	self._ShopGui = nil
	self._MainFrame = nil
	self._MainFrame2 = nil
	self._Resource = nil
	self._DisplayFrame = nil

	self._MainShop = nil
	self._BuildingContrainer = nil
	return self
end

function ShopVisualize:SetDependencies(locator)
	self._PlayerDataController = locator:Get("PlayerDataController")
end

local function setupBuildingViewport(viewPort: ViewportFrame, modelTemplate: Model)
	viewPort:ClearAllChildren()

	local model = modelTemplate:Clone()
	model.Parent = viewPort

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	viewPort.CurrentCamera = camera
	camera.Parent = viewPort

	local boundsCF, boundsSize = model:GetBoundingBox()
	local radius = boundsSize.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2))

	local rotation = CFrame.fromEulerAnglesYXZ(math.rad(-25), math.rad(45), 0)
	local offset = rotation:VectorToWorldSpace(Vector3.new(0, 0, distance * 1.05))

	camera.CFrame = CFrame.lookAt(boundsCF.Position + offset, boundsCF.Position)
end

function ShopVisualize:_updateResourceDisplay(key: string, value: number)
	local target = self._DisplayFrame:WaitForChild(key)
	if not target then
		warn(`[ShopVisualize] Cannot find resource container with name ${key}`)
		return
	end

	local frameValue: TextLabel = target:FindFirstChild("Value", true)
	if not frameValue then
		warn(`[ShopVisualize] Cannot find Value label in ${key} container`)
		return
	end

	frameValue.Text = tostring(value)
end

function ShopVisualize:_setupBuildingCard(frameName: Frame, modelTemplate: Model)
	local mainBtn = frameName:FindFirstChild("MainButton")
	if not mainBtn then
		warn(`[ShopVisualize] Cannot find MainButton ViewportFrame in {frameName.Name}`)
		return
	end

	local viewPort = mainBtn:FindFirstChildOfClass("ViewportFrame")
	if not viewPort then
		warn(`[ShopVisualize] Cannot find ViewportFrame in MainButton of {frameName.Name}`)
		return
	end

	local buildingData = BuildingConfig:GetBuildingData(frameName.Name, CONFIG.START_LEVEL)
	if not buildingData then
		warn(`[ShopVisualize] Cannot find building data for {frameName.Name} at level {CONFIG.START_LEVEL}`)
		return
	end

	setupBuildingViewport(viewPort, modelTemplate)

	self._CardConn[frameName.Name] = mainBtn.MouseButton1Click:Connect(function()
		--TODO
		warn(`[ShopVisualize] Clicked on building card {frameName.Name}`)
	end)
end

-- @ หาโมเดลจาก Frame name ที่ Asset Constucture และ Level ที่กำหนด
function ShopVisualize:_getModelByName(frameName: string, level: number)
	local lv = level or CONFIG.START_LEVEL
	local modelFloder = self._StructureModel:FindFirstChild(frameName, true)
	return modelFloder:FindFirstChild(tostring(lv))
end

function ShopVisualize:_updateResourceDisplay(key: string, value: number)
	local target = self._DisplayFrame:FindFirstChild(key, true)
	if not target or not target:IsA("Frame") then
		warn(`[ShopVisualize] Cannot find resource display with name {key}`)
		return
	end

	local textLabel = target:FindFirstChild("Value", true)
	if not textLabel or not textLabel:IsA("TextLabel") then
		warn(`[ShopVisualize] Cannot find TextLabel named "Value" in resource display {key}`)
		return
	end
	value = math.floor(value)
	textLabel.Text = tostring(value)
end

function ShopVisualize:Init()
	self._ShopGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Shop")
	self._MainFrame = self._ShopGui:WaitForChild("MainFrame")
	self._Resource = self._MainFrame:WaitForChild("Resource")
	self._DisplayFrame = self._Resource:WaitForChild("DisplayFrame")

	self._MainFrame2 = self._MainFrame:WaitForChild("MainFrame2")
	self._MainShop = self._MainFrame2:WaitForChild("MainShop")
	self._BuildingContrainer = self._MainShop:WaitForChild("BuildingContrainer")

	self._StructureModel = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Structure")
	if not self._StructureModel then
		warn("[ShopVisualize] Cannot find Structure model in ReplicatedStorage.Assets")
		return
	end
end

function ShopVisualize:Start()
	for _, frame in ipairs(self._BuildingContrainer:GetChildren()) do
		if frame:IsA("Frame") then
			local model = self:_getModelByName(frame.Name, CONFIG.START_LEVEL)
			if model and model:IsA("Model") then
				self:_setupBuildingCard(frame, model)
			else
				warn(`[ShopVisualize] Cannot find model for frame {frame.Name} at level {CONFIG.START_LEVEL}`)
			end
		end
	end

	self._PlayerDataController:WaitForDataReady():andThen(function(data)
		self:_updateResourceDisplay("Golds", data.Golds)
		self:_updateResourceDisplay("Elixirs", data.Elixirs)
		self:_updateResourceDisplay("Gems", data.Gems)
	end)
end

return ShopVisualize.new()
