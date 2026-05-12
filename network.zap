opt server_output = "src/ServerScriptService/Services/Core/ZapServer.lua"
opt client_output = "src/ReplicatedStorage/Shared/ZapClient.lua"

event PlayerRequestPalceBulidings = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        BuildingTypeEnum: u8,
        Position: Vector3
    }
}

event PlayersCreateBuilding = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        BuildingTypeEnum: u8,
        Position: Vector3
    }
}

event AssingZoneOwner = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        FolderName:string.utf8 ,
    }
}
