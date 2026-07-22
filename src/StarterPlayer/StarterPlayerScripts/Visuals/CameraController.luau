--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)

local CONFIG = {
	ZOOM_MAX = 130,
	ZOOM_MIN = 30,
	CENTER_PART = "Center",

	FRICTION = 5, --
	ZOOM_DECAY = 10,
	EPSILON = 0.01,

	WHEEL_SENSITIVITY = 5,
}

local CameraController = {}
CameraController.__index = CameraController
function CameraController.new()
	local self = setmetatable({}, CameraController)

	--state
	self._isDragging = false
	self._isMoveBuildingMode = false

	--references
	self._focus = Vector3.new(0, 0, 0)
	self._lastFocus = Vector3.new(0, 0, 0)

	self._grabPoint = Vector3.new(0, 0, 0)
	self._velocity = Vector3.new(0, 0, 0)
	self._PlayerFolder = nil
	self._pitch = math.rad(61)
	self._yaw = math.rad(225)
	self._zoom = 60
	self._currentZoom = 60
	self._Camera = Workspace.CurrentCamera

	--Connections
	self._ChangeConn = nil
	self._BeginConn = nil
	self._EndConn = nil

	return self
end

function CameraController:SetAngles(key: string, value: number)
	if key == "Pitch" then
		self._pitch = math.rad(value)
	elseif key == "Yaw" then
		self._yaw = math.rad(value)
	end
	warn(`[CameraController] SetAngles: {key} = {value}`)
end

function CameraController:_ScreenToGround(screenPos: Vector2): Vector3?
	local ray = self._Camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local groundY = self._focus.Y -- ระดับพื้น
	if math.abs(ray.Direction.Y) < 1e-6 then
		return nil
	end
	local t = (groundY - ray.Origin.Y) / ray.Direction.Y
	return ray.Origin + ray.Direction * t
end

function CameraController:OnCameraChanged()
	local horizontal = math.cos(self._pitch)
	local dir = Vector3.new(math.sin(self._yaw) * horizontal, math.sin(self._pitch), math.cos(self._yaw) * horizontal)
	local camPos = self._focus + dir * self._currentZoom
	self._Camera.CFrame = CFrame.lookAt(camPos, self._focus)
end

function CameraController:BlindInput()
	RunService:BindToRenderStep("CameraController", Enum.RenderPriority.Camera.Value, function(dt)
		local zAlpha = 1 - math.exp(-CONFIG.ZOOM_DECAY * dt)
		self._currentZoom += (self._zoom - self._currentZoom) * zAlpha

		if self._isDragging then
			self._velocity = (self._focus - self._lastFocus) / dt
		end

		if not self._isDragging then
			self._focus += self._velocity * dt
			self._velocity *= math.exp(-CONFIG.FRICTION * dt)
			if self._velocity.Magnitude < CONFIG.EPSILON then
				self._velocity = Vector3.zero
			end
		end

		self._lastFocus = self._focus

		self:OnCameraChanged()
	end)

	self._ChangeConn = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self._zoom =
				math.clamp(self._zoom - (input.Position.Z * CONFIG.WHEEL_SENSITIVITY), CONFIG.ZOOM_MIN, CONFIG.ZOOM_MAX)
		elseif self._isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local hitNow = self:_ScreenToGround(input.Position)
			if not hitNow then
				return
			end
			self._focus = self._focus + (self._grabPoint - hitNow)
		end
	end)

	self._BeginConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if self._isMoveBuildingMode then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isDragging = true
			self._grabPoint = self:_ScreenToGround(input.Position)
		end
	end)

	self._EndConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isDragging = false
		end
	end)
end

function CameraController:Disconnect()
	if self._ChangeConn then
		self._ChangeConn:Disconnect()
		self._ChangeConn = nil
	end
	if self._BeginConn then
		self._BeginConn:Disconnect()
		self._BeginConn = nil
	end
	if self._EndConn then
		self._EndConn:Disconnect()
		self._EndConn = nil
	end
	RunService:UnbindFromRenderStep("CameraController")
end

function CameraController:Init() end

function CameraController:Start()
	self._Camera.CameraType = Enum.CameraType.Scriptable

	EventBus:On(Events.LOCAL_FOLDER_READY, function(data)
		self._PlayerFolder = data.Folder
		if not self._PlayerFolder then
			warn("[CameraController] No PlayerFolder found, camera will not function properly.")
			return
		end

		local centerPart = self._PlayerFolder:FindFirstChild(CONFIG.CENTER_PART, true)
		if not centerPart then
			warn("[CameraController] No Center part found in PlayerFolder, camera will not function properly.")
			return
		end
		self._focus = centerPart.Position
		self:OnCameraChanged()
	end)

	self:BlindInput()

	EventBus:On(Events.LOCAL_MOVE_BUILDING, function(data)
		self._isMoveBuildingMode = data ~= nil
		if self._isMoveBuildingMode then
			self._isDragging = false
			self._velocity = Vector3.zero
		end
	end)

	EventBus:On(Events.LOCAL_MOVE_BUILDING_CONFIRM, function()
		self._isMoveBuildingMode = false
	end)
end

return CameraController.new()
