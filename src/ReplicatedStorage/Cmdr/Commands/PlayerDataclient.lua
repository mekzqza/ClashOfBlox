-- PlayerDataClient.lua
return {
    Name = "pdata",
    Aliases = { "playerdata", "pd" },
    Description = "Debug PlayerDataController (Client Cache)",
    Group = "Debug",
    Args = {
        {
            Type = "string",
            Name = "action",
            Description = "status| gold | level ",
            Optional = true,
        },
    },

    ClientRun = function(context, action)
        action = action or "status"
        action = string.lower(action)

        local output = {}
        local function addLine(text)
            table.insert(output, text)
        end

        -- DEBUG
        if action == "debug" or action == "d" then
            addLine(
                "╔══════════════════════════════════════════════════╗"
            )
            addLine("║           🔍 DEBUG: _G STATUS                    ║")
            addLine(
                "╚══════════════════════════════════════════════════╝"
            )
            addLine("")
            addLine(`_G.ControllerLocator: {_G.ControllerLocator and "✅ EXISTS" or "❌ NIL"}`)
            addLine(`_G.ControllersByCategory: {_G.ControllersByCategory and "✅ EXISTS" or "❌ NIL"}`)
            addLine(`_G.Controllers: {_G.Controllers and "✅ EXISTS" or "❌ NIL"}`)

            if _G.ControllersByCategory then
                addLine("")
                addLine("📋 Categories:")
                for cat, controllers in pairs(_G.ControllersByCategory) do
                    local names = {}
                    for name, _ in pairs(controllers) do
                        table.insert(names, name)
                    end
                    addLine(`  [{cat}]: {table.concat(names, ", ")}`)
                end
            end

            return table.concat(output, "\n")
        end

        -- หา PlayerDataController
        local PlayerDataController = nil
        local foundMethod = "none"

        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local dump = require(ReplicatedStorage.Utils.TableUtils)

        if _G.ControllerLocator then
            PlayerDataController = _G.ControllerLocator:Get("PlayerDataController")
            if PlayerDataController then
                foundMethod = "ControllerLocator"
            end
        end

        if not PlayerDataController and _G.ControllersByCategory then
            local core = _G.ControllersByCategory.Core
            if core then
                PlayerDataController = core.PlayerDataController
                if PlayerDataController then
                    foundMethod = "ControllersByCategory.Core"
                end
            end
        end

        if not PlayerDataController and _G.Controllers then
            PlayerDataController = _G.Controllers["Core.PlayerDataController"]
            if PlayerDataController then
                foundMethod = "Controllers"
            end
        end

        if not PlayerDataController then
            addLine("❌ PlayerDataController not found!")
            addLine("")
            addLine("🔍 Debug Info:")
            addLine(`  _G.ControllerLocator: {_G.ControllerLocator and "✅" or "❌ NIL"}`)
            addLine(`  _G.ControllersByCategory: {_G.ControllersByCategory and "✅" or "❌ NIL"}`)
            addLine(`  _G.Controllers: {_G.Controllers and "✅" or "❌ NIL"}`)
            addLine("")
            addLine("💡 Try: pdata debug")
            return table.concat(output, "\n")
        end

        if action == "getall" or action == "all" then
            if not PlayerDataController:IsReady() then
                return "⏳ Data not ready!"
            end
            return `📈 Player Data: {dump(PlayerDataController:GetAll())}`
        else
            return `❌ Unknown: "{action}" | Try: pdata help`
        end
    end,
}
