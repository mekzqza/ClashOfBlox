--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)

export type Collectors = {
	Timestamp: number,
	Capacity: number,
	ProductionRate: number,
}

local ResourceController = {}
ResourceController.__index = ResourceController
function ResourceController.new()
	local self = setmetatable({}, ResourceController)
	self._PlayerDataController = nil
	self._Collectors = {} :: { [string]: Collectors }
	return self
end

function ResourceController:RegisterCollectors(collector: string) end

function ResourceController:SetDependencies(locator)
	self._PlayerDataController = locator:Get("PlayerDataController")
end

function ResourceController:Init() end

function ResourceController:Start()
	-- task.spawn(function()
	-- 	while true do
	-- 		task.wait(5)
	-- 		EventBus:Emit(Events.C2S_PLAYER_CLICK_COLLECTOR, {
	-- 			CollectorType = "GoldCollector",
	-- 		})
	-- 		warn("Emit event to collect gold")
	-- 	end
	-- end)
end

return ResourceController.new()
