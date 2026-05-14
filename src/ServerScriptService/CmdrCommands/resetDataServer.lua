local ServerScriptService = game:GetService("ServerScriptService")
local ServiceLocator = require(ServerScriptService.Utils.ServiceLocator)

return function(context, targetPlayer: Player, fieldsString: string)
    local PlayerDataService = ServiceLocator:Get("PlayerDataService")


        if  fieldsString == "REST_ALL_FIELD" then
        PlayerDataService:ResetAllData(targetPlayer)
        return "✅ All data reset for player: " .. targetPlayer.Name
    end

    local fieldList = {}
    for field in string.gmatch(fieldsString, "[^,]+") do
        local trimmed = string.gsub(field, "^%s*(.-)%s*$", "%1") -- Trim whitespace
        if trimmed ~= "" then
            table.insert(fieldList, trimmed)
        end
    end

end
