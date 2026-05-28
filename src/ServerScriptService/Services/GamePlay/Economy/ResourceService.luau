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
	self._LookBack = {
		["GoldCollector"] = "Golds",
		["ElixirCollector"] = "Elixirs",
		[8] = "ElixirStorage",
		[9] = "ElixirCollector",
		[10] = "GoldMine",
		[11] = "GoldStorage",
	}
	return self
end

local function GetProductionRate(buildingTypeEnum: number, buildingLevel: number): number
	local buildingType = GameEnum:GetBuildingTypeById(buildingTypeEnum)
	local buildingData = BuildingConfig:GetBuildingData(buildingType, buildingLevel)
	return buildingData.ProductionRate
end

local function Gettimestamp(t: number): number
	local timestamp = t
	if timestamp == 0 then
		timestamp = os.time()
	end
	return timestamp
end

function ResourceService:ReisterColector(player: Player)
	self._PlayerDataService:WaitForData(player, 30):andThen(function()
		self._PlayersCollectors[player] = {
			["ElixirCollector"] = {},
			["GoldCollector"] = {},
		}
		local numE = 0
		local numG = 0

		local playerData = self._PlayerDataService:GetAll(player)
		local playerBuilding = playerData.PlayerBuildings
		for buildingId, buildingData in playerBuilding do
			if buildingData[1] == 9 then
				self._PlayersCollectors[player]["ElixirCollector"][numE] = {
					Timestamp = Gettimestamp(buildingData[4]),
					ProductionRate = GetProductionRate(buildingData[1], buildingData[2]),
					BuildingId = buildingId,
				}
				numE += 1
			elseif buildingData[1] == 10 then
				self._PlayersCollectors[player]["GoldCollector"][numG] = {
					Timestamp = Gettimestamp(buildingData[4]),
					ProductionRate = GetProductionRate(buildingData[1], buildingData[2]),
					BuildingId = buildingId,
				}
				numG += 1
			end
		end
	end)
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
		warn(`{amount}`)

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

	Players.PlayerAdded:Connect(function(player)
		self:ReisterColector(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._PlayersCollectors[player] = nil
	end)

	EventBus:On(Events.LOCAL_PLAYER_CLICK_COLLECTOR, function(data)
		self:PlayerClieckCollector(data.Player, data.CollectorType)
		warn(`Player {data.Player.Name} clicked on {data.CollectorType}`)
	end)
end

return ResourceService
