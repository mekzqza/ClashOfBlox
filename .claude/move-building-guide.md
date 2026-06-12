# คู่มือ: เริ่มทำระบบ "ย้ายอาคาร" (Move Building) แบบ Clash of Clans

> เอกสารสอน/แผนงาน: ประเมินว่า "ตอนนี้พร้อมทำระบบย้ายอาคารหรือยัง" แล้วแนะนำวิธีทำทีละไฟล์
> พร้อมชี้จุดที่พังบ่อย (gotcha) ที่ต้องระวังเป็นพิเศษ
>
> อ่านคู่กับ [`building-id-guide.md`](./building-id-guide.md) — เอกสารนั้นอธิบาย "ทำไมย้ายอาคารเคยยาก"
> เอกสารนี้คือ "ตอนนี้ทำไมง่ายขึ้นแล้ว และจะทำยังไง"

---

## 1. สรุปสั้น — พร้อมหรือยัง? (อ่านอันนี้ก่อน) ✅

**พร้อมแล้วเกือบทั้งหมด** เพราะงานสถาปัตยกรรมที่ยากที่สุด (ตามที่ `building-id-guide.md` เตือนไว้)
**โค้ดทำไปแล้ว** — โปรเจกต์ย้ายมาใช้ **surrogate key** เรียบร้อย:

- `buildingId` ตอนนี้ = `"n1"`, `"n2"`, ... (id ทึบ คงที่ตลอดชีวิตอาคาร) — **ไม่ใช่พิกัดอีกต่อไป**
- ตำแหน่งกลายเป็น **field** ในข้อมูลแล้ว: `[Gridx, Gridz, Enum, Level, EndTime, LastCollectedTime]`
- `GridController:freeCell` **มีให้แล้ว** (เมธอดสำคัญสุดของการย้าย)

แปลว่า **"ย้าย" = แก้ field `Gridx/Gridz` ตัวเดียว** ไม่ต้อง re-key ทุกระบบเหมือนดีไซน์เก่าอีกแล้ว 🎉

### ตารางความพร้อม

| ส่วนประกอบ | สถานะ | ไฟล์ |
|---|---|---|
| Surrogate key (id คงที่ `n1`, `n2`) | ✅ มีแล้ว | `BuildingService:_PlaceBuilding` |
| พิกัดเก็บเป็น field `Gridx/Gridz` | ✅ มีแล้ว | `KEYSTORE` ทั้ง client/server |
| `GridController:freeCell()` | ✅ มีแล้ว | `GridController.luau:111` |
| `occupyCell` / `CanPlace` / `SnapToGrid` | ✅ มีแล้ว | `GridController.luau` |
| schema ส่ง `Gridx/Gridz` แยก field | ✅ มีแล้ว | `network.zap → BuildingEntry` |
| โมเดลตั้งชื่อ = `buildingId` (กดเลือกได้) | ✅ มีแล้ว | `model.Name = buildingId` |
| **Remote ขอย้าย (Client→Server)** | ❌ ต้องเพิ่ม | `network.zap` |
| **Event ย้าย** | ❌ ต้องเพิ่ม | `Events.luau` |
| **`BuildingService:MoveBuilding`** | ❌ ต้องเพิ่ม | `BuildingService.luau` |
| **อัปเดตตำแหน่งใน collector cache** | ❌ ต้องเพิ่ม (⚠️ gotcha!) | `ResourceService.luau` |
| **โหมดลาก/ย้ายฝั่ง client** | ❌ ต้องเพิ่ม | `BuildingController.luau` |
| ตรวจกริดฝั่ง server (authority) | ⚠️ มี primitive แต่ยังไม่ wire | `GridService.luau` |
| Broadcast ให้ผู้เล่นคนอื่นเห็น | ⚠️ ปิดอยู่ (การวางก็ยังปิด) | `BuildingService._BroadCastBuilding` |

> **บรรทัดสรุป:** งานที่เหลือคือ "ต่อท่อ" (remote + event + เมธอด) ไม่ใช่ "รื้อโครงสร้าง"
> ประเมินขนาดงาน: **เล็ก–กลาง** ทำได้เลย

---

## 2. ทำไม "ตอนนี้" ถึงง่ายกว่าใน `building-id-guide.md`

เอกสารเก่าเขียนตอน `buildingId = "18,24"` (พิกัดเป็นกุญแจ) — ย้าย = เปลี่ยนกุญแจ = ต้องแก้ทุก store พร้อมกัน
แต่ตอนนี้โค้ดเปลี่ยนไปแล้ว เทียบให้เห็นชัด ๆ:

