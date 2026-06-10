--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local ZapServer = require(ServerScriptService.Services.Core.ZapServer)
local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)

local guard = IdempotentGuard.new("ServerNetWorkHandler")

local ServerNetWorkHandler = {}

local function DataLayer()
	ZapServer.ClientReady.SetCallback(function(player: Player)
		EventBus:Emit(Events.LOCAL_CLIENT_READY, player)
	end)

	EventBus:On(Events.S2C_SEND_BUILDING_SNAP_PLAYER, function(player, Arraybuildings)
		--[=[
		@BUG
		Hard Code Folder Name ,will fix in mutiplae folder now have noly 1
	]=]
		ZapServer.SnapshotBuildings.Fire(player, { FolderName = "IN TEST ", Buildings = Arraybuildings })
	end)

	EventBus:On(Events.S2C_PLAYER_DATA_FIRST_LOAD, function(data)
		ZapServer.LoadSnapshot.Fire(data.Player, {
			Golds = data.Golds,
			Elixirs = data.Elixirs,
			Gems = data.Gems,
			Level = data.Level,
			Experience = data.Experience,
			Buildings = data.Buildings,
			BuildingCount = data.BuildingCount,
			BuilderHutSlot = data.BuilderHutSlot,
		})
	end)

	EventBus:On(Events.S2C_PLAYER_DATA_UPDATE, function(player, data)
		local keyMap = {
			["Golds"] = "Golds",
			["Elixirs"] = "Elixirs",
			["Gems"] = "Gems",
			["Level"] = "Level",
			["Experience"] = "Experience",
			["BuildingCount"] = "BuildingCount",
			["BuilderHutSlot"] = "BuilderHutSlot",
		}

		local zapkey = keyMap[data.Key]
		if not zapkey then
			warn(`[ServerNetWorkHandler] ⚠️ Unrecognized data key: {data.Key}`)
			return
		end

		ZapServer.PlayerDataUpdate.Fire(player, {
			Key = zapkey,
			Value = data.newValue,
		})
	end)

	ZapServer.PlayerClickCollector.SetCallback(function(Player: Player, Value: { CollectorType: string })
		EventBus:Emit(Events.LOCAL_PLAYER_CLICK_COLLECTOR, {
			Player = Player,
			CollectorType = Value.CollectorType,
		})
	end)
end

local function BuildingSytem()
	ZapServer.PlayerRequestPalceBulidings.SetCallback(function(player, data)
		EventBus:Emit(Events.LOCAL_PLAYER_REQUIRE_PLACE, {
			Player = player,
			Gridx = data.Gridx,
			Gridz = data.Gridz,
			BuildingEnum = data.BuildingEnum,
			Position = data.Position,
		})
	end)

	ZapServer.ConstructionComplete.SetCallback(function(player, data)
		EventBus:Emit(Events.LOCAL_BUILDING_CONSTRUCTION_COMPLETE, {
			Player = player,
			BuildingId = data.BuildingId,
		})
	end)

	ZapServer.UpdateBuildingPosition.SetCallback(function(player, data)
		EventBus:Emit(Events.LOCAL_UPDATE_BUILDING_POSITION, {
			Player = player,
			BuildingId = data.BuildingId,
			Gridx = data.Gridx,
			Gridz = data.Gridz,
			Position = data.Position,
		})
	end)

	EventBus:On(Events.S2C_CREATE_BUILDING, function(data)
		ZapServer.PlayersCreateBuilding.FireExcept(data.Player, {
			BuildingTypeEnum = data.BuildingEnum,
			Position = data.Position,
		})
	end)

	EventBus:On(Events.S2C_ASSING_ZONE_OWNER, function(data)
		ZapServer.AssingZoneOwner.Fire(data.Player, { FolderName = data.FolderName })
	end)
end

function ServerNetWorkHandler:Init()
	if not guard:MarkInitialized() then
		return
	end
end

function ServerNetWorkHandler:Start()
	if not guard:MarkStarted() then
		return
	end

	BuildingSytem()
	DataLayer()
end

return ServerNetWorkHandler
