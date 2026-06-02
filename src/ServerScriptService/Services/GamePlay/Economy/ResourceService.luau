--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)
local ServiceLocator = require(ServerScriptService.Utils.ServiceLocator)
local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Promise = require(Packages.Promise)
local guard = IdempotentGuard.new("ResourceService", true)

export type CollectorsType = "GoldCollector" | "ElixirCollector"

export type Collectors = {
	BuildingEnum: number,
	BuildingLevel: number,
	EndTime: number,
	Timestamp: number,

	ProductionRate: number, -- pull from BuildingConfig
	BuildingId: string,
	Capacity: number,
}

local ResourceService = {}
ResourceService.__index = ResourceService
function ResourceService.new()
	local self = setmetatable({}, ResourceService)
	self._PlayerDataService = nil
	self._PlayersCollectors = {} :: { [Player]: { [CollectorsType]: { [string]: Collectors } } }
	self._PlayerResourceStorage = {} :: { [Player]: { [string]: number } }
	self._registeredPlayers = {} :: { [number]: boolean }
	self._registrationCallbacks = {} :: { [number]: { (boolean) -> () } }
	self._LookBack = {
		["GoldCollector"] = "Golds",
		["ElixirCollector"] = "Elixirs",
	}
	self._LokbackV2 = {
		["GoldCollector"] = "GoldStorage",
		["ElixirCollector"] = "ElixirStorage",
	}
	return self
end

function ResourceService:_collctorTimeremaining(
	player: Player,
	collectorsType: CollectorsType,
	buildingId: string,
	currentValue: number
): { timeRemain: number, amount: number }
	local collectors = self._PlayersCollectors[player][collectorsType][buildingId]
	local storageKey = self._LokbackV2[collectorsType]
	local storageSpace = math.max(self._PlayerResourceStorage[player][storageKey] - currentValue, 0)

	local accumulated =
		math.floor(math.min((os.time() - collectors.Timestamp) * collectors.ProductionRate, collectors.Capacity))
	local transferred = math.min(accumulated, storageSpace)
	local remaining = accumulated - transferred
	return { timeRemain = remaining, amount = transferred }
end

function ResourceService:WaitForReady(player: Player, timeout: number?): any
	if self._registeredPlayers[player.UserId] then
		return Promise.resolve(true)
	end

	local userId = player.UserId
	if not self._registrationCallbacks[userId] then
		self._registrationCallbacks[userId] = {}
	end

	return Promise.new(function(resolve)
		table.insert(self._registrationCallbacks[userId], resolve)
	end):timeout(timeout or 15)
end

function ResourceService:ReGisterColector(player, buildingId, buildingEnum, buildingLevel, endtime, LastCollectedTime)
	if endtime ~= 0 then
		warn(
			`[ResourceService] EndTime is not 0 Mean building is Constructing or Upgrade for player {player.Name} and building {buildingId} with endTime {endtime}`
		)
		return
	end

	if not self._PlayersCollectors[player] then
		self._PlayersCollectors[player] = { ["ElixirCollector"] = {}, ["GoldCollector"] = {} }
		self._PlayerResourceStorage[player] = { ["ElixirStorage"] = 0, ["GoldStorage"] = 0 }
	end

	local buildingData = BuildingConfig:GetBuildingDataByEnum(buildingEnum, buildingLevel)
	if buildingEnum == 9 then
		self._PlayersCollectors[player]["ElixirCollector"][buildingId] = {
			Timestamp = if LastCollectedTime == 0 then os.time() else LastCollectedTime,
			ProductionRate = buildingData.ProductionRate,
			Capacity = buildingData.Capacity,

			BuildingId = buildingId,
			BuildingEnum = buildingEnum,
			BuildingLevel = buildingLevel,
			EndTime = endtime,
		}
	elseif buildingEnum == 10 then
		self._PlayersCollectors[player]["GoldCollector"][buildingId] = {
			Timestamp = if LastCollectedTime == 0 then os.time() else LastCollectedTime,
			ProductionRate = buildingData.ProductionRate,
			Capacity = buildingData.Capacity,

			BuildingId = buildingId,
			BuildingEnum = buildingEnum,
			BuildingLevel = buildingLevel,
			EndTime = endtime,
		}
	elseif buildingEnum == 8 then
		self._PlayerResourceStorage[player]["ElixirStorage"] += buildingData.Capacity
	elseif buildingEnum == 11 then
		self._PlayerResourceStorage[player]["GoldStorage"] += buildingData.Capacity
	elseif buildingEnum == 1 then
		self._PlayerResourceStorage[player]["ElixirStorage"] += buildingData.Capacity
		self._PlayerResourceStorage[player]["GoldStorage"] += buildingData.Capacity
	end
end

function ResourceService:MarkRegistrationComplete(player: Player)
	self._registeredPlayers[player.UserId] = true
	local callbacks = self._registrationCallbacks[player.UserId]
	if callbacks then
		self._registrationCallbacks[player.UserId] = nil
		for _, cb in callbacks do
			task.spawn(cb, true)
		end
	end
end

function ResourceService:PlayerClieckCollector(player: Player, collectorType: CollectorsType)
	if not self._PlayersCollectors[player] then
		return
	end

	local collectors = self._PlayersCollectors[player][collectorType]
	if not collectors then
		return
	end

	local totalResource = 0
	local tragetVale = self._PlayerDataService:Get(player, self._LookBack[collectorType]) or 0

	for _, entry in collectors do
		local data = self:_collctorTimeremaining(player, collectorType, entry.BuildingId, tragetVale)

		local newTimestamp = os.time() - math.floor(data.timeRemain / entry.ProductionRate)
		entry.Timestamp = newTimestamp
		self._PlayerDataService:Set(player, `PlayerBuildings.{entry.BuildingId}`, {
			entry.BuildingEnum,
			entry.BuildingLevel,
			entry.EndTime or 0,
			newTimestamp,
		}, false)
		tragetVale += data.amount
		totalResource += data.amount
	end
	self._PlayerDataService:Increment(player, self._LookBack[collectorType], totalResource)
	warn(`[ResourceService] {player.Name} collected {totalResource} from {collectorType}`)
end

function ResourceService:GetPlayerCollectors(player: Player): { [CollectorsType]: { [number]: Collectors } }?
	return self._PlayersCollectors[player]
end

function ResourceService:GetPlayerResourceStorage(player: Player): { [string]: number }?
	return self._PlayerResourceStorage[player]
end

function ResourceService:Init()
	if not guard:MarkInitialized() then
		return
	end
	self._PlayerDataService = ServiceLocator:Get("PlayerDataService")
end

function ResourceService:Start()
	if not guard:MarkStarted() then
		return
	end

	Players.PlayerRemoving:Connect(function(player)
		self._PlayersCollectors[player] = nil
		self._PlayerResourceStorage[player] = nil
	end)

	EventBus:On(Events.LOCAL_PLAYER_CLICK_COLLECTOR, function(data)
		self:PlayerClieckCollector(data.Player, data.CollectorType)
	end)
end

return ResourceService
