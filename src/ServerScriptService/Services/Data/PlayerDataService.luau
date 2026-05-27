--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Promise = require(Packages.Promise)

local Libs = ServerScriptService:FindFirstChild("Libs")
local guard = IdempotentGuard.new("PlayerDataService", true)
local ProfileService: any = nil

export type ResourceType = "Golds" | "Elixirs" | "Gems"

export type Collectors = {
	Timestamp: number,
	Capacity: number,
	ProductionRate: number,
}

export type PlayerData = {
	_version: number,
	PlayerBuildings: { [string]: { number } },
	Golds: number,
	Elixirs: number,
	Gems: number,
	Level: number,
	Experience: number,
	Collectors: { [ResourceType]: Collectors },
}

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService
function PlayerDataService.new()
	local self = setmetatable({}, PlayerDataService)
	self._DATA_VERSION = 1
	self._PROFILE_STORE_NAME = "COB_PlayerData_v1"
	self._DEFAULT_DATA = {
		_version = self._DATA_VERSION,
		PlayerBuildings = {
			["18_24"] = {
				7,
			},
			["23_20"] = {
				1,
			},
			["29_23"] = {
				5,
			},
			["26_26"] = {
				10,
			},
		},
		Collectors = {
			GoldCollector = {
				Timestamp = 0,
				Capacity = 2500,
				ProductionRate = 0,
			},
			ElixirCollector = {
				Timestamp = 0,
				Capacity = 2500,
				ProductionRate = 0,
			},
		},
		Golds = 0,
		Elixirs = 0,
		Gems = 0,
		Level = 1,
		Experience = 0,
	} :: PlayerData
	self._ProfileStore = nil
	self._Profiles = {} :: { [number]: any }
	self._LoadingPlayers = {} :: { [number]: boolean }
	self._profileReadyCallbacks = {} :: { [number]: { (boolean) -> () } }
	self._VALIDATION_RULES = {
		Golds = { type = "number", min = 0, max = 999999999 },
		Elixirs = { type = "number", min = 0, max = 999999999 },
		Gems = { type = "number", min = 0, max = 999999999 },
		Level = { type = "number", min = 1, max = 100 },
		Experience = { type = "number", min = 0, max = 999999999 },
	} :: { [string]: { type: string, min: number?, max: number? } }
	return self
end

local function MapTOArray(tbl: { [string]: any }): { [number]: any }
	local arr = {}
	for key, value in pairs(tbl) do
		table.insert(arr, {
			SnapToString = key,
			BuildingTypeEnum = value[1],
		})
	end
	return arr
end

function PlayerDataService:_validateValue(
	key: string,
	value: any
): { valid: boolean, clampedValue: any?, reason: string? }
	local rule = self._VALIDATION_RULES[key]
	if not rule then
		return { valid = true }
	end

	if type(value) ~= rule.type then
		return { valid = false, reason = `Expected {rule.type}, got {type(value)}` }
	end

	if rule.type == "number" then
		local num = value :: number
		local clamped = num
		if rule.min and num < rule.min then
			clamped = rule.min
		end
		if rule.max and num > rule.max then
			clamped = rule.max
		end
		if clamped ~= num then
			return { valid = true, clampedValue = clamped, reason = `Value clamped from {num} to {clamped}` }
		end
	end

	return { valid = true }
end

function PlayerDataService:_deepClone(original: any): any
	if type(original) ~= "table" then
		return original
	end
	local copy = {}
	for key, value in pairs(original) do
		copy[self:_deepClone(key)] = self:_deepClone(value)
	end
	return copy
end

function PlayerDataService:_migrateData(data: { [string]: any }, fromVersion: number): { [string]: any }
	print(`[PlayerDataService] 🔄 Migrating data from v{fromVersion} to v{self._DATA_VERSION}`)
	return data
end

function PlayerDataService:_loadPlayerProfile(player: Player)
	local userId = player.UserId
	local profileKey = `Player_{userId}`

	if self._LoadingPlayers[userId] or self._Profiles[userId] then
		return
	end

	self._LoadingPlayers[userId] = true

	local profile = self._ProfileStore:LoadProfileAsync(profileKey, "ForceLoad")

	if not player or not player.Parent then
		if profile then
			profile:Release()
		end
		self._LoadingPlayers[userId] = nil
		return
	end

	if not profile then
		self._LoadingPlayers[userId] = nil
		warn(`[PlayerDataService] ❌ Failed to load profile for {player.Name}`)
		player:Kick("Failed to load your data. Please rejoin.")
		return
	end

	profile:AddUserId(userId)
	profile:Reconcile()

	local dataVersion = profile.Data._version or 0
	if dataVersion < self._DATA_VERSION then
		profile.Data = self:_migrateData(profile.Data, dataVersion)
	end

	profile:ListenToRelease(function()
		self._Profiles[userId] = nil
		if player and player.Parent then
			player:Kick("Your data session ended. Please rejoin.")
		end
	end)

	self._Profiles[userId] = profile
	self._LoadingPlayers[userId] = nil

	local callbacks = self._profileReadyCallbacks[userId]
	if callbacks then
		self._profileReadyCallbacks[userId] = nil
		for _, cb in callbacks do
			task.spawn(cb, true)
		end
	end

	print(`[PlayerDataService] ✅ Profile loaded for {player.Name}`)
