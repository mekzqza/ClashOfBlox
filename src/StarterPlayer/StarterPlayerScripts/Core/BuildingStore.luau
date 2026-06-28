--!strict
--
-- [[
--  @signature
--  จุดกลางในการจัดการข้อมูลอาคารของผู้เล่น รวมถึงการสร้างอาคารใหม่และการอัปเดตข้อมูลอาคารที่มีอยู่
--  ]]
export type BuildingRecord = {
	BuildingId: string,
	BuildingEnum: number,
	BuildingLevel: number,
	Gridx: number,
	Gridz: number,
	EndTime: number,
	LastCollectedTime: number,

	BuildingModel: Model?,
}

local BuildingStore = {}
BuildingStore.__index = BuildingStore
function BuildingStore.new()
	local self = setmetatable({}, BuildingStore)
	self.buildings = {} :: { [string]: BuildingRecord }
	self._buildingCount = 0

	return self
end

function BuildingStore:GetBuildings(): { [string]: BuildingRecord }
	return self.buildings
end

function BuildingStore:AddBuilding(
	buildingId: string,
	gridX: number,
	gridZ: number,
	buildingEnum: number,
	buildingLevel: number,
	endTime: number,
	lastCollectedTime: number,
	model: Model?
)
	local newBuilding: BuildingRecord = {
		BuildingId = buildingId,
		Gridx = gridX,
		Gridz = gridZ,
		BuildingEnum = buildingEnum,
		BuildingLevel = buildingLevel,
		EndTime = endTime,
		LastCollectedTime = lastCollectedTime,
		BuildingModel = model,
	}
	self.buildings[buildingId] = newBuilding
	self._buildingCount += 1
end

function BuildingStore:RemoveBuilding(buildingId: string)
	if self.buildings[buildingId] then
		self.buildings[buildingId] = nil
		self._buildingCount -= 1
	else
		warn("Attempted to remove non-existent building with ID:", buildingId)
	end
end

function BuildingStore:SetBuildingData(buildingId: string, buildingData: BuildingRecord)
	self.buildings[buildingId] = buildingData
end

function BuildingStore:GetBuildingData(buildingId: string): BuildingRecord?
	return self.buildings[buildingId]
end

function BuildingStore:GetbuildingCount()
	return self._buildingCount
end

function BuildingStore:SetBuildingCount(count: number)
	self._buildingCount = count
end

function BuildingStore:Init() end

function BuildingStore:Start() end

return BuildingStore.new()
