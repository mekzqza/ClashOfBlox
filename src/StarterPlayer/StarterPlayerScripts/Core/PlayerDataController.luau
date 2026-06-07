--!strict
--[[
    รับข้อมูลและเป็นตัวกลางในการเข้าถึงข้อมูลของ Contoller อื่นๆ
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Promise = require(Packages.Promise)

local CONFIG = {
	READY_TIMEOUT = 30, -- วินาที
}

local PlayerDataController = {}
PlayerDataController.__index = PlayerDataController
function PlayerDataController.new()
	local self = setmetatable({}, PlayerDataController)
	self._PlayerData = nil
	self._cachedData = {}
	self._isReady = false
	self._readyCallbacks = {}

	return self
end

function PlayerDataController:GetPlayerData()
	return self._PlayerData
end

function PlayerDataController:IsReady()
	return self._isReady and self._cachedData ~= nil
end

function PlayerDataController:WaitForDataReady(timeout: number?): any
	timeout = timeout or CONFIG.READY_TIMEOUT

	return Promise.new(function(resolve, reject)
		if self._isReady and self._cachedData then
			resolve(self._cachedData)
			return
		end

		table.insert(self._readyCallbacks, function()
			resolve(self._cachedData)
		end)
	end)
		:timeout(timeout)
		:catch(function(err)
			if Promise.Error.isKind(err, Promise.Error.Kind.TimedOut) then
				warn(`[PlayerDataController] ⏱️ TIMEOUT: Data not received in {timeout}s`)
				return nil
			end
			error(err)
		end)
end

function PlayerDataController:Get(key: string): any?
	local profile = self._cachedData
	if not profile then
		return nil
	end

	local keys = string.split(key, ".")
	local value: any = profile
	for _, k in ipairs(keys) do
		if type(value) ~= "table" then
			return nil
		end
		value = value[k]
	end
	return value
end

function PlayerDataController:Set(key: string, value: any)
	local profile = self._cachedData
	if not profile then
		return
	end

	local keys = string.split(key, ".")
	local target: any = profile
	for i, k in ipairs(keys) do
		if i == #keys then
			target[k] = value
		else
			if type(target[k]) ~= "table" then
				target[k] = {}
			end
			target = target[k]
		end
	end

	EventBus:Emit(Events.LOCAL_DATA_CHANGED, {
		Key = key,
		Value = value,
	})
end

function PlayerDataController:GetAll()
	return self._cachedData
end

function PlayerDataController:_setData(data)
	self._cachedData = data
	self._isReady = true

	for _, callback in self._readyCallbacks do
		task.spawn(callback)
	end
	table.clear(self._readyCallbacks)
end

function PlayerDataController:Init()
	-- Receive first snapshot Frome Server
	EventBus:On(Events.LOCAL_PLAYER_DATA_FIRST_LOAD, function(data)
		self:_setData(data)
	end)
end
function PlayerDataController:Start()
	EventBus:On(Events.LOCAL_PLAYER_DATA_UPDATE, function(data)
		self:Set(tostring(data.Key), data.Value)
	end)
end

return PlayerDataController.new()
