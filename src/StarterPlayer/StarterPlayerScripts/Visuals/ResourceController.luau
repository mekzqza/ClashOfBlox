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
	COLECCTOR_COOL_DOWN = 10,
}

local ResourceController = {}
ResourceController.__index = ResourceController
function ResourceController.new()
	local self = setmetatable({}, ResourceController)
	self._Collectors = {
		["AetherCollector"] = {},
		["CrystalCollector"] = {},
	} :: { [string]: { [string]: Collectors } }
	self._ResourceStorage = {
		["Crystals"] = {},
		["Aethers"] = {},
	} :: { [string]: { [string]: number } }

	self._TotalStorage = {
		["Crystals"] = 0,
		["Aethers"] = 0,
	} :: { [string]: number }

	self._CollectorModels = {
		["AetherCollector"] = {},
		["CrystalCollector"] = {},
	} :: { [string]: { Model } }

	self._lastClickTime = nil :: number?
	return self
end

function ResourceController:_uiCollectorIsActive(collectorType: string, visible: boolean)
	local models = self._CollectorModels[collectorType]
	if not models then
		warn("[ResourceController] No models found for collector type: " .. collectorType)
		return
	end

	if #models == 0 then
		warn("[ResourceController] No models registered for collector type: " .. collectorType)
		return
	end

	for _, model in models do
		local billboard = model:FindFirstChild("BillboardGui", true) :: BillboardGui?
		if billboard then
			billboard.Enabled = visible
		end
	end
end

function ResourceController:_updateIcon(collectorType: string)
	self:_uiCollectorIsActive(collectorType, false)
	Async.doAfter(CONFIG.DISAPPEAR_DELAY, function()
		warn("[ResourceController] Hiding collector icon for " .. collectorType)
		self:_uiCollectorIsActive(collectorType, true)
	end)
end

function ResourceController:_OnClickCollecResource(collectorType: string)
	local now = os.time()
	if self._lastClickTime and (now - self._lastClickTime) < CONFIG.COLECCTOR_COOL_DOWN then
		return
	end

	EventBus:Emit(Events.C2S_PLAYER_CLICK_COLLECTOR, { CollectorType = collectorType }) -- ส่งข้อมูล CollectorType ไปยัง Server
	self:_updateIcon(collectorType)
	self._lastClickTime = now
end

function ResourceController:_disPlayerCollectorInfo(CollectorType, buildingId: string)
	--[[
	    เชื่อต่อกับ MoreInfoFrame เพื่อแสดงข้อมูลของ Collector ที่ถูกคลิก
	]]
end

function ResourceController:RegisterColector(
	buildingId: string,
	buildingEnum: number,
	buildingLevel: number,
	model: Model
)
	local buildingData = BuildingConfig:GetBuildingDataByEnum(buildingEnum, buildingLevel)
	if not buildingData then
		warn(
			`[ResourceController] No building data found for BuildingEnum: {buildingEnum}, BuildingLevel: {buildingLevel}`
		)
		return
	end

	if buildingEnum == 9 then
		self._Collectors["AetherCollector"][buildingId] = {
			ProductionRate = buildingData.ProductionRate,
			Capacity = buildingData.Capacity,
		}
		table.insert(self._CollectorModels["AetherCollector"], model)
	elseif buildingEnum == 10 then
		self._Collectors["CrystalCollector"][buildingId] = {
			ProductionRate = buildingData.ProductionRate,
			Capacity = buildingData.Capacity,
		}
		table.insert(self._CollectorModels["CrystalCollector"], model)
	elseif buildingEnum == 8 then
		self._ResourceStorage["Aethers"][buildingId] = {
			Capacity = buildingData.Capacity,
		}
		self._TotalStorage["Aethers"] += buildingData.Capacity
	elseif buildingEnum == 11 then
		self._ResourceStorage["Crystals"][buildingId] = {
			Capacity = buildingData.Capacity,
		}
		self._TotalStorage["Crystals"] += buildingData.Capacity
	elseif buildingEnum == 1 then
		self._ResourceStorage["Aethers"][buildingId] = {
			Capacity = buildingData.Capacity,
		}
		self._ResourceStorage["Crystals"][buildingId] = {
			Capacity = buildingData.Capacity,
		}
		self._TotalStorage["Aethers"] += buildingData.Capacity
		self._TotalStorage["Crystals"] += buildingData.Capacity
	end
end

function ResourceController:GetCollectors()
	return self._Collectors
end

function ResourceController:GetResourceStorage(key: string)
	return self._TotalStorage[key]
end

function ResourceController:Init() end

function ResourceController:Start()
	EventBus:On(Events.LOCAL_PLAYER_CLICK_BUILDING, function(buildId)
		if self._Collectors["AetherCollector"][buildId] then
			self:_OnClickCollecResource("AetherCollector")
		elseif self._Collectors["CrystalCollector"][buildId] then
			self:_OnClickCollecResource("CrystalCollector")
		end
	end)
end

return ResourceController.new()
