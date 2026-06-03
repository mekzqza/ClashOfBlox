# คู่มือ: `buildingId` / `snapPosition` และการย้ายอาคาร

> เอกสารสอน: อธิบายว่า `buildingId` ในเกมตอนนี้คืออะไร มันลิงก์กันข้ามระบบยังไง
> ทำไม "การย้ายอาคาร" ถึงยากในดีไซน์ปัจจุบัน และควรแก้ยังไงให้ทุกอย่างยังลิงก์กันถูก

---

## 1. สรุปสั้น (อ่านอันนี้ก่อน)

ตอนนี้ `buildingId` = **พิกัดของอาคารบนกริด** (สตริง `"startX,startZ"` เช่น `"18,24"`)
เราเอา "พิกัด" มาใช้เป็น "ชื่อ/กุญแจ" ของอาคารโดยตรง → เรียกว่า **natural key** (กุญแจที่มีความหมายในตัวเอง)

ผลที่ตามมา 3 ข้อ:
1. **ตัวตน (identity) = ตำแหน่ง** → พอย้ายอาคาร พิกัดเปลี่ยน กุญแจก็ต้องเปลี่ยนตาม
2. **ตำแหน่งถูกถอดกลับมาจากกุญแจตอนโหลดเกม** → ตอน reload ฝั่ง client ไม่ได้รับพิกัดมาตรง ๆ แต่เอากุญแจ `"18,24"` ไปคำนวณตำแหน่งโลกเอง (`GridCoordsToWorld`)
3. **กุญแจตัวเดียวถูกใช้เป็น key ในหลายระบบพร้อมกัน** → client cache, server cache, collector store, และ key ใน saved data

> **ดังนั้นถ้าจะ "ย้าย" อาคาร คุณมี 2 ทาง:**
> - **ทาง A** (อยู่กับดีไซน์เดิม): ทำการ *re-key* = ลบกุญแจเก่า + สร้างกุญแจใหม่ พร้อมกันทุกระบบแบบ atomic และต้องคัดลอก state (เวลาเหลือก่อสร้าง / เวลาเก็บล่าสุด) ข้ามไปด้วย
> - **ทาง B** (แนะนำ): เปลี่ยนเป็น **surrogate key** = ให้ id คงที่ตลอดชีวิตอาคาร แล้วเก็บ "พิกัด" เป็น *field* แทน → ย้าย = แก้ field เดียว ไม่ต้องแตะ key ที่ไหนเลย

---

## 2. ตอนนี้ `buildingId` คืออะไรกันแน่

### 2.1 มันถูกสร้างที่ไหน

ฝั่ง client ตอนวางอาคาร — `BuildingController:_startPlacement`:

```lua
local startX, startZ = self._GridController:GetFootPrintStart(snapPos, dimention.Length, dimention.Width)
local buildingId = `{startX},{startZ}`   -- ← เกิดตรงนี้ เช่น "18,24"
```

`GetFootPrintStart` คืน "พิกัดเซลล์มุมล่างซ้าย" ของ footprint (อิงจาก origin ของโซน):

```lua
-- GridController.luau
function GridController:GetFootPrintStart(position, sizeX, sizeZ)
	local halfX = (sizeX or 1) * CONFIG.CELL_SIZE / 2
	local halfZ = (sizeZ or 1) * CONFIG.CELL_SIZE / 2
	local startX = math.floor((position.X - self._gridOriginX - halfX) / CONFIG.CELL_SIZE)
	local startZ = math.floor((position.Z - self._gridOriginZ - halfZ) / CONFIG.CELL_SIZE)
	return startX, startZ
end
```

### 2.2 ตำแหน่งถูก "ถอดกลับ" จากกุญแจยังไง

ตอนโหลดเกม — `BuildingController:RecreateBuildings`:

