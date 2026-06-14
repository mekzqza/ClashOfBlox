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
}

local CameraController = {}
CameraController.__index = CameraController
function CameraController.new()
	local self = setmetatable({}, CameraController)

	--state
	self._isDragging = false
	self._grabPoint = Vector2.new(0, 0)

	--references
	self._PlayerFolder = nil
	self._focus = Vector3.new(0, 0, 0)
	self._pitch = math.rad(55)
	self._zoom = 60
	self._Camera = Workspace.CurrentCamera

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
	return ray.Origin + ray.Direction * t -- จุดตัดบนพื้น
end

function CameraController:OnCameraChanged()
	local dir = Vector3.new(0, math.sin(self._pitch), math.cos(self._pitch))
	local camPos = self._focus + dir * self._zoom
	self._Camera.CFrame = CFrame.lookAt(camPos, self._focus)
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

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self._zoom = math.clamp(self._zoom - input.Position.Z, CONFIG.ZOOM_MIN, CONFIG.ZOOM_MAX)
			self:OnCameraChanged()
			warn(`{self._zoom}`)
		elseif self._isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local hitNow = self:_ScreenToGround(input.Position)
			self._focus = self._focus + (self._grabPoint - hitNow)
			self:OnCameraChanged()
		end
	end)

	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isDragging = true
			self._grabPoint = self:_ScreenToGround(input.Position)
			warn("[CameraController]  dragging")
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isDragging = false
			warn("[CameraController]  stopped dragging")
		end
	end)
end

return CameraController.new()
