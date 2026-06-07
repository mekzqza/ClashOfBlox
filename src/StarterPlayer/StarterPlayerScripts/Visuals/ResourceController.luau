--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)
local Async = require(ReplicatedStorage.Utils.Async)

export type Collectors = {
	ProductionRate: number,
	Capacity: number,
}

local CONFIG = {
	ACTION_PART_NAME = "ActionPart",
	DISAPPEAR_DELAY = 5,
}

local ResourceController = {}
ResourceController.__index = ResourceController
function ResourceController.new()
	local self = setmetatable({}, ResourceController)
	self._Collectors = {
		["ElixirCollector"] = {},
		["GoldCollector"] = {},
	} :: { [string]: { [string]: Collectors } }
	self._ResourceStorage = {
		["Golds"] = {},
		["Elixirs"] = {},
	} :: { [string]: { [string]: number } }

	self._TotalStorage = {
		["Golds"] = 0,
		["Elixirs"] = 0,
	} :: { [string]: number }

	-- เก็บ Building Id เข้ากับ _Collectors,_ResourceStorage

	self._CollectorModels = {} :: { [string]: { Model } }
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
			self:_OnClickCollecResource({ CollectorType = collectorType })
		end),
		CollectorType = collectorType,
	}

	if not self._CollectorModels[collectorType] then
		self._CollectorModels[collectorType] = {}
	end
	table.insert(self._CollectorModels[collectorType], model)
end

function ResourceController:_OnClickCollecResource(data)
	EventBus:Emit(Events.C2S_PLAYER_CLICK_COLLECTOR, { CollectorType = data.CollectorType })
	self:_UiCollectorIsActive(data.CollectorType, false)
	Async.doAfter(CONFIG.DISAPPEAR_DELAY, function()
		self:_UiCollectorIsActive(data.CollectorType, true)
	end)
end

function ResourceController:_onPlayerClickCollector(CollectorType, buildingId: string)
	--[[
	    เชื่อต่อกับ MoreInfoFrame เพื่อแสดงข้อมูลของ Collector ที่ถูกคลิก
	]]
end

function ResourceController:RegisterColector(buildingId: string, buildingEnum: number, buildingLevel: number)
	local buildingData = BuildingConfig:GetBuildingDataByEnum(buildingEnum, buildingLevel)
	if not buildingData then
		warn(
			`[ResourceController] No building data found for BuildingEnum: {buildingEnum}, BuildingLevel: {buildingLevel}`
		)
		return
	end
	if buildingEnum == 9 then
		self._Collectors["ElixirCollector"][buildingId] = {
			ProductionRate = buildingData.ProductionRate,
			Capacity = buildingData.Capacity,
		}
	elseif buildingEnum == 10 then
		self._Collectors["GoldCollector"][buildingId] = {
			ProductionRate = buildingData.ProductionRate,
			Capacity = buildingData.Capacity,
		}
	elseif buildingEnum == 8 then
		self._ResourceStorage["Elixirs"][buildingId] = {
			Capacity = buildingData.Capacity,
		}
		self._TotalStorage["Elixirs"] += buildingData.Capacity
	elseif buildingEnum == 11 then
		self._ResourceStorage["Golds"][buildingId] = {
			Capacity = buildingData.Capacity,
		}
		self._TotalStorage["Golds"] += buildingData.Capacity
	elseif buildingEnum == 1 then
		self._ResourceStorage["Elixirs"][buildingId] = {
			Capacity = buildingData.Capacity,
		}
		self._ResourceStorage["Golds"][buildingId] = {
			Capacity = buildingData.Capacity,
		}
		self._TotalStorage["Elixirs"] += buildingData.Capacity
		self._TotalStorage["Golds"] += buildingData.Capacity
	end
end

function ResourceController:GetCollectors()
	return self._Collectors
end

function ResourceController:GetResourceStorage(key: string)
	return self._TotalStorage[key]
end

function ResourceController:Init() end

function ResourceController:Start() end

return ResourceController.new()