```lua
local startX, startZ = string.match(snapPosition, "(-?%d+),(-?%d+)")   -- แกะตัวเลขออกจากกุญแจ
local worldPos = self._GridController:GridCoordsToWorld(
	tonumber(startX), tonumber(startZ), dimention.Length, dimention.Width
)   -- ← คำนวณตำแหน่งโลกกลับมาจากกุญแจ + ขนาด(จาก enum)
```

`GridCoordsToWorld` คือ "ฟังก์ชันผกผัน" ของ `GetFootPrintStart`:

```lua
function GridController:GridCoordsToWorld(startX, startZ, sizeX, sizeZ)
	local x = self._gridOriginX + startX * CONFIG.CELL_SIZE + sizeX * CONFIG.CELL_SIZE / 2
	local z = self._gridOriginZ + startZ * CONFIG.CELL_SIZE + sizeZ * CONFIG.CELL_SIZE / 2
	return Vector3.new(x, self._gridSurfaceY, z)
end
```

> ⚠️ **จุดสำคัญ:** ตอน `LoadSnapshot` (เครือข่าย) เราส่งแค่ `SnapToString` ไม่ได้ส่งพิกัดโลกมาด้วย
> client จึง *ต้อง* คำนวณตำแหน่งกลับจากกุญแจ — แปลว่า **กุญแจต้องถอดเป็นพิกัดได้เสมอ**
> และยังต้องรู้ "ขนาด" (จาก `enum` → `BuildingConfig`) เพื่อ recenter ให้ถูก
> นี่คือสาเหตุที่ดีไซน์นี้ "ผูกตำแหน่งติดกับกุญแจ" อย่างแน่นหนา

### 2.3 flow แบบเต็ม (วางอาคารใหม่)

```
[Client] _startPlacement
   │  buildingId = "18,24" (จาก GetFootPrintStart)
   │  _BuilderStore["18,24"] = {...}, RegisterBuildingCache("18,24", ...)
   ▼
EventBus C2S_PLAYER_REQUEST_PLACE { SnapToString = "18,24", ... }
   ▼
[Client] ClientNetworkController → ZapClient.PlayerRequestPalceBulidings.Fire { SnapToString = "18,24" }
   ▼  (เครือข่าย)
[Server] ServerNetWorkHandler → EventBus LOCAL_PLAYER_REQUIRE_PLACE { SnapToString = "18,24" }
   ▼
[Server] BuildingService:_PlaceBuilding
   │  PlayerDataService:Set(player, "PlayerBuildings.18,24", { enum, level, endTime, lastCollected })
   │                                              ▲ "18,24" กลายเป็น KEY ใน saved data
   ▼
   _BroadCastBuilding → S2C_CREATE_BUILDING (บอก client คนอื่นให้สร้าง)
```

flow ตอนโหลดเกม (reload):

```
[Server] BuildingService:Start (PlayerAdded)
   │  for buildingId in pairs(PlayerBuildings)   -- buildingId = "18,24"
   │    ResourceService:ReisterColector(player, "18,24", ...)  → _PlayersCollectors[p][type]["18,24"]
   │    _RegisterBuildingCache(player, "18,24", ...)           → _BuildingCache[p]["18,24"]
   ▼
[Server→Client] LoadSnapshot { Buildings = [{ SnapToString = "18,24", enum, level, ... }] }
   ▼
[Client] ClientNetworkController.LoadSnapshot
   │  buildingsMap["18,24"] = { enum, level, endTime, lastCollected }
   ▼
[Client] BuildingController.RecreateBuildings("18,24", ...)
   │  startX,startZ = parse("18,24") → GridCoordsToWorld → ตำแหน่งโลก
   │  _createBuilding / occupyCell / RegisterBuildingCache("18,24", ...)
```

---

## 3. แผนผัง "ทุกที่ที่ id ไปโผล่" (linkage map)

> ชื่อต่างกันในแต่ละชั้น แต่เป็น **สตริงตัวเดียวกัน**: `buildingId` = `SnapToString` = `snapTostring` = `snapPosition` = key ของ `PlayerBuildings`

