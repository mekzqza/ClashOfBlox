--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local Events = require(ReplicatedStorage.Shared.Events)

local MainInputUiController = {}
MainInputUiController.__index = MainInputUiController
function MainInputUiController.new()
	local self = setmetatable({}, MainInputUiController)
	self._playerGui = nil

	--Ui
	self._MainInPut = nil
	self._btnConns = {} :: { [string]: RBXScriptConnection }
	return self
end

function MainInputUiController:Init()
	self._playerGui = Player:WaitForChild("PlayerGui")
	self._MainInPut = self._playerGui:WaitForChild("MainInPut") :: ScreenGui
end

function MainInputUiController:Start()
	for _, element in ipairs(self._MainInPut:GetDescendants()) do
		if element:IsA("GuiButton") then
			self._btnConns[element.Name] = element.MouseButton1Click:Connect(function()
				local targetWindow = element.Name

				EventBus:Emit(Events.LOCAL_TOGGLE_UI, targetWindow)
				print(`[MainInputUiController] Button clicked: {targetWindow}`)
			end)
		end
	end
end

return MainInputUiController.new()