**ฝั่ง client — id มาจาก counter ไม่ใช่พิกัด** (`BuildingController:_startPlacement`):
```lua
local buildingCount = self._buildingCount :: number
local nextbuildingId = `n{buildingCount + 1}`   -- ← "n1", "n2" ... ไม่ผูกกับตำแหน่ง
```

**ฝั่ง server — เหมือนกัน** (`BuildingService:_PlaceBuilding`):
```lua
local nextBuildingId = buildingcount + CONFIG.NEXT_BUILDING_ID_NUMBER
self._PlayerDataService:Set(
    player,
    `PlayerBuildings.{`{CONFIG.NEXT_BUILDING_ID}{nextBuildingId}`}`,   -- "n" .. number
    { gridx, gridz, buildingEnum, CONFIG.STARTER_LEVEL, endtime, lastCollectedTime }
)
```

**ตอนโหลดเกม — อ่านพิกัดจาก field ตรง ๆ** (`BuildingController:RecreateBuildings`):
```lua
-- ไม่มี string.match แกะพิกัดจากกุญแจอีกแล้ว — รับ gridx/gridz เป็น argument มาตรง ๆ
local worldPos = self._GridController:GridCoordsToWorld(gridx, gridz, dimension.Length, dimension.Width)
```

> 👉 เพราะ **key ไม่เปลี่ยนเวลาย้าย** ทุก cache (`_BuildingCache`, `_PlayersCollectors`, `_BuildingStore`)
> จึงชี้ถูกอยู่แล้ว และ state สำคัญ (`EndTime` เวลาเหลือก่อสร้าง, `Timestamp` การสะสมทรัพยากร)
> **ไม่ต้องคัดลอกข้ามกุญแจ** — นี่คือเหตุผลหลักที่ตอนนี้ง่าย

---

## 3. flow ที่จะสร้าง (ภาพรวม)

```
[Client] ผู้เล่นกดเลือกอาคาร (อ่าน model.Name = buildingId)
   │  เข้าโหมดย้าย → freeCell(ตำแหน่งเดิม)   ← ปล่อยเซลล์เดิมก่อน! (ดู Gotcha #2)
   ▼
[Client] ลากเมาส์ → SnapToGrid + CanPlace (พรีวิวเขียว/แดง) → คลิกยืนยัน
   │  occupyCell(ตำแหน่งใหม่) + ย้าย model + อัปเดต _BuildingStore[id].Gridx/Gridz
   ▼
EventBus C2S_PLAYER_REQUEST_MOVE { BuildingId, Gridx, Gridz }
   ▼
[Client] ClientNetworkController → ZapClient.PlayerRequestMoveBuilding.Fire
   ▼  (เครือข่าย)
[Server] ServerNetWorkHandler → EventBus LOCAL_PLAYER_REQUIRE_MOVE
   ▼
[Server] BuildingService:MoveBuilding
   │  (phase 2) GridService:CanPlace ← ตรวจ authority
   │  read-modify-write PlayerBuildings.{id} แก้แค่ Gridx/Gridz   ← รักษา EndTime/LastCollected (Gotcha #1)
   │  _BuildingCache[p][id].Gridx/Gridz = ใหม่
   │  ResourceService:UpdateCollectorPosition(...)                 ← กัน teleport (Gotcha #1)
   ▼
   (phase 2) Broadcast S2C_MOVE_BUILDING ให้ client คนอื่น
```

---

## 4. ทำทีละไฟล์ (Step by step)

### 4.1 `network.zap` — เพิ่ม remote ขอย้าย
เพิ่ม event นี้ แล้วรัน `zap network.zap` ใหม่ (อย่าแก้ `ZapServer.lua`/`ZapClient.lua` ตรง ๆ):
```zap
event PlayerRequestMoveBuilding = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        BuildingId: string.utf8,
        Gridx: u16,
        Gridz: u16,
    }
}
```
> (phase 2 — broadcast ให้คนอื่น) เพิ่มอีกตัว `from: Server` ชื่อ `MoveBuilding` ที่ส่ง `{ BuildingId, Gridx, Gridz }`
> แต่ตอนนี้ `_BroadCastBuilding` ฝั่ง place ยัง comment ไว้ (บรรทัด `-- self:_BroadCastBuilding(...)`)
> ดังนั้น **เลื่อน broadcast ไปทำทีหลังได้** ทำเวอร์ชันเห็นเฉพาะตัวเองให้เสร็จก่อน

