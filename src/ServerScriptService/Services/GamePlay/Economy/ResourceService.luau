--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)
local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)
local ServiceLocator = require(ServerScriptService.Utils.ServiceLocator)
local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Promise = require(Packages.Promise)
local guard = IdempotentGuard.new("ResourceService", true)

export type CollectorsType = "GoldCollector" | "ElixirCollector"

export type Collectors = {
	Timestamp: number,
	ProductionRate: number, -- pull from BuildingConfig
	BuildingId: string,
}

local ResourceService = {}
ResourceService.__index = ResourceService
function ResourceService.new()
	local self = setmetatable({}, ResourceService)
	self._PlayerDataService = nil
	self._PlayersCollectors = {} :: { [Player]: { [CollectorsType]: { [number]: { Collectors } } } }
	self._PlayerResourceStorage = {} :: { [Player]: { [string]: number } }
	self._registeredPlayers = {} :: { [number]: boolean }
	self._registrationCallbacks = {} :: { [number]: { (boolean) -> () } }
	self._LookBack = {
		["GoldCollector"] = "Golds",
		["ElixirCollector"] = "Elixirs",
		[1] = "TownHall",
		[8] = "ElixirStorage",
		[9] = "ElixirCollector",
		[10] = "GoldMine",
		[11] = "GoldStorage",
	}
	return self
end

local function getBuildingData(buildingTypeEnum: number, buildingLevel: number): any
	local buildingType = GameEnum:GetBuildingTypeById(buildingTypeEnum)
	local buildingData = BuildingConfig:GetBuildingData(buildingType, buildingLevel)
	return buildingData
end

local function getTimeStamp(t: number): number
	local timestamp = t
	if timestamp == 0 then
		timestamp = os.time()
	end
	return timestamp
end

function ResourceService:GetPlayerCollectors(player: Player): { [CollectorsType]: { [number]: Collectors } }?
	return self._PlayersCollectors[player]
end

function ResourceService:GetPlayerResourceStorage(player: Player): { [string]: number }?
	return self._PlayerResourceStorage[player]
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

function ResourceService:ReisterColector(player, BuildingId, BuildingEnum, BuildingLevel, Endtime, LastCollectedTime)
	if not self._PlayersCollectors[player] then
		self._PlayersCollectors[player] = { ["ElixirCollector"] = {}, ["GoldCollector"] = {} }
		self._PlayerResourceStorage[player] = { ["ElixirStorage"] = 0, ["GoldStorage"] = 0 }
	end

	if BuildingEnum == 9 then
		table.insert(self._PlayersCollectors[player]["ElixirCollector"], {
			Timestamp = getTimeStamp(LastCollectedTime),
			ProductionRate = getBuildingData(BuildingEnum, BuildingLevel).ProductionRate,
			BuildingId = BuildingId,
		})
	elseif BuildingEnum == 10 then
		table.insert(self._PlayersCollectors[player]["GoldCollector"], {
			Timestamp = getTimeStamp(LastCollectedTime),
			ProductionRate = getBuildingData(BuildingEnum, BuildingLevel).ProductionRate,
			BuildingId = BuildingId,
		})
	elseif BuildingEnum == 8 then
		self._PlayerResourceStorage[player]["ElixirStorage"] = getBuildingData(BuildingEnum, BuildingLevel).Capacity
	elseif BuildingEnum == 11 then
		self._PlayerResourceStorage[player]["GoldStorage"] = getBuildingData(BuildingEnum, BuildingLevel).Capacity
	elseif BuildingEnum == 1 then
		self._PlayerResourceStorage[player]["ElixirStorage"] += getBuildingData(BuildingEnum, BuildingLevel).Capacity
		self._PlayerResourceStorage[player]["GoldStorage"] += getBuildingData(BuildingEnum, BuildingLevel).Capacity
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

	local now = os.time()
	local totalResource = 0

	for _, entry in collectors do
		local bd = self._PlayerDataService:Get(player, `PlayerBuildings.{entry.BuildingId}`)

		local lastCollected = if bd[4] == 0 then now else bd[4]
		local deltaTime = now - lastCollected
		local amount = math.floor(deltaTime * entry.ProductionRate)
		totalResource += amount

		self._PlayerDataService:Set(player, `PlayerBuildings.{entry.BuildingId}`, {
			bd[1],
			bd[2],
			bd[3] or 0,
			now,
		}, false)

		entry.Timestamp = now
	end

	self._PlayerDataService:Increment(player, self._LookBack[collectorType], totalResource)
	warn(`[ResourceService] {player.Name} collected {totalResource} from {collectorType}`)
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
