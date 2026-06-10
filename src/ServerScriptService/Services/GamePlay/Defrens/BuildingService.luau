--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceLocaltor = require(ServerScriptService.Utils.ServiceLocator)
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)

local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)
local guard = IdempotentGuard.new("BuildingService")

--[[
    @ SingNature
    - Register Building
    - Palce Building
    - Upgrade Building
    - Send Snapshot Building to Other client
 ]]

export type BuildingCache = {
	Gridx: number,
	Gridz: number,
	BuildingEnum: number,
	BuildingLevel: number,
	EndTime: number,
	LastCollectedTime: number,
}

local CONFIG = {
	STARTER_LEVEL = 0,
	NEXT_LEVEL = 1,
	STARTER_END_TIME = 0, -- 0 หมายถึง กำลังก่อสร้าง
	BUILDING_DONE = 0,
	-- เผื่อ skew นาฬิกา client/server + latency (client เป็นคนนับถอยหลังแล้วยิง event มาบอก)
	COMPLETE_GRACE = 2,
	TIME_OUT = 30,
	KEYSTORE = {
		["Gridx"] = 1,
		["Gridz"] = 2,
		["BuildingEnum"] = 3,
		["BuildingLevel"] = 4,
		["EndTime"] = 5,
		["LastCollectedTime"] = 6,
	},
	NEXT_BUILDING_ID = "n",
	NEXT_BUILDING_ID_NUMBER = 1,
}

local BuildingService = {}
BuildingService.__index = BuildingService
function BuildingService.new()
	local self = setmetatable({}, BuildingService)
	self._BuildingCache = {} :: { [Player]: { [string]: BuildingCache } }
	self._PlayerBuilderSlot = {} :: { [Player]: number }
	self._LookBack = {
		[8] = "ElixirStorage",
		[9] = "ElixirCollector",
		[10] = "GoldMine",
		[11] = "GoldStorage",
	}

	self._BuildingTemplate = nil
	self._GridService = nil
	self._PlayerDataService = nil
	self._ResourceService = nil

	return self
end

-- BoardCast to all client about building changes

-- Update
function BuildingService:_buildingChanges(player: Player, buildingId: string, gridx: number, gridz: number)
	--Veryfing buildingId and player
	if not self._BuildingCache[player] then
		warn(`[BuildingService] No building cache found for player {player.Name}`)
		return
	end

	local buildingcache = self._BuildingCache[player][buildingId]
	if not buildingcache then
		warn(`[BuildingService] No building found for player {player.Name} with buildingId {buildingId}`)
		return
	end

	self._PlayerDataService:Set(player, `PlayerBuildings.{buildingId}`, {
		gridx,
		gridz,
		buildingcache.BuildingEnum,
		buildingcache.BuildingLevel,
		buildingcache.EndTime,
		buildingcache.LastCollectedTime,
	}, false)
end

-- Deleted

-- @ ระบบก่อสร้าง นับถอยหลัง จะฝากclient นับ ส่งไปกับsnapshot ถ้าถึงเวลา จะส่ง event มาให้ server เพื่อเช็คและอัพเดตข้อมูล
-- ในเข้าเกมหลังจาก ก่อสร้างเสร็จ จะเช็คตอน BuildingRegister

function BuildingService:_IsbuilgIsComplete(player: Player, buildingId: string): boolean
	local buildingData = self._BuildingCache[player] and self._BuildingCache[player][buildingId]
	if not buildingData then
		warn(`[BuildingService] No building found for player {player.Name} with buildingId {buildingId}`)
		return false
	end

	local buildingendtime = buildingData.EndTime

	-- EndTime == 0 แปลว่าก่อสร้างเสร็จไปแล้ว กันยิง event ซ้ำมาอัพเลเวลฟรี
	if buildingendtime == CONFIG.BUILDING_DONE then
		warn(`[BuildingService] Building {buildingId} for {player.Name} is already completed`)
		return false
	end

	-- ยังก่อสร้างไม่เสร็จจริง (หัก grace เผื่อ skew/latency) — อาจเป็นการยิงก่อนเวลา
	if os.time() < buildingendtime - CONFIG.COMPLETE_GRACE then
		warn(`[BuildingService] Building {buildingId} for {player.Name} not finished yet`)
		return false
	end

	return true