| ชั้น | ไฟล์ : จุด | บทบาทของ id | ชื่อตัวแปร |
|---|---|---|---|
| Client | `BuildingController:_startPlacement` | **สร้าง** `"{startX},{startZ}"` | `buildingId` |
| Client | `BuildingController` | key ของ `_BuildingStore`, `_BuilderStore` | `buildingId` |
| Client | `BuildingController:BuildingComplete` | emit `{ BuildingId = id }` | `buildingId` |
| Client | `BuildingController:RecreateBuildings` | `string.match` → `GridCoordsToWorld` (ถอดพิกัด) | `snapPosition` |
| Client | `GridController:GetFootPrintStart` / `GridCoordsToWorld` | สร้าง/ถอด `startX,startZ` | `startX,startZ` |
| Client | `ClientNetworkController.LoadSnapshot` | `buildingsMap[entry.SnapToString]` | `SnapToString` |
| Client | `ClientNetworkController.BuildingSystem` | `Fire { SnapToString }` | `SnapToString` |
| Net | `network.zap` → `BuildingEntry.SnapToString` | key ใน snapshot | `SnapToString` |
| Net | `network.zap` → `PlayerRequestPalceBulidings.SnapToString` | request วางอาคาร | `SnapToString` |
| Server | `ServerNetWorkHandler.BuildingSytem` | emit `{ SnapToString }` | `SnapToString` |
| Server | `BuildingService:_PlaceBuilding` | `Set("PlayerBuildings.{snapTostring}", ...)` | `snapTostring` |
| Server | `BuildingService:Start` | `for buildingId in pairs(PlayerBuildings)` | `buildingId` |
| Server | `BuildingService._BuildingCache[player][id]` | key cache ฝั่ง server | `buildingId` |
| Server | `BuildingService:_IsbuilgIsComplete` | lookup ด้วย id | `buildingId` |
| Server | `ResourceService:ReisterColector` | `_PlayersCollectors[p][type][id]` + เก็บ `BuildingId = id` ใน entry | `buildingId` |
| Server | `ResourceService:PlayerClieckCollector` | `Set("PlayerBuildings.{entry.BuildingId}", ...)` (เขียนค่ากลับ) | `BuildingId` |
| Data | `PlayerDataService` | **key ของ `PlayerBuildings`** + `DEFAULT_DATA` (`"18,24"` ฯลฯ) | (key) |

> ทุกแถวในตารางนี้คือ "จุดที่ต้องแก้พร้อมกัน" ถ้าจะเปลี่ยน id แบบทาง A

---

## 4. ทำไม "การย้าย" ถึงยากในดีไซน์ปัจจุบัน

### เหตุผลที่ 1 — identity ผูกกับตำแหน่ง
กุญแจคือพิกัด ดังนั้น "ย้าย" = "เปลี่ยนกุญแจ" โดยอัตโนมัติ ไม่ใช่แค่ขยับโมเดล

### เหตุผลที่ 2 — ตำแหน่งถอดมาจากกุญแจตอนโหลด
`LoadSnapshot` ไม่ส่งพิกัดโลก → ถ้ากุญแจไม่ใช่พิกัดอีกต่อไป client จะ **ไม่รู้ว่าจะวางอาคารตรงไหน** (ต้องแก้ schema ให้ส่งพิกัดมาด้วย)

### เหตุผลที่ 3 — state อยู่ใน "ค่า" ไม่ใช่ "กุญแจ"
ค่าในแต่ละ entry มี state สำคัญที่ห้ามรีเซ็ต:
- `EndTime` → เวลาเหลือของการก่อสร้าง/อัปเกรด
- `Timestamp` / `LastCollectedTime` → ฐานเวลาในการสะสมทรัพยากรของ collector

