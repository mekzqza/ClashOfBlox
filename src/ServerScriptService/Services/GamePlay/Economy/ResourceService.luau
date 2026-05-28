--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local ServiceLocator = require(ServerScriptService.Utils.ServiceLocator)
local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)
local guard = IdempotentGuard.new("ResourceService", true)

export type CollectorsType = "GoldCollector" | "ElixirCollector"

export type Collectors = {
	Timestamp: number,
	ProductionRate: number,
	tickRate: number,
	tickrateBonus: number,
}

local ResourceService = {}
ResourceService.__index = ResourceService
function ResourceService.new()
	local self = setmetatable({}, ResourceService)
	self._PlayerDataService = nil
	self._PlayersCollectors = {} :: { [Player]: { [CollectorsType]: Collectors } }
	self._LookBack = {
		["GoldCollector"] = "Golds",
		["ElixirCollector"] = "Elixirs",
	}
	return self
end

function ResourceService:ReisterColector(player: Player)
	self._PlayerDataService:WaitForData(player, 10):andThen(function()
		local playerData = self._PlayerDataService:GetAll(player)
		local collectors = playerData.Collectors
		if not collectors then
			warn("Player ", player.Name, " does not have Collectors data.")
			return
		end

		local now = os.time()
		if collectors.GoldCollector.Timestamp == 0 then
			self._PlayerDataService:Set(player, "Collectors.GoldCollector.Timestamp", now)
			collectors.GoldCollector.Timestamp = now
		end
		if collectors.ElixirCollector.Timestamp == 0 then
			self._PlayerDataService:Set(player, "Collectors.ElixirCollector.Timestamp", now)
			collectors.ElixirCollector.Timestamp = now
		end

		self._PlayersCollectors[player] = {
			["GoldCollector"] = {
				Timestamp = collectors.GoldCollector.Timestamp,
				ProductionRate = collectors.GoldCollector.ProductionRate,
				tickRate = 1,
				tickrateBonus = 0,
			},
			["ElixirCollector"] = {
				Timestamp = collectors.ElixirCollector.Timestamp,
				ProductionRate = collectors.ElixirCollector.ProductionRate,
				tickRate = 1,
				tickrateBonus = 0,
			},
		}
	end)
end

function ResourceService:PlayerClieckCollector(player: Player, collectorType: CollectorsType)
	local traget = `Collectors.{collectorType}`
	local Collector = self._PlayerDataService:Get(player, traget)
	local timeStamp = Collector.Timestamp
	local productionRate = Collector.ProductionRate
	local now = os.time()
	local deltaTime = now - timeStamp
	local amount = math.floor(deltaTime * productionRate)
	self._PlayerDataService:Increment(player, self._LookBack[collectorType], amount)
	self._PlayerDataService:Set(player, `Collectors.{collectorType}.Timestamp`, now)
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
