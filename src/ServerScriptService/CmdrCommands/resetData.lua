return {
    Name = "resetdata",
    Aliases = { "resetfields", "cleardata" },
    Description = "Reset player data fields to default values or REST_ALL_FIELD to Reset all fields.",
    Group = "Admin",
    Args = {
        {
            Type = "player",
            Name = "Player",
            Description = "Target player"
        },
        {
            Type = "string",
            Name = "Fields",
            Description = "Comma-separated field names (e.g., Inventory,Coins,Gems) REST_ALL_FIELD to Reset all fields",
        },
    }
}
