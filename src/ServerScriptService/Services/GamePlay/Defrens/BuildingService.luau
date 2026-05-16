--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local ServiceLocaltor = require(ServerScriptService.Utils.ServiceLocator)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)

local BuildingService = {}
BuildingService.__index = BuildingService
function BuildingService.new()
	local self = setmetatable({}, BuildingService)
	self._BuildingTemplate = nil
	self._GridService = nil
	self.PlayerDataService = nil
	return self
end

-- BoardCast to all client about building changes
-- Update
-- Deleted

local function MapTOArray(tbl: { [string]: any }): { [number]: any }
	local arr = {}
	for key, value in pairs(tbl) do
		table.insert(arr, {
			SnapToString = key,
			BuildingTypeEnum = value[1], -- value = { buildingTypeEnum }
		})
	end
	return arr
end

function BuildingService:_BroadCastBuilding(player: Player, buildingType: string, position: Vector3)
	EventBus:Emit(Events.S2C_CREATE_BUILDING, {
		Player = player,
		BuildingType = buildingType,
		Position = position,
	})
end

function BuildingService:_PlaceBuilding(
	player: Player,
	snapTostring: string,
	buildingTypeEnum: number,
	position: Vector3
)
	local buildingType = GameEnum:GetBuildingTypeById(buildingTypeEnum)
	local template = self._BuildingTemplate:FindFirstChild(buildingType, true)
	if not template then
		warn(`[BuildingService] ❌ Invalid buildingType: {buildingType}`)
		return
	end

	self:_BroadCastBuilding(player, buildingType, position)

	self.PlayerDataService:Set(player, `PlayerBuildings.{snapTostring}`, { buildingTypeEnum })
end

function BuildingService:SendSnapshotBuildings(player: Player)
	local loaded = self.PlayerDataService:WaitForData(player, 10)
	if not loaded then
		warn(`[BuildingService] Timeout waiting for data: {player.Name}`)
		return
	end

	local PlayerData = self.PlayerDataService:GetAll(player)
	if not PlayerData then
		warn(`[BuildingService] No player data found for player {player.Name} (ID: {player.UserId})`)
		return
	end

	local ArrayBuilding = MapTOArray(PlayerData.PlayerBuildings)
	EventBus:Emit(Events.S2C_SEND_BUILDING_SNAP_PLAYER, player, ArrayBuilding)
end

function BuildingService:Init()
	self._GridService = ServiceLocaltor:Get("GridService")
	if not self._GridService then
		warn("[BuildingService] ❌ ERROR: GridService not found in ServiceLocator")
		return
	end

	self.PlayerDataService = ServiceLocaltor:Get("PlayerDataService")
	if not self.PlayerDataService then
		warn("[BuildingService] ❌ ERROR: PlayerDataService not found in ServiceLocator")
		return
	end

	self._BuildingTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Structure")
	if not self._BuildingTemplate then
		warn("[BuildingService] Building template folder not found in ReplicatedStorage.Assets")
		return
	end
end

function BuildingService:Start()
	EventBus:On(Events.LOCAL_PLAYER_REQUIRE_PLACE, function(data)
		self:_PlaceBuilding(data.Player, data.SnapToString, data.BuildingTypeEnum, data.Position)
	end)

	EventBus:On(Events.LOCAL_CLIENT_READY, function(player)
		self:SendSnapshotBuildings(player)
	end)
end

return BuildingService