### 4.2 `Events.luau` — เพิ่ม event คู่ (C2S + LOCAL)
```lua
Events.C2S_PLAYER_REQUEST_MOVE = "C2S_PLAYER_REQUEST_MOVE"
Events.LOCAL_PLAYER_REQUIRE_MOVE = "LOCAL_PLAYER_REQUIRE_MOVE"
```
> ⚠️ ทุก event ต้องลงทะเบียนที่นี่ก่อน ไม่งั้น `EventBus:Emit` จะ error (strict mode)

### 4.3 ต่อท่อ remote ↔ EventBus

**`ClientNetworkController.luau`** — ใน `BuildingSystem()`:
```lua
EventBus:On(Events.C2S_PLAYER_REQUEST_MOVE, function(data)
    ZapClient.PlayerRequestMoveBuilding.Fire({
        BuildingId = data.BuildingId,
        Gridx = data.Gridx,
        Gridz = data.Gridz,
    })
end)
```

**`ServerNetWorkHandler.luau`** — ใน `BuildingSytem()`:
```lua
ZapServer.PlayerRequestMoveBuilding.SetCallback(function(player, data)
    EventBus:Emit(Events.LOCAL_PLAYER_REQUIRE_MOVE, {
        Player = player,
        BuildingId = data.BuildingId,
        Gridx = data.Gridx,
        Gridz = data.Gridz,
    })
end)
```

### 4.4 `BuildingService.luau` — เพิ่ม `MoveBuilding` + handler

