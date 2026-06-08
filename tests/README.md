# ทดสอบโค้ดนอก Roblox Studio (Lune)

ระบบนี้ให้รันและทดสอบโมดูล Luau ของโปรเจ็ค **โดยไม่ต้องเปิด Roblox Studio**
ผ่าน [Lune](https://lune-org.github.io/docs) (ติดตั้งแล้วใน `aftman.toml`)

## รันเทส

```bash
lune run tests/run                         # รันทุกไฟล์ tests/*.test.luau
lune run tests/BuildingStore.test.luau     # รันไฟล์เดียว
```

exit code = 0 เมื่อผ่านหมด, ≠ 0 เมื่อมีเทสล้มเหลว (ใช้ใน CI ได้)

## ไฟล์ในโฟลเดอร์นี้

| ไฟล์ | หน้าที่ |
|---|---|
| `harness.luau` | สร้าง fake `game` + `require` จาก `sourcemap.json` เพื่อรันโมดูลจริง |
| `testkit.luau` | assertion จิ๋ว (`eq`, `ok`, `isNil`, `notNil`, `throws`) + ตัวรัน |
| `run.luau` | ค้นหาและรันไฟล์ `*.test.luau` ทุกไฟล์ (แต่ละไฟล์เป็น subprocess) |
| `*.test.luau` | ไฟล์เทส |

## harness ทำงานยังไง

โมดูล Roblox เรียก `game:GetService(...)` และ `require(game.X.Y)` ซึ่ง Lune ไม่มีให้ตรง ๆ
harness จึง:

1. อ่าน `sourcemap.json` (สร้างด้วย `rojo sourcemap`) → สร้าง tree ของ "fake Instance"
   ที่ map ชื่อ Instance ไปยังไฟล์จริงบนดิสก์
2. รันซอร์สของโมดูลด้วย `luau.load(src, { environment = ..., injectGlobals = true })`
   โดยยัด `game` (fake DataModel) และ `require` (resolver ของเราเอง) เข้าไปใน environment
3. `require(node)` จะ:
   - คืน **mock** ถ้าลงทะเบียนไว้
   - ไม่งั้นอ่านไฟล์ของ node นั้นมารัน (แล้ว cache ผลไว้)

> ⚠️ ก่อนรันเทส ต้องมี `sourcemap.json` — `scripts/analyze.luau` สร้างให้อยู่แล้ว
> ถ้ายังไม่มี/เพิ่มไฟล์ใหม่ ให้รัน `rojo sourcemap default.project.json -o sourcemap.json`

## เขียนเทสใหม่

ตั้งชื่อไฟล์ลงท้าย `.test.luau` แล้ววางในโฟลเดอร์ `tests/`

```lua
--!strict
local process = require("@lune/process")
local testkit = require("./testkit")
local Harness = require("./harness")

testkit.test("คำอธิบายเทส", function()
    local h = Harness.new()

    -- mock dependency ที่ไม่อยากให้รันจริง (path = ไม่ต้องมี "game." นำหน้า)
    h:mock("ReplicatedStorage.Shared.Events", {})

    -- require โมดูลที่จะทดสอบ
    local Store = h:require("StarterPlayer.StarterPlayerScripts.Core.BuildingStore")

    Store:AddBuilding("n1", 3, 5, 101, 1, 0, 0)
    testkit.eq(Store:GetBuildingData("n1").Gridx, 3)
end)

process.exit(testkit.run())  -- ปิดท้ายไฟล์เสมอ
```

### mock เมื่อไหร่

- โมดูลที่ทดสอบ `require` ของที่พึ่งพา runtime ของ Roblox (เช่น `EventBus` ที่ connect
  `Players.PlayerRemoving`, หรือ package ที่ใช้ `task`) → **mock มันทิ้ง** เพื่อตัด dependency ออก
- โมดูล logic ล้วน (เช่น `Events`, config) → ปล่อยให้ harness โหลดไฟล์จริงได้เลย ไม่ต้อง mock

### API ของ Harness

- `Harness.new()` → สร้าง instance ใหม่ (state/cache สะอาด — ควรสร้างใหม่ต่อหนึ่งเทสเพื่อ isolate)
- `h:mock(path, value)` → ให้ `require(path)` คืน `value`
- `h:require(target)` → require ด้วย string path หรือ fake Instance node
- `h:getGame()` → fake DataModel root (ไว้สร้าง fake Instance เพิ่มเองได้)

## ข้อจำกัด (รู้ไว้ก่อนเจอ)

- harness นี้เหมาะกับ **โมดูล logic ล้วน** ไม่ได้จำลอง DataModel/physics/rendering จริง
  ของพวกนั้นให้ mock แทน
- `game:GetService("Players")` ฯลฯ ที่ไม่มีใน sourcemap จะได้ node ว่าง (index ลูกที่ไม่มีคืน `nil`)
  ถ้าโมดูลเรียกเมธอด runtime ของมันต่อจะ error — ให้ mock โมดูลที่เรียกใช้แทน
- ทุกครั้งที่ **เพิ่ม/ลบไฟล์** ต้อง regenerate `sourcemap.json` (รัน `scripts/analyze.luau` ก็ได้)

## เกี่ยวข้องกัน

ดู `scripts/analyze.luau` สำหรับ **type-check ทั้งโปรเจ็ค** (luau-lsp analyze) — คนละชั้นกับเทสนี้
(เทส = พฤติกรรม runtime, analyze = ความถูกต้องของ type แบบ static)
