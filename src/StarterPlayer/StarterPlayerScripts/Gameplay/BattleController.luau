--!strict

--[[
    -- เก็บ current vision ของผู้เล่นที่กำจะถูกโจมตี
    -- ถ้ากดอะรก็ตาม จะเข้าสู่ Battlemode เพื่อจัดการ Simulation ของการโจมตี

]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local Pathfinding = require(ReplicatedStorage.Shared.Pathfinding)
local Simulation = require(ReplicatedStorage.Shared.Simulation)
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)

local CONFIG = {
	CELL_SIZE = 4,
	STRIDE = 100,
	KEYSTORE = {
		["Gridx"] = 1,
		["Gridz"] = 2,
		["BuildingEnum"] = 3,
		["BuildingLevel"] = 4,
		["EndTime"] = 5,
		["LastCollectedTime"] = 6,
	},
	INTERVAL = 0.1, -- วินาที
	MAX_QUEUE_SIZE = 1000,
	MATCH_TIMEOUT = 20, -- วินาที
	GRID_DISTANCE_INSTUD = 1000, -- smoothly move unit to target (in studs)
}

local BattleController = {}
BattleController.__index = BattleController
function BattleController.new()
	local self = setmetatable({}, BattleController)
	self._BattleFolder = nil :: Folder?
	self._victem = nil :: Player?

	self._state = {} :: Simulation.State

	self._currentUnitId = 1
	self._units = {} :: { [string]: Simulation.UnitState }
	self._buildings = {} :: { [string]: Simulation.BuildingState }

	-- FlowField ของBuildingแต่ละตัว
	self._flowFields = {} :: { [string]: Pathfinding.FlowField }
	self._validCells = {} :: { [number]: true }
	self._occupiedCells = {} :: { [number]: true }

	self._isFindingMatch = false
	self._isRaidStarted = false
	self._isRaiding = false
	self._macthConnection = nil
	self._matchStartTime = 0 :: number

	self._isReady = false
	self._onReadyCallback = nil :: ((BasePart) -> ())?
	self._gridOriginX = 0 :: number
	self._gridOriginZ = 0 :: number
	self._gridSurfaceY = 0 :: number

	--Visualization
	self._UnitsTemplate = nil
	self._unitModels = {} :: { [string]: Model }
	self._buildingModels = {} :: { [string]: Model }
	return self
end

function BattleController:_creatUnitModel(unitType: string, unitLevel: number): Model?
	local unitFolder = self._UnitsTemplate:FindFirstChild(unitType)
	if not unitFolder then
		warn("[BattleController] Unit type not found: " .. unitType)
		return nil
	end
	local unitModel = unitFolder:FindFirstChild(tostring(unitLevel))
	if not unitModel then
		warn("[BattleController] Unit level not found: " .. unitLevel .. " for type: " .. unitType)
		return nil
	end
	return unitModel:Clone()
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

-- หลังจากวาง unit แล้วให้หา target ที่ใกล้ที่สุดจาก unit นั้น
-- [[
--  @TODO After place unit in the raid, find the nearest target from that unit. If there is no target, the unit will wait until a target appears.
-- ]]
function BattleController:UnitfindindTarget(unitId: string) end

