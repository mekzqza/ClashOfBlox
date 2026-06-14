local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)
local EventBus = require(ReplicatedStorage.SystemsShared.EventBus)

local ServerScriptService = game:GetService("ServerScriptService")
local ServiceLocator = require(ServerScriptService.Utils.ServiceLocator)

-- ✅ Valid keys (ใช้ชื่อที่ตรงกับ Types.luau)
local VALID_KEYS = {
    "Crystas",
    "Gems",
    "Level",
    "Aethers",
    "Experience",

}

return function(context, player, key, amount)
    local PDS = ServiceLocator:Get("PlayerDataService")

    if not PDS then
        return "❌ PlayerDataService ไม่พร้อม!"
    end

    if not PDS:IsDataLoaded(player) then
        return `❌ ข้อมูลของ {player.Name} ยังไม่โหลด!`
    end

    if not table.find(VALID_KEYS, key) then
        local validKeysStr = table.concat(VALID_KEYS, ", ")
        return `❌ ฟิลด์ '{key}' ไม่ถูกต้อง!\n\n📋 ฟิลด์ที่ใช้ได้:\n{validKeysStr}`
    end

    if type(amount) ~= "number" then
        return `❌ จำนวนต้องเป็นตัวเลข! ได้รับ: {type(amount)}`
    end

    local currentValue = PDS:Get(player, key)
    if currentValue == nil then
        return `❌ ไม่พบฟิลด์ '{key}' ในข้อมูลของ {player.Name}!\n💡 ตรวจสอบว่า PlayerData มีฟิลด์นี้หรือไม่`
    end

    if type(currentValue) ~= "number" then
        return `❌ ฟิลด์ '{key}' ไม่ใช่ตัวเลข! (type: {type(currentValue)})`
    end
    local success, newValue = PDS:Increment(player, key, amount)

    if success then
        local changeSymbol = amount >= 0 and "+" or ""
        return `✅ {player.Name}\n📊 {key}: {currentValue} → {newValue} ({changeSymbol}{amount})`
    else
        return `❌ ล้มเหลวในการแก้ไข '{key}' ของ {player.Name}!\n💡 อาจเกิน validation limit`
    end
end