end

function BuildingService:_OnbuilingDone(player: Player, buildingId: string)
	local buildingdata = self._BuildingCache[player] and self._BuildingCache[player][buildingId]
	if not buildingdata then
		warn(`[BuildingService] No building found for player {player.Name} with buildingId {buildingId}`)
		return
	end

	local level = buildingdata.BuildingLevel + CONFIG.NEXT_LEVEL

	self._PlayerDataService:Set(player, `PlayerBuildings.{buildingId}`, {
		buildingdata.Gridx,
		buildingdata.Gridz,
		buildingdata.BuildingEnum,
		level,
		CONFIG.BUILDING_DONE,
		buildingdata.LastCollectedTime,
	}, false)

	self._PlayerBuilderSlot[player] = -1

	self._BuildingCache[player][buildingId].EndTime = CONFIG.BUILDING_DONE
	self._BuildingCache[player][buildingId].BuildingLevel = level
	warn(
		`[BuildingService] Building construction complete for player {player.Name} and buildingId {buildingId}, updating player data and cache`
	)

	if self._LookBack[buildingdata.BuildingEnum] ~= nil then
		self._ResourceService:ReGisterColector(
			player,
			buildingId,
			buildingdata.Gridx,
			buildingdata.Gridz,
			buildingdata.BuildingEnum,
			buildingdata.BuildingLevel,
			CONFIG.BUILDING_DONE,
			buildingdata.LastCollectedTime
		)
	end
end

function BuildingService:_RegisterBuildingCache(
	player: Player,
	buildingId: string,
	gridCellx: number,
	gridCellz: number,
	buildingEnum: number,
	buildingLevel: number,
	endtime: number,
	LastCollectedTime: number
)
	if not self._BuildingCache[player] then
		self._BuildingCache[player] = {}
	end

	self._BuildingCache[player][buildingId] = {
		Gridx = gridCellx,
		Gridz = gridCellz,
		BuildingEnum = buildingEnum,
		BuildingLevel = buildingLevel,
		EndTime = endtime,
		LastCollectedTime = LastCollectedTime,
	}
end

function BuildingService:_BroadCastBuilding(player: Player, buildingEnum: number, position: Vector3)
	EventBus:Emit(Events.S2C_CREATE_BUILDING, {
		Player = player,
		BuildingEnum = buildingEnum,
		Position = position,
	})
end

function BuildingService:_PlaceBuilding(
	player: Player,
	gridx: number,
	gridz: number,
	buildingEnum: number,
	position: Vector3
)
	local playerData = self._PlayerDataService:GetAll(player)
	if not playerData then
		warn(`[BuildingService] Player data not found for player: {player.Name}`)
		return
	end

	local builderHutSlot = playerData.BuilderHutSlot
	if self._PlayerBuilderSlot[player] >= builderHutSlot then
		warn(`[BuildingService] Player {player.Name} has no available builder slots to place new building`)
		return
	end

	local buildingData = BuildingConfig:GetBuildingDataByEnum(buildingEnum, CONFIG.STARTER_LEVEL + CONFIG.NEXT_LEVEL)
	if not buildingData then
		warn(
			`[BuildingService] No building data found for BuildingEnum: {buildingEnum}, BuildingLevel: {CONFIG.STARTER_LEVEL}`
		)
		return
	end

	-- ทรัพยาการที่ต้องใช้ในการสร้าง

	-- อาคารที่เพิ่งวางเริ่มที่ 0 เสมอ — ResourceService ตีความ 0 ว่า "เริ่มนับเวลาผลิต ณ ตอนสร้างเสร็จ"
	-- (buildingData เป็น level-data จึงไม่มี CollectorType ให้เช็ก ฟิลด์นั้นอยู่ที่ตัวอาคาร)
	local lastCollectedTime = 0

	local endtime = os.time() + buildingData.UpgradeTime
	local buildingcount = self._PlayerDataService:Get(player, "BuildingCount") :: number
	local nextBuildingId = buildingcount + CONFIG.NEXT_BUILDING_ID_NUMBER
	self._PlayerDataService:Set(
		player,
		`PlayerBuildings.{`{CONFIG.NEXT_BUILDING_ID}{nextBuildingId}`}`,
		{ gridx, gridz, buildingEnum, CONFIG.STARTER_LEVEL, endtime, lastCollectedTime }
	)
	self._PlayerDataService:Increment(player, "BuildingCount", CONFIG.NEXT_BUILDING_ID_NUMBER)

	-- นับว่าเก็บ BuilderHut
	self:_RegisterBuildingCache(
		player,
		CONFIG.NEXT_BUILDING_ID .. nextBuildingId,
		gridx,
		gridz,
		buildingEnum,
		CONFIG.STARTER_LEVEL,
		endtime,
		lastCollectedTime
	)

	self._PlayerBuilderSlot[player] = self._PlayerBuilderSlot[player] + 1

	-- self:_BroadCastBuilding(player, buildingEnum, position)
