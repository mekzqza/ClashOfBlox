--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local ZapServer = require(ServerScriptService.Services.Core.ZapServer)
local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)

local guard = IdempotentGuard.new("ServerNetWorkHandler")

local ServerNetWorkHandler = {}

local function BuildingSytem()
	ZapServer.PlayerRequestPalceBulidings.SetCallback(function(player, data)
		EventBus:Emit(Events.LOCAL_PLAYER_REQUIRE_PLACE, {
			Player = player,
			BuildingType = GameEnum:GetBuildingTypeById(data.BuildingTypeEnum),
			Position = data.Position,
		})
	end)

	EventBus:On(Events.S2C_CREATE_BUILDING, function(data)
		ZapServer.PlayersCreateBuilding.FireExcept(data.Player, {
			BuildingTypeEnum = GameEnum:GetBuildingTypeIdByName(data.BuildingType),
			Position = data.Position,
		})
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
end

return ServerNetWorkHandler
