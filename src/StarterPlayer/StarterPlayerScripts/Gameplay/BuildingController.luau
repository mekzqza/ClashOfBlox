--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)
local Player = Players.LocalPlayer

local CONFIG = {
	FOOTPRINTS_TEMPLATE = "FootPrints",
	HARD_CODE_HIGHT = 0.5,
	STARTER_LEVEL = 1,
	FOOTPRINTS = {
		[1] = "1*1Grid",
		[4] = "2*2Grid",
		[9] = "3*3Grid",
		[16] = "4*4Grid",
	},
	KEYSTORE = {
		["Gridx"] = 1,
		["Gridz"] = 2,
		["BuildingEnum"] = 3,
		["BuildingLevel"] = 4,
		["EndTime"] = 5,
		["LastCollectedTime"] = 6,
	},
}

export type BuildingCache = {
	Gridx: number,
	Gridz: number,
	BuildingEnum: number,
	BuildingLevel: number,
	EndTime: number,
	LastCollectedTime: number,
}

local BuildingController = {}
BuildingController.__index = BuildingController
function BuildingController.new()
	local self = setmetatable({}, BuildingController)
	self._BuildingStore = {} :: { [string]: BuildingCache }
	self._BuilderStore = {} :: { [string]: BuildingCache }

	self._buildingCount = 0
	self._isPlacing = false
	self._renderConnection = nil
	self._indicatorModel = nil
	self._mouseConnettion = nil
	self._PlayerFolder = nil
	self._RuntimeChecker = nil

	self._footPrintindicator = nil
	self._BuildingTemplate = nil
	self._GridController = nil
	self._PlayerDataController = nil
	self._ResourceController = nil
	return self
end

function BuildingController:SetDependencies(locator)
	self._PlayerDataController = locator:Get("PlayerDataController")
	self._ResourceController = locator:Get("ResourceController")
	self._GridController = locator:Get("GridController")
end

function BuildingController:SetPlayerFolder(folder: Folder)
	self._PlayerFolder = folder
	if not self._PlayerFolder then
		warn(`[BuildingController] Player folder {folder} not found in workspace`)
	end
end

function BuildingController:BuildingComplete(buildingId: string)
	EventBus:Emit(Events.C2S_BUILDING_CONSTRUCTION_COMPLETE, {
		BuildingId = buildingId,
	})
	self._BuilderStore[buildingId] = nil
	warn(`[BuildingController] Building construction complete for buildingId {buildingId}`)
end

function BuildingController:_ensureRuntimeChecker()
	if self._RuntimeChecker then
		return
	end
	self._RuntimeChecker = task.spawn(function()
		while next(self._BuilderStore) ~= nil do
			local currentTime = os.time()
			for buildingId, data in pairs(self._BuilderStore) do
				if currentTime >= data.EndTime then
					self:BuildingComplete(buildingId)
				end
			end
			task.wait(1)
		end
		self._RuntimeChecker = nil
	end)
end

function BuildingController:_requestPlaceBuilding(gridx: number, gridz: number, buildingEnum: number, position: Vector3)
	EventBus:Emit(Events.C2S_PLAYER_REQUEST_PLACE, {
		Gridx = gridx,
		Gridz = gridz,
		BuildingEnum = buildingEnum,
		Position = position,
	})
end

function BuildingController:RegisterBuildingCache(
	buildingId: string,
	gridx: number,
	gridz: number,
	buildingEnum: number,
	buildingLevel: number,
	endtime: number,
	lastCollectedTime: number
)
	self._BuildingStore[buildingId] = {
		BuildingEnum = buildingEnum,
		BuildingLevel = buildingLevel,
		EndTime = endtime,
		LastCollectedTime = lastCollectedTime,
	}
end

function BuildingController:_createFootPrints(position: Vector3, size: number)
	local template = self._BuildingTemplate:FindFirstChild(CONFIG.FOOTPRINTS_TEMPLATE, true)
	if not template then
		warn(`[BuildingController] Footprints template not found in BuildingTemplate`)
		return
	end

	local newFootPrint: BasePart = template:FindFirstChild(CONFIG.FOOTPRINTS[size], true):Clone()
	if not newFootPrint then
		warn(`[BuildingController] Footprints model with size {size} not found in BuildingTemplate`)
		return
	end

	local haffHeight = newFootPrint.Size.Y / 2
	newFootPrint.Parent = self._PlayerFolder
	newFootPrint.CFrame = CFrame.new(position.X, position.Y + haffHeight + CONFIG.HARD_CODE_HIGHT, position.Z)
end

