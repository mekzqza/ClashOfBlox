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
	self._ProfileContainer = nil
	self._LevelCount = nil
	self._LevelFillBar = nil

	self._ElixirContainer = nil
	self._GemContainer = nil
	self._GoldContainer = nil

	self._Collectors = {
		["Golds"] = {
			Timestamp = 0,
			Capacity = 0,
			ProductionRate = 0,
		},
		["Elixirs"] = {
			Timestamp = 0,
			Capacity = 0,
			ProductionRate = 0,
		},
	}
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
		warn(`[MainDisplayContrcoller] Cannot find Value label in ${key} container`)
		return
	end

	local fillFrame = traget:FindFirstChild("Fill", true)
	if fillFrame and fillFrame:IsA("Frame") then
		local fillAmount = math.clamp(value / self._Collectors[key].Capacity, 0, 1)
		fillFrame.AnchorPoint = Vector2.new(1, 0)
		fillFrame.Position = UDim2.new(1, 0, 0, 0)
		fillFrame.Size = UDim2.new(fillAmount, 0, 1, 0)
	end

	frameValue.Text = tostring(value)
end

function MainDisplayController:_setPlayerName(player: Player)
	local playerName: TextLabel = self._LevelFillBar:FindFirstChild("PlayerName", true)
	if not playerName then
		warn("[MainDisplayController] Cannot find PlayerName label in LevelFillBar")
		return
	end

	playerName.Text = player.Name
end

function MainDisplayController:_updateLevelDisplay(level: number)
	local levelText = self._LevelCount:FindFirstChild("Value", true)
	if not levelText then
		warn("[MainDisplayController] Cannot find Value label in LevelCount container")
		return
	end
	levelText.Text = tostring(level)
end

function MainDisplayController:_updateExperience(experience: number)
	local fillExperience = self._LevelFillBar:FindFirstChild("Fill", true)
	if not fillExperience or not fillExperience:IsA("Frame") then
		warn("[MainDisplayController] Cannot find Fill frame in LevelFillBar")
		return
	end
	local fillAmount = math.clamp(experience / 1000, 0, 1)
	fillExperience.AnchorPoint = Vector2.new(1, 0)
	fillExperience.Position = UDim2.new(1, 0, 0, 0)
	fillExperience.Size = UDim2.new(fillAmount, 0, 1, 0)
end

function MainDisplayController:Init()
	self._PlayerGui = Player:WaitForChild("PlayerGui")
	self._MainDisPlay = self._PlayerGui:WaitForChild("MainDisPlay")
	self._MainFrame = self._MainDisPlay:WaitForChild("MainFrame")
	self._ResourceFrame = self._MainFrame:WaitForChild("ResourceFrame")
	self._ProfileFrame = self._MainFrame:WaitForChild("ProfileFrame")
	self._ProfileContainer = self._ProfileFrame:WaitForChild("ProfileContainer")
	self._LevelCount = self._ProfileContainer:WaitForChild("LevelCount")
	self._LevelFillBar = self._ProfileContainer:WaitForChild("LevelFillBar")

	self._GoldContainer = self._ResourceFrame:WaitForChild("Golds")
	self._ElixirContainer = self._ResourceFrame:WaitForChild("Elixirs")
	self._GemContainer = self._ResourceFrame:WaitForChild("Gems")
end

function MainDisplayController:Start()
	EventBus:On(Events.LOCAL_DATA_CHANGED, function(data)
		if data.Key == "Golds" then
			self:_updateResourceDisplay("Golds", data.Value)
		elseif data.Key == "Elixirs" then
			self:_updateResourceDisplay("Elixirs", data.Value)
		elseif data.Key == "Gems" then
			self:_updateResourceDisplay("Gems", data.Value)
		elseif data.Key == "Level" then
			self:_updateLevelDisplay(data.Value)
		elseif data.Key == "Experience" then
			self:_updateExperience(data.Value)
		end
	end)

	self._PlayerDataController:WaitForDataReady():andThen(function(data)
		local Golds = data.Golds or 0
		local elixir = data.Elixirs or 0
		local gem = data.Gems or 0
		local level = data.Level or 1
		local experience = data.Experience or 0

		-- self._Collectors = {
		-- 	Golds = data.Collectors and data.Collectors.GoldCollector or 0,
		-- 	Elixirs = data.Collectors and data.Collectors.ElixirCollector or 0,
		-- }
		-- self:_updateResourceDisplay("Golds", Golds)
		-- self:_updateResourceDisplay("Elixirs", elixir)
		-- self:_updateResourceDisplay("Gems", gem)
		self:_setPlayerName(Player)
		self:_updateLevelDisplay(level)
		self:_updateExperience(experience)
	end)
end

return MainDisplayController.new()
