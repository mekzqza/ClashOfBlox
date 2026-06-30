--!strict

--[[
    -- เก็บ current vision ของผู้เล่นที่กำจะถูกโจมตี
    -- ถ้ากดอะรก็ตาม จะเข้าสู่ Battlemode เพื่อจัดการ Simulation ของการโจมตี

]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BuildingConfig = require(ReplicatedStorage.Shared.BuildingConfig)
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
local Pathfinding = require(ReplicatedStorage.Shared.Pathfinding)
local Simulation = require(ReplicatedStorage.Shared.Simulation)

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

	self._isReady = false
	self._onReadyCallback = nil :: ((BasePart) -> ())?
	self._gridOriginX = 0 :: number
	self._gridOriginZ = 0 :: number
	self._gridSurfaceY = 0 :: number
	return self
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

function BattleController:RegisterBuildings(
	buildingId: string,
	gridX: number,
	gridZ: number,
	buildingEnum: number,
	buildingLevel: number,
	endTime: number,
	lastCollectedTime: number
)
	local buildingData = BuildingConfig:GetBuildingDataByEnum(buildingEnum, buildingLevel)
	if not buildingData then
		warn(`[BattleController] No building data found for enum {buildingEnum} level {buildingLevel}`)
		return
	end

	local buildingType = GameEnum:GetBuildingTypeById(buildingEnum)
	if not buildingType then
		warn(`[BattleController] No building type found for enum {buildingEnum}`)
		return
	end

	local dimensions = BuildingConfig:GetBuildingDimensions(buildingType)
	if not dimensions then
		warn(`[BattleController] No dimensions found for building enum {buildingEnum}`)
		return
	end
	local buildingPosition = self:GridCoordsToWorld(gridX, gridZ, dimensions.Width, dimensions.Length)
	self:occupyCell(buildingPosition, dimensions.Width, dimensions.Length)

	self._buildings[buildingId] = Simulation.RegisterBuilding(buildingId, buildingPosition, buildingData.MaxHp)

	warn(
		`[BattleController] Registered building {buildingId} at grid ({gridX}, {gridZ}) with enum {buildingEnum} level {buildingLevel}`
	)
	--[[
	    @TODO
		จัดการ endTime เพื่อเช็คว่ากำลังสร้างอยู่หรือไม่ ถ้าใช่ให้ spawn เป็น building under construction
		จัดการ lastCollectedTime เพื่อเช็คว่ามี resource ที่ยังไม่ได้เก็บหรือไม่ เพื่อให้ผู้เล่นปล้นเอา resource ได้
	]]
end

function BattleController:RegisterUnit(unitTypeEnum: number, unitLevel: number, position: Vector3)
	local Grid = {
		GridX = math.floor((position.X - self._gridOriginX) / CONFIG.CELL_SIZE),
		GridZ = math.floor((position.Z - self._gridOriginZ) / CONFIG.CELL_SIZE),
	}
	local maxHp = 50
	local attack = 10
	local walkSpeed = 5

	local id = `n{self._currentUnitId}`
	self._units[id] = Simulation.RegisterUnit(id, Grid, maxHp, attack, walkSpeed)
	self._currentUnitId += 1
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

-- ponytail: เดโม่ combat ล้วนๆ ลบทิ้งได้ — รันครั้งเดียวเห็น ranged attack ทำงานจริง
function BattleController:_TestCombatWow()
	local BOUNDS = { MinX = 0, MaxX = 50, MinZ = 0, MaxZ = 50 }

	-- ตึกเป้าหมายตรงกลาง + flow field พาทหารวิ่งเข้าหา
	local building = Simulation.RegisterBuilding("b1", { GridX = 25, GridZ = 25 }, 1500)
	local flow = Pathfinding.buildFlowField({ GridX = 25, GridZ = 25 }, BOUNDS, {})
	local flowFields: { [string]: Pathfinding.FlowField } = { b1 = flow }

	-- ทหาร 2 แบบใช้ field เดียวกัน: melee (range 1, แดง) แถวล่าง + ranged (range 6, ฟ้า) แถวบน
	local units: { Simulation.UnitState } = {}
	local nextId = 0
	local function spawn(gx: number, gz: number, range: number)
		nextId += 1
		local u = Simulation.RegisterUnit(`u{nextId}`, { GridX = gx, GridZ = gz }, 50, 5, 5, range, 6)
		u.TargetId = "b1"
		table.insert(units, u)
	end
	for i = 0, 50, 5 do
		spawn(i, 0, 1)
		spawn(i, 50, 6)
	end

	local state: Simulation.State = { Tick = 0, Units = units, Buildings = { building }, Spells = {} }

	-- ── ภาพ ────────────────────────────────────────────────
	local old = Workspace:FindFirstChild("CombatTest")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "CombatTest"
	folder.Parent = Workspace

	local function world(gridX: number, gridZ: number, y: number): Vector3
		return self:GridCoordsToWorld(gridX, gridZ, 1, 1) + Vector3.new(0, y, 0)
	end

	local buildPart = Instance.new("Part")
	buildPart.Anchored, buildPart.CanCollide = true, false
	buildPart.Material = Enum.Material.Neon
	buildPart.Color = Color3.fromRGB(60, 230, 90)
	buildPart.Size = Vector3.new(8, 10, 8)
	buildPart.Position = world(25, 25, 5)
	buildPart.Parent = folder

	local unitParts: { [string]: BasePart } = {}
	for _, u in units do
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Anchored, ball.CanCollide = true, false
		ball.Material = Enum.Material.Neon
		ball.Color = if u.Range > 1 then Color3.fromRGB(70, 160, 255) else Color3.fromRGB(255, 90, 70)
		ball.Size = Vector3.new(1.8, 1.8, 1.8)
		ball.Position = world(u.Position.GridX, u.Position.GridZ, 2.5)
		ball.Parent = folder
		unitParts[u.UnitId] = ball
	end

	local lasers = Instance.new("Folder")
	lasers.Name = "Lasers"
	lasers.Parent = folder

	-- ── เดิน sim ───────────────────────────────────────────
	task.spawn(function()
		for _ = 1, 1000 do
			if building.Hp <= 0 then
				break
			end
			Simulation.stepTick(state, flowFields)
			lasers:ClearAllChildren()

			for _, u in units do
				local ball = unitParts[u.UnitId]
				ball.Position = world(u.Position.GridX, u.Position.GridZ, 2.5)

				-- เข้าระยะ → ยิงเลเซอร์ไปที่ตึก (สีตามชนิดทหาร)
				local dx = u.Position.GridX - building.Position.GridX
				local dz = u.Position.GridZ - building.Position.GridZ
				if dx * dx + dz * dz <= u.Range * u.Range then
					local from = world(u.Position.GridX, u.Position.GridZ, 2.5)
					local to = world(25, 25, 5)
					local len = (from - to).Magnitude
					local beam = Instance.new("Part")
					beam.Anchored, beam.CanCollide = true, false
					beam.Material = Enum.Material.Neon
					beam.Color = ball.Color
					beam.Size = Vector3.new(0.15, 0.15, len)
					beam.CFrame = CFrame.lookAt((from + to) / 2, to)
					beam.Parent = lasers
				end
			end

			-- ตึกเปลี่ยนสีตาม Hp (เขียว → แดง)
			local ratio = building.Hp / building.MaxHp
			buildPart.Color =
				Color3.fromRGB(math.floor(60 + (1 - ratio) * 195), math.floor(230 * ratio), math.floor(90 * ratio))

			task.wait(0.1)
		end

		buildPart:Destroy()
		lasers:Destroy()
		warn(`[BattleController] 🏚️ ตึกพังที่ tick {state.Tick}`)
	end)
end

function BattleController:Init() end

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
		for buildingId, buildingdata in buildings do
			self:RegisterBuildings(
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

	-- EventBus:On(Events.LOCAL_DEPLOY_UNIT, function(data)
	-- 	-- self:RegisterUnit(data.UnitTypeEnum, data.UnitLevel, data.Position)
	-- end)

	-- TEST
	EventBus:On(Events.LOCAL_FOLDER_READY, function(data)
		local folder = data.Folder
		local GridPart = folder:WaitForChild("GridPart", 30):WaitForChild("LogicPart", 30)
		if not GridPart or not GridPart:IsA("BasePart") then
			warn(`[BattleController] Grid part not found for folder: {data.FolderName}`)
			return
		end
		self:RegisterZone(GridPart)
	end)

	EventBus:On(Events.LOCAL_TOGGLE_UI, function(targetWindow)
		if targetWindow == "Test_Raid" then
			EventBus:Emit(Events.C2S_REQUEST_FINDING_RAID)
		end
	end)
end

return BattleController.new()
