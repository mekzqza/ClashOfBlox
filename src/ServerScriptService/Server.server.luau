--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local ServiceLocator = require(ServerScriptService.Utils.ServiceLocator)

local Services = ServerScriptService:WaitForChild("Services")

local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)

local Core = Services:FindFirstChild("Core")
local Data = Services:FindFirstChild("Data")
local Gameplay = Services:FindFirstChild("GamePlay")

--Data Layer
local PlayerDataService = require(Data.PlayerDataService).new()
local FirstLoadService = require(Data.FirstLoadService).new()
--Core Layer
local CmdrService = require(Core.CmdrService)
local ServerNetWorkHandler = require(Core.ServerNetWorkHandler)

--Gameplay Layer
local Defrens = Gameplay:FindFirstChild("Defrens")
local GridService = require(Defrens.GridService).new()
local BuildingService = require(Defrens.BuildingService).new()

local Economy = Gameplay:FindFirstChild("Economy")
local ResourceService = require(Economy.ResourceService).new()

local TIMEOUTS = {
	ServiceInit = 15,
	ServiceStart = 15,
	LayerInit = 45,
	LayerStart = 45,
}

local function initService(service: any, name: string, timeout: number?): any
	timeout = timeout or TIMEOUTS.ServiceInit

	return Promise.new(function(resolve, reject)
		local success, err = pcall(function()
			if service and type(service.Init) == "function" then
				service:Init()
			end
		end)

		if success then
			print(`[Init] ✅ {name} initialized`)
			resolve(true)
		else
			reject(`{name} failed: {err}`)
		end
	end)
		:timeout(timeout)
		:catch(function(err)
			if Promise.Error.isKind(err, Promise.Error.Kind.TimedOut) then
				error(`[Init] ⏱️ TIMEOUT: {name} Init exceeded {timeout}s`)
			else
				error(`[Init] ❌ ERROR: {name} Init failed: {err}`)
			end
		end)
end

local function startService(service: any, name: string, timeout: number?): any
	timeout = timeout or TIMEOUTS.ServiceStart

	return Promise.new(function(resolve, reject)
		local success, err = pcall(function()
			if service and type(service.Start) == "function" then
				service:Start()
			end
		end)

		if success then
			print(`[Init] ✅ {name} started`)
			resolve(true)
		else
			reject(`{name} failed: {err}`)
		end
	end)
		:timeout(timeout)
		:catch(function(err)
			if Promise.Error.isKind(err, Promise.Error.Kind.TimedOut) then
				error(`[Init] ⏱️ TIMEOUT: {name} Start exceeded {timeout}s`)
			else
				error(`[Init] ❌ ERROR: {name} Start failed: {err}`)
			end
		end)
end

Promise
	.resolve()
	:andThen(function()
		ServiceLocator:Register("EventBus", EventBus)
		ServiceLocator:Register("Events", Events)

		ServiceLocator:Register("CmdrService", CmdrService)
		ServiceLocator:Register("ServerNetWorkHandler", ServerNetWorkHandler)

		ServiceLocator:Register("PlayerDataService", PlayerDataService)
		ServiceLocator:Register("FirstLoadService", FirstLoadService)

		ServiceLocator:Register("GridService", GridService)
		ServiceLocator:Register("BuildingService", BuildingService)

		ServiceLocator:Register("ResourceService", ResourceService)
	end)
	:catch(function(err)
		error(`[Server Init] Failed to initialize server: {err}`)
	end)
	--Init services
	:andThen(function()
		-- CoreLayer
		print("[Init] CoreLayer initialized")
		return Promise.all({
			initService(CmdrService, "CmdrService"),
			initService(ServerNetWorkHandler, "ServerNetWorkHandler"),
		}):timeout(TIMEOUTS.LayerInit)
	end)
	:andThen(function()
		--DataLayer
		print("[Init] DataLayer initialized")
		return Promise.all({
			initService(PlayerDataService, "PlayerDataService"),
			initService(FirstLoadService, "FirstLoadService"),
		}):timeout(TIMEOUTS.LayerInit)
	end)
	:andThen(function()
		print("[Init] GameplayLayer initialized")
		return Promise.all({
			initService(GridService, "GridService"),
			initService(BuildingService, "BuildingService"),
		}):timeout(TIMEOUTS.LayerInit)
	end)
	:andThen(function()
		print("[Init] EconomyLayer initialized")
		return Promise.all({
			initService(ResourceService, "ResourceService"),
		}):timeout(TIMEOUTS.LayerInit)
	end)
	-- Start services
	:andThen(function()
		print("[Init] CoreLayer started")
		return Promise.all({
			startService(CmdrService, "CmdrService"),
			startService(ServerNetWorkHandler, "ServerNetWorkHandler"),
		}):timeout(TIMEOUTS.LayerStart)
	end)
	:andThen(function()
		print("[Init] DataLayer started")
		return Promise.all({
			startService(PlayerDataService, "PlayerDataService"),
			startService(FirstLoadService, "FirstLoadService"),
		}):timeout(TIMEOUTS.LayerStart)
	end)
	:andThen(function()
		print("[Init] GameplayLayer started")
		return Promise.all({
			startService(GridService, "GridService"),
			startService(BuildingService, "BuildingService"),
		}):timeout(TIMEOUTS.LayerStart)
	end)
	:andThen(function()
		print("[Init] EconomyLayer started")
		return Promise.all({
			startService(ResourceService, "ResourceService"),
		}):timeout(TIMEOUTS.LayerStart)
	end)
