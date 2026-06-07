--!strict
--[[
	ชุดทดสอบจิ๋วสำหรับรันด้วย Lune (ไม่ต้องเปิด Roblox Studio)
	-----------------------------------------------------------
	ลงทะเบียนเทสด้วย testkit.test(name, fn) แล้วปิดท้ายไฟล์ด้วย:
		process.exit(testkit.run())
	เพื่อให้ exit code = จำนวนเทสที่ล้มเหลว (0 = ผ่านหมด)
]]

local testkit = {}

type Case = { name: string, fn: () -> () }
local cases: { Case } = {}

function testkit.test(name: string, fn: () -> ())
	table.insert(cases, { name = name, fn = fn })
end

-- ── assertions ───────────────────────────────────────────────────
function testkit.eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "ค่าไม่ตรงกัน"} (expected '{tostring(expected)}', got '{tostring(actual)}')`, 2)
	end
end

function testkit.ok(value: any, msg: string?)
	if not value then
		error(msg or "คาดหวังค่าที่เป็น truthy", 2)
	end
end

function testkit.isNil(value: any, msg: string?)
	if value ~= nil then
		error(`{msg or "คาดหวัง nil"}, got '{tostring(value)}'`, 2)
	end
end

function testkit.notNil(value: any, msg: string?)
	if value == nil then
		error(msg or "คาดหวังค่าที่ไม่ใช่ nil", 2)
	end
end

function testkit.throws(fn: () -> (), msg: string?)
	local ok = pcall(fn)
	if ok then
		error(msg or "คาดหวังให้ฟังก์ชัน error แต่ไม่ error", 2)
	end
end

-- ── runner ───────────────────────────────────────────────────────
-- คืนจำนวนเทสที่ล้มเหลว (ใช้เป็น exit code ได้เลย)
function testkit.run(): number
	local passed, failed = 0, 0
	print(`\n── running {#cases} test(s) ──`)
	for _, case in cases do
		local ok, err = pcall(case.fn)
		if ok then
			passed += 1
			print(`  ✓ {case.name}`)
		else
			failed += 1
			print(`  ✗ {case.name}`)
			print(`      {tostring(err)}`)
		end
	end
	print(`\n{passed} passed, {failed} failed\n`)
	return failed
end

return testkit
