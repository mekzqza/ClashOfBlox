--!strict
--
-- [[
--    @signature
--  ระบบนี้จะจัดการเกี่ยวกับการแสดงผลของอาคาร เช่น การแสดงตำแหน่งที่สามารถวางอาคารได้ และการแสดงข้อมูลของอาคารเมื่อผู้เล่นคลิกที่อาคารนั้น
--  เชื่อม Ui กับ BuildingStore เพื่อดึงข้อมูลอาคารมาแสดงผล
-- ]]
local Player = game:GetService("Players").LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)

local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)

local CONFIG = {
	MAX_DISTANCE = 100,
	VALID_PLACEMENT_COLOR = Color3.fromRGB(0, 255, 0),
	INVALID_PLACEMENT_COLOR = Color3.fromRGB(255, 0, 0),
	DEBOUNCE_TIME = 0.2,
	KEY_STORE = {
		["1*1Grid"] = "1*1Grid",
		["2*2Grid"] = "2*2Grid",
		["3*3Grid"] = "3*3Grid",
		["4*4Grid"] = "4*4Grid",
	},
}

local BuildingVisualize = {}
BuildingVisualize.__index = BuildingVisualize
function BuildingVisualize.new()
	local self = setmetatable({}, BuildingVisualize)
	self._playerGui = Player:WaitForChild("PlayerGui")
	self._MainDisPlay = self._playerGui:WaitForChild("MainDisplay")
	self._MainInfoFrame = self._MainDisPlay:WaitForChild("MainInfoFrame")
	self._BuildingInfo = self._MainInfoFrame:WaitForChild("BuildingInfo")

	self._currentBuildingId = nil
	self._connInputBegan = nil
	self._connInputChanged = nil
	self._connInputEnded = nil
	self._isDragging = false

	self._BuildingStore = nil
	return self
end

function BuildingVisualize:_ondetectBuilding(buildingId: string)
	local buildingCache = self._BuildingStore:GetBuildingData(buildingId)
	if not buildingCache then
		return
	end

	local buildingData = BuildingConfig:GetBuildingDataByEnum(buildingCache.BuildingEnum, buildingCache.BuildingLevel)

	local buildingLevelt = self._BuildingInfo:FindFirstChild("BuildingLevel")
	local buildingNameT = self._BuildingInfo:FindFirstChild("BuildingName")

	EventBus:Emit(Events.LOCAL_MOVE_BUILDING, buildingId)
end

function BuildingVisualize:_stopConnections()
	self._isDragging = false
	self._currentBuildingId = nil
	if self._connInputBegan then
		self._connInputBegan:Disconnect()
		self._connInputBegan = nil
	end
	if self._connInputChanged then
		self._connInputChanged:Disconnect()
		self._connInputChanged = nil
	end
	if self._connInputEnded then
		self._connInputEnded:Disconnect()
		self._connInputEnded = nil
	end
end

function BuildingVisualize:SetDependencies(locator)
	self._BuildingStore = locator:Get("BuildingStore")
end

function BuildingVisualize:Init() end

function BuildingVisualize:Start()
	self._connInputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local data = Camera:ViewportPointToRay(input.Position.X, input.Position.Y)
			local raycastResult = workspace:Raycast(data.Origin, data.Direction * CONFIG.MAX_DISTANCE)

			if raycastResult then
				local buildId = nil
				-- footPrint อยู่สูงกว่ BuildingModel 1 ชั้น ดังนั้นต้องทำ eadge case
				if CONFIG.KEY_STORE[raycastResult.Instance.Parent.Parent.Name] ~= nil then
					buildId = raycastResult.Instance.Parent.Name
				else
					buildId = raycastResult.Instance.Parent.Parent.Name
				end
				if self._BuildingStore:GetBuildingData(buildId) then
					self._isDragging = true
					self._currentBuildingId = buildId
				end
			end
		end
	end)

	self._connInputChanged = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if not self._isDragging or not self._currentBuildingId then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local data = Camera:ViewportPointToRay(input.Position.X, input.Position.Y)
			local raycastResult = workspace:Raycast(data.Origin, data.Direction * CONFIG.MAX_DISTANCE)
			if raycastResult and self._isDragging then
				self:_ondetectBuilding(self._currentBuildingId)
			end
		end
	end)

	self._connInputEnded = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if self._isDragging then
				self._isDragging = false
				print("หยุดลาก")
				self._currentBuildingId = nil
			end
		end
	end)
end

return BuildingVisualize.new()
