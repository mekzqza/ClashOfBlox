--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)

local MainDisplayController = {}
MainDisplayController.__index = MainDisplayController
function MainDisplayController.new()
	local self = setmetatable({}, MainDisplayController)
	self._PlayerDataController = nil
	self._PlayerGui = nil
	self._MainDisPlay = nil
	self._MainFrame = nil
	self._ResourceFrame = nil

	self._ElixirContainer = nil
	self._GemContainer = nil
	self._GoldContainer = nil
	return self
end

function MainDisplayController:SetDependencies(locator)
	self._PlayerDataController = locator:Get("PlayerDataController")
end

function MainDisplayController:_updateResourceDisplay(key: string, value: number)
	local traget = self._ResourceFrame:FindFirstChild(key, true)
	if not traget then
		warn(`[MainDisplayController] Cannot find resource container with name ${key}`)
		return
	end

	local frameValue: TextLabel = traget:FindFirstChild("Value", true)
	if not frameValue then
		warn(`[MainDisplayController] Cannot find Value label in ${key} container`)
		return
	end

	local fillFrame = traget:FindFirstChild("Fill", true)
	if fillFrame and fillFrame:IsA("Frame") then
		local fillAmount = math.clamp(value / 1000, 0, 1) -- Assuming 1000 is the max value for demonstration
		fillFrame.Size = UDim2.new(fillAmount, 0, 1, 0)
	end

	frameValue.Text = tostring(value)
end

function MainDisplayController:Init()
	self._PlayerGui = Player:WaitForChild("PlayerGui")
	self._MainDisPlay = self._PlayerGui:WaitForChild("MainDisPlay")
	self._MainFrame = self._MainDisPlay:WaitForChild("MainFrame")
	self._ResourceFrame = self._MainFrame:WaitForChild("ResourceFrame")

	self._GoldContainer = self._ResourceFrame:WaitForChild("Gold")
	self._ElixirContainer = self._ResourceFrame:WaitForChild("Elixir")
	self._GemContainer = self._ResourceFrame:WaitForChild("Gem")
end

function MainDisplayController:Start()
	EventBus:On(Events.LOCAL_PLAYER_DATA_CHANGED, function(data) end)
end

return MainDisplayController.new()
