--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)

export type MODE = "Raid" | "Spectator" | "OwnHome"

local ModeController = {}
ModeController.__index = ModeController
function ModeController.new()
	local self = setmetatable({}, ModeController)
	self._currentMode = "OwnHome"
	self.oldMode = nil
	return self
end

function ModeController:SetMode(mode: MODE)
	if self._currentMode == mode then
		return
	end
	self.oldMode = self._currentMode
	self._currentMode = mode
	EventBus:Emit(Events.LOCAL_MODE_CHANGED, self._currentMode)
end

function ModeController:GetMode(): string
	return self._currentMode
end

function ModeController:Init() end
function ModeController:Start()
	EventBus:On(Events.LOCAL_MODE_CHANGE_REQUEST, function(mode)
		self:SetMode(mode)
		print("[ModeController] Mode changed to: " .. mode)
	end)
end
return ModeController.new()
