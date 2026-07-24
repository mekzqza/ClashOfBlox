--!strict

--[[
    -- เก็บ current vision ของผู้เล่นที่กำจะถูกโจมตี
    -- ถ้ากดอะรก็ตาม จะเข้าสู่ Battlemode เพื่อจัดการ Simulation ของการโจมตี

]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local Pathfinding = require(ReplicatedStorage.Shared.Pathfinding)
local Simulation = require(ReplicatedStorage.Shared.Simulation)
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)

local CONFIG = {
	CELL_SIZE = 4, --stud
	STRIDE = 100, --stud
	KEYSTORE = {
		["Gridx"] = 1,
		["Gridz"] = 2,
		["BuildingEnum"] = 3,
		["BuildingLevel"] = 4,
		["EndTime"] = 5,
		["LastCollectedTime"] = 6,
	},
	INTERVAL = 0.1, -- วินาที
	MATCH_TIMEOUT = 20, -- วินาที
	CREATE_BUILDING_TEMPLATE = "CreatingBuilding",
}

local BattleController = {}
local EventHandler: { [number]: (any, Simulation.SimEvent) -> () } = {}
BattleController.__index = BattleController
function BattleController.new()
	local self = setmetatable({}, BattleController)
	self._BattleFolder = nil :: Folder?
	self._victem = nil :: Player?

	-- game simulation state
	self._state = {} :: Simulation.State

	-- Data Visualization
	self._currentUnitId = 1
	self._units = {} :: { [string]: Simulation.UnitState }
	self._buildings = {} :: { [string]: Simulation.BuildingState }
	self._buildingPositionGolas = {} :: { [string]: { Simulation.GridPosition } }

	--Model Visualization
	self._UnitsTemplate = nil
	self._unitModels = {} :: { [string]: Model }
	self._buildingModels = {} :: { [string]: Model }

	self._unitVisuals = {} :: { [string]: { Prev: Vector3, Current: Vector3, StartTime: number, Duration: number } }
	-- ระยะเยื้องจากกลาง cell ตอนวาง unit ครั้งแรก (visual เท่านั้น — simulation อยู่บน grid ล้วน)
	self._unitOffsets = {} :: { [string]: Vector3 }
	self._runServiceConnection = nil :: RBXScriptConnection?

	-- FlowField ของBuildingแต่ละตัว
	self._flowFields = {} :: { [string]: Pathfinding.FlowField }
	self._validCells = {} :: { [number]: true }
	self._occupiedCells = {} :: { [number]: true }

	self._isFindingRaid = false
	self._isRaidStarted = false
	self._isRaiding = false
	self._macthConnection = nil
	self._matchStartTime = 0 :: number

	self._isReady = false
	self._onReadyCallback = nil :: ((BasePart) -> ())?
	self._gridOriginX = 0 :: number
	self._gridOriginZ = 0 :: number
	self._gridSurfaceY = 0 :: number

	self._UnitController = nil

	return self
end

function BattleController:SetDependencies(locator)
	self._UnitController = locator:Get("UnitController")
	self._BuildingController = locator:Get("BuildingController")
end

function BattleController:_gridKeyfromCoords(gridx: number, gridz: number): number
	return gridx * CONFIG.STRIDE + gridz
end

function BattleController:GridCoordsToWorld(startX: number, startZ: number, sizeX: number, sizeZ: number): Vector3
	local x = self._gridOriginX + startX * CONFIG.CELL_SIZE + sizeX * CONFIG.CELL_SIZE / 2
	local z = self._gridOriginZ + startZ * CONFIG.CELL_SIZE + sizeZ * CONFIG.CELL_SIZE / 2
	return Vector3.new(x, self._gridSurfaceY, z)
end

function BattleController:RegisterZone(part: BasePart)
	self._gridOriginX = part.Position.X - part.Size.X / 2
	self._gridOriginZ = part.Position.Z - part.Size.Z / 2
	self._gridSurfaceY = part.Position.Y + part.Size.Y / 2
	local xCells = math.ceil(part.Size.X / CONFIG.CELL_SIZE)
	local zCells = math.ceil(part.Size.Z / CONFIG.CELL_SIZE)

	for x = 0, xCells - 1 do
		for z = 0, zCells - 1 do
			self._validCells[self:_gridKeyfromCoords(x, z)] = true
		end
	end

	self._isReady = true
	if self._onReadyCallback then
		self._onReadyCallback(part)
		self._onReadyCallback = nil
	end
end

