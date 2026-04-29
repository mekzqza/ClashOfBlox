--!strict

--[[
╔════════════════════════════════════════════════════════════════╗
║            IDEMPOTENT GUARD UTILITY - PRODUCTION GRADE         ║
╠════════════════════════════════════════════════════════════════╣
║ Purpose: Prevent double initialization/execution              ║
║ Features:                                                      ║
║  ✅ Reusable across all Services/Controllers                  ║
║  ✅ Thread-safe state tracking                                ║
║  ✅ Lifecycle validation (Init → Start order)                 ║
║  ✅ Debug mode support                                        ║
║  ✅ Analytics tracking                                        ║
╚════════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════════
-- TYPE DEFINITIONS
-- ═══════════════════════════════════════════════════════════════

export type LifecycleState = "Created" | "Initialized" | "Started" | "Stopped"

export type GuardInstance = {
	-- State queries
	IsInitialized: (self: GuardInstance) -> boolean,
	IsStarted: (self: GuardInstance) -> boolean,
	IsStopped: (self: GuardInstance) -> boolean,
	GetState: (self: GuardInstance) -> LifecycleState,

	-- State transitions
	MarkInitialized: (self: GuardInstance) -> boolean,
	MarkStarted: (self: GuardInstance) -> boolean,
	MarkStopped: (self: GuardInstance) -> boolean,

	-- Validation
	RequireInitialized: (self: GuardInstance) -> (),
	RequireNotInitialized: (self: GuardInstance) -> (),
	RequireStarted: (self: GuardInstance) -> (),

	-- Utilities
	Reset: (self: GuardInstance) -> (),
	GetAnalytics: (self: GuardInstance) -> { [string]: any },

	-- Internal
	_name: string,
	_state: LifecycleState,
	_initTime: number?,
	_startTime: number?,
	_stopTime: number?,
	_initCount: number,
	_startCount: number,
	_debug: boolean,
}

local IdempotentGuard = {}

-- ═══════════════════════════════════════════════════════════════
-- GLOBAL REGISTRY
-- ═══════════════════════════════════════════════════════════════

local guards: { [string]: GuardInstance } = {}
local globalStats = {
	totalGuardsCreated = 0,
	totalInitAttempts = 0,
	totalStartAttempts = 0,
	blockedInits = 0,
	blockedStarts = 0,
}

-- ═══════════════════════════════════════════════════════════════
-- PRIVATE FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

local function log(guard: GuardInstance, level: "Info" | "Warn" | "Error", message: string)
	if not guard._debug and level == "Info" then
		return
	end

	local prefix = string.format("[IdempotentGuard:%s]", guard._name)

	if level == "Error" then
		error(prefix .. " " .. message)
	elseif level == "Warn" then
		warn(prefix .. " " .. message)
	else
		print(prefix .. " " .. message)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- CONSTRUCTOR
-- ═══════════════════════════════════════════════════════════════

--[[
	Create a new IdempotentGuard instance

	@param name string - Identifier for this guard (e.g., "NetworkHandler")
	@param debug boolean? - Enable debug logging
	@return GuardInstance

	Example:
		local guard = IdempotentGuard.new("MyService", true)
]]
function IdempotentGuard.new(name: string, debug: boolean?): GuardInstance
	-- Check if guard already exists
	if guards[name] then
		warn(`[IdempotentGuard] ⚠️ Guard '{name}' already exists! Returning existing instance.`)
		return guards[name]
	end

	local self = {} :: GuardInstance

	-- Properties
	self._name = name
	self._state = "Created"
	self._debug = debug or false
	self._initTime = nil
	self._startTime = nil
	self._stopTime = nil
	self._initCount = 0
	self._startCount = 0

	-- ═══════════════════════════════════════════════════════════
	-- STATE QUERIES
	-- ═══════════════════════════════════════════════════════════

	function self:IsInitialized(): boolean
		return self._state == "Initialized" or self._state == "Started" or self._state == "Stopped"
	end

	function self:IsStarted(): boolean
		return self._state == "Started"
	end

	function self:IsStopped(): boolean
		return self._state == "Stopped"
	end

	function self:GetState(): LifecycleState
		return self._state
	end

	-- ═══════════════════════════════════════════════════════════
	-- STATE TRANSITIONS
	-- ═══════════════════════════════════════════════════════════

	function self:MarkInitialized(): boolean
		self._initCount += 1
		globalStats.totalInitAttempts += 1

		if self:IsInitialized() then
			log(self, "Warn", `⚠️ Already initialized! (State: {self._state})`)
			globalStats.blockedInits += 1
			return false
		end

		self._state = "Initialized"
		self._initTime = os.clock()

		log(self, "Info", "✅ Marked as Initialized")
		return true
	end

	function self:MarkStarted(): boolean
		self._startCount += 1
		globalStats.totalStartAttempts += 1

		if self:IsStarted() then
			log(self, "Warn", `⚠️ Already started! (State: {self._state})`)
			globalStats.blockedStarts += 1
			return false
		end

		if not self:IsInitialized() then
			log(self, "Error", "❌ Cannot start before Init()!")
			return false
		end

		self._state = "Started"
		self._startTime = os.clock()

		log(self, "Info", "✅ Marked as Started")
		return true
	end

	function self:MarkStopped(): boolean
		if self:IsStopped() then
			log(self, "Warn", "⚠️ Already stopped!")
			return false
		end

		self._state = "Stopped"
		self._stopTime = os.clock()

		log(self, "Info", "🛑 Marked as Stopped")
		return true
	end

	-- ═══════════════════════════════════════════════════════════
	-- VALIDATION
	-- ═══════════════════════════════════════════════════════════

	function self:RequireInitialized()
		if not self:IsInitialized() then
			error(`[{self._name}] ❌ Must be initialized first! (Current state: {self._state})`)
		end
	end

	function self:RequireNotInitialized()
		if self:IsInitialized() then
			error(`[{self._name}] ❌ Already initialized! (State: {self._state})`)
		end
	end

	function self:RequireStarted()
		if not self:IsStarted() then
			error(`[{self._name}] ❌ Must be started first! (Current state: {self._state})`)
		end
	end

	-- ═══════════════════════════════════════════════════════════
	-- UTILITIES
	-- ═══════════════════════════════════════════════════════════

	function self:Reset()
		log(self, "Warn", "⚠️ Resetting guard state...")
		self._state = "Created"
		self._initTime = nil
		self._startTime = nil
		self._stopTime = nil
	end

	function self:GetAnalytics(): { [string]: any }
		local now = os.clock()

		return {
			name = self._name,
			state = self._state,
			initCount = self._initCount,
			startCount = self._startCount,
			initTime = self._initTime,
			startTime = self._startTime,
			stopTime = self._stopTime,
			uptime = self._startTime and (self._stopTime or now) - self._startTime or 0,
			timeSinceInit = self._initTime and now - self._initTime or 0,
		}
	end

	-- Register in global registry
	guards[name] = self
	globalStats.totalGuardsCreated += 1

	log(self, "Info", `🛡️ Created (Debug: {self._debug})`)

	return self
end

-- ═══════════════════════════════════════════════════════════════
-- GLOBAL UTILITIES
-- ═══════════════════════════════════════════════════════════════

--[[
	Get existing guard by name

	@param name string
	@return GuardInstance?
]]
function IdempotentGuard.get(name: string): GuardInstance?
	return guards[name]
end

--[[
	Get all registered guards

	@return {[string]: GuardInstance}
]]
function IdempotentGuard.getAll(): { [string]: GuardInstance }
	return guards
end

--[[
	Get global statistics

	@return {[string]: any}
]]
function IdempotentGuard.getGlobalStats(): { [string]: any }
	local stats = {
		totalGuardsCreated = globalStats.totalGuardsCreated,
		totalInitAttempts = globalStats.totalInitAttempts,
		totalStartAttempts = globalStats.totalStartAttempts,
		blockedInits = globalStats.blockedInits,
		blockedStarts = globalStats.blockedStarts,
		activeGuards = 0,
		states = {
			Created = 0,
			Initialized = 0,
			Started = 0,
			Stopped = 0,
		},
	}

	for _, guard in pairs(guards) do
		stats.activeGuards += 1
		stats.states[guard._state] = (stats.states[guard._state] or 0) + 1
	end

	return stats
end

--[[
	Print summary of all guards (debug)
]]
function IdempotentGuard.printSummary()
	print(
		"╔════════════════════════════════════════════════════════════════╗"
	)
	print("║              IDEMPOTENT GUARD SUMMARY                          ║")
	print(
		"╠════════════════════════════════════════════════════════════════╣"
	)

	local stats = IdempotentGuard.getGlobalStats()
	print(string.format("║ Total Guards: %d", stats.totalGuardsCreated))
	print(string.format("║ Init Attempts: %d (Blocked: %d)", stats.totalInitAttempts, stats.blockedInits))
	print(string.format("║ Start Attempts: %d (Blocked: %d)", stats.totalStartAttempts, stats.blockedStarts))
	print(
		"╠════════════════════════════════════════════════════════════════╣"
	)

	for name, guard in pairs(guards) do
		local symbol = guard._state == "Started" and "✅"
			or guard._state == "Initialized" and "🔵"
			or guard._state == "Stopped" and "🛑"
			or "⚪"

		print(string.format("║ %s %-30s %s", symbol, name, guard._state))
	end

	print(
		"╚════════════════════════════════════════════════════════════════╝"
	)
end

return IdempotentGuard
