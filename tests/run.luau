--!strict
--[[
	รัน unit test ทุกไฟล์ (tests/*.test.luau) นอก Roblox Studio
		lune run tests/run

	แต่ละไฟล์เทสรันแยกเป็น subprocess (state สะอาด + รันไฟล์เดียวก็ได้ด้วย
	`lune run tests/<ชื่อ>.test.luau`)
]]

local process = require("@lune/process")
local fs = require("@lune/fs")
local stdio = require("@lune/stdio")

local files = {}
for _, name in fs.readDir("tests") do
	if name:match("%.test%.luau$") then
		table.insert(files, "tests/" .. name)
	end
end
table.sort(files)

if #files == 0 then
	stdio.write("ไม่พบไฟล์เทส (tests/*.test.luau)\n")
	process.exit(0)
end

local failedFiles = 0
for _, file in files do
	stdio.write(`\n══════ {file} ══════\n`)
	local r = process.exec("lune", { "run", file })
	if #r.stdout > 0 then
		stdio.write(r.stdout)
	end
	if #r.stderr > 0 then
		stdio.ewrite(r.stderr)
	end
	if not r.ok then
		failedFiles += 1
	end
end

stdio.write(`\n════════════════════════════\n`)
stdio.write(`รวม {#files} ไฟล์, ล้มเหลว {failedFiles} ไฟล์\n`)
process.exit(if failedFiles > 0 then 1 else 0)
