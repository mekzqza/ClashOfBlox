--!strict

local ServiceLocator = {}

export type ServiceLocator = {
	Register: (self: ServiceLocator, name: string, service: any) -> (),
	Get: (self: ServiceLocator, name: string) -> any?,
	GetAll: (self: ServiceLocator) -> { [string]: any },
}

local registry: { [string]: any } = {}
local pendingCallbacks: { [string]: { (service: any) -> () } } = {}

function ServiceLocator:Register(name: string, service: any)
	if registry[name] then
		warn(`[ServiceLocator] ⚠️ Service '{name}' already registered, overwriting`)
	end

	registry[name] = service

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

function ServiceLocator:GetAll(): { [string]: any }
	return registry
end

return ServiceLocator
