-- BuildingMove.lua
return {
    Name = "setcameraangle",
    Aliases = { "setcamangle", "sca" },
    Description = " DEBUG: Set Camera Angle",
    Group = "Debug",
    Args = {
        {
            Type = "string",
            Name = "angleType",
            Description = "Angle Type (Pitch/Yaw)",
            Optional = false,
        },
        {
            Type = "number",
            Name = "angleValue",
            Description = "Angle Value (degrees)",
            Optional = false,
        }
    },

    ClientRun = function(context, angleType, angleValue)
        local CameraController = _G.ControllerLocator:Get("CameraController")
        if not CameraController then
            return "❌ CameraController not found"
        end

        CameraController:SetAngles(angleType, angleValue)
        return `✅ Set {angleType} to {angleValue} degrees`
    end,
}
