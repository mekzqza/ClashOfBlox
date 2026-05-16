local ServerScriptService = game:GetService("ServerScriptService")
local ServiceLocator = require(ServerScriptService.Utils.ServiceLocator)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local dumppp = require(ReplicatedStorage.Utils.TableUtils)


return function(context, player, field: string)
    local PDS = ServiceLocator:Get("PlayerDataService")

    if not PDS then
        return "❌ PlayerDataService ไม่พร้อม!"
    end

    local data = PDS:GetAll(player)

    if not data then
        return `❌ ไม่พบข้อมูลของ {player.Name}`
    end

    local output = {
        ` $All Player Data: {dumppp(data)}`,
    }

    return table.concat(output, "\n")
end