-- ponytail: เดโม่ wow ล้วนๆ ลบทิ้งได้
function BattleController:_TestPathfindingWow()
	local BOUNDS = { MinX = 0, MaxX = 50, MinZ = 0, MaxZ = 50 }
	local GOAL = { GridX = 25, GridZ = 25 }

	-- กำแพงตั้ง 2 ท่อน เว้นช่อง → บังคับให้ฝูงไหลคดเคี้ยว
	local occupied: Pathfinding.Occupied = self._occupiedCells

	local old = Workspace:FindFirstChild("PathfindingTest")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "PathfindingTest"
	folder.Parent = Workspace

	local function world(gridX: number, gridZ: number, y: number): Vector3
		return self:GridCoordsToWorld(gridX, gridZ, 1, 1) + Vector3.new(0, y, 0)
	end

	local flow = Pathfinding.buildFlowField(GOAL, BOUNDS, occupied)

	-- กำแพง(แดง) + goal(เขียวใหญ่)
	for hash in occupied do
		local gx, gz = Pathfinding.decode(hash)
		if gx and gz then
			local w = Instance.new("Part")
			w.Anchored, w.CanCollide = true, false
			w.Material = Enum.Material.Neon
			w.Color = Color3.fromRGB(200, 50, 50)
			w.Size = Vector3.new(4, 4, 4)
			w.Position = world(gx, gz, 2)
			w.Parent = folder
		end
	end
	local goalPart = Instance.new("Part")
	goalPart.Anchored, goalPart.CanCollide = true, false
	goalPart.Material = Enum.Material.Neon
	goalPart.Color = Color3.fromRGB(60, 230, 90)
	goalPart.Size = Vector3.new(4, 8, 4)
	goalPart.Position = world(GOAL.GridX, GOAL.GridZ, 4)
	goalPart.Parent = folder

	-- ★ วาดลูกศรทั้ง field (ใช้ nextStep หาทิศ ไม่ต้องแตะภายใน Pathfinding)
	for hash in flow do
		local gx, gz = Pathfinding.decode(hash)
		if gx and gz then
			local nxt = Pathfinding.nextStep(flow, { GridX = gx, GridZ = gz })
			if nxt then
				local from = world(gx, gz, 0.5)
				local to = world(nxt.GridX, nxt.GridZ, 0.5)
				local a = Instance.new("Part")
				a.Anchored, a.CanCollide = true, false
				a.Material = Enum.Material.Neon
				a.Color = Color3.fromRGB(70, 160, 255)
				a.Size = Vector3.new(0.4, 0.4, 3)
				a.CFrame = CFrame.lookAt(from, to)
				a.Parent = folder
			end
		end
	end

	-- ★ ปล่อยฝูงทหาร (checkerboard เว้นช่อง) ทุกตัวใช้ field เดียวกัน
	for hash in flow do
		local gx, gz = Pathfinding.decode(hash)
		if (gx + gz) % 2 == 0 then
			local ball = Instance.new("Part")
			ball.Shape = Enum.PartType.Ball
			ball.Anchored, ball.CanCollide = true, false
			ball.Material = Enum.Material.Neon
			ball.Color = Color3.fromHSV(math.random(), 0.85, 1)
			ball.Size = Vector3.new(1.6, 1.6, 1.6)
			ball.Position = world(gx, gz, 2.5)
			ball.Parent = folder

			task.spawn(function()
				local pos = { GridX = gx, GridZ = gz }
				for _ = 1, 200 do
					if ball.Parent == nil then
						return
					end
					local nxt = Pathfinding.nextStep(flow, pos)
					if not nxt then
						break
					end
					pos = nxt
					ball.Position = world(pos.GridX, pos.GridZ, 2.5)
					task.wait(0.18)
				end
				ball:Destroy()
			end)
		end
	end
end

function BattleController:StartRiding()
	if not self._state.Tick or not self._state.Buildings or not self._state.Spells then
		self._state.Buildings = self._state.Buildings or {}
		self._state.Tick = 0
		self._state.Units = {}
		self._state.Spells = {}
	end

	self._isRaiding = true
	self._macthConnection = task.spawn(function()
		local startTime = tick()
		local endTime = startTime + CONFIG.MATCH_TIMEOUT
		while self._isRaiding and tick() < endTime do
			Simulation.stepTick(self._state, self._flowFields)

			for _, unit in self._state.Units do
				local unitId = unit.UnitId
				if not unitId then
					warn("[BattleController] Unit has no UnitId, skipping")
					continue
				end
				local unitState = self._units[unitId]
				if not unitState or unit.Hp <= 0 then
					continue
				end

				self._unitModels[unitId]:PivotTo(
					CFrame.new(self:GridCoordsToWorld(unit.Position.GridX, unit.Position.GridZ, 1, 1))
				)
			end
			task.wait(CONFIG.INTERVAL)
		end
		-- self:MatchEnd()
	end)