ถ้า re-key แล้วลืมคัดลอก state พวกนี้ → อาคารจะ "เริ่มก่อสร้างใหม่" หรือ collector "รีเซ็ตการสะสม"

### ⚠️ Gotcha: คนละระบบพิกัด
- **`buildingId` (client)** = footprint start แบบ *อิง origin ของโซน* (`GetFootPrintStart`)
- **กุญแจ occupancy ฝั่ง server** = `GridService:_worldToGrid` = `math.floor(pos / CELL)` แบบ *พิกัดโลกสัมบูรณ์*

สองอันนี้เป็นสตริง `"x,z"` เหมือนกันแต่ **คนละความหมาย** อย่าเอามาเทียบกันตรง ๆ
(ปัจจุบันการเช็ค cell ฝั่ง server ยังไม่ถูกต่อเข้ากับ flow วางอาคาร — มี `@Bug` หมายเหตุไว้แล้วใน `BuildingService:Start`)

---

## 5. ทาง A — คงพิกัดเป็นกุญแจ (re-key เมื่อย้าย)

เหมาะเมื่อ: ยังไม่อยากแตะ schema/data เยอะ และยอมรับความเสี่ยงเรื่อง atomicity ได้

### หลักการ
"ย้าย" = ทำ 2 อย่างพร้อมกันแบบ all-or-nothing:
1. **ลบ** entry ที่กุญแจเก่า (ทุกระบบ)
2. **สร้าง** entry ที่กุญแจใหม่ โดย **คัดลอกค่าเดิมทั้งก้อน** (เพื่อรักษา `EndTime` / `Timestamp`)

### Checklist ทุก store ที่ต้อง re-key
- [ ] `PlayerDataService` → `PlayerBuildings[oldKey]` ลบ, `PlayerBuildings[newKey]` ตั้งค่า
- [ ] `BuildingService._BuildingCache[player]` → ย้าย oldKey → newKey
- [ ] `ResourceService._PlayersCollectors[player][type]` → ย้าย oldKey → newKey (พร้อม field `BuildingId` ข้างใน)
- [ ] `GridService` (server) → `FreeCell(footprint เก่า)` แล้ว `OccupyCell(footprint ใหม่)`
- [ ] Client `_BuildingStore` / `_BuilderStore` → ย้าย key
- [ ] Client `GridController` → `freeCell(เก่า)` + `occupyCell(ใหม่)`
- [ ] Broadcast ให้ client คนอื่น (ต้อง **เพิ่ม remote ใหม่** — ตอนนี้มีแค่ "create" ยังไม่มี "move/delete")

### ลำดับขั้นที่ปลอดภัย (server เป็นเจ้าของความจริง)
```
1. รับ request ย้าย { buildingId เก่า, ตำแหน่งใหม่ } จาก client
2. คำนวณ footprint ใหม่ → ตรวจ GridService:CanPlace (กันวางทับ)        ← ถ้าไม่ผ่าน reject ทันที
3. อ่านค่าเดิม v = Get("PlayerBuildings." .. oldId)                      ← เก็บ state ไว้
4. GridService:FreeCell(เก่า)  →  GridService:OccupyCell(ใหม่)
5. Set("PlayerBuildings." .. newId, v)   (v ตัวเดิม คง EndTime/Timestamp)
6. Set("PlayerBuildings." .. oldId, nil) (ลบกุญแจเก่า)
7. ย้าย _BuildingCache / _PlayersCollectors: cache[newId] = cache[oldId]; cache[oldId] = nil
8. Broadcast S2C_MOVE_BUILDING { oldId, newId, position } ให้ทุก client
```

> หมายเหตุ: `PlayerDataService:Set(player, "PlayerBuildings.18,24", nil)` ลบกุญแจได้จริง
> เพราะ `Set` แยก path ด้วย `"."` → `["PlayerBuildings", "18,24"]` แล้ว set ช่องสุดท้ายเป็น `nil`
> (เพราะงั้น **ห้ามให้กุญแจมีจุด `.`** เด็ดขาด — comma ใช้ได้)

