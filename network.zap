opt server_output = "src/ServerScriptService/Services/ZapServer.lua"
opt client_output = "src/ReplicatedStorage/Shared/ZapClient.lua"


event ApiRespone = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Services: string.utf8,
        Action: string.utf8,
        Success: boolean,
        KeyId: u8,
        KeyValue:u8,
        Message: string.utf8
    }
}
