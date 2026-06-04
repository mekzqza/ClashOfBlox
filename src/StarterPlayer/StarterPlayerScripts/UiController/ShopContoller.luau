--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local Events = require(ReplicatedStorage.Shared.Events)
local Players = game:GetService("Players")

local ShopController = {}
ShopController.__index = ShopController
function ShopController.new()
	local self = setmetatable({}, ShopController)
	-- Dependencies
	self._PlayerDataController = nil

	-- Ui
	self._ShopGui = nil
	self._MainFrame = nil
	self._Resource = nil
	self._DisplayFrame = nil
	self._Elixir = nil
	self._Gold = nil
	self._Gem = nil
	return self
end

function ShopController:SetDependencies(locator)
	self._PlayerDataController = locator:Get("PlayerDataController")
end

function ShopController:_updateResourceDisplay(key: string, value: number)
	local target = self._DisplayFrame:FindFirstChild(key, true)
	if not target or target:IsA("Frame") then
		warn(`[ShopController] Cannot find resource display with name {key}`)
		return
	end

	local textLabel = target:FindFirstChild("Value", true)
	if not textLabel or not textLabel:IsA("TextLabel") then
		warn(`[ShopController] Cannot find TextLabel named "Value" in resource display {key}`)
		return
	end
	value = math.floor(value)
	textLabel.Text = tostring(value)
end

function ShopController:Init()
	self._ShopGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Shop")
	self._MainFrame = self._ShopGui:WaitForChild("MainFrame")
	self._Resource = self._MainFrame:WaitForChild("Resource")
	self._DisplayFrame = self._Resource:WaitForChild("DisplayFrame")
	self._Elixir = self._DisplayFrame:WaitForChild("Elixir")
	self._Gold = self._DisplayFrame:WaitForChild("Gold")
	self._Gem = self._DisplayFrame:WaitForChild("Gem")
end

function ShopController:Start() end

return ShopController.new()
