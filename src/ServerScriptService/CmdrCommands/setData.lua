return {
    Name = "setdata",
    Aliases = { "setstats", "give" },
    Description = "ตั้งค่าข้อมูลผู้เล่น (Coins, Gems, Level, Attributes.Endurance)",
    Group = "Admin",
    Args = {
        {
            Type = "player",
            Name = "ผู้เล่น",
            Description = "ผู้เล่นที่ต้องการตั้งค่าข้อมูล",
        },
        {
            Type = "string",
            Name = "ฟิลด์",
            Description = "ฟิลด์ข้อมูล: Coins, Elixirs, Gems, Level, ",
        },
        {
            Type = "number", -- ✅ เปลี่ยนจาก string เป็น number
            Name = "จำนวน",
            Description = "จำนวนที่ต้องการเพิ่ม/ลด (ใช้ค่าลบเพื่อลด)",
        },
    },
}
