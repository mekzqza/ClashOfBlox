--!strict
--[[
    --Auto Register Building and Unit for Simulation and Run Server mainThead
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceLocator = require(ServerScriptService.Utils.ServiceLocator)
local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)

local Simulation = require(ReplicatedStorage.Shared.Simulation)
local Pathfinding = require(ReplicatedStorage.Shared.Pathfinding)
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)
local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)

local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local guard = IdempotentGuard.new("BattleService")

export type MatchData = {
	Victem: Player,
	State: Simulation.State,
	ValidCells: { { [string]: true } },
	OccupiedCells: { { [string]: true } },
	Seed: number,
}

local CONFIG = {
	KEYSTORE = {
		["Gridx"] = 1,
		["Gridz"] = 2,
		["BuildingEnum"] = 3,
		["BuildingLevel"] = 4,
		["EndTime"] = 5,
		["LastCollectedTime"] = 6,
	},
	GRID_DISTANCE_INSTUD = 1000,
	SEED = 12345,
}

local BattleService = {}
BattleService.__index = BattleService
function BattleService.new()
	local self = setmetatable({}, BattleService)

	--
	self._PlayerInmatch = {} :: { [Player]: MatchData }

	-- Dependencies
	self._PlayerDataService = nil
	return self
end

-- @TODO เป็น Event ตอนวาง troop แต่ละตัว init Unit ณ ตำแหน่งนั้นๆ
-- function BattleService:_RigisterUnitState(attacker: Player, unitId: string, unitype: number, unitLevel: number,position: Vector3)
-- 	local initUnitState = {} :: Simulation.UnitState
-- end

function BattleService:_RigisterStateBuilding(player: Player): Simulation.BuildingState
	local initBuildingState = {}
	local playerData = self._PlayerDataService:WaitForData(player)
	local Buildings = playerData.Buildings
	if not Buildings then
		warn("[BattleService] PlayerDataService:WaitForData() - Buildings not found for player:", player.Name)
		return initBuildingState
	end

	for id, building in pairs(Buildings) do
		local buildingData = BuildingConfig:GetBuildingDataByEnum(
			building[CONFIG.KEYSTORE.BuildingEnum],
			building[CONFIG.KEYSTORE.BuildingLevel]
		)
		if not buildingData then
			warn(
				"[BattleService] BuildingConfig:GetBuildingDataByEnum() - Building data not found for enum:",
				building[CONFIG.KEYSTORE.BuildingEnum],
				"level:",
				building[CONFIG.KEYSTORE.BuildingLevel]
			)
			continue
		end

		--[[
		    @ TODO 1
			ระว่างที่เก็บ GridX และ GridZ จะให้เก็บ cells ที่สามารถเดินได้
            @ TODO 2
            -- ทำตอนพิ่มกำแพงเก็บ cells ที่สามารถเดินได้
			]]
		local buildingState = {
			BuildingId = id,
			MaxHp = buildingData.MaxHp,
			Hp = buildingData.MaxHp,
			Position = {
				GridX = building[CONFIG.KEYSTORE.Gridx],
				GridZ = building[CONFIG.KEYSTORE.Gridz],
			},
		}
		table.insert(initBuildingState, buildingState)
	end

	return initBuildingState
end

function BattleService:RegisterMatch(Attacker: Player, Victem: Player): Simulation.State
	local newState = {} :: Simulation.State
	local initBuildingState = self:_RigisterStateBuilding(Victem)
	newState.Buildings = initBuildingState
	newState.Units = {}
	newState.Spells = {}
	return newState
end

function BattleService:Init()
	if not guard:MarkInitialized() then
		return
	end

	self._PlayerDataService = ServiceLocator:Get("PlayerDataService")
	if not self._PlayerDataService then
		warn("[BattleService] PlayerDataService not found. Make sure it is registered in ServiceLocator.")
		return
	end
end

function BattleService:Start()
	if not guard:MarkStarted() then
		return
	end

	EventBus:On(Events.LOCAL_PLAYER_RAID_START, function(Attacker: Player, Victem: Player)
		self._PlayerInmatch[Attacker] = self:RegisterMatch(Attacker, Victem)
	end)
end

return BattleService
