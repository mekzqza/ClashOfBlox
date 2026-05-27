opt server_output = "src/ServerScriptService/Services/Core/ZapServer.lua"
opt client_output = "src/ReplicatedStorage/Shared/ZapClient.lua"

type BuildingEntry = struct {
    SnapToString: string.utf8,
    BuildingTypeEnum: u8,
    BuildingLevel: u8,
}

type DataKey = enum {
    Golds,
    Elixirs,
    Gems,
    Level,
    Experience,
}

type CollectorData = struct {
   Timestamp: u32,
    ProductionRate: u32,
    Capacity: u32,
}

type Collector = struct {
    GoldCollector: CollectorData,
    ElixirCollector: CollectorData,
}

event LoadSnapshot = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Golds: u32,
        Elixirs: u32,
        Gems: u32,
        Level: u32,
        Experience: u32,
        Buildings: BuildingEntry[],
        Collectors: Collector,
    }
}

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

event PlayerDataUpdate = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Key: DataKey,
        Value: unknown
    }
}

event PlayerClickCollector = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        CollectorType: string.utf8,
    }
}