function BuildingController:_createBuilding(buildingType: string, snapPosition: Vector3, buildingLevel: number?): Model?
	local buildingFolder = self._BuildingTemplate:FindFirstChild(buildingType, true)
	if not buildingFolder then
		warn(`Building {buildingType} not found`)
		return
	end

	local Template = buildingFolder:FindFirstChild(buildingLevel or CONFIG.STARTER_LEVEL)
	if not Template then
		warn(`Level {CONFIG.STARTER_LEVEL} not found in {buildingType}`)
		return
	end

	if not Template:IsA("Model") then
		return
	end

	local newBuilding = Template:Clone()
	newBuilding.Parent = self._PlayerFolder

	local primaryPart: BasePart? = newBuilding.PrimaryPart
	if not primaryPart then
		warn(`[BuildingController] Building model with id {buildingType} does not have a PrimaryPart`)
		return
	end
	local templateRotation = Template:GetPivot().Rotation
	local halfHeight = primaryPart.Size.Y / 2
	newBuilding:PivotTo(
		CFrame.new(snapPosition.X, snapPosition.Y + halfHeight + CONFIG.HARD_CODE_HIGHT, snapPosition.Z)
			* templateRotation
	)
	return newBuilding
end

function BuildingController:_startPlacement(buildType: string)
	local buildingFolder = self._BuildingTemplate:FindFirstChild(buildType, true)
	if not buildingFolder then
		warn(`[BuildingController] Building {buildType} not found`)
		return
	end

	local Template = buildingFolder:FindFirstChild(CONFIG.STARTER_LEVEL)
	if not Template then
		warn(`[BuildingController] Level {CONFIG.STARTER_LEVEL} not found in {buildType}`)
		return
	end

	local dimention = BuildingConfig:GetBuildingDimensions(buildType)
	if not dimention then
		warn(`[BuildingController] Building config with id {buildType} not found in BuildingConfig`)
		return
	end

	if not Template:IsA("Model") then
		return
	end
	self._indicatorModel = Template:Clone()
	self._footPrintindicator = self._BuildingTemplate
		:FindFirstChild(CONFIG.FOOTPRINTS_TEMPLATE, true)
		:FindFirstChild(CONFIG.FOOTPRINTS[dimention.Length * dimention.Width], true)
		:Clone()
	self._footPrintindicator.Parent = self._indicatorModel
	local templateRotation = Template:GetPivot().Rotation

	self._indicatorModel.Parent = self._PlayerFolder
	self._isPlacing = true

	local primaryPart: BasePart? = self._indicatorModel.PrimaryPart
	if not primaryPart then
		return
	end

	local indicatorModelhalfHeight = primaryPart.Size.Y / 2
	local footPrintindicatorhalfHeight = self._footPrintindicator.Size.Y / 2

	self._renderConnection = RunService.RenderStepped:Connect(function()
		local mouse = Player:GetMouse()
		local traget = mouse.Target
		if not traget then
			return
		end

		if not self._indicatorModel then
			return
		end

		local snapPos =
			self._GridController:SnapToGrid(mouse.Hit.Position, dimention.Length, dimention.Width) :: Vector3

		local canPlace = self._GridController:Canplace(snapPos, dimention.Length, dimention.Width)
		local color = if canPlace then Color3.new(0, 1, 0) else Color3.new(1, 0, 0)
		for _, child in ipairs(self._indicatorModel:GetDescendants()) do
			if child:IsA("BasePart") then
				if child:IsA("UnionOperation") then
					child.UsePartColor = true
				end
				child.Color = color
			end
		end
		self._indicatorModel:SetPrimaryPartCFrame(
			CFrame.new(snapPos.X, snapPos.Y + indicatorModelhalfHeight, snapPos.Z) * templateRotation
		)
		self._footPrintindicator.CFrame = CFrame.new(snapPos.X, snapPos.Y + footPrintindicatorhalfHeight, snapPos.Z)
	end)

	local mouse = Player:GetMouse()
	self._mouseConnettion = mouse.Button1Down:Connect(function()
		local snapPos =
			self._GridController:SnapToGrid(mouse.Hit.Position, dimention.Length, dimention.Width) :: Vector3
		if self._GridController:Canplace(snapPos, dimention.Length, dimention.Width) then
			local startX, startZ = self._GridController:GetFootPrintStart(snapPos, dimention.Length, dimention.Width)
			local buildingEnum = GameEnum:GetBuildingTypeIdByName(buildType)
			self:_requestPlaceBuilding(startX, startZ, buildingEnum, snapPos)
			self:_createBuilding(buildType, snapPos)
			self:_createFootPrints(snapPos, dimention.Length * dimention.Width)
			self._GridController:occupyCell(snapPos, dimention.Length, dimention.Width)

			-- เก็บcache ไว้ก่อน โยยไม่รอserver
			local buildingCount = self._buildingCount :: number
			local nextbuildingId = `n{buildingCount + 1}`
			self:RegisterBuildingCache(
				nextbuildingId,
				startX,
				startZ,
				buildingEnum,
				CONFIG.STARTER_LEVEL,
				os.time() + BuildingConfig:GetBuildingDataByEnum(buildingEnum, CONFIG.STARTER_LEVEL).UpgradeTime,
				0
			)

			self._BuilderStore[nextbuildingId] = {
				Gridx = startX,
				Gridz = startZ,
				BuildingEnum = buildingEnum,
				BuildingLevel = CONFIG.STARTER_LEVEL,
				EndTime = os.time()
					+ BuildingConfig:GetBuildingDataByEnum(buildingEnum, CONFIG.STARTER_LEVEL).UpgradeTime,
				LastCollectedTime = 0,
			}
			self:_ensureRuntimeChecker()

			-- เล่นanimation วางอาคารเรียกคนสร้างออกมา

			-- นับถอยหลังเองเลย

			--ส่งข้อมูลวางไปหาserver
		end
	end)
