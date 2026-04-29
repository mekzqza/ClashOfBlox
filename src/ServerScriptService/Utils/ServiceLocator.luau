--!strict

local ServiceLocator = {}

export type ServiceLocator = {
	Register: (self: ServiceLocator, name: string, service: any) -> (),
	Get: (self: ServiceLocator, name: string) -> any?,
	GetAsync: (self: ServiceLocator, name: string, callback: (service: any) -> (), timeout: number?) -> (),
	Has: (self: ServiceLocator, name: string) -> boolean,
	WaitFor: (self: ServiceLocator, name: string, timeout: number?) -> any?,
	GetAll: (self: ServiceLocator) -> { [string]: any },
	PrintRegistry: (self: ServiceLocator) -> (),
}

local registry: { [string]: any } = {}
local pendingCallbacks: { [string]: { (service: any) -> () } } = {}

function ServiceLocator:Register(name: string, service: any)
	if registry[name] then
		warn(`[ServiceLocator] ⚠️ Service '{name}' already registered, overwriting`)
	end

	registry[name] = service
	print(`[ServiceLocator] ✅ Registered: {name}`)

	-- Fire pending callbacks
	if pendingCallbacks[name] then
		for _, callback in ipairs(pendingCallbacks[name]) do
			task.spawn(callback, service)
		end
		pendingCallbacks[name] = nil
	end
end

function ServiceLocator:Get(name: string): any?
	return registry[name]
end

function ServiceLocator:GetAsync(name: string, callback: (service: any) -> (), timeout: number?)
	-- Already registered
	if registry[name] then
		task.spawn(callback, registry[name])
		return
	end

	-- Add to pending
	if not pendingCallbacks[name] then
		pendingCallbacks[name] = {}
	end
	table.insert(pendingCallbacks[name], callback)

	-- Timeout handler
	timeout = timeout or 10
	task.delay(timeout, function()
		if not registry[name] then
			warn(`[ServiceLocator] ⏱️ Timeout waiting for '{name}' ({timeout}s)`)
			-- Remove callback
			if pendingCallbacks[name] then
				local index = table.find(pendingCallbacks[name], callback)
				if index then
					table.remove(pendingCallbacks[name], index)
				end
			end
		end
	end)
end

function ServiceLocator:Has(name: string): boolean
	return registry[name] ~= nil
end

function ServiceLocator:WaitFor(name: string, timeout: number): any?
	timeout = timeout or 10
	local startTime = os.clock()

	while not registry[name] do
		local elapsed = os.clock() - startTime
		if elapsed > timeout then
			warn(`[ServiceLocator] ⏱️ Timeout waiting for '{name}'`)
			return nil
		end
		task.wait(0.1)
	end

	return registry[name]
end

function ServiceLocator:GetAll(): { [string]: any }
	return registry
end

function ServiceLocator:PrintRegistry()
	print(
		"╔════════════════════════════════════════════════════════════════╗"
	)
	print("║              SERVICE LOCATOR REGISTRY                          ║")
	print(
		"╠════════════════════════════════════════════════════════════════╣"
	)

	local count = 0
	for name, _ in pairs(registry) do
		count += 1
		print(`║ ✅ {name}`)
	end

	print(
		"╠════════════════════════════════════════════════════════════════╣"
	)
	print(`║ Total Services: {count}`)
	print(
		"╚════════════════════════════════════════════════════════════════╝"
	)
end

return ServiceLocator
