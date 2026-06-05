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
	CREATE_BUILDING_TEMPLATE = "CreatingBuilding",
	UPGRADE_BUILDING_TEMPLATE = "UpgradingBuilding",

	HEIGHT = 0.5,
	STARTER_LEVEL = 0,
	NEXT_LEVEL = 1,
	GRID_KEY = {
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
	BuildingModel: Model,

	BuilderModel: Model?,
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
	self._Connetion = nil
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
	local building = self._BuildingStore[buildingId]
	if not building then
		warn(`[BuildingController] No builder data found for buildingId {buildingId} on construction complete`)
		return
	end
	building.EndTime = 0

	-- clone model ของจริงมาแทนที่
	local level = if building.BuildingLevel == CONFIG.STARTER_LEVEL
		then CONFIG.NEXT_LEVEL
		else (building.BuildingLevel + CONFIG.NEXT_LEVEL)

	building.BuildingLevel += level

	local builder = self._BuilderStore[buildingId]
	if builder then
		builder.BuilderModel:Destroy()
		builder.BuildingModel = nil
		builder.BuilderModel = nil
		self._BuilderStore[buildingId] = nil
	end

	EventBus:Emit(Events.C2S_BUILDING_CONSTRUCTION_COMPLETE, {
		BuildingId = buildingId,
	})

	-- local model = self:_createBuilding()

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

function BuildingController:_CloneConstructionVisual(templatename: string, gridsize: number): Model?
	local template = self._BuildingTemplate:FindFirstChild(templatename, true)
	if not template then
		warn(`[BuildingController] Upgrade building template not found in BuildingTemplate`)
		return
	end
	local model = template:FindFirstChild(CONFIG.GRID_KEY[gridsize], true)
	if not model then
		warn(`[BuildingController] Upgrade building model with grid size {gridsize} not found in BuildingTemplate`)
		return
	end
	return model:Clone()
end

function BuildingController:RegisterBuildingCache(
	buildingId: string,
	gridx: number,
	gridz: number,
	buildingEnum: number,
	buildingLevel: number,
	endtime: number,
	lastCollectedTime: number,
	model: Model
)
	self._BuildingStore[buildingId] = {
		BuildingEnum = buildingEnum,
		Gridx = gridx,
		Gridz = gridz,
		BuildingLevel = buildingLevel,
		EndTime = endtime,
		LastCollectedTime = lastCollectedTime,
		BuildingModel = model,
	}
end

function BuildingController:_GetBuilderModel(
	buildingLevel: number,
	gridx: number,
	gridz: number,
	sizex: number,
	sizez: number
): Model?
	-- return clone แบบแปลงส่วนสูง โดยดึงจากModel primarypart setposition ให้เรียบร้อยก่อนส่ง
	local clone = nil
	local worldPos = self._GridController:GridCoordsToWorld(gridx, gridz, sizex, sizez)

	if buildingLevel == 0 then
		clone = Instance.new("Model")
		local model1 = self:_CloneConstructionVisual(CONFIG.CREATE_BUILDING_TEMPLATE, sizex * sizez)
		local model2 = self:_CloneConstructionVisual(CONFIG.UPGRADE_BUILDING_TEMPLATE, sizex * sizez)
		local primaryPart1 = model1.PrimaryPart :: BasePart
		local primaryPart2 = model2.PrimaryPart :: BasePart
		local haftHeight1 = primaryPart1.Size.Y / 2
		local haftHeight2 = primaryPart2.Size.Y / 2
		model1:PivotTo(CFrame.new(worldPos.X, worldPos.Y + haftHeight1 + CONFIG.HEIGHT, worldPos.Z))
		model2:PivotTo(CFrame.new(worldPos.X, worldPos.Y + haftHeight2 + CONFIG.HEIGHT, worldPos.Z))
		model1.Parent = clone
		model2.Parent = clone
	else
		clone = self:_CloneConstructionVisual(CONFIG.UPGRADE_BUILDING_TEMPLATE, sizex * sizez)
		local primaryPart = clone.PrimaryPart :: BasePart
		local haftHeight = primaryPart.Size.Y / 2
		clone:PivotTo(CFrame.new(worldPos.X, worldPos.Y + haftHeight + CONFIG.HEIGHT, worldPos.Z))
	end

	return clone
end

function BuildingController:_RegisterBuilderStore(
	buildingId: string,
	gridx: number,
	gridz: number,
	buildingEnum: number,
	buildingLevel: number,
	endtime: number,
	lastCollectedTime: number,
	model: Model
)
	self._BuilderStore[buildingId] = {
		Gridx = gridx,
		Gridz = gridz,
		BuildingEnum = buildingEnum,
		BuildingLevel = buildingLevel,
		EndTime = endtime,
		LastCollectedTime = lastCollectedTime,
		BuildingModel = model,
	}

	self:_ensureRuntimeChecker()
end

function BuildingController:_createFootPrints(position: Vector3, size: number): BasePart?
	local template = self._BuildingTemplate:FindFirstChild(CONFIG.FOOTPRINTS_TEMPLATE, true)
	if not template then
		warn(`[BuildingController] Footprints template not found in BuildingTemplate`)
		return
	end

	local newFootPrint: BasePart = template:FindFirstChild(CONFIG.GRID_KEY[size], true):Clone()
	if not newFootPrint then
		warn(`[BuildingController] Footprints model with size {size} not found in BuildingTemplate`)
		return
	end

	local half = newFootPrint.Size.Y / 2
	newFootPrint.CFrame = CFrame.new(position.X, position.Y + half + CONFIG.HEIGHT, position.Z)
	return newFootPrint
end

function BuildingController:_createBuilding(buildingType: string, snapPosition: Vector3, buildingLevel: number?): Model?
	local buildingFolder = self._BuildingTemplate:FindFirstChild(buildingType, true)
	if not buildingFolder then
		warn(`Building {buildingType} not found`)
		return
	end

	local Template = buildingFolder:FindFirstChild(tostring(buildingLevel or CONFIG.STARTER_LEVEL), true)
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
		CFrame.new(snapPosition.X, snapPosition.Y + halfHeight + CONFIG.HEIGHT, snapPosition.Z) * templateRotation
	)
	return newBuilding