end

function BuildingService:_UpdateBuilding() end

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

	Players.PlayerAdded:Connect(function(player)
		self._PlayerDataService
			:WaitForData(player, CONFIG.TIME_OUT)
			:andThen(function()
				local PlayerData = self._PlayerDataService:GetAll(player)
				local playerBuildings = PlayerData.PlayerBuildings

				local BuilderHutSlot = 0
				for buildingId, buildingData in pairs(playerBuildings) do
					if buildingData[CONFIG.KEYSTORE["EndTime"]] ~= 0 then
						BuilderHutSlot = BuilderHutSlot + 1
					end

					self:_RegisterBuildingCache(
						player,
						buildingId,
						buildingData[CONFIG.KEYSTORE["Gridx"]],
						buildingData[CONFIG.KEYSTORE["Gridz"]],
						buildingData[CONFIG.KEYSTORE["BuildingEnum"]],
						buildingData[CONFIG.KEYSTORE["BuildingLevel"]],
						buildingData[CONFIG.KEYSTORE["EndTime"]],
						buildingData[CONFIG.KEYSTORE["LastCollectedTime"]]
					)

					if buildingData[CONFIG.KEYSTORE["BuildingEnum"]] ~= nil then
						self._ResourceService:ReGisterColector(
							player,
							buildingId,
							buildingData[CONFIG.KEYSTORE["Gridx"]],
							buildingData[CONFIG.KEYSTORE["Gridz"]],
							buildingData[CONFIG.KEYSTORE["BuildingEnum"]],
							buildingData[CONFIG.KEYSTORE["BuildingLevel"]],
							buildingData[CONFIG.KEYSTORE["EndTime"]],
							buildingData[CONFIG.KEYSTORE["LastCollectedTime"]]
						)
					end
				end
				self._PlayerBuilderSlot[player] = BuilderHutSlot
				self._ResourceService:MarkRegistrationComplete(player)
			end)
			:catch(function()
				warn(`[PlayerDataService] ⏱️ Timed out waiting for profile: {player.Name}`)
			end)
	end)

	EventBus:On(Events.LOCAL_PLAYER_REQUIRE_PLACE, function(data)
		--[=[
		    @Bug
		    ตอนนี้ยังไม่มี การเช็ค cell ว่าถูกใช้ไปไหม ทำให้สามารถว่า วางทับกันได้ถ้ามีแฮค foce remote แต่ในอนาคตจะมีการเช็ค cell ก่อนที่จะsave
		--]=]
		self:_PlaceBuilding(data.Player, data.Gridx, data.Gridz, data.BuildingEnum, data.Position)
	end)

	EventBus:On(Events.LOCAL_UPDATE_BUILDING_POSITION, function(data)
		warn(
			`[BuildingService] Received request to update building position for player {data.Player.Name}, buildingId {data.BuildingId}, new gridx: {data.Gridx}, new gridz: {data.Gridz}`
		)
		self:_buildingChanges(data.Player, data.BuildingId, data.Gridx, data.Gridz)
	end)

	EventBus:On(Events.LOCAL_BUILDING_CONSTRUCTION_COMPLETE, function(data)
		local player = data.Player
		local buildingId = data.BuildingId
		local sucess = self:_IsbuilgIsComplete(player, buildingId)
		if sucess then
			warn(
				`[BuildingService] Building construction complete for player {player.Name} and buildingId {buildingId}`
			)
			self:_OnbuilingDone(player, buildingId)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._BuildingCache[player] = nil
	end)
end

return BuildingService
