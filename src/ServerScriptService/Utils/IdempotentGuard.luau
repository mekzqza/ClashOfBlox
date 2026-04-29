--!strict

export type LifecycleState = "Created" | "Initialized" | "Started" | "Stopped"

export type GuardInstance = {
	IsInitialized: (self: GuardInstance) -> boolean,
	IsStarted: (self: GuardInstance) -> boolean,
	IsStopped: (self: GuardInstance) -> boolean,
	GetState: (self: GuardInstance) -> LifecycleState,

	MarkInitialized: (self: GuardInstance) -> boolean,
	MarkStarted: (self: GuardInstance) -> boolean,
	MarkStopped: (self: GuardInstance) -> boolean,

	RequireInitialized: (self: GuardInstance) -> (),
	RequireNotInitialized: (self: GuardInstance) -> (),
	RequireStarted: (self: GuardInstance) -> (),

	Reset: (self: GuardInstance) -> (),
	GetAnalytics: (self: GuardInstance) -> { [string]: any },

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

local guards: { [string]: GuardInstance } = {}
local globalStats = {
	totalGuardsCreated = 0,
	totalInitAttempts = 0,
	totalStartAttempts = 0,
	blockedInits = 0,
	blockedStarts = 0,
}

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

function IdempotentGuard.getAll(): { [string]: GuardInstance }
	return guards
end

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

-- เพิ่ม cleanup method
function IdempotentGuard.remove(name: string)
	if guards[name] then
		guards[name] = nil
		globalStats.totalGuardsCreated -= 1
	end
end

return IdempotentGuard

--[[]
╔════════════════════════════════════════════════════════════════╗
║               📚 IDEMPOTENT GUARD - สรุปการใช้งาน              ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║ 🎯 PURPOSE (จุดประสงค์):                                       ║
║    ป้องกันการ Init() และ Start() ซ้ำซ้อนใน Service/Controller ║
║    รักษา lifecycle ให้ถูกต้อง (Created → Init → Start)        ║
║                                                                ║
║ ✨ FEATURES (ฟีเจอร์หลัก):                                      ║
║    1. State Tracking    - ติดตาม lifecycle state              ║
║    2. Double-Init Guard - ป้องกัน Init ซ้ำ                    ║
║    3. Order Validation  - ต้อง Init ก่อน Start เสมอ           ║
║    4. Analytics         - เก็บสถิติการใช้งาน                  ║
║    5. Global Registry   - ดู guard ทั้งหมดได้                 ║
║                                                                ║
║ 📖 BASIC USAGE (วิธีใช้พื้นฐาน):                               ║
║                                                                ║
║    local IdempotentGuard = require(...)                       ║
║    local guard = IdempotentGuard.new("MyService", true)       ║
║                                                                ║
║    function MyService:Init()                                  ║
║        if not guard:MarkInitialized() then                    ║
║            return  -- Already initialized                     ║
║        end                                                     ║
║        -- Init logic here (รันครั้งเดียว)                    ║
║    end                                                         ║
║                                                                ║
║    function MyService:Start()                                 ║
║        if not guard:MarkStarted() then                        ║
║            return  -- Already started or not initialized      ║
║        end                                                     ║
║        -- Start logic here (รันครั้งเดียว)                   ║
║    end                                                         ║
║                                                                ║
║ 🔄 LIFECYCLE STATES (สถานะต่างๆ):                             ║
║                                                                ║
║    1. Created      → guard สร้างใหม่ ยังไม่ได้ init          ║
║    2. Initialized  → Init() เรียกแล้ว พร้อม Start             ║
║    3. Started      → Start() เรียกแล้ว กำลังทำงาน            ║
║    4. Stopped      → Stop() เรียกแล้ว หยุดทำงาน              ║
║                                                                ║
║    Transition Flow:                                           ║
║    Created → Initialized → Started → Stopped                  ║
║                                                                ║
║ 🎓 ADVANCED USAGE (ใช้งานขั้นสูง):                             ║
║                                                                ║
║    -- Require state ก่อนทำงาน                                 ║
║    function MyService:DoSomething()                           ║
║        guard:RequireStarted()  -- Error ถ้ายังไม่ Start       ║
║        -- Safe to execute                                     ║
║    end                                                         ║
║                                                                ║
║    -- เช็คสถานะ                                                ║
║    if guard:IsInitialized() then                              ║
║        print("Ready to start!")                               ║
║    end                                                         ║
║                                                                ║
║    -- ดู analytics                                             ║
║    local analytics = guard:GetAnalytics()                     ║
║    print("Uptime:", analytics.uptime)                         ║
║    print("Init count:", analytics.initCount)                  ║
║                                                                ║
║ 💡 USE CASES (กรณีใช้งาน):                                     ║
║                                                                ║
║    ✅ ป้องกัน Service/Controller Init ซ้ำ                     ║
║    ✅ บังคับให้ Init ก่อน Start                               ║
║    ✅ ป้องกัน memory leak จาก double initialization          ║
║    ✅ ติดตาม lifecycle ของ modules                            ║
║    ✅ Debug ได้ง่ายว่า module ไหน Init/Start แล้ว            ║
║                                                                ║
║ ⚠️ IMPORTANT NOTES (ข้อควรระวัง):                             ║
║                                                                ║
║    • สร้าง guard เพียงครั้งเดียวต่อ module                    ║
║    • ใช้ชื่อที่ unique สำหรับแต่ละ service                     ║
║    • เช็ค return value ของ Mark* methods                     ║
║    • อย่า Reset() ใน production (ใช้เฉพาะ testing)           ║
║                                                                ║
║ 📊 GLOBAL UTILITIES (ฟังก์ชันส่วนกลาง):                       ║
║                                                                ║
║    -- ดู guard ทั้งหมด                                         ║
║    local allGuards = IdempotentGuard.getAll()                 ║
║    for name, guard in allGuards do                            ║
║        print(name, guard:GetState())                          ║
║    end                                                         ║
║                                                                ║
║    -- ดู guard เฉพาะ                                           ║
║    local guard = IdempotentGuard.get("NetworkHandler")        ║
║    if guard then                                              ║
║        print(guard:GetState())                                ║
║    end                                                         ║
║                                                                ║
║    -- ดูสถิติทั้งหมด                                           ║
║    local stats = IdempotentGuard.getGlobalStats()             ║
║    print("Total guards:", stats.totalGuardsCreated)           ║
║    print("Blocked inits:", stats.blockedInits)                ║
║                                                                ║
║    -- แสดงสรุปแบบสวย                                           ║
║    IdempotentGuard.printSummary()                             ║
║                                                                ║
║ 🎯 REAL-WORLD EXAMPLE (ตัวอย่างจริง):                         ║
║                                                                ║
║    -- NetworkHandler.luau                                     ║
║    local guard = IdempotentGuard.new("NetworkHandler", true)  ║
║                                                                ║
║    function NetworkHandler:Init()                             ║
║        if not guard:MarkInitialized() then                    ║
║            return                                             ║
║        end                                                     ║
║        -- สร้าง RemoteEvent (ครั้งเดียว)                     ║
║        self.remoteEvent = Instance.new("RemoteEvent")         ║
║    end                                                         ║
║                                                                ║
║    function NetworkHandler:Start()                            ║
║        if not guard:MarkStarted() then                        ║
║            return                                             ║
║        end                                                     ║
║        -- Connect events (ครั้งเดียว)                         ║
║        self.remoteEvent.OnServerEvent:Connect(...)            ║
║    end                                                         ║
║                                                                ║
║    function NetworkHandler:SendData(data)                     ║
║        guard:RequireStarted()  -- ต้อง Start แล้ว            ║
║        self.remoteEvent:FireAllClients(data)                  ║
║    end                                                         ║
║                                                                ║
║ 🐛 DEBUGGING (การ Debug):                                     ║
║                                                                ║
║    -- F9 Console                                              ║
║    _G.IdempotentGuard.printSummary()                          ║
║                                                                ║
║    -- เช็ค state ของ service                                  ║
║    local guard = _G.IdempotentGuard.get("NetworkHandler")     ║
║    print(guard:GetState())  -- "Started"                      ║
║                                                                ║
║    -- ดู analytics                                             ║
║    local stats = _G.IdempotentGuard.getGlobalStats()          ║
║    print(stats)                                               ║
║                                                                ║
║ 📚 API REFERENCE (รายละเอียด API):                            ║
║                                                                ║
║    Constructor:                                               ║
║    • new(name, debug) -> GuardInstance                        ║
║                                                                ║
║    State Queries:                                             ║
║    • IsInitialized() -> boolean                               ║
║    • IsStarted() -> boolean                                   ║
║    • IsStopped() -> boolean                                   ║
║    • GetState() -> LifecycleState                             ║
║                                                                ║
║    State Transitions:                                         ║
║    • MarkInitialized() -> boolean                             ║
║    • MarkStarted() -> boolean                                 ║
║    • MarkStopped() -> boolean                                 ║
║                                                                ║
║    Validation:                                                ║
║    • RequireInitialized()                                     ║
║    • RequireNotInitialized()                                  ║
║    • RequireStarted()                                         ║
║                                                                ║
║    Utilities:                                                 ║
║    • Reset()                                                  ║
║    • GetAnalytics() -> table                                  ║
║                                                                ║
║    Global Functions:                                          ║
║    • IdempotentGuard.get(name) -> GuardInstance?              ║
║    • IdempotentGuard.getAll() -> {[string]: GuardInstance}    ║
║    • IdempotentGuard.getGlobalStats() -> table                ║
║    • IdempotentGuard.printSummary()                           ║
║                                                                ║
║ 📝 BEST PRACTICES (แนวทางที่ดี):                              ║
║                                                                ║
║    ✅ สร้าง guard ครั้งเดียวต่อ module (module-level)         ║
║    ✅ เช็ค return value ของ Mark* เสมอ                       ║
║    ✅ ใช้ Require* สำหรับ critical operations                 ║
║    ✅ เปิด debug mode ใน development                          ║
║    ✅ ใช้ printSummary() เพื่อ monitor services               ║
║                                                                ║
║    ❌ อย่าสร้าง guard ใน function (memory leak!)             ║
║    ❌ อย่าลืมเช็ค return value                                ║
║    ❌ อย่า Reset() ใน production                              ║
║    ❌ อย่าใช้ชื่อซ้ำกัน                                        ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

TLDR (สรุปสั้นๆ):
─────────────────────────────────────────────────────────────────
IdempotentGuard = ตัวป้องกันการ Init/Start ซ้ำซ้อน

การใช้งาน 3 ขั้นตอน:
1. สร้าง:    local guard = IdempotentGuard.new("ServiceName")
2. ใน Init:  if not guard:MarkInitialized() then return end
3. ใน Start: if not guard:MarkStarted() then return end

Lifecycle: Created → Initialized → Started → Stopped

เหมาะสำหรับ:
• ทุก Service และ Controller
• ป้องกัน double initialization
• บังคับ Init → Start order
─────────────────────────────────────────────────────────────────

Version: 1.0.0
Author: OneShortArena Team
Last Updated: 2024
]]