### ตัวอย่างเชิงแนวคิด (server)
```lua
function BuildingService:MoveBuilding(player: Player, oldId: string, newStartX: number, newStartZ: number)
	local cache = self._BuildingCache[player]
	if not (cache and cache[oldId]) then
		return false
	end

	local newId = `{newStartX},{newStartZ}`
	if newId == oldId then
		return true
	end

	-- 1) อ่านค่าเดิม (รักษา state)
	local v = self._PlayerDataService:Get(player, `PlayerBuildings.{oldId}`)
	if not v then
		return false
	end

	-- 2) ตรวจกริด + จองเซลล์ใหม่ / ปล่อยเซลล์เก่า  (เรียก GridService ตาม footprint)
	-- if not self._GridService:CanPlace(...) then return false end
	-- self._GridService:FreeCell(...) ; self._GridService:OccupyCell(...)

	-- 3) re-key ใน saved data
	self._PlayerDataService:Set(player, `PlayerBuildings.{newId}`, v)
	self._PlayerDataService:Set(player, `PlayerBuildings.{oldId}`, nil)

	-- 4) re-key ทุก cache ฝั่ง server
	cache[newId] = cache[oldId]
	cache[oldId] = nil
	self._ResourceService:ReKeyCollector(player, oldId, newId)  -- ต้องเขียนเมธอดนี้เพิ่ม

	-- 5) broadcast (ต้องเพิ่ม remote S2C_MOVE_BUILDING)
	return true
end
```

### ข้อควรระวังของทาง A
- **ต้อง atomic** — ถ้าทำสำเร็จบางระบบแล้ว error กลางทาง จะเกิด "กุญแจค้าง" (orphan) / กริดล็อกค้าง ควรเตรียม rollback
- **ลืมคัดลอก state = บั๊กเงียบ** — เช่นลืม `Timestamp` ของ collector → ผู้เล่นเสียทรัพยากรสะสม
- **ต้องแก้ทุกแถวในตารางหัวข้อ 3** ครบ พลาดที่เดียวเกิด desync
- ยิ่งระบบโตขึ้น (ทหาร/กับดัก/ความเสียหายผูกกับ id) ยิ่งมีจุดต้อง re-key เพิ่ม → เปราะขึ้นเรื่อย ๆ

---

## 6. ทาง B — surrogate key (✅ แนะนำ)

แนวคิด: **แยก "ตัวตน" ออกจาก "ตำแหน่ง"**
- `buildingId` = id คงที่ที่ไม่มีความหมายเชิงตำแหน่ง (เช่น `"b_1"`, `"b_2"` หรือ GUID) — **ไม่เปลี่ยนตลอดชีวิตอาคาร**
- พิกัดกลายเป็น **field** ในค่าของอาคาร

### 6.1 เปลี่ยนโครงข้อมูล
ค่าใน `PlayerBuildings` เพิ่มช่องพิกัดเข้าไป (ต่อจากของเดิม เพื่อ migrate ง่าย):

```lua
-- เดิม:   [enum, level, endTime, lastCollected]
-- ใหม่:   [enum, level, endTime, lastCollected, gridX, gridZ]
PlayerBuildings = {
	["b_1"] = { 7, 1, 0, 0, 18, 24 },
	["b_2"] = { 1, 1, 0, 0, 23, 20 },
}
```

อัปเดต `CONFIG.KEYSTORE` ใน `BuildingService`:
```lua
KEYSTORE = {
	BuildingEnum = 1, BuildingLevel = 2, EndTime = 3, LastCollectedTime = 4,
	GridX = 5, GridZ = 6,   -- ← เพิ่ม
}
```