end

function PlayerDataService:_releasePlayerProfile(player: Player)
	local userId = player.UserId
	local profile = self._Profiles[userId]

	if profile then
		profile:Release()
	end

	self._LoadingPlayers[userId] = nil
end

function PlayerDataService:GetProfile(player: Player): any?
	return self._Profiles[player.UserId]
end

function PlayerDataService:IsDataLoaded(player: Player): boolean
	return self._Profiles[player.UserId] ~= nil
end

function PlayerDataService:WaitForData(player: Player, timeout: number?): any
	if self:IsDataLoaded(player) then
		return Promise.resolve(true)
	end

	local userId = player.UserId
	if not self._profileReadyCallbacks[userId] then
		self._profileReadyCallbacks[userId] = {}
	end

	return Promise.new(function(resolve)
		table.insert(self._profileReadyCallbacks[userId], resolve)
	end):timeout(timeout or 15)
end

function PlayerDataService:Get(player: Player, key: string): any?
	local profile = self._Profiles[player.UserId]
	if not profile then
		return nil
	end

	local keys = string.split(key, ".")
	local value: any = profile.Data
	for _, k in ipairs(keys) do
		if type(value) ~= "table" then
			return nil
		end
		value = value[k]
	end
	return value
end

function PlayerDataService:GetAll(player: Player): PlayerData?
	local profile = self._Profiles[player.UserId]
	if not profile then
		return nil
	end
	return self:_deepClone(profile.Data)
end

function PlayerDataService:Set(player: Player, key: string, value: any): boolean
	local profile = self._Profiles[player.UserId]
	if not profile or not profile:IsActive() then
		return false
	end

	local validation = self:_validateValue(key, value)
	if not validation.valid then
		return false
	end

	local finalValue = validation.clampedValue or value
	local keys = string.split(key, ".")

	if #keys == 1 then
		profile.Data[key] = finalValue
	else
		local target: any = profile.Data
		for i = 1, #keys - 1 do
			if type(target[keys[i]]) ~= "table" then
				target[keys[i]] = {}
			end
			target = target[keys[i]]
		end
		target[keys[#keys]] = finalValue
	end

	EventBus:Emit(Events.S2C_PLAYER_DATA_UPDATE, player, { Key = key, newValue = finalValue })
	return true
end

function PlayerDataService:Increment(player: Player, key: string, amount: number): (boolean, number?)
	local currentValue = self:Get(player, key)
	if type(currentValue) ~= "number" then
		return false, nil
	end
	local newValue = currentValue + amount
	local success = self:Set(player, key, newValue)
	return success, success and newValue or nil
end

function PlayerDataService:ResetAllData(player: Player): boolean
	local profile = self._Profiles[player.UserId]
	if not profile or not profile:IsActive() then
		return false
	end

	local newData = self:_deepClone(self._DEFAULT_DATA)
	newData._version = self._DATA_VERSION

	profile.Data = newData

	return true
end

function PlayerDataService:Init()
	if not guard:MarkInitialized() then
		return
	end

	local ok, result = pcall(require, Libs:WaitForChild("ProfileService"))
	if not ok then
		warn(`[PlayerDataService] ❌ ProfileService failed: {result}`)
		return
	end
	ProfileService = result

	self._ProfileStore = ProfileService.GetProfileStore(self._PROFILE_STORE_NAME, self._DEFAULT_DATA)
end

function PlayerDataService:Start()
	if not guard:MarkStarted() then
		return
	end

	if not self._ProfileStore then
		warn("[PlayerDataService] ⚠️ Cannot start - ProfileStore not available")
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_loadPlayerProfile(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		self:_loadPlayerProfile(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:_releasePlayerProfile(player)
	end)
	-- [[
	-- @Feta Emit first time when player data is loaded
	--]]
	EventBus:On(Events.LOCAL_CLIENT_READY, function(player)
		self:WaitForData(player, 15)
			:andThen(function()
				local profile = self._Profiles[player.UserId]
				if not profile or not profile:IsActive() then
					return
				end
				local playerData = self:GetAll(player)

				local ArrayBuilding = MapTOArray(playerData.PlayerBuildings)
				local playload = {
					Player = player,
					Golds = playerData and playerData.Golds or 0,
					Elixirs = playerData and playerData.Elixirs or 0,
					Gems = playerData and playerData.Gems or 0,
					Level = playerData and playerData.Level or 1,
					Experience = playerData and playerData.Experience or 0,
					Buildings = playerData and ArrayBuilding or {},
					Collectors = playerData and playerData.Collectors or {},
				}
				EventBus:Emit(Events.S2C_PLAYER_DATA_FIRST_LOAD, playload)
			end)
			:catch(function()
				warn(`[PlayerDataService] ⏱️ Timed out waiting for profile: {player.Name}`)
			end)
	end)
end

return PlayerDataService
