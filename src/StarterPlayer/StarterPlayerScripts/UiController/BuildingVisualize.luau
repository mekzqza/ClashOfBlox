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
	RAY_MODE = "Mouse",
	INSET_OFFSET = Vector2.new(0, 36),
	DEBUG_HIT = true,
	DEBUG_HIT_SIZE = 1,
}

local BuildingVisualize = {}
BuildingVisualize.__index = BuildingVisualize
function BuildingVisualize.new()
	local self = setmetatable({}, BuildingVisualize)
	self._playerGui = nil
	self._MainDisPlay = nil
	self._MainInfoFrame = nil
	self._BuildingInfo = nil
	self._PlaceBillderboards = nil

	self._currentBuildingId = nil
	self._connInputBegan = nil
	self._connInputChanged = nil
	self._connInputEnded = nil
	self._isDragging = false

	self._connConfirmMove = nil
	self._connCancelMove = nil

	self._mouse = nil
	self._raycastParams = nil
	self._debugPart = nil

	self._BuildingStore = nil
	return self
end

function BuildingVisualize:_ondetectBuilding(buildingId: string)
	local buildingCache = self._BuildingStore:GetBuildingData(buildingId)
	if not buildingCache then
		warn("Building data not found for ID:", buildingId)
		return
	end

	-- local buildingData = BuildingConfig:GetBuildingDataByEnum(buildingCache.BuildingEnum, buildingCache.BuildingLevel)
	-- local buildingLevelt = self._BuildingInfo:FindFirstChild("BuildingLevel")
	-- local buildingNameT = self._BuildingInfo:FindFirstChild("BuildingName")

	EventBus:Emit(Events.LOCAL_MOVE_BUILDING, buildingId)
end

function BuildingVisualize:_showPlaceBillderboards(buildingId: string)
	local buildingData = self._BuildingStore:GetBuildingData(buildingId)
	if not buildingData then
		warn("Building data not found for ID:", buildingId)
		return
	end
	local buildingModel = buildingData.BuildingModel
	if not buildingModel then
		warn("Building model not found for ID:", buildingId)
		return
	end

	local attachPart = buildingModel:FindFirstChild("Attachment", true) :: BasePart
	if not attachPart then
		warn("Attachment part not found in building model for ID:", buildingId)
		return
	end

	-- local cancelBnt = self._PlaceBillderboards:FindFirstChild("CancelBnt", true)
	-- local confirm = self._PlaceBillderboards:FindFirstChild("Confirm", true)

	-- self._connConfirmMove = confirm.Activated:Connect(function()
	-- 	EventBus:Emit(Events.LOCAL_MOVE_BUILDING_CONFIRM, true)
	-- 	self._PlaceBillderboards.Enabled = false
	-- end)

	-- self._connCancelMove = cancelBnt.Activated:Connect(function()
	-- 	EventBus:Emit(Events.LOCAL_MOVE_BUILDING_CONFIRM, false)
	-- 	self._PlaceBillderboards.Enabled = false
	-- end)

	self._PlaceBillderboards.Enabled = true
	self._PlaceBillderboards.Adornee = attachPart
end

function BuildingVisualize:_raycastFromInput(input: InputObject): RaycastResult?
	local filter: { Instance } = {}
	local character = Player.Character
	if character then
		table.insert(filter, character)
	end
	self._raycastParams.FilterDescendantsInstances = filter

	local origin: Vector3
	local direction: Vector3
	if CONFIG.RAY_MODE == "Mouse" then
		local unitRay = self._mouse.UnitRay
		origin, direction = unitRay.Origin, unitRay.Direction
	else
		local p = input.Position
		local ray = Camera:ViewportPointToRay(p.X - CONFIG.INSET_OFFSET.X, p.Y - CONFIG.INSET_OFFSET.Y)
		origin, direction = ray.Origin, ray.Direction
	end

	local result = workspace:Raycast(origin, direction * CONFIG.MAX_DISTANCE, self._raycastParams)
	if CONFIG.DEBUG_HIT and result then
		self:_showDebugHit(result.Position)
	end
	return result
end

function BuildingVisualize:_resolveBuildingId(instance: Instance): string?
	local current: Instance? = instance
	while current and current ~= workspace do
		if self._BuildingStore:GetBuildingData(current.Name) then
			return current.Name
		end
		current = current.Parent
	end
	return nil
end

function BuildingVisualize:_showDebugHit(position: Vector3)
	if not self._debugPart then
		local part = Instance.new("Part")
		part.Name = "RaycastDebugHit"
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(CONFIG.DEBUG_HIT_SIZE, CONFIG.DEBUG_HIT_SIZE, CONFIG.DEBUG_HIT_SIZE)
		part.Color = Color3.new(1, 0, 0)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Parent = workspace
		self._debugPart = part
	end
	self._debugPart.Position = position
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

function BuildingVisualize:Init()
	self._playerGui = Player:WaitForChild("PlayerGui")
	self._MainDisPlay = self._playerGui:WaitForChild("MainDisPlay")
	self._PlaceBillderboards = self._playerGui:WaitForChild("PlaceBillderboards")
	self._MainInfoFrame = self._MainDisPlay:WaitForChild("MainInfoFrame")
	self._BuildingInfo = self._MainInfoFrame:WaitForChild("BuildingInfo")

	self._mouse = Player:GetMouse()

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	self._raycastParams = params
end

function BuildingVisualize:Start()
	-- หาโมเดลของอาคารที่ถูกสร้างในเกม และเชื่อมต่อกับ Event ของการคลิกเพื่อแสดงข้อมูลของอาคารนั้น
	self._connInputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local raycastResult = self:_raycastFromInput(input)
		if not raycastResult then
			return
		end

		local buildId = self:_resolveBuildingId(raycastResult.Instance)
		if not buildId then
			return
		end

		self._isDragging = true
		self._currentBuildingId = buildId
		self:_ondetectBuilding(buildId)
	end)

	self._connInputChanged = UserInputService.InputChanged:Connect(function(input)
		if not self._isDragging or not self._currentBuildingId then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end

		local raycastResult = self:_raycastFromInput(input)
		if raycastResult then
			EventBus:Emit(Events.LOCAL_MOVE_BUILDING_UPDATE, raycastResult.Position)
		end
	end)

	-- @TODO เปลี่ยนเป็นการกด ปุ่มอื่นยกเว้นการลากต่อจะ cancel การวางอาคาร
	self._connInputEnded = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if not self._isDragging then
			return
		end

		self._isDragging = false
		self._currentBuildingId = nil

		EventBus:Emit(Events.LOCAL_MOVE_BUILDING_CONFIRM)
	end)
end

return BuildingVisualize.new()
