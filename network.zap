opt server_output = "src/ServerScriptService/Services/Core/ZapServer.lua"
opt client_output = "src/ReplicatedStorage/Shared/ZapClient.lua"

event PlayerRequestPalceBulidings = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        SnapToString: string.utf8,
        BuildingTypeEnum: u8,
        Position: Vector3
    }
}

type BuildingEntry = struct {
    SnapToString: string.utf8,
    BuildingTypeEnum: u8,
}

event SnapshotBuildings = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        FolderName: string.utf8,
        Buildings: BuildingEntry[],
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

event ClientReady = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
}

event LoadSnapshot = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Coins: u32,
        Elixirs: u32,
        Gems: u32,
        Level: u32,
        Experience: u32,
        Buildings: BuildingEntry[]
    }
}


type DataKey = enum {
    Coins,
    Elixirs,
    Gems,
    Level,
    Experience,
}

event PlayerDataUpdate = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Key: DataKey,
        Value: unknown
    }
}
