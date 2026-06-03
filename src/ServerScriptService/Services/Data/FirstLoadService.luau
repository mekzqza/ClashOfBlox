--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServiceLocator = require(ServerScriptService.Utils.ServiceLocator)
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local Promise = require(ReplicatedStorage.Packages.Promise)
local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)
local guard = IdempotentGuard.new("FirstLoadService")

export type Collectors = {
	Timestamp: number,
	ProductionRate: number, -- pull from BuildingConfig
	BuildingId: string,
}

local FirstLoadService = {}
FirstLoadService.__index = FirstLoadService
function FirstLoadService.new()
	local self = setmetatable({}, FirstLoadService)
	self._PlayerDataService = nil
	self._ResourceService = nil
	return self
end

local function MapTOArray(tbl: { [string]: any }): { [number]: any }
	local arr = {}
	for key, value in pairs(tbl) do
		table.insert(arr, {
			BuildingId = key,
			Gridx = value[1],
			Gridz = value[2],
			BuildingEnum = value[3],
			BuildingLevel = value[4],
			EndTime = value[5],
			LastCollectedTime = value[6],
		})
	end
	return arr
end

function FirstLoadService:Init()
	if not guard:MarkInitialized() then
		return
	end
	self._PlayerDataService = ServiceLocator:Get("PlayerDataService")
	self._ResourceService = ServiceLocator:Get("ResourceService")
end

function FirstLoadService:Start()
	if not guard:MarkStarted() then
		return
	end

	-- [[
	-- @Feta Emit first time when player data is loaded
	--]]
	EventBus:On(Events.LOCAL_CLIENT_READY, function(player)
		Promise.all({
			self._PlayerDataService:WaitForData(player, 15),
			self._ResourceService:WaitForReady(player, 15),
		})
			:andThen(function()
				local playerData = self._PlayerDataService:GetAll(player)
				if not playerData then
					warn(`[FirstLoadService] ⏱️ Player data not found for player: {player.Name}`)
					return
				end

				local storage = self._ResourceService:GetPlayerResourceStorage(player) :: { [string]: number }
				local collectors =
					self._ResourceService:GetPlayerCollectors(player) :: { [string]: { [number]: Collectors } }

				local ArrayBuilding = MapTOArray(playerData.PlayerBuildings)
				local playload = {
					Player = player,
					Golds = playerData.Golds or 0,
					Elixirs = playerData.Elixirs or 0,
					Gems = playerData.Gems or 0,
					Level = playerData.Level or 1,
					Experience = playerData.Experience or 0,
					Buildings = ArrayBuilding or {},
					BuildingCount = playerData.BuildingCount or 0,
					-- Storage = storage,
					-- Collectors = collectors,
				}
				EventBus:Emit(Events.S2C_PLAYER_DATA_FIRST_LOAD, playload)
			end)
			:catch(function()
				warn(`[PlayerDataService] ⏱️ Timed out waiting for profile: {player.Name}`)
			end)
	end)
end

return FirstLoadService