end

function BattleController:MatchEnd()
	self._isRaiding = false
	if self._macthConnection then
		task.cancel(self._macthConnection)
		self._macthConnection = nil
	end

	if self._state then
		self._state.Tick = 0
		self._state.Buildings = {}
		self._state.Units = {}
		self._state.Spells = {}
	end

	if self._flowFields then
		self._flowFields = {}
	end
end

function BattleController:Init()
	local Assets = ReplicatedStorage:WaitForChild("Assets")
	if not Assets then
		warn("[BattleController] Assets folder not found in ReplicatedStorage")
		return
	end

	self._UnitsTemplate = Assets:WaitForChild("Units")
	if not self._UnitsTemplate then
		warn("[BattleController] Units template not found in Assets")
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
			warn("[BattleController] Register building with ID: " .. buildingId)
			if not building then
				warn("[BattleController] Failed to register building with ID: " .. buildingId)
				continue
			end
			self._buildings[buildingId] = building
			self:occupyCell(
				self:GridCoordsToWorld(
					buildingdata[CONFIG.KEYSTORE["Gridx"]],
					buildingdata[CONFIG.KEYSTORE["Gridz"]],
					self._buildings[buildingId].Dimensions.Width,
					self._buildings[buildingId].Dimensions.Length
				),
				self._buildings[buildingId].Dimensions.Width,
				self._buildings[buildingId].Dimensions.Length
			)
			table.insert(self._state.Buildings, self._buildings[buildingId])
		end
	end)

	EventBus:On(Events.LOCAL_DEPLOY_UNIT, function(data)
		if not self._isRaiding then
			self:StartRiding()
		end

		-- local enum = data.UnitEnum
		-- if not enum then
		-- 	warn("[BattleController] No unit enum data received for deployment")
		-- 	return
		-- end

		-- local position = data.Position
		-- if not position then
		-- 	warn("[BattleController] No position data received for deployment")
		-- 	return
		-- end

		if not self._state.Units then
			self._state.Units = {}
		end

		-- ตำแหน่ง Grid ของ unit ที่จะถูกวางลงไปใน ระหว่าง cellนั้ๆ แบบละเอียด 1 - 1000 เพื่อทำให้การเดินสท
		local test_Unit_position = {
			GridX = 5,
			GridZ = 5,
		}

		local unitId = `test_Unit{self._currentUnitId}`
		local unitLevel = 1
		local unitEnum = 1

		-- find target for this unit Then retunr the buildingId
		-- and then Create flow field for this unit to move to the target
		local test_nestest_building = "n1"
		if not self._buildings[test_nestest_building] then
			warn("[BattleController] No building data found for target buildingId: " .. test_nestest_building)
			return
		end

		if not self._flowFields[test_nestest_building] then
			self._flowFields[test_nestest_building] =
				Pathfinding.buildFlowField(self._buildings[test_nestest_building].Position, {
					MinX = 0,
					MaxX = 50,
					MinZ = 0,
					MaxZ = 50,
				}, self._occupiedCells)
		end

		local unit = Simulation.RegisterUnit(unitId, unitEnum, unitLevel, test_Unit_position)
		if not unit then
			warn("[BattleController] Failed to register unit with ID: " .. unitId)
			return
		end

		local unitModel = self:_creatUnitModel(GameEnum:GetUnitTypeById(unitEnum), unitLevel)
		if not unitModel then
			warn("[BattleController] Failed to create unit model for unitId: " .. unitId)
			return
		end
		unitModel.Name = unitId
		unitModel.Parent = self._BattleFolder
		local worldPos = self:GridCoordsToWorld(test_Unit_position.GridX, test_Unit_position.GridZ, 1, 1)
		unitModel:PivotTo(CFrame.new(worldPos))
		self._unitModels[unitId] = unitModel

		self._units[unitId] = unit
		self._units[unitId].TargetId = test_nestest_building
		table.insert(self._state.Units, self._units[unitId])

		self._currentUnitId += 1
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
