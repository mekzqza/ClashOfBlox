--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CmdrController = {}

export type CmdrController = {
	Init: (self: CmdrController) -> (),
	Start: (self: CmdrController) -> (),
}

local CmdrClient = nil

local CONFIG = {
	MaxRetries = 10, -- Max attempts to find CmdrClient
	RetryDelay = 1, -- Delay between retries (seconds)
	Timeout = 15, -- Total timeout (seconds)
	ActivationKey = Enum.KeyCode.F2, -- Press this to open
}

local function loadCmdrClient(): any?
	local startTime = os.clock()

	for attempt = 1, CONFIG.MaxRetries do
		-- Check timeout
		if (os.clock() - startTime) > CONFIG.Timeout then
			warn("[CmdrController] ⏱️ Timeout waiting for CmdrClient")
			return nil
		end

		-- Try to find CmdrClient
		local success, result = pcall(function()
			return ReplicatedStorage:FindFirstChild("CmdrClient")
		end)

		if success and result then
			-- Found it! Try to require
			local success2, result2 = pcall(function()
				return require(result)
			end)

			if success2 and result2 then
				return result2
			else
				warn(`[CmdrController] ⚠️ Found CmdrClient but require failed: {result2}`)
			end
		end

		-- Not found yet, wait and retry
		if attempt < CONFIG.MaxRetries then
			print(`[CmdrController] ⏳ CmdrClient not found, retrying... (attempt {attempt}/{CONFIG.MaxRetries})`)
			task.wait(CONFIG.RetryDelay)
		end
	end

	return nil
end

function CmdrController:Init()
	print("[CmdrController] 🔧 Initializing...")

	-- ✅ Load CmdrClient with retry logic
	CmdrClient = loadCmdrClient()

	if not CmdrClient then
		warn("[CmdrController] ⚠️ CmdrClient not found in ReplicatedStorage")
		warn("[CmdrController] 📝 Possible causes:")
		warn("[CmdrController]    1. Cmdr not installed in ServerScriptService/cmdr/")
		warn("[CmdrController]    2. CmdrService failed to start on server")
		warn("[CmdrController]    3. Server hasn't cloned CmdrClient yet (wait longer)")
		warn("[CmdrController] 💡 Game will continue without Cmdr console")
		return
	end

	if CmdrClient.SetActivationKeys then
		CmdrClient:SetActivationKeys({ CONFIG.ActivationKey })
		print(`[CmdrController] ✅ Initialized. Press [{CONFIG.ActivationKey.Name}] to open console`)
	else
		warn("[CmdrController] ⚠️ SetActivationKeys not found!")
	end
end

function CmdrController:Start()
	print("[CmdrController] 🚀 Starting...")

	if not CmdrClient then
		warn("[CmdrController] ⚠️ CmdrClient not loaded - console unavailable")
		return
	end
end

return CmdrController
