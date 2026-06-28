-- !strict
-- [[
--  finding target player to raid and send the snapshot of the target player to the attacker
-- ]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)
local guard = IdempotentGuard.new("RaidService")
local ServiceLocator = require(ServerScriptService.Utils.ServiceLocator)

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

local RaidService = {}
RaidService.__index = RaidService
function RaidService.new()
	local self = setmetatable({}, RaidService)

	self._PlayerDataService = nil
	return self
end

function RaidService:FoundTarget(player: Player)
	self._PlayerDataService:WaitForData(player):andThen(function()
		local playerdata = self._PlayerDataService:GetAll(player)

		local buildings = MapTOArray(playerdata.PlayerBuildings)
		local mapSkin = playerdata.MapSkin

		-- Test By Send own player data to self
		-- send the snapshot of the target player to the attacker
		EventBus:Emit(Events.S2C_FOUND_RAID_TARGET, {
			Player = player,
			Buildings = buildings,
			MapSkin = mapSkin,
		})
	end)
end

function RaidService:Init()
	if not guard:MarkInitialized() then
		return
	end

	self._PlayerDataService = ServiceLocator:Get("PlayerDataService")
end

function RaidService:Start()
	if not guard:MarkStarted() then
		return
	end

	-- finding target player for raid
	-- [[
	-- @TODO ตาหมายการหา player ที่สามารถโจมตีได้ โดยอาจจะใช้ระบบ matchmaking หรือ random selection ตอนนี้ Test ใช้ ของplayerคนนั้นดเอง
	-- ]]
	EventBus:On(Events.LOCAL_REQUEST_FINDING_RAID, function(Attacker: Player)
		self:FoundTarget(Attacker)
	end)
end

return RaidService
