local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UnitConfig = require(ReplicatedStorage.Shared.UnitConfig)

local UnitController = {}
UnitController.__index = UnitController
function UnitController.new()
	local self = setmetatable({}, UnitController)
	self._unitAvaliable = {} :: { [string]: { [number]: { Model } } }

	self._pool_Unit_Floder = nil
	self._pool_Position_Floder = nil
	self._UnitsTemplate = nil

	-- 1 = IDLE, 2 = MOVING, 3 = ATTACKING, 4 = DYING
	self._tracks = {} :: { [Model]: { [number]: AnimationTrack } }
	self._currentAnimationState = {} :: { [Model]: number }
	return self
end

function UnitController:LoadAnimatioTracks(model: Model)
	if self._tracks[model] then
		return -- โหลดไปแล้ว เรียกซ้ำจาก GetUnit ได้ไม่พัง
	end

	local unitType = model:GetAttribute("UnitType") :: string

	local animationController = model:FindFirstChild("AnimationController", true)
	if not animationController then
		warn("[UnitController] AnimationController not found in model: " .. model.Name)
		return
	end

	local animator = animationController:FindFirstChildOfClass("Animator")
	if not animator then
		warn("[UnitController] Animator not found in AnimationController for model: " .. model.Name)
		return
	end

	local unitAnimationId = UnitConfig:GetAnimationId(unitType)
	if not unitAnimationId then
		warn("[UnitController] Animation ID not found for unit type: " .. unitType)
		return
	end

	local tracks: { [number]: AnimationTrack } = {}
	for state, id in unitAnimationId do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		tracks[state] = animator:LoadAnimation(animation)
	end
	self._tracks[model] = tracks
end

function UnitController:PlayAnimation(model: Model, state: number)
	local currentState = self._currentAnimationState[model]
	if currentState == state then
		return -- อยู่ท่านี้อยู่แล้ว ปล่อยให้เล่นต่อ อย่ารีสตาร์ท
	end

	local tracks = self._tracks[model]
	if not tracks then
		warn("[UnitController] No animation tracks found for model: " .. model.Name)
		return
	end

	local trackToPlay = tracks[state]
	if not trackToPlay then
		warn("[UnitController] No animation track for state: " .. state .. " in model: " .. model.Name)
		return
	end

	local currTrack = if currentState then tracks[currentState] else nil
	if currTrack then
		currTrack:Stop(0.1)
	end

	trackToPlay:Play(0.1)
	self._currentAnimationState[model] = state
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
	-- @TODO [ANIM] ทางนี้คือ unit ที่ใช้ซ้ำจาก pool — track ยังอยู่ครบ (LoadAnimatioTracks กันซ้ำอยู่แล้ว)
	--   แต่ยังไม่มีใครสั่ง PlayAnimation ให้ ต้องให้ BattleController สั่งท่าเริ่มต้นตอน spawn
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

	-- หยุดท่าที่ค้างอยู่ก่อนโยนเข้า pool แล้วล้าง state ทิ้ง
	-- (ต้องล้าง ไม่งั้น PlayAnimation ตอนถูกหยิบไปใช้ใหม่จะเห็นว่า state เดิมแล้ว return ทันที = ยืนแข็ง)
	local currentState = self._currentAnimationState[unitModel]
	local tracks = self._tracks[unitModel]
	if currentState and tracks and tracks[currentState] then
		tracks[currentState]:Stop()
	end
	self._currentAnimationState[unitModel] = nil

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

	self:LoadAnimatioTracks(newUnitModel)

	return newUnitModel
end

function UnitController:UnitMove(model: Model) end

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
