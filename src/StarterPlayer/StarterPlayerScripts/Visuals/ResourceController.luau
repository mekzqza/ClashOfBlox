--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local Async = require(ReplicatedStorage.Utils.Async)

export type Collectors = {
	Timestamp: number,
	Capacity: number,
	ProductionRate: number,
}

local CONFIG = {
	ACTION_PART_NAME = "ActionPart",
	DISAPPEAR_DELAY = 5,
}

local ResourceController = {}
ResourceController.__index = ResourceController
function ResourceController.new()
	local self = setmetatable({}, ResourceController)
	self._PlayerDataController = nil
	self._Collectors = {} :: { [string]: Collectors }
	self._CollectorModels = {} :: { [string]: { Model } }
	self._Connections = {} :: { [Model]: { Connection: RBXScriptConnection, CollectorType: string } }
	return self
end

function ResourceController:SetDependencies(locator)
	self._PlayerDataController = locator:Get("PlayerDataController")
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

function ResourceController:_CreateUiCollector(collectorType: string, model: Model)
	warn(`[ResourceController] _CreateUiCollector called: {collectorType} on {model.Name}`)
end

function ResourceController:_UiCollectorIsActive(collectorType: string, visible: boolean)
	local models = self._CollectorModels[collectorType]
	if not models then
		return
	end

	for _, model in models do
		local billboard = model:FindFirstChild("BillboardGui", true) :: BillboardGui?
		if billboard then
			billboard.Enabled = visible
		end
	end
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

	if not self._CollectorModels[collectorType] then
		self._CollectorModels[collectorType] = {}
	end
	table.insert(self._CollectorModels[collectorType], model)

	local collectorData = self._PlayerDataController:Get(`Collectors.{collectorType}`)
	if collectorData then
		self._Collectors[collectorType] = collectorData
	end

	self:_CreateUiCollector(collectorType, model)
end

function ResourceController:OnClickCollector(data)
	EventBus:Emit(Events.C2S_PLAYER_CLICK_COLLECTOR, { CollectorType = data.CollectorType })
	self:_UiCollectorIsActive(data.CollectorType, false)
	Async.doAfter(CONFIG.DISAPPEAR_DELAY, function()
		self:_UiCollectorIsActive(data.CollectorType, true)
	end)
end

function ResourceController:Init() end

function ResourceController:Start()
	self._PlayerDataController:WaitForDataReady():andThen(function(playerData)
		warn("[ResourceController] Player data is ready, initializing collectors")
	end)
end

return ResourceController.new()