function BattleController:GetFootPrintStart(position: Vector3, sizeX: number?, sizeZ: number?): (number, number)
	local halfX = (sizeX or 1) * CONFIG.CELL_SIZE / 2
	local halfZ = (sizeZ or 1) * CONFIG.CELL_SIZE / 2
	local startX = math.floor((position.X - self._gridOriginX - halfX) / CONFIG.CELL_SIZE)
	local startZ = math.floor((position.Z - self._gridOriginZ - halfZ) / CONFIG.CELL_SIZE)
	return startX, startZ
end

function BattleController:GetFootPrintCells(position: Vector3, sizeX: number?, sizeZ: number?): { [number]: true }
	local sx = sizeX or 1
	local sz = sizeZ or 1
	local startX, startZ = self:GetFootPrintStart(position, sx, sz)

	local cells: { [number]: true } = {}
	for x = 0, sx - 1 do
		for z = 0, sz - 1 do
			cells[self:_gridKeyfromCoords(startX + x, startZ + z)] = true
		end
	end
	return cells
end

function BattleController:occupyCell(position: Vector3, sizeX: number?, sizeZ: number?)
	local sx = sizeX or 1
	local sz = sizeZ or 1
	local startX, startZ = self:GetFootPrintStart(position, sx, sz)

	for x = 0, sx - 1 do
		for z = 0, sz - 1 do
			local key = self:_gridKeyfromCoords(startX + x, startZ + z)
			if self._validCells[key] then
				self._occupiedCells[key] = true
			end
		end
	end
end

function BattleController:freeCell(position: Vector3, sizeX: number?, sizeZ: number?)
	local sx = sizeX or 1
	local sz = sizeZ or 1
	local startX, startZ = self:GetFootPrintStart(position, sx, sz)

	for x = 0, sx - 1 do
		for z = 0, sz - 1 do
			local key = self:_gridKeyfromCoords(startX + x, startZ + z)
			if self._validCells[key] then
				self._occupiedCells[key] = nil
			end
		end
	end
end

function BattleController:SpawnUnit(unitEnum: number, unitLevel, position: Simulation.GridPosition, offset: Vector3?)
	if not self._state.Units then
		self._state.Units = {}
	end
	local unitId = "Unit_" .. tostring(self._currentUnitId)

	local unit = Simulation.RegisterUnit(unitId, unitEnum, unitLevel, position)
	if not unit then
		warn("[BattleController] Failed to register unit with ID: " .. unitId)
		return
	end

	local unitModel = self._UnitController:GetUnit(GameEnum:GetUnitTypeById(unitEnum), unitLevel)
	if not unitModel then
		warn("[BattleController] Failed to create unit model for unitId: " .. unitId)
		return
	end
	unitModel.Name = unitId
	unitModel.Parent = self._BattleFolder
	self._unitOffsets[unitId] = offset or Vector3.zero
	local worldPos = self:GridCoordsToWorld(position.GridX, position.GridZ, 1, 1) :: Vector3 + self._unitOffsets[unitId]
	unitModel:PivotTo(CFrame.new(worldPos))
	self._unitModels[unitId] = unitModel

	self._units[unitId] = unit
	table.insert(self._state.Units, self._units[unitId])

	self._currentUnitId += 1
end

function BattleController:_getListOfFootPrintCells(
	buildingPosition: Simulation.GridPosition,
	sizeX: number,
	sizeZ: number
): { Simulation.GridPosition }
	local cells: { Simulation.GridPosition } = {}
	for x = 0, sizeX - 1 do
		for z = 0, sizeZ - 1 do
			table.insert(cells, { GridX = buildingPosition.GridX + x, GridZ = buildingPosition.GridZ + z })
		end
	end
	return cells
end

EventHandler[Simulation.EVENT.Unit_Attack] = function(self, event: Simulation.SimEvent)
	-- @TODO play attack animation for unit and update building health bar
end

EventHandler[Simulation.EVENT.Building_Destroyed] = function(self, event: Simulation.SimEvent)
	local buildingId = event.BuildingId
	if not buildingId then
		return
	end

	-- @TODO play building destroyed animation แล้วค่อยลบ model
	local model = self._buildingModels[buildingId]
	if model then
		model:Destroy()
		self._buildingModels[buildingId] = nil
	end

	local building = self._buildings[buildingId]
	if building then
		local sizeX = building.Dimensions.Width
		local sizeZ = building.Dimensions.Length
		local worldPosition = self:GridCoordsToWorld(building.Position.GridX, building.Position.GridZ, sizeX, sizeZ)
		self:freeCell(worldPosition, sizeX, sizeZ)
	end

	-- ตึกหาย → ทางเดินเปลี่ยน ทิ้ง flow field ทั้งหมดให้สร้างใหม่
	self._flowFields = {}
end

