--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IdempotentGuard = require(ServerScriptService.Utils.IdempotentGuard)

local CmdrService = {}

local guard = IdempotentGuard.new("CmdrService", true)

local Cmdr = nil

local function loadCmdr()
	-- Check if Cmdr is already loaded
	if Cmdr then
		return Cmdr
	end

	-- Attempt to load Cmdr from ReplicatedStorage
	local success, result = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Cmdr"))
	end)

	if not success then
		warn("[CmdrService] ⚠️ Failed to load Cmdr: " .. tostring(result))
		return nil
	end

	return result
end

function CmdrService:Init()
	if not guard:MarkInitialized() then
		return
	end

	local startTime = os.clock()

	Cmdr = loadCmdr()

	if not Cmdr then
		warn("[CmdrService] ⚠️ Cmdr not loaded - commands will not be available")
		warn("[CmdrService] 💡 This is optional - game will continue without Cmdr console")
		return
	end
end

function CmdrService:Start()
	if not guard:MarkStarted() then
		return
	end

	if not Cmdr then
		warn("[CmdrService] ⚠️ Cannot start - Cmdr not loaded")
		return
	end

	local success1, err1 = pcall(function()
		Cmdr:RegisterDefaultCommands()
	end)

	if success1 then
		print("[CmdrService] ✅ Registered default commands")
	else
		warn(`[CmdrService] ⚠️ Failed to register default commands: {err1}`)
	end

	local serverCmdrCommands = ServerScriptService:FindFirstChild("CmdrCommands")
	if serverCmdrCommands then
		local success2, err2 = pcall(function()
			Cmdr:RegisterCommandsIn(serverCmdrCommands)
		end)

		if success2 then
			print("[CmdrService] ✅ Registered server commands from ServerScriptService/CmdrCommands")
		else
			warn(`[CmdrService] ⚠️ Failed to register server commands: {err2}`)
		end
	else
		print("[CmdrService] ℹ️ No ServerScriptService/CmdrCommands folder found (optional)")
	end

	local cmdrFolder = ReplicatedStorage:FindFirstChild("Cmdr")
	if cmdrFolder then
		local commandsFolder = cmdrFolder:FindFirstChild("Commands")
		if commandsFolder then
			local success3, err3 = pcall(function()
				Cmdr:RegisterCommandsIn(commandsFolder)
			end)

			if success3 then
				print("[CmdrService] ✅ Registered client commands from ReplicatedStorage/Cmdr/Commands")

				-- นับจำนวน commands
				local count = 0
				for _, child in commandsFolder:GetChildren() do
					if child:IsA("ModuleScript") and not child.Name:match("Server$") then
						count += 1
					end
				end
				print(`[CmdrService]    └── Found {count} command definition(s)`)
			else
				warn(`[CmdrService] ⚠️ Failed to register client commands: {err3}`)
			end
		else
			warn("[CmdrService] ⚠️ ReplicatedStorage/Cmdr/Commands folder not found!")
		end
	else
		warn("[CmdrService] ⚠️ ReplicatedStorage/Cmdr folder not found!")
	end

	local secrets = ServerStorage:FindFirstChild("Secrets")
	if secrets then
		local hooksFolder = secrets:FindFirstChild("Hooks")
		if hooksFolder then
			local success4, err4 = pcall(function()
				Cmdr:RegisterHooksIn(hooksFolder)
			end)

			if success4 then
				print("[CmdrService] ✅ Registered hooks from ServerStorage/Secrets/Hooks")
			else
				warn(`[CmdrService] ⚠️ Failed to register hooks: {err4}`)
			end
		end
	end
end

return CmdrService
