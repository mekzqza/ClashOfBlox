--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)
local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)
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
	self._Collectors = {
		["ElixirCollector"] = {},
		["GoldCollector"] = {},
	} :: { [string]: { [string]: Collectors } }
	self._ResourceStorage = {
		["Golds"] = 0,
		["Elixirs"] = 0,
	}
	self._CollectorModels = {} :: { [string]: { Model } }
	self._Connections = {} :: { [Model]: { Connection: RBXScriptConnection, CollectorType: string } }
	self._LookBack = {
		[1] = "TownHall",
		[8] = "ElixirStorage",
		[9] = "ElixirCollector",
		[10] = "GoldMine",
		[11] = "GoldStorage",
	}
	return self
end

function ResourceController:SetDependencies(locator)
	self._PlayerDataController = locator:Get("PlayerDataController")
end

local function getBuildingData(buildingTypeEnum: number, buildingLevel: number): any
	local buildingType = GameEnum:GetBuildingTypeById(buildingTypeEnum)
	local buildingData = BuildingConfig:GetBuildingData(buildingType, buildingLevel)
	return buildingData
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

function ResourceController:RegisterclickDetector(collectorType: string, model: Model)
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
end

function ResourceController:OnClickCollector(data)
	EventBus:Emit(Events.C2S_PLAYER_CLICK_COLLECTOR, { CollectorType = data.CollectorType })
	self:_UiCollectorIsActive(data.CollectorType, false)
	Async.doAfter(CONFIG.DISAPPEAR_DELAY, function()
		self:_UiCollectorIsActive(data.CollectorType, true)
	end)
end

function ResourceController:RegisterColector(BuildingId, BuildingEnum, BuildingLevel, Endtime, LastCollectedTime)
	if BuildingEnum == 9 then
		self._Collectors["ElixirCollector"][BuildingId] = {
			Timestamp = LastCollectedTime,
			ProductionRate = getBuildingData(BuildingEnum, BuildingLevel).ProductionRate,
			BuildingId = BuildingId,
		}
	elseif BuildingEnum == 10 then
		self._Collectors["GoldCollector"][BuildingId] = {
			Timestamp = LastCollectedTime,
			ProductionRate = getBuildingData(BuildingEnum, BuildingLevel).ProductionRate,
			BuildingId = BuildingId,
		}
	elseif BuildingEnum == 8 then
		self._ResourceStorage["Elixirs"] = getBuildingData(BuildingEnum, BuildingLevel).Capacity
	elseif BuildingEnum == 11 then
		self._ResourceStorage["Golds"] = getBuildingData(BuildingEnum, BuildingLevel).Capacity
	elseif BuildingEnum == 1 then
		self._ResourceStorage["Elixirs"] += getBuildingData(BuildingEnum, BuildingLevel).Capacity
		self._ResourceStorage["Golds"] += getBuildingData(BuildingEnum, BuildingLevel).Capacity
	end
end

function ResourceController:GetCollectors()
	return self._Collectors
end

function ResourceController:GetResourceStorage(key: string)
	return self._ResourceStorage[key]
end

function ResourceController:Init() end

function ResourceController:Start() end

return ResourceController.new()
