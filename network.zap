opt server_output = "src/ServerScriptService/Services/Core/ZapServer.lua"
opt client_output = "src/ReplicatedStorage/Shared/ZapClient.lua"

type BuildingEntry = struct {
    BuildingId: string.utf8,
    Gridx: u16,
    Gridz: u16,

    BuildingEnum: u8,
    BuildingLevel: u8,
    EndTime: u32,
    LastCollectedTime : u32,
}

type DataKey = enum {
    Crystals,
    Aethers,
    Gems,
    Level,
    Experience,
    BuildingCount,
    BuilderHutSlot,
    MapSkin
}

type CollectorData = struct {
   Timestamp: u32,
    ProductionRate: u32,
    Capacity: u32,
}

type Collector = struct {
    CrystalCollector: CollectorData,
    AetherCollector: CollectorData,
}

event LoadSnapshot = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Crystals: u32,
        Aethers: u32,
        Gems: u32,
        Level: u32,
        Experience: u32,
        Buildings: BuildingEntry[],
        BuildingCount: u32,
        BuilderHutSlot: u8,
        MapSkin: u8,
    }
}

event PlayerRequestPalceBulidings = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Gridx: u16,
        Gridz: u16,
        BuildingEnum: u8,
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

event ConstructionComplete = {
    from:Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
    BuildingId: string.utf8,
    }
}

event UpdateBuildingPosition = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        BuildingId: string.utf8,
        Gridx: u16,
        Gridz: u16,
        Position: Vector3
    }
}