### 6.2 สิ่งที่ต้องแก้ทีละไฟล์
| ไฟล์ | แก้อะไร |
|---|---|
| `network.zap` → `BuildingEntry` | เพิ่ม `GridX: i32, GridZ: i32` และให้ `SnapToString` เป็น **id ทึบ** (ไม่ใช่พิกัดอีกต่อไป) แล้ว `zap network.zap` ใหม่ |
| `BuildingService:_PlaceBuilding` | **server เป็นคน gen id** (กัน cheat) เช่น counter ต่อผู้เล่น หรือ `HttpService:GenerateGUID(false)` แล้ว `Set("PlayerBuildings.{id}", { enum, level, endTime, lastCollected, startX, startZ })` |
| Client request วาง | ส่ง `GridX/GridZ` (footprint start) ไปด้วย แทนที่จะแอบฝังในกุญแจ |
| `BuildingController:RecreateBuildings` | อ่าน `startX = value[5]`, `startZ = value[6]` **แทนการ `string.match` จากกุญแจ** |
| `ClientNetworkController.LoadSnapshot` | ใส่ `gridX/gridZ` ลงใน map ของแต่ละอาคาร |
| `ResourceService` / `BuildingService` caches | key เป็น id ทึบเหมือนเดิม — แต่ตอนนี้ "ปลอดภัยถาวร" เพราะ id ไม่เปลี่ยน |
| `PlayerDataService` | `DEFAULT_DATA` เปลี่ยนเป็น shape ใหม่ + เขียน migration (ดู 6.4) |

### 6.3 ย้ายอาคาร = แก้ field เดียว
```lua
function BuildingService:MoveBuilding(player: Player, buildingId: string, newStartX: number, newStartZ: number)
	local v = self._PlayerDataService:Get(player, `PlayerBuildings.{buildingId}`)
	if not v then return false end

	-- ตรวจกริด + ปล่อย/จองเซลล์ (เหมือนเดิม)
	-- self._GridService:CanPlace(...) / FreeCell(เก่า) / OccupyCell(ใหม่)

	v[5], v[6] = newStartX, newStartZ                 -- อัปเดตพิกัดในค่า
	self._PlayerDataService:Set(player, `PlayerBuildings.{buildingId}`, v)

	-- broadcast S2C_MOVE_BUILDING { buildingId, gridX, gridZ }
	return true
end
```
ไม่ต้องแตะ `_BuildingCache`, `_PlayersCollectors`, ไม่ต้องคัดลอก `Timestamp`/`EndTime` —
เพราะ **key ไม่เปลี่ยน** ทุก cache ชี้ถูกอยู่แล้ว `Timestamp` ของ collector อยู่ครบ ✅

### 6.4 Migration (สำคัญ — ห้ามลืม)
มีของเก่าที่บันทึกไว้แล้วเป็น "พิกัดเป็นกุญแจ" ต้องแปลง โดยใช้ hook ที่มีอยู่แล้ว:

```lua
-- PlayerDataService
self._DATA_VERSION = 2   -- bump จาก 1 → 2

function PlayerDataService:_migrateData(data, fromVersion)
	if fromVersion < 2 then
		local old = data.PlayerBuildings
		local new = {}
		local counter = 0
		for posKey, v in pairs(old) do
			local sx, sz = string.match(posKey, "(-?%d+),(-?%d+)")
			counter += 1
			new[`b_{counter}`] = { v[1], v[2], v[3], v[4], tonumber(sx), tonumber(sz) }
		end
		data.PlayerBuildings = new
	end
	return data
end
```
> `_migrateData` ถูกเรียกอัตโนมัติเมื่อ `profile.Data._version < self._DATA_VERSION` (ดู `_loadPlayerProfile`)
> อย่าลืมอัปเดต `DEFAULT_DATA.PlayerBuildings` ให้เป็น shape ใหม่ด้วย (สำหรับโปรไฟล์ใหม่)

---

## 7. เทียบข้อดี–ข้อเสีย

