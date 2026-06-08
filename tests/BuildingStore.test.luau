--!strict
--[[
	Unit test ของ BuildingStore — รันนอก Roblox Studio ด้วย Lune
		lune run tests/BuildingStore.test.luau

	BuildingStore require Events/EventBus ไว้ตอนต้นไฟล์ แต่ไม่ได้ใช้ในเมธอดเลย
	จึง mock ทั้งสองด้วยตารางว่าง เพื่อตัด dependency (Signal/Players) ออกไป

	```bash
	lune run tests/run                         # รันทุกไฟล์ tests/*.test.luau
	lune run tests/BuildingStore.test.luau     # รันไฟล์เดียว
	```
]]

local process = require("@lune/process")
local testkit = require("./testkit")
local Harness = require("./harness")

-- สร้าง store ใหม่ (state สะอาด) ต่อหนึ่งเทส
local function freshStore(): any
	local h = Harness.new()
	h:mock("ReplicatedStorage.Shared.Events", {})
	h:mock("ReplicatedStorage.SystemsShared.EventBus", {})
	return h:require("StarterPlayer.StarterPlayerScripts.Core.BuildingStore")
end

testkit.test(
	"AddBuilding เก็บข้อมูลแล้วอ่านกลับได้ครบ field",
	function()
		local store = freshStore()
		store:AddBuilding("n1", 3, 5, 101, 1, 0, 0, nil)

		local rec = store:GetBuildingData("n1")
		testkit.notNil(rec, "ควรมี record ของ n1")
		testkit.eq(rec.BuildingId, "n1")
		testkit.eq(rec.Gridx, 3)
		testkit.eq(rec.Gridz, 5)
		testkit.eq(rec.BuildingEnum, 101)
		testkit.eq(rec.BuildingLevel, 1)
		testkit.eq(rec.EndTime, 0)
		testkit.eq(rec.LastCollectedTime, 0)
	end
)

testkit.test(
	"buildingCount เริ่มที่ 0 แล้วเพิ่มตามจำนวนที่ Add",
	function()
		local store = freshStore()
		testkit.eq(store:GetbuildingCount(), 0, "เริ่มต้นต้องเป็น 0")
		store:AddBuilding("n1", 0, 0, 1, 1, 0, 0)
		store:AddBuilding("n2", 1, 1, 1, 1, 0, 0)
		testkit.eq(store:GetbuildingCount(), 2)
	end
)

testkit.test("GetBuildingData คืน nil เมื่อไม่มี id", function()
	local store = freshStore()
	testkit.isNil(store:GetBuildingData("ไม่มีจริง"))
end)

testkit.test("SetBuildingCount ตั้งค่า count ได้โดยตรง", function()
	local store = freshStore()
	store:SetBuildingCount(7)
	testkit.eq(store:GetbuildingCount(), 7)
end)

testkit.test("SetBuildingData เขียนทับ record เดิมได้", function()
	local store = freshStore()
	store:AddBuilding("n1", 0, 0, 1, 1, 0, 0)
	store:SetBuildingData("n1", {
		BuildingId = "n1",
		BuildingEnum = 2,
		BuildingLevel = 3,
		Gridx = 9,
		Gridz = 9,
		EndTime = 0,
		LastCollectedTime = 0,
	})
	local rec = store:GetBuildingData("n1")
	testkit.eq(rec.Gridx, 9)
	testkit.eq(rec.BuildingLevel, 3)
end)

process.exit(testkit.run())