EventHandler[Simulation.EVENT.Unit_Died] = function(self, event: Simulation.SimEvent)
	local unitId = event.UnitId
	if not unitId then
		return
	end

	-- @TODO play unit death animation ให้จบก่อนแล้วค่อย recycle (ต้อง Stop track ก่อนคืน pool)
	local model = self._unitModels[unitId]
	if model then
		self._UnitController:RecycleUnit(model)
		self._unitModels[unitId] = nil
	end
	self._unitVisuals[unitId] = nil
	self._unitOffsets[unitId] = nil
end

function BattleController:StartRiding()
	EventBus:Emit(Events.LOCAL_MODE_CHANGED, "Raid")

	if not self._state.Tick or not self._state.Buildings or not self._state.Spells then
		self._state.Buildings = self._state.Buildings or {}
		self._state.Tick = 0
		self._state.Units = {}
		self._state.Spells = {}
	end
	self._isRaiding = true

	self._runServiceConnection = RunService.Heartbeat:Connect(function()
		for unitId, visual in self._unitVisuals do
			local alpha = math.clamp((os.clock() - visual.StartTime) / visual.Duration, 0, 1)
			local model = self._unitModels[unitId]
			if model then
				local prevPos = visual.Prev
				local currentPos = visual.Current
				local interpolatedPos = prevPos:Lerp(currentPos, alpha)
				model:PivotTo(CFrame.new(interpolatedPos))
			end
		end
	end)

	self._macthConnection = task.spawn(function()
		local startTime = tick()
		local endTime = startTime + CONFIG.MATCH_TIMEOUT
		while self._isRaiding and tick() < endTime do
			local _, stateEvents = Simulation.stepTick(self._state, self._flowFields)

			for _, event in stateEvents do
				local handler = EventHandler[event.Type]
				if handler then
					handler(self, event)
				else
					warn("[BattleController] No handler for event type: " .. event.Type)
				end
			end

			--@Unit Loop
			for _, unit in self._state.Units do
				local unitId = unit.UnitId
				if not unitId then
					warn("[BattleController] Unit has no UnitId, skipping")
					continue
				end

				--@TODO play animation ตาม unit.state (สลับเฉพาะตอน state เปลี่ยน)
				warn("[BattleController] Unit state: " .. unitId .. " is " .. unit.state)

				local unitTargetId = unit.TargetId

				if unitTargetId then
					if not self._flowFields[unitTargetId] then
						self._flowFields[unitTargetId] =
							Pathfinding.buildFlowField(self._buildingPositionGolas[unitTargetId], {
								MinX = 0,
								MaxX = 50,
								MinZ = 0,
								MaxZ = 50,
							}, self._occupiedCells)
					end
				end
				local unitState = self._units[unitId]
				if not unitState or unit.Hp <= 0 then
					continue
				end

				local currentWorld = self:GridCoordsToWorld(
						unit.Position.GridX,
						unit.Position.GridZ,
						1,
						1
					) :: Vector3 + (self._unitOffsets[unitId] or Vector3.zero)
				local oldVisual = self._unitVisuals[unitId]
				if not oldVisual or (oldVisual.Current :: Vector3) ~= currentWorld then
					self._unitVisuals[unitId] = {
						Prev = oldVisual and oldVisual.Current or currentWorld,
						Current = currentWorld,
						StartTime = os.clock(),
						Duration = if (10 / unit.WalkSpeed) * CONFIG.INTERVAL == 0
							then CONFIG.INTERVAL
							else (10 / unit.WalkSpeed) * CONFIG.INTERVAL,
					}
				end
			end

			task.wait(CONFIG.INTERVAL)
		end
		self:MatchEnd()
		warn("[BattleController] Match ended after " .. (tick() - startTime) .. " seconds")
	end)
end

function BattleController:ResetRaidState()
	self._buildings = {}
	self._units = {}
	self._occupiedCells = {}

	if self._buildingModels then
		for _, model in self._buildingModels do
			if model and model.Parent then
				model:Destroy()
			end
		end
		self._buildingModels = {}
	end
end

--  @TODOขาดUnit ตายหมด ,สิ่งก่อสร้างพังหมด
function BattleController:MatchEnd()
	self._isRaiding = false
	self._isRaidStarted = false
	self._currentUnitId = 1

	if self._macthConnection then
		self._macthConnection = nil
	end
	self._state.Tick = 0
	self._state.Buildings = {}
	self._state.Units = {}
	self._state.Spells = {}
	self._flowFields = {}
	self._occupiedCells = {}
	self._units = {}
	self._buildings = {}
	self._unitVisuals = {}
	self._unitOffsets = {}
	self._buildingPositionGolas = {}

	if self._runServiceConnection then
		self._runServiceConnection:Disconnect()
		self._runServiceConnection = nil
	end

	-- ในอนาคตจะทำ unit polling
	if self._unitModels then
		for _, model in self._unitModels do
			if model and model.Parent then
				self._UnitController:RecycleUnit(model)
			end
		end
		self._unitModels = {}
	end

	if self._buildingModels then
		for _, model in self._buildingModels do
			if model and model.Parent then
				model:Destroy()
				warn("[BattleController] Destroying building model: " .. model.Name)
			end
		end
		self._buildingModels = {}
	end

	self._matchStartTime = 0
	EventBus:Emit(Events.LOCAL_RAID_ENDED)
	EventBus:Emit(Events.LOCAL_MODE_CHANGED, "OwnHome")
