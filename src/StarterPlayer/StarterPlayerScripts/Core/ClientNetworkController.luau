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
end

local function BuildingSystem()
	EventBus:On(Events.C2S_PLAYER_REQUEST_PLACE, function(data)
		ZapClient.PlayerRequestPalceBulidings.Fire({
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
