--!strict

local Signal = require(game.ReplicatedStorage.Packages.Signal)
local Events = require(game.ReplicatedStorage.Shared.Events)
local Players = game:GetService("Players")

-- ═══════════════════════════════════════════════════════════════
-- TYPES
-- ═══════════════════════════════════════════════════════════════

type EventCallback = (...any) -> ()
type SignalConnection = typeof(Signal.new():Connect(function() end))

export type EventBus = {
	On: (self: EventBus, eventName: string, callback: EventCallback, safeMode: boolean?) -> SignalConnection,
	Once: (self: EventBus, eventName: string, callback: EventCallback, safeMode: boolean?) -> SignalConnection,
	Emit: (self: EventBus, eventName: string, ...any) -> (),
	Off: (self: EventBus, eventName: string) -> (),
	Clear: (self: EventBus) -> (),
	OnForPlayer: (self: EventBus, player: Player, eventName: string, callback: EventCallback) -> SignalConnection,
	CleanupPlayer: (self: EventBus, userId: number) -> (),
}

-- ═══════════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════════

local STRICT_MODE = true

local allowedEvents = {}
for _, eventName in pairs(Events) do
	allowedEvents[eventName] = true
end

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════

local EventBus = {} :: EventBus
local signals: { [string]: any } = {}
local playerConnections: { [number]: { SignalConnection } } = {}

-- ═══════════════════════════════════════════════════════════════
-- PRIVATE
-- ═══════════════════════════════════════════════════════════════

local function validateEventName(eventName: any, fnName: string)
	if type(eventName) ~= "string" then
		error(`EventBus:{fnName}() - eventName must be a string, got {type(eventName)}`, 3)
	end

	if STRICT_MODE and not allowedEvents[eventName] then
		error(`EventBus:{fnName}() - Unknown event '{eventName}'. Add it to Events.luau first!`, 3)
	end
end

local function getSignal(eventName: string)
	if not signals[eventName] then
		signals[eventName] = Signal.new()
	end
	return signals[eventName]
end

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC
-- ═══════════════════════════════════════════════════════════════

function EventBus:On(eventName: string, callback: EventCallback, safeMode: boolean?): SignalConnection
	validateEventName(eventName, "On")
	assert(type(callback) == "function", "callback must be a function")

	local signal = getSignal(eventName)

	if safeMode then
		return signal:Connect(function(...)
			local ok, err = pcall(callback, ...)
			if not ok then
				warn(`[EventBus] ❌ Error in '{eventName}': {err}`)
			end
		end)
	end

	return signal:Connect(callback)
end

function EventBus:Once(eventName: string, callback: EventCallback, safeMode: boolean?): SignalConnection
	validateEventName(eventName, "Once")
	assert(type(callback) == "function", "callback must be a function")

	local signal = getSignal(eventName)

	if safeMode then
		return signal:Once(function(...)
			local ok, err = pcall(callback, ...)
			if not ok then
				warn(`[EventBus] ❌ Error in Once '{eventName}': {err}`)
			end
		end)
	end

	return signal:Once(callback)
end

function EventBus:Emit(eventName: string, ...: any)
	validateEventName(eventName, "Emit")

	local signal = signals[eventName]
	if signal then
		signal:Fire(...)
	end
end

function EventBus:Off(eventName: string)
	validateEventName(eventName, "Off")

	local signal = signals[eventName]
	if signal then
		signal:Destroy()
		signals[eventName] = nil
	end
end

function EventBus:Clear()
	for _, signal in pairs(signals) do
		signal:Destroy()
	end
	signals = {}
end

-- ═══════════════════════════════════════════════════════════════
-- PLAYER HELPERS
-- ═══════════════════════════════════════════════════════════════

function EventBus:OnForPlayer(player: Player, eventName: string, callback: EventCallback): SignalConnection
	local userId = player.UserId

	if not playerConnections[userId] then
		playerConnections[userId] = {}
	end

	local connection = self:On(eventName, function(...)
		if Players:GetPlayerByUserId(userId) then
			callback(...)
		end
	end)

	table.insert(playerConnections[userId], connection)
	return connection
end

function EventBus:CleanupPlayer(userId: number)
	local connections = playerConnections[userId]
	if connections then
		for _, conn in ipairs(connections) do
			conn:Disconnect()
		end
		playerConnections[userId] = nil
	end
end

-- ═══════════════════════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════════════════════

Players.PlayerRemoving:Connect(function(player)
	EventBus:CleanupPlayer(player.UserId)
end)

return EventBus