end

function BattleController:Init()
	if not self._UnitController then
		warn("[BattleController] UnitController dependency not set")
		return
	end
end

function BattleController:Start()
	EventBus:On(Events.LOCAL_FOUND_RAID_TARGET, function(data)
		if not data then
			warn("[BattleController] No player data received (timeout)")
			return
		end

		local Mapskin = data.MapSkin
		if not Mapskin then
			warn("[BattleController] No map skin data found for player")
			return
		end

		local buildings = data.Buildings
		if not buildings then
			warn("[BattleController] No building data found for player")
			return
		end

		self._state.Buildings = {}
		for buildingId, buildingdata in buildings do
			local building = Simulation.RegisterBuilding(
				buildingId,
				buildingdata[CONFIG.KEYSTORE["Gridx"]],
				buildingdata[CONFIG.KEYSTORE["Gridz"]],
				buildingdata[CONFIG.KEYSTORE["BuildingEnum"]],
				buildingdata[CONFIG.KEYSTORE["BuildingLevel"]],
				buildingdata[CONFIG.KEYSTORE["EndTime"]],
				buildingdata[CONFIG.KEYSTORE["LastCollectedTime"]]
			)
			if not building then
				warn("[BattleController] Failed to register building with ID: " .. buildingId)
				continue
			end

			self._buildings[buildingId] = building
			local buildPosion = self:GridCoordsToWorld(
				buildingdata[CONFIG.KEYSTORE["Gridx"]],
				buildingdata[CONFIG.KEYSTORE["Gridz"]],
				self._buildings[buildingId].Dimensions.Width,
				self._buildings[buildingId].Dimensions.Length
			)
			self:occupyCell(
				buildPosion,
				self._buildings[buildingId].Dimensions.Width,
				self._buildings[buildingId].Dimensions.Length
			)
			self._buildingPositionGolas[buildingId] =
				self:_getListOfFootPrintCells(building.Position, building.Dimensions.Width, building.Dimensions.Length)
			local buildingType = GameEnum:GetBuildingTypeById(building.BuildingEnum)
			local model = self._BuildingController:_createBuilding(buildingType, buildPosion, building.BuildingLevel)
			local footprint = self._BuildingController:_createFootPrints(
				buildPosion,
				building.Dimensions.Width * building.Dimensions.Length
			)
			footprint.Parent = model
			model.Parent = self._BattleFolder
			self._buildingModels[buildingId] = model
			table.insert(self._state.Buildings, self._buildings[buildingId])
		end
	end)

	EventBus:On(Events.LOCAL_DEPLOY_UNIT, function(data)
		if not self._isRaiding then
			self:StartRiding()
		end

		local unitEnum = data.UnitEnum
		if not unitEnum then
			warn("[BattleController] No unit enum data received for deployment")
			return
		end

		local girdPosition = data.GirdPosition
		if not girdPosition then
			warn("[BattleController] No grid position data received for unit deployment")
			return
		end
		local unitLevel = data.UnitLevel or 1
		self:SpawnUnit(unitEnum, unitLevel, girdPosition, data.Offset)
	end)

	EventBus:On(Events.LOCAL_FOLDER_READY, function(data)
		local folder = data.Folder
		local gridPart = folder:WaitForChild("GridPart", 30)
		if not gridPart then
			warn(`[BattleController] Grid part not found for folder: {data.FolderName}`)
			return
		end
		local logicPart = gridPart:WaitForChild("LogicPart", 30)
		if not logicPart or not logicPart:IsA("BasePart") then
			warn(`[BattleController] Logic part not found or not a BasePart for folder: {data.FolderName}`)
			return
		end

		self._BattleFolder = folder:WaitForChild("BattleFolder", 30)
		if not self._BattleFolder or not self._BattleFolder:IsA("Folder") then
			warn(`[BattleController] Battle folder not found or not a Folder for folder: {data.FolderName}`)
			return
		end
		self:RegisterZone(logicPart)
	end)

	EventBus:On(Events.LOCAL_TOGGLE_UI, function(targetWindow)
		if targetWindow == "Test_Raid" then
			EventBus:Emit(Events.C2S_REQUEST_FINDING_RAID)
		end
	end)
end

return BattleController.new()
