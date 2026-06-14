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

	WHELL_SENSITIVITY = 5,
}

local CameraController = {}
CameraController.__index = CameraController
function CameraController.new()
	local self = setmetatable({}, CameraController)

	--state
	self._isDragging = false

	--references
	self._focus = Vector3.new(0, 0, 0)
	self._lastFocus = Vector3.new(0, 0, 0)

	self._grabPoint = Vector3.new(0, 0, 0)
	self._velocity = Vector3.new(0, 0, 0)
	self._PlayerFolder = nil
	self._pitch = math.rad(55)
	self._yaw = math.rad(45)
	self._zoom = 60
	self._currentZoom = 60
	self._Camera = Workspace.CurrentCamera

	--Connections
	self._CahngeConn = nil
	self._BeginConn = nil
	self._EndConn = nil

	--dependencies
	self._GridController = nil
	return self
end
function CameraController:SetDependencies(locator)
	self._GridController = locator:Get("GridController")
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
	local dir = Vector3.new(0, math.sin(self._pitch), math.cos(self._pitch))
	local camPos = self._focus + dir * self._currentZoom
	self._Camera.CFrame = CFrame.lookAt(camPos, self._focus)
end

function CameraController:Disconnect()
	if self._CahngeConn then
		self._CahngeConn:Disconnect()
		self._CahngeConn = nil
	end
	if self._BeginConn then
		self._BeginConn:Disconnect()
		self._BeginConn = nil
	end
	if self._EndConn then
		self._EndConn:Disconnect()
		self._EndConn = nil
	end
end

function CameraController:Init()
	if not self._GridController then
		warn("[CameraController] No GridController found, camera will not function properly.")
		return
	end
end

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

	self._CahngeConn = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self._zoom =
				math.clamp(self._zoom - (input.Position.Z * CONFIG.WHELL_SENSITIVITY), CONFIG.ZOOM_MIN, CONFIG.ZOOM_MAX)
		elseif self._isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local hitNow = self:_ScreenToGround(input.Position)
			if not hitNow then
				return
			end
			self._focus = self._focus + (self._grabPoint - hitNow)
		end
	end)

	self._BeginConn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isDragging = true
			self._grabPoint = self:_ScreenToGround(input.Position)
		end
	end)

	self._EndConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isDragging = false
		end
	end)
end

return CameraController.new()
