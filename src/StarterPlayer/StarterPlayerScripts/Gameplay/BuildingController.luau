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
	DEFAULT_FOOTPRINT_COLOR = Color3.fromRGB(117, 161, 37),
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

	-- @TODO
	-- HARD_CODE Building Position เพื่อให้ สามารถทดสอบการย้ายได้ง่ายขึ้น อาคารไม่ทับกับตอนเข้า buildingMove mode
}

export type BuilderRecord = {
	Gridx: number,
	Gridz: number,
	BuildingEnum: number,
	BuildingLevel: number,
	EndTime: number,
	LastCollectedTime: number,
	BuildingModel: Model,
}

local BuildingController = {}
BuildingController.__index = BuildingController
function BuildingController.new()
	local self = setmetatable({}, BuildingController)
	self._BuilderStore = {} :: { [string]: BuilderRecord }

	self._currentBuilder = 0
	self._isPlacing = false
	self._renderConnection = nil
	self._indicatorModel = nil
	self._Connetion = nil
	self._moveSession = nil
	self._PlayerFolder = nil
	self._RuntimeChecker = nil

	self._footPrintindicator = nil
	self._BuildingTemplate = nil
	self._GridController = nil
	self._PlayerDataController = nil
	self._ResourceController = nil
	self._BuilderHutController = nil
	self._BuildingStore = nil
	return self
end

function BuildingController:SetDependencies(locator)
	self._PlayerDataController = locator:Get("PlayerDataController")
	self._ResourceController = locator:Get("ResourceController")
	self._GridController = locator:Get("GridController")
	self._BuilderHutController = locator:Get("BuilderHutController")
	self._BuildingStore = locator:Get("BuildingStore")
end

function BuildingController:_syncToserver(buildingId: string, gridx: number, gridz: number, position: Vector3)
	EventBus:Emit(Events.C2S_UPDATE_BUILDING_POSITION, {
		BuildingId = buildingId,
		Gridx = gridx,
		Gridz = gridz,
		Position = position,
	})
end

function BuildingController:BuildingComplete(buildingId: string)
	local building = self._BuildingStore:GetBuildingData(buildingId)
	if not building then
		warn(`[BuildingController] No builder data found for buildingId {buildingId} on construction complete`)
		return
	end

	local buildingType = GameEnum:GetBuildingTypeById(building.BuildingEnum)
	local dimension = BuildingConfig:GetBuildingDimensions(buildingType)
	if not dimension then
		warn(`[BuildingController] Building config for {buildingType} not found on construction complete`)
		return
	end

	local nextlevel = building.BuildingLevel + CONFIG.NEXT_LEVEL
	local worldPos =
		self._GridController:GridCoordsToWorld(building.Gridx, building.Gridz, dimension.Length, dimension.Width)

	local model = self:_createBuilding(buildingType, worldPos, nextlevel)
	if not model then
		warn(`[BuildingController] Failed to create completed building model for buildingId {buildingId}`)
		return
	end
	model.Name = buildingId

	local footPrint = self:_createFootPrints(worldPos, dimension.Length * dimension.Width)
	if footPrint then
		footPrint.Parent = model
		model.PrimaryPart = footPrint
	end

	self._BuilderStore[buildingId] = nil
	self._BuilderHutController:BuildingComplated(building.BuildingModel)
	if building.BuildingModel then
		building.BuildingModel:Destroy()
	end

	building.EndTime = 0
	building.BuildingLevel = nextlevel
	building.BuildingModel = model

	local collectorType = BuildingConfig:GetCollectorType(buildingType)
	if collectorType then
		self._ResourceController:RegisterclickDetector(collectorType, model)
	end
	self._ResourceController:RegisterColector(buildingId, building.BuildingEnum, nextlevel)

	EventBus:Emit(Events.C2S_BUILDING_CONSTRUCTION_COMPLETE, {
		BuildingId = buildingId,
	})

	self._currentBuilder -= 1
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
				else
					self._BuilderHutController:UpdateBuildingProgressBar(data.BuildingModel)
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

