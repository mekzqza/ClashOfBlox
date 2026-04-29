--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local ServiceLocator = require(ServerScriptService.Utils.ServiceLocator)

local CmdrCommand = ServerScriptService:WaitForChild("CmdrCommands")
local Services = ServerScriptService:WaitForChild("Services")

local Core = Services:FindFirstChild("Core")
local Data = Services:FindFirstChild("Data")
local Gameplay = Services:FindFirstChild("GamePlay")

local CmdrService = require(Core.CmdrService)

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

Promise.resolve()
	:andThen(function()
		ServiceLocator:Register("CmdrService", CmdrService)
	end)
	:catch(function(err)
		error(`[Server Init] Failed to initialize server: {err}`)
	end)
	:andThen(function()
		return Promise.all({
			initService(CmdrService, "CmdrService"),
		})
	end)
	:andThen(function()
		return Promise.all({
			startService(CmdrService, "CmdrService"),
		})
	end)
