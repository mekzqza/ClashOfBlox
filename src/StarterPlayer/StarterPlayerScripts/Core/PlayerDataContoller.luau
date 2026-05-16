--!strict
--[[
    รับข้อมูลและเป็นตัวกลางในการเข้าถึงข้อมูลของ Contoller อื่นๆ
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)

local PlayerDataContoller = {}
PlayerDataContoller.__index = PlayerDataContoller
function PlayerDataContoller.new()
	local self = setmetatable({}, PlayerDataContoller)
	self._PlayerData = nil
	return self
end

function PlayerDataContoller:GetPlayerData()
	return self._PlayerData
end

function PlayerDataContoller:Init() end
function PlayerDataContoller:Start() end

return PlayerDataContoller.new()
