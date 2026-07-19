return {
    Name = "testpathfinding",
    Aliases = { "path" },
    Description = "Test pathfinding for Path System",
    Group = "Debug",
    Args = {
        {
            Type = "string",
            Name = "Goal",
            Description = "Type 1 to  for test _TestPathfindingWow,",
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
        elseif Goal == "00" then
            local girdPosition = {
                GridX = 5,
                GridZ = 5,
            }
            local posiiton     = BattleController:GridCoordsToWorld(5, 5, 1, 1)
            local unitLevel    = 1
            local unitEnum     = 1
            warn("Deploying unit at position:", posiiton, "GridPosition:", girdPosition, "UnitEnum:", unitEnum,
                "UnitLevel:", unitLevel)
            EventBus:Emit(Events.LOCAL_DEPLOY_UNIT, {
                UnitEnum = unitEnum,
                UnitLevel = unitLevel,
                GirdPosition = girdPosition,
            })
            EventBus:Emit(Events.LOCAL_DEPLOY_UNIT, {
                UnitEnum = 2,
                UnitLevel = unitLevel,
                GirdPosition = girdPosition,
            })
        end
    end,
}
