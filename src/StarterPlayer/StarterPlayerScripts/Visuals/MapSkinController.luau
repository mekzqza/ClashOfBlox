-- !strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEnum = require(ReplicatedStorage.Shared.GameEnum)
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)

local CONFIG = {
	GRID_PART_NAME = "GridPart",
	CENTER_PART_NAME = "Center",
	MAP_FOLDER_NAME = "MapSkin",
}

local MapSkinController = {}
MapSkinController.__index = MapSkinController
function MapSkinController.new()
	local self = setmetatable({}, MapSkinController)
	self._PlayerDataController = nil

	self._PlayerFolder = nil
	self._CurrentMapSkin = nil
	self._mapSkinTemplates = nil
	return self
end

function MapSkinController:SetDependencies(locator)
	self._PlayerDataController = locator:Get("PlayerDataController")
end

function MapSkinController:_getMapFolder(): Folder?
	local mapFolder = self._PlayerFolder:FindFirstChild(CONFIG.MAP_FOLDER_NAME, true)
	if not mapFolder then
		warn("[MapSkinController] Failed to find map folder in workspace")
		return nil
	end
	return mapFolder
end

function MapSkinController:_getCenterPart(): BasePart?
	local gridpart = self._PlayerFolder:FindFirstChild(CONFIG.GRID_PART_NAME)
	if not gridpart then
		warn("[MapSkinController] Failed to find grid part in player folder")
		return nil
	end

	local centerPart = gridpart:FindFirstChild(CONFIG.CENTER_PART_NAME, true)
	if not centerPart then
		warn("[MapSkinController] Failed to find center part in grid part")
		return nil
	end

	return centerPart
end

function MapSkinController:_setupMapSkin(mapSkin: string)
	local mapSkinFolder = self._mapSkinTemplates:FindFirstChild(mapSkin, true)
	if not mapSkinFolder then
		warn("[MapSkinController] Failed to find map skin template for " .. mapSkin)
		return
	end

	local playerSkin = mapSkinFolder:Clone()

	local centerPart = self:_getCenterPart()
	if not centerPart then
		warn("[MapSkinController] Cannot setup map skin without center part")
		return
	end

	local mapFolder = self:_getMapFolder()
	if not mapFolder then
		warn("[MapSkinController] Cannot setup map skin without map folder")
		return
	end

	playerSkin:SetPrimaryPartCFrame(centerPart.CFrame)
	playerSkin.Parent = mapFolder
	self._CurrentMapSkin = mapSkin
end

function MapSkinController:Destroy()
	if self._CurrentMapSkin then
		self._CurrentMapSkin:Destroy()
		self._CurrentMapSkin = nil
	end
end

function MapSkinController:Init()
	self._mapSkinTemplates = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("MapSkin")
	if not self._mapSkinTemplates then
		warn("[MapSkinController] Failed to find MapSkin templates in ReplicatedStorage.Assets.MapSkin")
		return
	end
end

function MapSkinController:Start()
	EventBus:On(Events.LOCAL_FOLDER_READY, function(data)
		self._PlayerFolder = data.Folder
	end)

	self._PlayerDataController:WaitForDataReady():andThen(function(data)
		if not data.MapSkin then
			warn("[MapSkinController] Player data missing MapSkin, defaulting to None")
			return
		end
		local mapSkin = GameEnum:GetMapSkinById(data.MapSkin)
		self:_setupMapSkin(mapSkin)
	end)
end

return MapSkinController.new()