function BuildingController:_CloneConstructionVisual(
	templatename: string,
	gridx: number,
	gridz: number,
	sizex: number,
	sizez: number
): Model?
	local template = self._BuildingTemplate:FindFirstChild(templatename, true)
	if not template then
		warn(`[BuildingController] Upgrade building template not found in BuildingTemplate`)
		return
	end

	local gridsize = sizex * sizez
	local gridModel = template:FindFirstChild(CONFIG.GRID_KEY[gridsize], true)
	if not gridModel then
		warn(`[BuildingController] Construction visual model with grid size {gridsize} not found in BuildingTemplate`)
		return
	end
	local model = gridModel:Clone()

	local worldPos = self._GridController:GridCoordsToWorld(gridx, gridz, sizex, sizez)
	local primaryPart1 = model.PrimaryPart :: BasePart
	local haft = primaryPart1.Size.Y / 2
	model:PivotTo(CFrame.new(worldPos.X, worldPos.Y + haft + CONFIG.HEIGHT, worldPos.Z))
	return model
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

	local buildingData = BuildingConfig:GetBuildingDataByEnum(buildingEnum, buildingLevel + CONFIG.NEXT_LEVEL)
	local startTime = if buildingData then endtime - buildingData.UpgradeTime else os.time()
	self._BuilderHutController:RegisterBuildingProgressBar(model, endtime, startTime)

	self._currentBuilder += 1

	self:_ensureRuntimeChecker()
end