end

function BuildingController:_startPlacement(buildType: string)
	local buildingFolder = self._BuildingTemplate:FindFirstChild(buildType, true)
	if not buildingFolder then
		warn(`[BuildingController] Building {buildType} not found`)
		return
	end

	local Template = buildingFolder:FindFirstChild(tostring(CONFIG.NEXT_LEVEL))
	if not Template then
		warn(`[BuildingController] Level {CONFIG.NEXT_LEVEL} not found in {buildType}`)
		return
	end

	local dimension = BuildingConfig:GetBuildingDimensions(buildType)
	if not dimension then
		warn(`[BuildingController] Building config with id {buildType} not found in BuildingConfig`)
		return
	end

	if not Template:IsA("Model") then
		return
	end

	self._indicatorModel = Template:Clone()
	self._footPrintindicator = self._BuildingTemplate
		:FindFirstChild(CONFIG.FOOTPRINTS_TEMPLATE, true)
		:FindFirstChild(CONFIG.GRID_KEY[dimension.Length * dimension.Width], true)
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
		local target = mouse.Target
		if not target then
			return
		end

		if not self._indicatorModel then
			return
		end

		local snapPos =
			self._GridController:SnapToGrid(mouse.Hit.Position, dimension.Length, dimension.Width) :: Vector3

		local CanPlace = self._GridController:CanPlace(snapPos, dimension.Length, dimension.Width)
		local color = if CanPlace then Color3.new(0, 1, 0) else Color3.new(1, 0, 0)
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
	self._Connetion = mouse.Button1Down:Connect(function()
		local snapPos =
			self._GridController:SnapToGrid(mouse.Hit.Position, dimension.Length, dimension.Width) :: Vector3
		if self._GridController:CanPlace(snapPos, dimension.Length, dimension.Width) then
			local startX, startZ = self._GridController:GetFootPrintStart(snapPos, dimension.Length, dimension.Width)
			local buildingEnum = GameEnum:GetBuildingTypeIdByName(buildType)
			local footPrint = self:_createFootPrints(snapPos, dimension.Length * dimension.Width)

			-- เปลี่ยนไปใช้ CreatingBuilding Template แทนพอสร้างเสร้จค่อให้โมเดลจริง
			-- local model = self:_createBuilding(buildType, snapPos)
			-- if not model then
			-- 	warn(`[BuildingController] Failed to create building model for {buildType} at position {snapPos}`)
			-- 	return
			-- end

			-- สร้างmodel คนสร้างออกมา จาก Crate upgrad
			local model = self:_GetBuilderModel(CONFIG.STARTER_LEVEL, startX, startZ, dimension.Length, dimension.Width)
			if not model then
				warn(`[BuildingController] Failed to create builder model for {buildType} at position {snapPos}`)
				return
			end
			model.Parent = self._PlayerFolder

			self:_requestPlaceBuilding(startX, startZ, buildingEnum, snapPos)
			self._GridController:occupyCell(snapPos, dimension.Length, dimension.Width)

			-- เก็บcache ไว้ก่อน โยยไม่รอserver
			local buildingCount = self._buildingCount :: number
			local nextbuildingId = `n{buildingCount + 1}`
			local BuildingData = BuildingConfig:GetBuildingDataByEnum(buildingEnum, CONFIG.NEXT_LEVEL)
			local builTime = os.time() + BuildingData.UpgradeTime

			self:RegisterBuildingCache(
				nextbuildingId,
				startX,
				startZ,
				buildingEnum,
				CONFIG.STARTER_LEVEL,
				builTime,
				0,
				model
			)

			self:_RegisterBuilderStore(
				nextbuildingId,
				startX,
				startZ,
				buildingEnum,
				CONFIG.STARTER_LEVEL,
				builTime,
				0,
				model
			)
			model.Name = nextbuildingId
			footPrint.Parent = model

			self._buildingCount = buildingCount + 1
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
	local buildingType = GameEnum:GetBuildingTypeById(buildingEnum)
	if not buildingType then
		warn(`[BuildingController] Invalid building enum {buildingEnum} for buildingId {buildingId}`)
		return
	end

	local dimension = BuildingConfig:GetBuildingDimensions(buildingType)
	if not dimension then
		return
	end

	local worldPos = self._GridController:GridCoordsToWorld(gridx, gridz, dimension.Length, dimension.Width)
	local model = self:_createBuilding(buildingType, worldPos, buildingLevel)
	if not model then
		warn(`[BuildingController] Failed to create building model for {buildingType} at position {worldPos}`)
		return
	end
	model.Name = buildingId
	model.Parent = self._PlayerFolder

	local footPrint = self:_createFootPrints(worldPos, dimension.Length * dimension.Width)
	footPrint.Parent = model
	self._GridController:occupyCell(worldPos, dimension.Length, dimension.Width)

	local collectorType = BuildingConfig:GetCollectorType(buildingType)
	if collectorType then
		self._ResourceController:RegisterclickDetector(collectorType, model)
	end

	self:RegisterBuildingCache(buildingId, gridx, gridz, buildingEnum, buildingLevel, endTime, lastCollectedTime, model)

	if endTime ~= 0 then
		self:_RegisterBuilderStore(
			buildingId,
			gridx,
			gridz,
			buildingEnum,
			buildingLevel,
			endTime,
			lastCollectedTime,
			model
		)
	end
end

function BuildingController:_stopPlacement()
	self._isPlacing = false
	if self._renderConnection then
		self._renderConnection:Disconnect()
		self._renderConnection = nil
	end

	if self._Connetion then
		self._Connetion:Disconnect()
		self._Connetion = nil
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
