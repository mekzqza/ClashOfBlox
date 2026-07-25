--!strict
-- [[
-- เป็นตัวส่งสัญญานเริ่ม raid และจบ raid ให้กับ UI
-- และเป็นคนส่งสัญญานให้วาง Unit และ Spell battleController
-- ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = game:GetService("Players").LocalPlayer
local UnitConfig = require(ReplicatedStorage.Shared.UnitConfig)
local GameEum = require(ReplicatedStorage.Shared.GameEnum)
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)

export type TroopCardField = {
	UnitEnum: number,
	TroopCount: number,
	TroopLevel: number,
}

local CONFIG = {
	TROOP_CARD_FRAME_NAME = "Troopcard",
	THICKNESS_SELECTED_CARD = 2,
	THICKNESS_UNSELECTED_CARD = 0,
	-- ครึ่ง cell คือ 2 studs เว้นขอบไว้กัน unit เบียดเข้า cell ข้าง
	MAX_DEPLOY_OFFSET = 1.5,
}

--@TODO : Remove this test data and replace it with actual data from the server when the raid starts
local TEST_UNIT = {
	{ UnitEnum = 1, TroopCount = 10, TroopLevel = 1 },
	{ UnitEnum = 2, TroopCount = 5, TroopLevel = 1 },
	{ UnitEnum = 3, TroopCount = 20, TroopLevel = 1 },
}

local InraidController = {}
InraidController.__index = InraidController
function InraidController.new()
	local self = setmetatable({}, InraidController)
	self._inraid = false
	self._currentCardtroopFrame = nil

	-- Ui
	self._mainFrame = nil
	self._troopContrain = nil
	self._giveUpframe = nil

	--Connections
	self._cardActivated = {} :: {
		[Frame]: {
			conn: RBXScriptConnection,
			unitType: string,
			unitEnum: number,
			TroopCount: number,
			TroopLevel: number,
		},
	}
	self._giveUpConn = nil
	self._Uitemplate = nil

	--dependencry
	self._BattleController = nil
	return self
end

function InraidController:SetDependencies(locator)
	self._BattleController = locator:Get("BattleController")
end

function InraidController:onSelectCard(frame: Frame)
	if self._currentCardtroopFrame then
		local previousUIStroke = self._currentCardtroopFrame:FindFirstChild("UIStroke")
		if previousUIStroke then
			previousUIStroke.Thickness = CONFIG.THICKNESS_UNSELECTED_CARD
		end
	end

	local UIStroke = frame:FindFirstChild("UIStroke")
	if UIStroke then
		UIStroke.Thickness = CONFIG.THICKNESS_SELECTED_CARD
	end
end

function InraidController:CreateTroopCardFrame(): Frame?
	local TroopCardTemplate = self._Uitemplate:FindFirstChild(CONFIG.TROOP_CARD_FRAME_NAME)
	if not TroopCardTemplate then
		warn("[InraidController] Troop card template not found in UI")
		return nil
	end
	return TroopCardTemplate:Clone()
end

function InraidController:RegisterUnitCard(unit: TroopCardField)
	local unitType = GameEum:GetUnitTypeById(unit.UnitEnum)
	if not unitType then
		warn("[InraidController] Invalid unit enum:", unit.UnitEnum)
		return
	end

	local unitData = UnitConfig:GetUnitLevelData(unitType, unit.TroopLevel)
	if not unitData then
		warn("[InraidController] Unit data not found for enum:", unitType, "level:", unit.TroopLevel)
		return
	end

	local card = self:CreateTroopCardFrame()
	if not card then
		return
	end
	card.Troopcount.Text = tostring(unit.TroopCount)
	card.TroopLevel.Text = tostring(unit.TroopLevel)

	self._cardActivated[card] = {
		conn = card.Btn.Activated:Connect(function()
			self._currentCardtroopFrame = card
			self:onSelectCard(card)
		end),
		unitType = unitType,
		unitEnum = unit.UnitEnum,
		TroopCount = unit.TroopCount,
		TroopLevel = unit.TroopLevel,
	}
	card.Parent = self._troopContrain
end

function InraidController:RaidEnd()
	self._inraid = false
	self._currentCardtroopFrame = nil
	for card, data in pairs(self._cardActivated) do
		data.conn:Disconnect()
		card:Destroy()
	end
	self._cardActivated = {}
end

function InraidController:Init()
	local Assets = ReplicatedStorage:WaitForChild("Assets")
	self._Uitemplate = Assets:WaitForChild("UI")

	local PlayerGui = Player:WaitForChild("PlayerGui")
	local RaidScreen = PlayerGui:WaitForChild("RaidScreen")
	self._mainFrame = RaidScreen:WaitForChild("MainFrame")
	local Frame = self._mainFrame:WaitForChild("Frame")
	local BottomFrame = self._mainFrame:WaitForChild("BottomFrame")
	self._troopContrain = BottomFrame:WaitForChild("TroopContrain")
	self._giveUpframe = Frame:WaitForChild("GiveUpframe")
end

function InraidController:Start()
	self._giveUpConn = self._giveUpframe.Btn.Activated:Connect(function()
		--@TODO : Implement give up logic, such as notifying the server and ending the raid
		warn("[InraidController] Give up button activated")
	end)

	EventBus:On(Events.LOCAL_RAID_ENDED, function()
		warn("[InraidController] Raid ended")
		self:RaidEnd()
		self._mainFrame.Visible = false
	end)

	EventBus:On(Events.LOCAL_FOUND_RAID_TARGET, function()
		-- if mode ~= "Raid" then
		-- 	self._mainFrame.Visible = false
		-- 	self._inraid = false
		-- 	return
		-- end

		if self._inraid then
			warn("[InraidController] Raid mode already active")
			return
		end

		self._mainFrame.Visible = true
		self._inraid = true
		for _, unit in ipairs(TEST_UNIT) do
			self:RegisterUnitCard(unit)
		end
	end)

	EventBus:On(Events.LOCAL_GROUND_TAP, function(hitPosition)
		if not self._inraid then
			return
		end
		if not self._currentCardtroopFrame then
			return
		end

		local Unitdata = self._cardActivated[self._currentCardtroopFrame]
		if not Unitdata then
			warn("[InraidController] No unit data found for the selected card")
			return
		end

		local gridX, gridZ = self._BattleController:GetFootPrintStart(hitPosition, 1, 1)
		local cellCenter = self._BattleController:GridCoordsToWorld(gridX, gridZ, 1, 1)
		local offset = Vector3.new(
			math.clamp(hitPosition.X - cellCenter.X, -CONFIG.MAX_DEPLOY_OFFSET, CONFIG.MAX_DEPLOY_OFFSET),
			0,
			math.clamp(hitPosition.Z - cellCenter.Z, -CONFIG.MAX_DEPLOY_OFFSET, CONFIG.MAX_DEPLOY_OFFSET)
		)
		EventBus:Emit(Events.LOCAL_DEPLOY_UNIT, {
			UnitEnum = Unitdata.unitEnum,
			UnitLevel = Unitdata.TroopLevel,
			GirdPosition = { GridX = gridX, GridZ = gridZ },
			Offset = offset,
		})
	end)
end

return InraidController.new()
