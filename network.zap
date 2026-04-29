opt server_output = "src/ServerScriptService/Services/ZapServer.lua"
opt client_output = "src/ReplicatedStorage/Shared/ZapClient.lua"

type ChatMessage = struct {
    SenderUserId: f64,
    Body: string(..200),
    Timestamp: f64,
}

event C2S_SEND_MESSAGE = {
    from: Client,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        TargetUserId: f64,
        Body: string(..200),
    }
}

event S2C_RECEIVE_MESSAGE = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: ChatMessage,
}

event C2S_TYPING = {
    from: Client,
    type: Unreliable,
    call: ManyAsync,
    data: struct {
        TargetUserId: f64,
        IsTyping: boolean,
    }
}

event S2C_TYPING = {
    from: Server,
    type: Unreliable,
    call: ManyAsync,
    data: struct {
        SenderUserId: f64,
        IsTyping: boolean,
    }
}
