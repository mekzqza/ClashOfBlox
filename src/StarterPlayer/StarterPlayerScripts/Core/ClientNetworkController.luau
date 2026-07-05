--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameEnum = require(ReplicatedStorage.Shared.GameEnum)
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local ZapClient = require(ReplicatedStorage.Shared.ZapClient)

local ClientNetworkController = {}

local function ArrayTOMap(arr: { any }): { [string]: { any } }
	local Map = {}
	for _, entry in arr do
		Map[entry.BuildingId] = {
			entry.Gridx,
			entry.Gridz,
			entry.BuildingEnum,
			entry.BuildingLevel,
			entry.EndTime,
			entry.LastCollectedTime,
		} :: { any }
	end
	return Map
end

local function DataLayer()
	EventBus:On(Events.C2S_CLIENT_READY, function()
		ZapClient.ClientReady.Fire()
	end)

	EventBus:On(Events.C2S_PLAYER_CLICK_COLLECTOR, function(data)
		ZapClient.PlayerClickCollector.Fire({
			CollectorType = data.CollectorType,
		})
	end)

	ZapClient.LoadSnapshot.SetCallback(function(data)
		local buildingsMap = ArrayTOMap(data.Buildings)

		local playload = {
			Crystals = data.Crystals,
			Aethers = data.Aethers,
			Gems = data.Gems,
			Level = data.Level,
			Experience = data.Experience,
			Buildings = buildingsMap,
			BuildingCount = data.BuildingCount,
			BuilderHutSlot = data.BuilderHutSlot,
			MapSkin = data.MapSkin,
		}
		EventBus:Emit(Events.LOCAL_PLAYER_DATA_FIRST_LOAD, playload)
	end)

	ZapClient.PlayerDataUpdate.On(function(data)
		EventBus:Emit(Events.LOCAL_PLAYER_DATA_UPDATE, {
			Key = data.Key,
			Value = data.Value,
		})
	end)
end

local function BuildingSystem()
	EventBus:On(Events.C2S_PLAYER_REQUEST_PLACE, function(data)
		ZapClient.PlayerRequestPalceBulidings.Fire({
			Gridx = data.Gridx,
			Gridz = data.Gridz,
			BuildingEnum = data.BuildingEnum,
			Position = data.Position,
		})
	end)

	EventBus:On(Events.C2S_BUILDING_CONSTRUCTION_COMPLETE, function(data)
		ZapClient.ConstructionComplete.Fire({
			BuildingId = data.BuildingId,
		})
	end)

	EventBus:On(Events.C2S_UPDATE_BUILDING_POSITION, function(data)
		ZapClient.UpdateBuildingPosition.Fire({
			BuildingId = data.BuildingId,
			Gridx = data.Gridx,
			Gridz = data.Gridz,
			Position = data.Position,
		})
	end)

	EventBus:On(Events.C2S_REQUEST_FINDING_RAID, function()
		ZapClient.PlayerRquestRaid.Fire()
	end)

	ZapClient.FoundRaid.SetCallback(function(data)
		EventBus:Emit(Events.LOCAL_FOUND_RAID_TARGET, {
			Buildings = ArrayTOMap(data.Buildings),
			MapSkin = data.MapSkin,
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
