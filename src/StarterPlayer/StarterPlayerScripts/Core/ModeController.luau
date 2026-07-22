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
	return self
end

function ModeController:SetMode(mode: MODE)
	if self._currentMode == mode then
		return
	end
	self.oldMode = self._currentMode
	self._currentMode = mode
end

function ModeController:GetMode(): MODE
	return self._currentMode
end

function ModeController:Init() end
function ModeController:Start()
	EventBus:On(Events.LOCAL_MODE_CHANGED, function(mode)
		self:SetMode(mode)
	end)
end
return ModeController.new()
