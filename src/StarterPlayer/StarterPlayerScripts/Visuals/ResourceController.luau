--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)

export type Collectors = {
	Timestamp: number,
	Capacity: number,
	ProductionRate: number,
}

local CONFIG = {
	ACTION_PART_NAME = "ActionPart",
}

local ResourceController = {}
ResourceController.__index = ResourceController
function ResourceController.new()
	local self = setmetatable({}, ResourceController)
	self._PlayerDataController = nil
	self._Collectors = {} :: { [string]: Collectors }
	self._Connections = {} :: { [Model]: { Connection: RBXScriptConnection, CollectorType: string } }
	return self
end

function ResourceController:_CreateclickDetector(model: Model): ClickDetector
	local clickDetector = model:FindFirstChild("ClickDetector", true) :: ClickDetector
	if clickDetector then
		return clickDetector
	end

	local newclickDetector = Instance.new("ClickDetector")
	newclickDetector.Parent = model.PrimaryPart
	return newclickDetector
end

function ResourceController:_CreateUiCollector(model: Model)
	warn("Creating UI for collector:", model.Name)
end

function ResourceController:RegisterCollectors(collectorType: string, model: Model)
	if not model then
		warn(`[ResourceController] model is nil for collectorType: {collectorType}`)
		return
	end
	local clickDetector = self:_CreateclickDetector(model)
	self._Connections[model] = {
		Connection = clickDetector.MouseClick:Connect(function(_player)
			self:OnClickCollector({ CollectorType = collectorType })
		end),
		CollectorType = collectorType,
	}

	local collectorData = self._PlayerDataController:Get(`Collectors.{collectorType}`)
	if collectorData then
		self._Collectors[collectorType] = collectorData
	end
	warn({ #self._Connections })
	self:_CreateUiCollector(model)
end

function ResourceController:SetDependencies(locator)
	self._PlayerDataController = locator:Get("PlayerDataController")
end

function ResourceController:OnClickCollector(data)
	EventBus:Emit(Events.C2S_PLAYER_CLICK_COLLECTOR, { CollectorType = data.CollectorType })

	if self._Collectors[data.CollectorType] then
		self._Collectors[data.CollectorType].Timestamp = os.time()
	end
end

function ResourceController:Init() end

function ResourceController:Start()
	self._PlayerDataController:WaitForDataReady():andThen(function(playerData)
		local collectors = playerData.Collectors
		if not collectors then
			warn("Player data does not contain Collectors information.")
			return
		end
	end)
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