end

function BuildingController:RecreateBuildings(
	buildingId: string,
	gridx: number,
	gridz: number,
	buildingEnum: number,
	buildingLevel: number,
	endTime: number,
	lastCollectedTime: number
)
	local startX = gridx
	local startZ = gridz

	local buildingType = GameEnum:GetBuildingTypeById(buildingEnum)
	if not buildingType then
		warn(`[BuildingController] Invalid building enum {buildingEnum} for buildingId {buildingId}`)
		return
	end

	local dimention = BuildingConfig:GetBuildingDimensions(buildingType)
	if not dimention then
		return
	end

	local worldPos = self._GridController:GridCoordsToWorld(startX, startZ, dimention.Length, dimention.Width)
	local model = self:_createBuilding(buildingType, worldPos, buildingLevel)
	self:_createFootPrints(worldPos, dimention.Length * dimention.Width)
	self._GridController:occupyCell(worldPos, dimention.Length, dimention.Width)

	local collectorType = BuildingConfig:GetCollectorType(buildingType)
	if collectorType then
		self._ResourceController:RegisterclickDetector(collectorType, model)
	end

	self:RegisterBuildingCache(buildingId, gridx, gridz, buildingEnum, buildingLevel, endTime, LastCollectedTime)

	--Building hut
	if endTime ~= 0 then
		self._BuilderStore[buildingId] = {
			Gridx = gridx,
			Gridz = gridz,
			BuildingEnum = buildingEnum,
			BuildingLevel = buildingLevel,
			EndTime = endTime,
			LastCollectedTime = lastCollectedTime,
		}
		self:_ensureRuntimeChecker()
	end
end

function BuildingController:_stopPlacement()
	self._isPlacing = false
	if self._renderConnection then
		self._renderConnection:Disconnect()
		self._renderConnection = nil
	end

	if self._mouseConnettion then
		self._mouseConnettion:Disconnect()
		self._mouseConnettion = nil
	end

	if self._indicatorModel then
		self._indicatorModel:Destroy()
		self._indicatorModel = nil
	end

	if self._footPrintindicator then
		self._footPrintindicator:Destroy()
		self._footPrintindicator = nil
	end
end

function BuildingController:Init()
	self._BuildingTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Structure")
	if not self._BuildingTemplate then
		warn("[BuildingController] Building template folder not found in ReplicatedStorage.Assets")
		return
	end
end

function BuildingController:Start()
	EventBus:On(Events.LOCAL_TEST_BUILDING, function(building: string)
		if building == nil or building == "" then
			self:_stopPlacement()
			return
		end
		warn(`[BuildingController] Test building: {building}`)
		self:_stopPlacement()
		self:_startPlacement(building)
	end)

	self._PlayerDataController:WaitForDataReady():andThen(function(data)
		if not data then
			warn("[BuildingController] No player data received (timeout)")
			return
		end

		self._buildingCount = data.BuildingCount or 0
		local buildings = data.Buildings
		if not buildings then
			warn("[BuildingController] No building data found for player")
			return
		end
		for buildingId, buildingdata in buildings do
			self:RecreateBuildings(
				buildingId,
				buildingdata[CONFIG.KEYSTORE["Gridx"]],
				buildingdata[CONFIG.KEYSTORE["Gridz"]],
				buildingdata[CONFIG.KEYSTORE["BuildingEnum"]],
				buildingdata[CONFIG.KEYSTORE["BuildingLevel"]],
				buildingdata[CONFIG.KEYSTORE["EndTime"]],
				buildingdata[CONFIG.KEYSTORE["LastCollectedTime"]]
			)
			self._ResourceController:RegisterColector(
				buildingId,
				buildingdata[CONFIG.KEYSTORE["Gridx"]],
				buildingdata[CONFIG.KEYSTORE["Gridz"]],
				buildingdata[CONFIG.KEYSTORE["BuildingEnum"]],
				buildingdata[CONFIG.KEYSTORE["BuildingLevel"]],
				buildingdata[CONFIG.KEYSTORE["EndTime"]],
				buildingdata[CONFIG.KEYSTORE["LastCollectedTime"]]
			)
		end
	end)
end

return BuildingController.new()
