--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceLocator = require(ServerScriptService.Utils.ServiceLocator)
local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)

local guard = IdempotentGuard.new("SnapShotService", true)

local SnapShotService = {}
SnapShotService.__index = SnapShotService
function SnapShotService.new()
	local self = setmetatable({}, SnapShotService)
	self.PlayerDataService = nil
	return self
end

local function MapTOArray(tbl: { [string]: any }): { [number]: any }
	local arr = {}
	for key, value in pairs(tbl) do
		table.insert(arr, { key, value })
	end
	return arr
end

function SnapShotService:SendSnapShot(player: Player)
	local PlayerData = self.PlayerDataService:GetAll(player)
	if not PlayerData then
		warn(`[SnapShotService] No player data found for player {player.Name} (ID: {player.UserId})`)
		return
	end
	local playLoad = {}

	playLoad.PlayerBuildings = MapTOArray(PlayerData.PlayerBuildings)
	playLoad.Coins = PlayerData.Coins
end

function SnapShotService:Init()
	if not guard:MarkInitialized() then
		warn("[SnapShotService] Init called more than once. Ignoring subsequent calls.")
		return
	end

	self.PlayerDataService = ServiceLocator:Get("PlayerDataService")
	if not self.PlayerDataService then
		warn("[SnapShotService] Failed to retrieve PlayerDataService from ServiceLocator")
		return
	end
end

function SnapShotService:Start()
	if not guard:MarkStarted() then
		warn("[SnapShotService] Start called more than once. Ignoring subsequent calls.")
		return
	end
	-- EventBus:On(Events.LOCAL_CLIENT_READY, function()
	-- 	-- ส่ง snapShotให้ไปสร้าง Building
	-- end)
end
return SnapShotService
