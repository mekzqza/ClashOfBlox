--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local ServiceLocaltor = require(ServerScriptService.Utils.ServiceLocator)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local GridService
local BuildingTemplate

local BuildingService = {}
BuildingService.__index = BuildingService
function BuildingService.new()
	local self = setmetatable({}, BuildingService)
	self._BuildingStore = {}
	return self
end

-- BoardCast to all client about building changes
-- Update

-- Deleted

function BuildingService:_BroadCastBuilding(player: Player, buildingType: string, position: Vector3)
	EventBus:Emit(Events.S2C_CREATE_BUILDING, {
		Player = player,
		BuildingType = buildingType,
		Position = position,
	})
end

function BuildingService:_PlaceBuilding(player: Player, buildingType: string, position: Vector3)
	local template = BuildingTemplate:FindFirstChild(buildingType, true)
	if not template then
		warn(`[BuildingService] ❌ Invalid buildingType: {buildingType}`)
		return
	end
	self:_BroadCastBuilding(player, buildingType, position)
end

function BuildingService:Init()
	GridService = ServiceLocaltor:Get("GridService")
	if not GridService then
		warn("[BuildingService] ❌ ERROR: GridService not found in ServiceLocator")
		return
	end

	BuildingTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Structure")
	if not BuildingTemplate then
		warn("[BuildingService] Building template folder not found in ReplicatedStorage.Assets")
		return
	end
end

function BuildingService:Start()
	EventBus:On(Events.LOCAL_PLAYER_REQUIRE_PLACE, function(data)
		self:_PlaceBuilding(data.Player, data.BuildingType, data.Position)
	end)
end

return BuildingService
