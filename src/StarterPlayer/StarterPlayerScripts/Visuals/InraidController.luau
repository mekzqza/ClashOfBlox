--!strict
-- [[
-- เป็นตัวส่งสัญญานเริ่ม raid และจบ raid ให้กับ UI
-- และเป็นคนส่งสัญญานให้วาง Unit และ Spell battleController
-- ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = game:GetService("Players").LocalPlayer
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)

export type TroppCardFiled = {
	UnitType: string,
	Count: number,
	TroppLevel: number,
}

local CONFIG = {
	TROOP_CARD_FRAME_NAME = "Troopcard",
}

local InraidController = {}
InraidController.__index = InraidController
function InraidController.new()
	local self = setmetatable({}, InraidController)
	self._inraid = false

	self._Uitemplate = nil
	self._currentCardtroopFrame = nil
	return self
end

function InraidController:Init()
	local Assets = ReplicatedStorage:WaitForChild("Assets")
	self._Uitemplate = Assets:WaitForChild("UI")

	local PlayerGui = Player:WaitForChild("PlayerGui")
	local RaidScreen = PlayerGui:WaitForChild("RaidScreen")
	local MainFrame = RaidScreen:WaitForChild("MainFrame")
	local BottomFrame = MainFrame:WaitForChild("BottomFrame")
	local TroopContrain = BottomFrame:WaitForChild("TroopContrain")
end

function InraidController:CreateTroopCardFrame(): Frame?
	local troppCardTemplate = self._Uitemplate:FindFirstChild(CONFIG.TROOP_CARD_FRAME_NAME)
	if not troppCardTemplate then
		warn("[InraidController] Troop card template not found in UI")
		return nil
	end
	return troppCardTemplate:Clone()
end

function InraidController:Start() end

return InraidController.new()
