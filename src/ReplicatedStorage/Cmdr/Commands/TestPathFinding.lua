return {
    Name = "testpathfinding",
    Aliases = { "path" },
    Description = "Test pathfinding for Path System",
    Group = "Debug",
    Args = {
        {
            Type = "string",
            Name = "Goal",
            Description = "Type 1 to  for test _TestPathfindingWow, 2 to _TestCombatWow",
            Optional = true,
        },

    },

    ClientRun = function(context, Goal)
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
        local Events = require(ReplicatedStorage.Shared.Events)

        local BattleController = _G.ControllerLocator:Get("BattleController")
        if not BattleController then
            return "❌ BattleController not found"
        end

        if Goal == "1" then
            BattleController:_TestPathfindingWow()
            return
        elseif Goal == "2" then
            BattleController:_TestCombatWow()
            return
        end
    end,
}
