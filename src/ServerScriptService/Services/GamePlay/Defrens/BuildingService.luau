--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceLocaltor = require(ServerScriptService.Utils.ServiceLocator)
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)

local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)
local guard = IdempotentGuard.new("BuildingService")

local CONFIG = {
	STARTER_LEVEL = 1,
	STARTER_END_TIME = 0, -- 0 หมายถึง กำลังก่อสร้าง
	STARTER_LAST_COLLECTED_TIME = os.time(),
	Category = {
		Army = 1,
		Resources = 2,
		Defense = 3,
		Trap = 4,
	},
}

local BuildingService = {}
BuildingService.__index = BuildingService
function BuildingService.new()
	local self = setmetatable({}, BuildingService)
	self._BuildingTemplate = nil
	self._GridService = nil
	self._PlayerDataService = nil
	self._ResourceService = nil
	self._LookBack = {
		[8] = "ElixirStorage",
		[9] = "ElixirCollector",
		[10] = "GoldMine",
		[11] = "GoldStorage",
	}

	return self
end

-- BoardCast to all client about building changes
-- Update
-- Deleted

-- @ ระบบก่อสร้าง นับถอยหลัง จะฝากclient นับ ส่งไปกับsnapshot ถ้าถึงเวลา จะส่ง event มาให้ server เพื่อเช็คและอัพเดตข้อมูล
-- ในเข้าเกมหลังจาก ก่อสร้างเสร็จ จะเช็คตอน BuildingRegister

local function BuildingTOArray(tbl: { [string]: any }): { [number]: any }
	local arr = {}
	for key, value in pairs(tbl) do
		table.insert(arr, {
			SnapToString = key,
			BuildingTypeEnum = value[1], -- value = { buildingTypeEnum }
			BuildingLevel = value[2],
			EndTime = value[3],
			LastCollectedTime = value[4],
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

	local lastCollectedTime = 0
	if self._LookBack[buildingTypeEnum] ~= nil then
		lastCollectedTime = CONFIG.STARTER_LAST_COLLECTED_TIME
	end

	self._PlayerDataService:Set(
		player,
		`PlayerBuildings.{snapTostring}`,
		{ buildingTypeEnum, CONFIG.STARTER_LEVEL, CONFIG.STARTER_END_TIME, lastCollectedTime }
	)
end

function BuildingService:_UpdateBuilding() end

function BuildingService:SendSnapshotBuildings(player: Player)
	self._PlayerDataService
		:WaitForData(player, 10)
		:andThen(function()
			local PlayerData = self._PlayerDataService:GetAll(player)
			if not PlayerData then
				warn(`[BuildingService] No player data found for player {player.Name} (ID: {player.UserId})`)
				return
			end

			--[=[
		    @BUG
		    ตอนนี้เป็นการส่งให้ Player นั้นๆคนเดี่ยวยังไม่ braodcast ไปยังผู้เล่นอื่นๆ เพื่อใช้ในการrender building
			]=]
			local ArrayBuilding = BuildingTOArray(PlayerData.PlayerBuildings)
			EventBus:Emit(Events.S2C_SEND_BUILDING_SNAP_PLAYER, player, ArrayBuilding)
		end)
		:catch(function()
			warn(`[PlayerDataService] ⏱️ Timed out waiting for profile: {player.Name}`)
		end)
end

function BuildingService:Init()
	if not guard:MarkInitialized() then
		return
	end
	self._GridService = ServiceLocaltor:Get("GridService")
	if not self._GridService then
		warn("[BuildingService] ❌ ERROR: GridService not found in ServiceLocator")
		return
	end

	self._PlayerDataService = ServiceLocaltor:Get("PlayerDataService")
	if not self._PlayerDataService then
		warn("[BuildingService] ❌ ERROR: PlayerDataService not found in ServiceLocator")
		return
	end

	self._BuildingTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Structure")
	if not self._BuildingTemplate then
		warn("[BuildingService] Building template folder not found in ReplicatedStorage.Assets")
		return
	end

	self._ResourceService = ServiceLocaltor:Get("ResourceService")
	if not self._ResourceService then
		warn("[BuildingService] ❌ ERROR: ResourceService not found in ServiceLocator")
		return
	end
end

function BuildingService:Start()
	if not guard:MarkStarted() then
		return
	end
	EventBus:On(Events.LOCAL_PLAYER_REQUIRE_PLACE, function(data)
		--[=[
		    @Bug
		    ตอนนี้ยังไม่มี การเช็ค cell ว่าถูกใช้ไปไหม ทำให้สามารถว่า วางทับกันได้ แต่ในอนาคตจะมีการเช็ค cell ก่อนที่จะวาง
		--]=]
		self:_PlaceBuilding(data.Player, data.SnapToString, data.BuildingTypeEnum, data.Position)
	end)

	--[[
	@ BUG use ohter event to trigger send snapshot building to player when player join the game because if use LOCAL_CLIENT_READY it will cause problem when player teleport to other place and back to home it will resend snapshot building again
	]]
	-- EventBus:On(Events.LOCAL_CLIENT_READY, function(player)
	-- self:SendSnapshotBuildings(player)
	-- end)
	Players.PlayerAdded:Connect(function(player)
		self._PlayerDataService
			:WaitForData(player, 30)
			:andThen(function()
				local PlayerData = self._PlayerDataService:GetAll(player)
				local playerBuildings = PlayerData.PlayerBuildings
				for snapToString, buildingData in pairs(playerBuildings) do
					self._ResourceService:ReisterColector(
						player,
						snapToString,
						buildingData[1],
						buildingData[2],
						buildingData[3],
						buildingData[4]
					)
				end
				self._ResourceService:MarkRegistrationComplete(player)
			end)
			:catch(function()
				warn(`[PlayerDataService] ⏱️ Timed out waiting for profile: {player.Name}`)
			end)
	end)
end

return BuildingService