| หัวข้อ | ทาง A: พิกัดเป็นกุญแจ (re-key) | ทาง B: surrogate key (แนะนำ) |
|---|---|---|
| ย้ายอาคาร | ต้อง re-key ทุกระบบพร้อมกัน + คัดลอก state | แก้ field `gridX/gridZ` ค่าเดียว |
| ความเสี่ยง desync | สูง (พลาดที่เดียวพัง) | ต่ำ (key ไม่เปลี่ยน) |
| รักษา state (เวลา/สะสม) | ต้องทำเอง เสี่ยงลืม | อัตโนมัติ |
| โหลดเกม | กุญแจถอดเป็นพิกัดได้อยู่แล้ว | ต้องส่ง `gridX/gridZ` เพิ่มใน schema |
| งานที่ต้องทำตอนนี้ | เขียน flow ย้าย + remote ใหม่ | แก้ schema + migration + อ่านพิกัดจาก field |
| ความยั่งยืนระยะยาว | เปราะขึ้นเมื่อระบบโต | ขยายระบบใหม่ผูก id ได้ปลอดภัย |

**คำแนะนำ:** ถ้ามีแผนทำฟีเจอร์ "ย้ายอาคาร" จริงจัง ลงทุนทำ **ทาง B** ตั้งแต่ตอนนี้ (ตอนนี้ migration ยังถูก เพราะข้อมูลผู้เล่นยังน้อย) จะคุ้มกว่ามากในระยะยาว

---

## 8. Checklist ก่อน merge / ทดสอบ

ไม่ว่าจะเลือกทางไหน เทสต์เคสที่ต้องผ่าน:
- [ ] วางอาคารใหม่ → relog → อาคารอยู่ตำแหน่งเดิม (ตำแหน่ง round-trip ถูก)
- [ ] ย้ายอาคารที่กำลังก่อสร้าง (`EndTime > os.time()`) → relog → เวลาเหลือยังถูก ไม่รีเซ็ต
- [ ] ย้าย collector ที่สะสมทรัพยากรค้างไว้ → กดเก็บ → ได้ยอดถูก (ไม่รีเซ็ต `Timestamp`)
- [ ] ย้ายไปทับอาคารอื่น → ต้องถูก reject (กริดกันชน)
- [ ] ปล่อยเซลล์เก่าแล้วจริง (วางอาคารอื่นลงที่เดิมได้)
- [ ] client คนอื่นเห็นอาคารขยับตาม (ต้องมี broadcast)
- [ ] (ทาง B) ผู้เล่นเก่าที่มี data v1 → migrate เป็น v2 ได้ ไม่ crash

---

## 9. ของแถม — ความไม่สอดคล้องของชื่อที่ควรเก็บกวาด

ระหว่างไล่โค้ดเจอชื่อเรียกสิ่งเดียวกันหลายแบบ ควร rename ให้เป็นมาตรฐานเดียว (จะช่วยลดบั๊กตอนแก้เรื่อง id):
- `buildingId` / `SnapToString` / `snapTostring` / `snapPosition` → เลือกชื่อเดียว เช่น `buildingId`
- เมธอดสะกดผิด: `ReisterColector` / `ReGisterColector` (สองที่สะกดไม่ตรงกัน), `PlayerClieckCollector`, `_IsbuilgIsComplete`, `_collctorTimeremaining` → ตั้งใหม่ให้ถูก จะได้ไม่เรียกผิด
- ปัจจุบัน `C2S_BUILDING_CONSTRUCTION_COMPLETE` ฝั่ง client handler (`ClientNetworkController`) **ยังว่าง** ไม่ได้ยิงไปหา server จริง → server `LOCAL_BUILDING_CONSTRUCTION_COMPLETE` เลยไม่เคยถูกกระตุ้นจาก client (ต้องเพิ่ม remote + ต่อสายให้ครบถ้าจะใช้ระบบนับถอยหลังก่อสร้าง)
```

