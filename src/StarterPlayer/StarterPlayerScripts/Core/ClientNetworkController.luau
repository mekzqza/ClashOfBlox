--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameEnum = require(ReplicatedStorage.Shared.GameEnum)
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local ZapClient = require(ReplicatedStorage.Shared.ZapClient)

local ClientNetworkController = {}

local function DataLayer()
	EventBus:On(Events.C2S_CLIENT_READY, function()
		ZapClient.ClientReady.Fire()
	end)

	ZapClient.SnapshotBuildings.SetCallback(function(data)
		local buildingsMap = {}
		for _, entry in data.Buildings do
			buildingsMap[entry.SnapToString] = GameEnum:GetBuildingTypeById(entry.BuildingTypeEnum)
		end
		EventBus:Emit(Events.LOCAL_PLAYER_DATA_UPDATE, {
			--[[
			@Bug Hard Code Key Name
			--]]
			Key = "Buildings",
			Value = buildingsMap,
		})
	end)

	ZapClient.LoadSnapshot.SetCallback(function(data)
		local buildingsMap = {}
		for _, entry in data.Buildings do
			buildingsMap[entry.SnapToString] = GameEnum:GetBuildingTypeById(entry.BuildingTypeEnum)
		end

		local playload = {
			Coins = data.Coins,
			Elixirs = data.Elixirs,
			Gems = data.Gems,
			Level = data.Level,
			Experience = data.Experience,
			Buildings = buildingsMap,
		}
		EventBus:Emit(Events.LOCAL_PLAYER_DATA_FIRST_LOAD, playload)
	end)

	ZapClient.PlayerDataUpdate.On(function(data)
		EventBus:Emit(Events.LOCAL_PLAYER_DATA_UPDATE, {
			Key = data.Key,
			Value = data.Value,
		})
		warn(`[ClientNetworkController] PlayerDataUpdate: {data.Key} = {data.Value}`)
	end)
end

local function BuildingSystem()
	EventBus:On(Events.C2S_PLAYER_REQUEST_PLACE, function(data)
		ZapClient.PlayerRequestPalceBulidings.Fire({
			SnapToString = data.SnapToString,
			BuildingTypeEnum = GameEnum:GetBuildingTypeIdByName(data.BuildingType),
			Position = data.Position,
		})
	end)

	ZapClient.PlayersCreateBuilding.On(function(data)
		EventBus:Emit(Events.LOCAL_CREATE_BUILDING, {
			BuildingType = GameEnum:GetBuildingTypeById(data.BuildingTypeEnum),
			Position = data.Position,
		})
	end)

	ZapClient.AssingZoneOwner.SetCallback(function(Value: { FolderName: string })
		EventBus:Emit(Events.LOCAL_ASSING_ZONE_OWNER, { FolderName = Value.FolderName })
	end)
end

function ClientNetworkController:Init() end

function ClientNetworkController:Start()
	BuildingSystem()
	DataLayer()
end

return ClientNetworkController
