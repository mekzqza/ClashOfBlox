local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local CONFIG = {
	TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0, false, 0),
}

local UnitController = {}
UnitController.__index = UnitController
function UnitController.new()
	local self = setmetatable({}, UnitController)
	self._unitAvaliable = {} :: { [string]: { [number]: { Model } } }

	self._pool_Unit_Floder = nil
	self._pool_Position_Floder = nil
	self._UnitsTemplate = nil
	return self
end

-- @TODO Unitpolling
function UnitController:GetUnit(unitType: string, unitLevel: number): Model?
	if not self._unitAvaliable[unitType] then
		self._unitAvaliable[unitType] = {}
	end

	if not self._unitAvaliable[unitType][unitLevel] then
		self._unitAvaliable[unitType][unitLevel] = {}
	end

	local model = table.remove(self._unitAvaliable[unitType][unitLevel], 1)
	if not model then
		local createModel = self:CreateUnit(unitType, unitLevel)
		if not createModel then
			warn("[UnitController] Failed to create unit of type: " .. unitType .. " and level: " .. unitLevel)
			return nil
		end
		return createModel
	end
	model:SetAttribute("UnitType", unitType)
	model:SetAttribute("UnitLevel", unitLevel)
	return model
end

function UnitController:RecycleUnit(unitModel: Model)
	local unitType = unitModel:GetAttribute("UnitType")
	local unitLevel = unitModel:GetAttribute("UnitLevel")

	if not unitType or not unitLevel then
		warn("[UnitController] Unit model missing UnitType or UnitLevel attributes")
		return
	end

	if not self._unitAvaliable[unitType] then
		self._unitAvaliable[unitType] = {}
	end

	if not self._unitAvaliable[unitType][unitLevel] then
		self._unitAvaliable[unitType][unitLevel] = {}
	end

	unitModel.Parent = self._pool_Unit_Floder
	unitModel:PivotTo(CFrame.new(self._pool_Position_Floder))
	table.insert(self._unitAvaliable[unitType][unitLevel], unitModel)
end

function UnitController:CreateUnit(unitType: string, unitLevel: number): Model?
	local unitFolder = self._UnitsTemplate:FindFirstChild(unitType)
	if not unitFolder then
		warn("[UnitController] Unit type not found: " .. unitType)
		return nil
	end
	local unitModel = unitFolder:FindFirstChild(tostring(unitLevel))
	if not unitModel then
		warn("[UnitController] Unit level not found: " .. unitLevel .. " for type: " .. unitType)
		return nil
	end

	local newUnitModel = unitModel:Clone()
	newUnitModel.Parent = self._pool_Unit_Floder
	newUnitModel:PivotTo(CFrame.new(self._pool_Position_Floder))
	newUnitModel:SetAttribute("UnitType", unitType)
	newUnitModel:SetAttribute("UnitLevel", unitLevel)

	return newUnitModel
end

function UnitController:UnitWalk(model: Model) end

-- @TODO UpdateUnit Walk, Attack, Die,
function UnitController:UpdateUnit(model: Model, prevPosition: Vector3, curr) end

function UnitController:Init()
	local Assets = ReplicatedStorage:WaitForChild("Assets", 30)
	if not Assets then
		warn("[UnitController] Assets folder not found in ReplicatedStorage")
		return
	end

	self._UnitsTemplate = Assets:WaitForChild("Units", 30)
	if not self._UnitsTemplate then
		warn("[UnitController] Units template not found in Assets")
		return
	end

	local poolFolder = Workspace:WaitForChild("Pool", 30)
	if not poolFolder then
		warn("[UnitController] Pool folder not found in Workspace")
		return
	end

	self._pool_Unit_Floder = poolFolder:WaitForChild("Units", 30)
	if not self._pool_Unit_Floder then
		warn("[UnitController] Units pool folder not found in Pool")
		return
	end

	local positionPart = poolFolder:WaitForChild("Position", 30)
	if not positionPart then
		warn("[UnitController] Positions part not found in Pool")
		return
	end
	self._pool_Position_Floder =
		Vector3.new(positionPart.Position.X, positionPart.Position.Y + 10, positionPart.Position.Z)
end

function UnitController:Start()

	-- @TODO ในอนาคต ดึง playLoadUnit player data มาใช้ในการ spawn unit
end

return UnitController.new()
