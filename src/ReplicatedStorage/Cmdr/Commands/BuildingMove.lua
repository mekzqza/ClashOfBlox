-- BuildingMove.lua
return {
    Name = "buildingmove",
    Aliases = { "moveBd", "mvB" },
    Description = "Debug BuildingController:MoveBuilding (Client Cache)",
    Group = "Debug",
    Args = {
        {
            Type = "string",
            Name = "buildingId",
            Description = "building Id",
            Optional = false,
        },
    },

    ClientRun = function(context, buildingId)
        local BuildingController = _G.ControllerLocator:Get("BuildingController")
        if not BuildingController then
            return "❌ BuildingController not found"
        end

        BuildingController:MoveBuilding(buildingId)
        return `MoveBuilding({buildingId})`
    end,
}
