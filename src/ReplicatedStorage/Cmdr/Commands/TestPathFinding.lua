return {
    Name = "testpathfinding",
    Aliases = { "path" },
    Description = "Test pathfinding for Path System",
    Group = "Debug",
    Args = {
        {
            Type = "string",
            Name = "Goal",
            Description = "Target goal for pathfinding",
            Optional = true,
        },
        {
            Type = "string",
            Name = "Start",
            Description = "Starting point for pathfinding",
            Optional = true,
        }
    },

    ClientRun = function(context, Goal, Start)
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)
        local Events = require(ReplicatedStorage.Shared.Events)

        if not Goal or not Start then
            EventBus:Emit(Events.TEST_PATH_FINDING)
            return "Testing pathfinding with default parameters."
        end
    end,
}