**สำคัญ:** ใช้ **read-modify-write** (อ่านค่าปัจจุบันมาก่อน แก้แค่พิกัด) — **อย่าประกอบค่าใหม่จาก `_BuildingCache`**
เพราะ `cache.LastCollectedTime` อาจเก่ากว่าค่าจริงที่ collector เพิ่งเขียนลง data (ดู Gotcha #1)

```lua
function BuildingService:MoveBuilding(player: Player, buildingId: string, newGridx: number, newGridz: number)
    local cache = self._BuildingCache[player] and self._BuildingCache[player][buildingId]
    if not cache then
        warn(`[BuildingService] ไม่พบอาคาร {buildingId} ของ {player.Name}`)
        return
    end

    -- (phase 2) ตรวจกริดฝั่ง server ที่นี่ก่อน reject ถ้าวางทับ — ดู Gotcha #3
    -- if not self._GridService:CanPlace(folderName, worldPos) then return end

    -- 1) อ่านค่าปัจจุบันมาทั้งแถว แล้วแก้แค่ดัชนีพิกัด (รักษา EndTime/LastCollectedTime/Level เป๊ะ)
    local row = self._PlayerDataService:Get(player, `PlayerBuildings.{buildingId}`)
    if not row then
        return
    end
    row[CONFIG.KEYSTORE["Gridx"]] = newGridx
    row[CONFIG.KEYSTORE["Gridz"]] = newGridz
    self._PlayerDataService:Set(player, `PlayerBuildings.{buildingId}`, row, false)

    -- 2) อัปเดต cache ฝั่ง server
    cache.Gridx = newGridx
    cache.Gridz = newGridz

    -- 3) ⚠️ อัปเดตตำแหน่งใน collector cache ด้วย (ถ้าอาคารนี้เป็น collector) — Gotcha #1
    self._ResourceService:UpdateCollectorPosition(player, buildingId, newGridx, newGridz)

    -- 4) (phase 2) broadcast ให้ client คนอื่นเห็น
    warn(`[BuildingService] ย้าย {buildingId} ของ {player.Name} ไป ({newGridx},{newGridz})`)
end
```

handler ใน `BuildingService:Start()`:
```lua
EventBus:On(Events.LOCAL_PLAYER_REQUIRE_MOVE, function(data)
    self:MoveBuilding(data.Player, data.BuildingId, data.Gridx, data.Gridz)
end)
```

### 4.5 `ResourceService.luau` — เพิ่มเมธอดอัปเดตตำแหน่ง collector (กัน teleport)
```lua
-- อาคาร collector เก็บ Gridx/Gridz ไว้ใน cache ของตัวเอง และ PlayerClieckCollector
-- จะเขียนค่าพวกนี้ "กลับลง PlayerBuildings" ทุกครั้งที่กดเก็บ → ถ้าไม่อัปเดตตรงนี้
-- พอผู้เล่นกดเก็บหลังย้าย ตำแหน่งเก่าจะถูกเขียนทับ → อาคารเด้งกลับที่เดิมตอน relog
function ResourceService:UpdateCollectorPosition(player: Player, buildingId: string, gridx: number, gridz: number)
    local byType = self._PlayersCollectors[player]
    if not byType then
        return
    end
    for _, collectors in byType do          -- วนทั้ง GoldCollector / ElixirCollector
        local entry = collectors[buildingId]
        if entry then
            entry.Gridx = gridx
            entry.Gridz = gridz
        end
    end
end
```

### 4.6 `BuildingController.luau` — โหมดย้ายฝั่ง client

ใช้ `_startPlacement` เป็นต้นแบบ (logic snap + พรีวิวเขียว/แดง เหมือนกันเป๊ะ) ต่างกันแค่:
ย้ายของที่มีอยู่แล้ว → **ต้อง `freeCell` ของเก่าก่อน** แล้วค่อยพรีวิว

```lua
function BuildingController:_startMoveMode(buildingId: string)
    local building = self._BuildingStore[buildingId]
    if not building then
        warn(`[BuildingController] ไม่พบอาคาร {buildingId}`)
        return
    end

    local buildingType = GameEnum:GetBuildingTypeById(building.BuildingEnum)
    local dimension = BuildingConfig:GetBuildingDimensions(buildingType)
    local model = building.BuildingModel
    local primaryPart = model.PrimaryPart :: BasePart
    local halfHeight = primaryPart.Size.Y / 2

    -- เก็บตำแหน่งเดิมไว้เผื่อ "ยกเลิก" จะได้คืนเซลล์ + ย้าย model กลับ
    local oldWorld = self._GridController:GridCoordsToWorld(building.Gridx, building.Gridz, dimension.Length, dimension.Width)

    -- ① ปล่อยเซลล์เดิมก่อน ไม่งั้นอาคารจะ "กันที่ตัวเอง" (CanPlace=false เวลาเลื่อนทับเดิม) — Gotcha #2
    self._GridController:freeCell(oldWorld, dimension.Length, dimension.Width)
    self._isPlacing = true

    -- ② พรีวิวตามเมาส์ (ทาสีเขียว/แดง + เลื่อนทั้ง model)
    self._renderConnection = RunService.RenderStepped:Connect(function()
        local mouse = Player:GetMouse()
        local snapPos = self._GridController:SnapToGrid(mouse.Hit.Position, dimension.Length, dimension.Width)
        local canPlace = self._GridController:CanPlace(snapPos, dimension.Length, dimension.Width)
        local color = if canPlace then Color3.new(0, 1, 0) else Color3.new(1, 0, 0)
        for _, child in ipairs(model:GetDescendants()) do
            if child:IsA("BasePart") then
                if child:IsA("UnionOperation") then child.UsePartColor = true end
                child.Color = color
            end
        end
        model:PivotTo(CFrame.new(snapPos.X, snapPos.Y + halfHeight + CONFIG.HEIGHT, snapPos.Z))
    end)

    -- ③ คลิกยืนยัน
    self._Connetion = Player:GetMouse().Button1Down:Connect(function()
        local mouse = Player:GetMouse()
        local snapPos = self._GridController:SnapToGrid(mouse.Hit.Position, dimension.Length, dimension.Width)
        if not self._GridController:CanPlace(snapPos, dimension.Length, dimension.Width) then
            return  -- วางไม่ได้ ยังไม่ยืนยัน (ปล่อยให้ลากต่อ)
        end
        local newX, newZ = self._GridController:GetFootPrintStart(snapPos, dimension.Length, dimension.Width)

        self._GridController:occupyCell(snapPos, dimension.Length, dimension.Width)
        building.Gridx, building.Gridz = newX, newZ                    -- อัปเดต cache client
        model:PivotTo(CFrame.new(snapPos.X, snapPos.Y + halfHeight + CONFIG.HEIGHT, snapPos.Z))

        EventBus:Emit(Events.C2S_PLAYER_REQUEST_MOVE, {               -- ยิงไป server
            BuildingId = buildingId, Gridx = newX, Gridz = newZ,
        })
        self:_stopMoveMode(model)  -- คืนสีปกติ + disconnect
    end)
end
```

> **อย่าลืม path ยกเลิก:** ถ้าผู้เล่นกด "ยกเลิก" ต้อง `occupyCell(oldWorld, ...)` คืน + `model:PivotTo` กลับ `oldWorld`
> + คืนสีโมเดลเป็นปกติ มิฉะนั้นเซลล์เดิมจะว่างค้าง (วางทับได้) และโมเดลค้างสีเขียว/แดง

**การเลือกอาคาร** ใช้ของที่มีอยู่แล้ว: ทุกโมเดลตั้งชื่อ = `buildingId` (`model.Name = buildingId`)
→ คลิกโมเดล อ่าน `model.Name` แล้วเรียก `_startMoveMode(model.Name)` ได้เลย (ผูกกับปุ่ม UI "ย้าย" ในเมนูอาคาร)

---

## 5. ⚠️ Gotchas — จุดพังบ่อย (อ่านให้ครบ)

### Gotcha #1 — collector "เด้งกลับที่เดิม" ตอน relog (อันตรายสุด)
`ResourceService:PlayerClieckCollector` เขียนตำแหน่งจาก cache ของ collector กลับลง `PlayerBuildings` ทุกครั้งที่กดเก็บ:
```lua
self._PlayerDataService:Set(player, `PlayerBuildings.{entry.BuildingId}`, {
    entry.Gridx, entry.Gridz,  -- ← ถ้าไม่อัปเดต cache นี้ตอนย้าย มันจะเขียนพิกัดเก่าทับ
    entry.BuildingEnum, entry.BuildingLevel, entry.EndTime or 0, newTimestamp,
})
```
**วิธีกัน:** เรียก `ResourceService:UpdateCollectorPosition` ใน `MoveBuilding` เสมอ (ข้อ 4.5)
และฝั่ง `MoveBuilding` ให้ **read-modify-write** อย่าประกอบค่าจาก `_BuildingCache` (ค่า `LastCollectedTime` ใน cache นั้นอาจเก่ากว่า `entry.Timestamp` จริง → ถ้าเขียนทับจะทำให้สะสมทรัพยากรเพี้ยน/โกงได้)

### Gotcha #2 — ต้อง `freeCell` ของเก่า "ก่อน" เช็ค `CanPlace`
ถ้าไม่ปล่อยเซลล์เดิมก่อน อาคารจะนับ footprint ตัวเองเป็นสิ่งกีดขวาง → ขยับทีละ 1 ช่อง (ที่ footprint ซ้อนเดิม) จะ `CanPlace=false` ตลอด ย้ายไม่ได้
**ลำดับที่ถูก:** `freeCell(เก่า)` → พรีวิว/`CanPlace(ใหม่)` → ยืนยัน `occupyCell(ใหม่)` / ยกเลิก `occupyCell(เก่า)`

### Gotcha #3 — server ยังไม่เป็น authority เรื่องกริด (เหมือนการวางตอนนี้)
`GridService` มี `CanPlace/OccupyCell/FreeCell` ก็จริง แต่:
- **ยังไม่ถูกเรียกใน `_PlaceBuilding`** (มี `@Bug` หมายเหตุไว้: ตอนนี้ไม่เช็ก cell เลย) → `_occupiedCells` ฝั่ง server ว่างเปล่าตลอด
- **เช็กทีละ 1 เซลล์** (`_worldToGrid(position)`) ยังไม่รองรับ footprint หลายช่อง
- **ใช้พิกัดโลกสัมบูรณ์** (`floor(pos/CELL)`) ส่วน client ใช้พิกัด **อิง origin ของโซน** (`GetFootPrintStart` + `_gridOriginX`) → **คนละระบบพิกัด** อย่าเอามาเทียบตรง ๆ

**สรุป:** เวอร์ชันแรกให้เชื่อ `CanPlace` ฝั่ง client ไปก่อน (สอดคล้องกับการวางที่ตอนนี้ก็ client-check อย่างเดียว)
แล้วค่อยทำ server authority เป็น **phase 2** (ดูข้อ 7) — ไม่งั้นจะติดเรื่องระบบพิกัดไม่ตรงกัน

### Gotcha #4 — key ต้องไม่มีจุด `.`
`PlayerDataService:Set` แยก path ด้วย `"."` → `buildingId` แบบ `"n1"` ปลอดภัย แต่ห้ามเปลี่ยนรูปแบบ id ให้มี `.` เด็ดขาด

### Gotcha #5 — ย้ายอาคารที่กำลังก่อสร้าง/อัปเกรด (`EndTime > 0`) ทำได้ ไม่ต้องกังวล
เพราะ key ไม่เปลี่ยน + เราใช้ read-modify-write → `EndTime` ถูกรักษาไว้ การนับถอยหลังก่อสร้างเดินต่อปกติ
(เป็น **design choice** ว่าจะอนุญาตให้ย้ายระหว่างก่อสร้างไหม — โค้ดรองรับทั้งสองแบบ ถ้าจะ "ห้าม" ก็เช็ก `cache.EndTime ~= 0` แล้ว reject)

### Gotcha #6 — broadcast ให้ผู้เล่นคนอื่นยังปิดอยู่
`_BroadCastBuilding` ในการวางถูก comment ไว้ (`-- self:_BroadCastBuilding(...)`) → ตอนนี้ผู้เล่นอื่นยังไม่เห็นการวาง/ย้าย realtime อยู่แล้ว ดังนั้น **ไม่ต้องทำ broadcast การย้ายในเฟสแรก** ทำให้ตัวเองเห็นถูกก่อน

---

## 6. Checklist ทดสอบก่อน merge

- [ ] ย้ายอาคารปกติ → relog → อยู่ตำแหน่งใหม่ (พิกัด round-trip ถูก)
- [ ] ย้าย **collector** ที่สะสมทรัพยากรค้าง → กดเก็บ → ได้ยอดถูก ไม่รีเซ็ต → relog → **ไม่เด้งกลับที่เดิม** (Gotcha #1)
- [ ] ย้ายอาคารที่ **กำลังก่อสร้าง** (`EndTime > os.time()`) → relog → เวลาเหลือยังถูก ไม่รีเซ็ต (Gotcha #5)
- [ ] เลื่อนทับอาคารอื่น → พรีวิวแดง + คลิกแล้วไม่ยืนยัน (กันชนทำงาน)
- [ ] เลื่อนทีละ 1 ช่อง (footprint ซ้อนเดิม) → ต้องย้ายได้ (Gotcha #2 — freeCell ก่อน)
- [ ] เซลล์เดิมว่างจริงหลังย้าย (วางอาคารอื่นลงที่เดิมได้)
- [ ] กด **ยกเลิก** กลางคัน → อาคารกลับที่เดิม + เซลล์เดิมยังถูกจอง + สีโมเดลกลับปกติ
- [ ] ย้ายอาคารขนาดใหญ่ (เช่น 3×3 / 4×4) → footprint ถูกทั้งก้อน

---

## 7. Phase 2 — งานเสริม (ทำเมื่อ core เสร็จแล้ว)

1. **Server grid authority** (แก้ Gotcha #3): wire `GridService:OccupyCell/FreeCell` เข้ากับทั้ง place และ move,
   ทำให้ `CanPlace` รองรับ footprint หลายช่อง, และรวมระบบพิกัด client/server ให้ตรงกัน
   → ป้องกัน force-remote วางทับ/ย้ายทับ (anti-cheat)
2. **Broadcast การย้าย** (แก้ Gotcha #6): เพิ่ม event `from: Server` + เปิด broadcast ทั้ง place และ move พร้อมกัน
3. **เงื่อนไข/ค่าใช้จ่าย:** ใน CoC การย้ายฟรี — แต่ถ้าจะจำกัด (เช่น cooldown, ห้ามย้ายขณะถูกโจมตี) ใส่เช็กใน `MoveBuilding`
4. **เก็บกวาดชื่อ** (อ้างอิง `building-id-guide.md` ข้อ 9): `ReGisterColector`/`ReisterColector`, `PlayerClieckCollector`, `_IsbuilgIsComplete` สะกดผิด — rename ให้ตรงกันจะลดบั๊กเวลาต่อระบบย้าย

---

## 8. ไฟล์ที่ต้องแตะ (สรุป)

| ไฟล์ | งาน |
|---|---|
| `network.zap` | + `PlayerRequestMoveBuilding` แล้ว `zap network.zap` |
| `Events.luau` | + `C2S_PLAYER_REQUEST_MOVE`, `LOCAL_PLAYER_REQUIRE_MOVE` |
| `ClientNetworkController.luau` | ต่อ EventBus → `ZapClient...Fire` |
| `ServerNetWorkHandler.luau` | ต่อ `ZapServer...SetCallback` → EventBus |
| `BuildingService.luau` | + `MoveBuilding` + handler (read-modify-write) |
| `ResourceService.luau` | + `UpdateCollectorPosition` (⚠️ Gotcha #1) |
| `BuildingController.luau` | + `_startMoveMode` / `_stopMoveMode` + ปุ่มเลือกอาคาร |

> เริ่มจาก client→server ฝั่งเดียวให้ทำงานเห็นเฉพาะตัวเองก่อน (ข้อ 4) แล้วค่อยทำ phase 2