function BuildingController:_createFootPrints(position: Vector3, size: number): BasePart?
	local template = self._BuildingTemplate:FindFirstChild(CONFIG.FOOTPRINTS_TEMPLATE, true)
	if not template then
		warn(`[BuildingController] Footprints template not found in BuildingTemplate`)
		return
	end

	local footPrintTemplate = template:FindFirstChild(CONFIG.GRID_KEY[size], true)
	if not footPrintTemplate then
		warn(`[BuildingController] Footprints model with size {size} not found in BuildingTemplate`)
		return
	end
	local newFootPrint = footPrintTemplate:Clone() :: BasePart

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
	-- @TODO ทำใ้รองรับมือถือ
	self._Connetion = mouse.Button1Down:Connect(function()
		if self._currentBuilder >= self._PlayerDataController:GetAll().BuilderHutSlot then
			warn(`[BuildingController] All builder huts are currently occupied. Cannot place new building.`)
			return
		end

		local snapPos =
			self._GridController:SnapToGrid(mouse.Hit.Position, dimension.Length, dimension.Width) :: Vector3
		if self._GridController:CanPlace(snapPos, dimension.Length, dimension.Width) then
			local startX, startZ = self._GridController:GetFootPrintStart(snapPos, dimension.Length, dimension.Width)
			local buildingEnum = GameEnum:GetBuildingTypeIdByName(buildType)
			local footPrint = self:_createFootPrints(snapPos, dimension.Length * dimension.Width)

			local model = Instance.new("Model")
			local modelUpgrade = self:_CloneConstructionVisual(
				CONFIG.UPGRADE_BUILDING_TEMPLATE,
				startX,
				startZ,
				dimension.Length,
				dimension.Width
			)
			local modelCreate = self:_CloneConstructionVisual(
				CONFIG.CREATE_BUILDING_TEMPLATE,
				startX,
				startZ,
				dimension.Length,
				dimension.Width
			)

			footPrint.Parent = model
			modelUpgrade.Parent = model
			modelCreate.Parent = model
			model.PrimaryPart = footPrint
			model.Parent = self._PlayerFolder

			self:_requestPlaceBuilding(startX, startZ, buildingEnum, snapPos)
			self._GridController:occupyCell(snapPos, dimension.Length, dimension.Width)

			local buildingCount = self._BuildingStore:GetbuildingCount() :: number
			local nextbuildingId = `n{buildingCount + 1}`
			local BuildingData = BuildingConfig:GetBuildingDataByEnum(buildingEnum, CONFIG.NEXT_LEVEL)
			local builTime = os.time() + BuildingData.UpgradeTime

			self._BuildingStore:AddBuilding(
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

	local model = Instance.new("Model")

	local modelCrate = nil
	local modelUpgrade = nil
	if buildingLevel == CONFIG.STARTER_LEVEL then
		modelCrate = self:_CloneConstructionVisual(
			CONFIG.UPGRADE_BUILDING_TEMPLATE,
			gridx,
			gridz,
			dimension.Length,
			dimension.Width
		)
		modelUpgrade = self:_CloneConstructionVisual(
			CONFIG.CREATE_BUILDING_TEMPLATE,
			gridx,
			gridz,
			dimension.Length,
			dimension.Width
		)
		modelCrate.Parent = model
		modelUpgrade.Parent = model

		self:_RegisterBuilderStore(buildingId, gridx, gridz, buildingEnum, CONFIG.STARTER_LEVEL, endTime, 0, model)
	elseif endTime ~= 0 then
		modelCrate = self:_createBuilding(buildingType, worldPos, buildingLevel)
		modelUpgrade = self:_CloneConstructionVisual(
			CONFIG.UPGRADE_BUILDING_TEMPLATE,
			gridx,
			gridz,
			dimension.Length,
			dimension.Width
		)

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

		modelUpgrade.Parent = model
		modelCrate.Parent = model
	else
		modelCrate = self:_createBuilding(buildingType, worldPos, buildingLevel)
		local collectorType = BuildingConfig:GetCollectorType(buildingType)
		if collectorType then
			self._ResourceController:RegisterclickDetector(collectorType, modelCrate)
		end
		self._ResourceController:RegisterColector(buildingId, buildingEnum, buildingLevel)

		modelCrate.Parent = model
	end

	if not model then
		warn(`[BuildingController] Failed to create building model for {buildingType} at position {worldPos}`)
		return
	end

	local footPrint = self:_createFootPrints(worldPos, dimension.Length * dimension.Width) :: BasePart
	self._GridController:occupyCell(worldPos, dimension.Length, dimension.Width)

	footPrint.Parent = model
	model.Name = buildingId
	model.Parent = self._PlayerFolder
	model.PrimaryPart = footPrint

	self._BuildingStore:AddBuilding(
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

	self._moveSession = nil

	if self._indicatorModel then
		self._indicatorModel:Destroy()
		self._indicatorModel = nil
	end

	if self._footPrintindicator then
		self._footPrintindicator:Destroy()
		self._footPrintindicator = nil
	end
end

function BuildingController:MoveBuilding(buildingId: string)
	local buildingData = self._BuildingStore:GetBuildingData(buildingId)
	if not buildingData then
		warn(`[BuildingController] No building data found for buildingId {buildingId} on move request`)
		return
	end

	local buildingModel = buildingData.BuildingModel
	if not buildingModel then
		warn(`[BuildingController] No building model found for buildingId {buildingId} on move request`)
		return
	end

	self:_stopPlacement()

	self._isPlacing = true

	local primaryPart: BasePart? = buildingModel.PrimaryPart
	if not primaryPart then
		warn(`[BuildingController] No primary part found for buildingId {buildingId} on move request`)
		return
	end

	local texture = primaryPart:FindFirstChild("Texture") :: Texture
	if not texture then
		warn(`[BuildingController] No texture found on primary part of buildingId {buildingId} during move request`)
		return
	end

	local dimension = BuildingConfig:GetBuildingDimensions(GameEnum:GetBuildingTypeById(buildingData.BuildingEnum))
	if not dimension then
		warn(`[BuildingController] Building config for buildingId {buildingId} not found on move request`)
		return
	end

	local oldPosition = self._GridController:GridCoordsToWorld(
		buildingData.Gridx,
		buildingData.Gridz,
		dimension.Length,
		dimension.Width
	) :: Vector3

	self._moveSession = {
		buildingId = buildingId,
		buildingModel = buildingModel,
		buildingData = buildingData,
		dimension = dimension,
		oldPosition = oldPosition,
		currentPosition = oldPosition,
		canPlace = true,
		ignoreCells = self._GridController:GetFootPrintCells(oldPosition, dimension.Length, dimension.Width),
		halfHeight = primaryPart.Size.Y / 2,
		PrimaryPart = primaryPart,
		FootPrintTexture = texture,
	}
end

function BuildingController:_updateMovePreview(position: Vector3)
	local session = self._moveSession
	if not session then
		return
	end

	local model = session.buildingModel
	if not model then
		return
	end

	local primaryPart = session.PrimaryPart
	if not primaryPart then
		return
	end

	local texture = session.FootPrintTexture
	if not texture then
		warn(
			`[BuildingController] No texture found in move session for buildingId {session.buildingId} during move preview update`
		)
		return
	end

	local snapPos =
		self._GridController:SnapToGrid(position, session.dimension.Length, session.dimension.Width) :: Vector3
	local canPlace =
		self._GridController:CanPlace(snapPos, session.dimension.Length, session.dimension.Width, session.ignoreCells)

	session.currentPosition = snapPos
	session.canPlace = canPlace

	texture.Color3 = if canPlace then Color3.new(0, 1, 0) else Color3.new(1, 0, 0)

	model:SetPrimaryPartCFrame(CFrame.new(snapPos.X, snapPos.Y + session.halfHeight + CONFIG.HEIGHT, snapPos.Z))
end

function BuildingController:_confirmMove()
	local session = self._moveSession
	if not session then
		return
	end

	-- ปล่อยบนช่องแดง → ไม่ commit ไม่ revert ปล่อยให้อาคารค้างที่เดิม(แดง)
	-- การกลับ oldPosition จะเกิดตอนผู้เล่นคลิกอย่างอื่น (ดู handler LOCAL_MOVE_BUILDING)
	if not session.canPlace then
		return
	end

	local newsnapPos = session.currentPosition :: Vector3
	local startX, startZ =
		self._GridController:GetFootPrintStart(newsnapPos, session.dimension.Length, session.dimension.Width)
	session.buildingModel:SetPrimaryPartCFrame(
		CFrame.new(newsnapPos.X, newsnapPos.Y + session.halfHeight + CONFIG.HEIGHT, newsnapPos.Z)
	)

	self._BuildingStore:SetBuildingData(session.buildingId, {
		Gridx = startX,
		Gridz = startZ,
		BuildingEnum = session.buildingData.BuildingEnum,
		BuildingLevel = session.buildingData.BuildingLevel,
		EndTime = session.buildingData.EndTime,
		LastCollectedTime = session.buildingData.LastCollectedTime,
		BuildingModel = session.buildingModel,
	})

	self._GridController:freeCell(session.oldPosition, session.dimension.Length, session.dimension.Width)
	self._GridController:occupyCell(newsnapPos, session.dimension.Length, session.dimension.Width)

	self:_syncToserver(session.buildingId, startX, startZ, newsnapPos)

	if session.FootPrintTexture then
		session.FootPrintTexture.Color3 = CONFIG.DEFAULT_FOOTPRINT_COLOR
	end

	self:_stopPlacement()
end

function BuildingController:_cancelMove()
	local session = self._moveSession
	if not session then
		return
	end

	local oldPos = session.oldPosition :: Vector3
	session.buildingModel:SetPrimaryPartCFrame(
		CFrame.new(oldPos.X, oldPos.Y + session.halfHeight + CONFIG.HEIGHT, oldPos.Z)
	)

	if session.FootPrintTexture then
		session.FootPrintTexture.Color3 = CONFIG.DEFAULT_FOOTPRINT_COLOR
	end

	self:_stopPlacement()
end

function BuildingController:Init()
	self._BuildingTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Structure")
	if not self._BuildingTemplate then
		warn("[BuildingController] Building template folder not found in ReplicatedStorage.Assets")
		return
	end
end

function BuildingController:Start()
	EventBus:On(Events.LOCAL_FOLDER_READY, function(data)
		self._PlayerFolder = data.Folder
	end)

	EventBus:On(Events.LOCAL_TEST_BUILDING, function(building: string)
		if building == nil or building == "" then
			self:_stopPlacement()
			return
		end
		warn(`[BuildingController] Test building: {building}`)
		self:_stopPlacement()
		self:_startPlacement(building)
	end)

	EventBus:On(Events.LOCAL_MOVE_BUILDING, function(buildingId: string?)
		if self._moveSession then
			self:_cancelMove()
		end
		if buildingId == nil or buildingId == "" then
			return
		end
		self:MoveBuilding(buildingId)
	end)

	EventBus:On(Events.LOCAL_MOVE_BUILDING_UPDATE, function(position: Vector3)
		self:_updateMovePreview(position)
	end)

	EventBus:On(Events.LOCAL_MOVE_BUILDING_CONFIRM, function()
		self:_confirmMove()
	end)

	self._PlayerDataController:WaitForDataReady():andThen(function(data)
		if not data then
			warn("[BuildingController] No player data received (timeout)")
			return
		end

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
		end
	end)
end

return BuildingController.new()
