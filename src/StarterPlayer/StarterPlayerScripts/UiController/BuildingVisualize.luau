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
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)
local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)

local CONFIG = {
	MAX_DISTANCE = 100,
	RAY_MODE = "Mouse",
	INSET_OFFSET = Vector2.new(0, 36),
	DEBUG_HIT = true,
	DEBUG_HIT_SIZE = 1,

	HOLD_TIME = 0.2,
	MOVE_TOLERANCE = 12,
}

local BuildingVisualize = {}
BuildingVisualize.__index = BuildingVisualize
function BuildingVisualize.new()
	local self = setmetatable({}, BuildingVisualize)
	self._playerGui = nil
	self._MainDisPlay = nil
	self._MainInfoFrame = nil
	self._BuildingInfo = nil

	self._currentBuildingId = nil
	self._connInputBegan = nil
	self._connInputChanged = nil
	self._connInputEnded = nil
	self._isDragging = false

	self._holdThread = nil
	self._pressing = false
	self._holdFired = false
	self._pressStartPos = nil
	self._pendingBuildingId = nil

	self._mouse = nil
	self._raycastParams = nil
	self._debugPart = nil

	self._BuildingStore = nil
	return self
end

function BuildingVisualize:_buildingInfo(buildingId: string?)
	if buildingId == nil then
		self._MainInfoFrame.Visible = false
		return
	end

	local buildingCache = self._BuildingStore:GetBuildingData(buildingId)
	if not buildingCache then
		warn("Building data not found for ID:", buildingId)
		return
	end

	self._MainInfoFrame.Visible = true

	local buildingData = BuildingConfig:GetBuildingDataByEnum(buildingCache.BuildingEnum, buildingCache.BuildingLevel)
	local buildingTypeName = GameEnum:GetBuildingTypeById(buildingCache.BuildingEnum)

	local buildingLevel = self._BuildingInfo:FindFirstChild("BuildingLevel")
	local buildingName = self._BuildingInfo:FindFirstChild("BuildingName")

	buildingLevel.Text = "Level: " .. buildingCache.BuildingLevel
	buildingName.Text = buildingTypeName
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

function BuildingVisualize:_cancelPress()
	if self._holdThread then
		task.cancel(self._holdThread)
		self._holdThread = nil
	end
	self._pressing = false
	self._holdFired = false
	self._pendingBuildingId = nil
	self._pressStartPos = nil
	self._isDragging = false
	self._currentBuildingId = nil
end

function BuildingVisualize:SetDependencies(locator)
	self._BuildingStore = locator:Get("BuildingStore")
end

function BuildingVisualize:Init()
	self._playerGui = Player:WaitForChild("PlayerGui")
	self._MainDisPlay = self._playerGui:WaitForChild("MainDisPlay")
	self._MainInfoFrame = self._MainDisPlay:WaitForChild("MainInfoFrame")
	self._BuildingInfo = self._MainInfoFrame:WaitForChild("BuildingInfo")

	self._mouse = Player:GetMouse()

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	self._raycastParams = params
end

function BuildingVisualize:Start()
	self._connInputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local raycastResult = self:_raycastFromInput(input)
		local buildId = raycastResult and self:_resolveBuildingId(raycastResult.Instance)
		if not buildId then
			self:_buildingInfo(buildId)
			return
		end

		self._pressing = true
		self._holdFired = false
		self._pressStartPos = input.Position
		self._pendingBuildingId = buildId
		self:_buildingInfo(buildId)

		self._holdThread = task.delay(CONFIG.HOLD_TIME, function()
			self._holdThread = nil
			if not self._pressing then
				return
			end

			self._holdFired = true
			self._isDragging = true
			self._currentBuildingId = self._pendingBuildingId
			EventBus:Emit(Events.LOCAL_MOVE_BUILDING, self._currentBuildingId)
		end)
	end)

	self._connInputChanged = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if not self._pressing then
			return
		end

		if not self._holdFired then -- เฟสรอ: เลื่อนไกล = ยกเลิก
			local p, s = input.Position, self._pressStartPos
			if (Vector2.new(p.X, p.Y) - Vector2.new(s.X, s.Y)).Magnitude > CONFIG.MOVE_TOLERANCE then
				self:_cancelPress()
			end
			return
		end

		local r = self:_raycastFromInput(input)
		if r then
			EventBus:Emit(Events.LOCAL_MOVE_BUILDING_UPDATE, r.Position)
		end
	end)

	self._connInputEnded = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if not self._pressing then
			return
		end
		if self._holdFired then
			EventBus:Emit(Events.LOCAL_MOVE_BUILDING_CONFIRM)
		end
		self:_cancelPress()
	end)
end

return BuildingVisualize.new()
