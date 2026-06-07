--!strict
--[[
	Type-check ทั้งโปรเจ็คนอก Roblox Studio ด้วย luau-lsp analyze
		lune run scripts/analyze

	ขั้นตอน:
	  1) สร้าง sourcemap.json ใหม่ (เผื่อมีไฟล์เพิ่ม/ลบ)
	  2) โหลด globalTypes.d.luau (Roblox API) ถ้ายังไม่มี
	  3) รัน luau-lsp analyze แล้วกรอง noise:
	       - บรรทัด [INFO]
	       - บรรทัดรายงานซ้ำจาก dependency-analysis (header มี "[game/...]")
]]

local process = require("@lune/process")
local fs = require("@lune/fs")
local stdio = require("@lune/stdio")

local GLOBAL_TYPES_URL =
	"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"

local ANALYZE_ARGS = {
	"analyze",
	"--sourcemap=sourcemap.json",
	"--defs=globalTypes.d.luau",
	"--base-luaurc=.luaurc",
	"--platform=roblox",
	"--no-strict-dm-types",
	-- ตัด vendored libraries ออก (จับ error เฉพาะโค้ดเราเอง)
	"--ignore=**/Packages/**",
	"--ignore=**/_Index/**",
	"--ignore=**/Cmdr/**",
	"--ignore=**/Libs/**",
	"src",
}

-- ── 1) sourcemap ─────────────────────────────────────────────────
stdio.write("▶ rojo sourcemap …\n")
local sm = process.exec("rojo", { "sourcemap", "default.project.json", "-o", "sourcemap.json" })
if not sm.ok then
	stdio.ewrite(sm.stderr)
	process.exit(1)
end

-- ── 2) globalTypes.d.luau ────────────────────────────────────────
if not fs.isFile("globalTypes.d.luau") then
	stdio.write("▶ ดาวน์โหลด globalTypes.d.luau …\n")
	local dl = process.exec("curl", { "-sSL", "-o", "globalTypes.d.luau", GLOBAL_TYPES_URL })
	if not dl.ok then
		stdio.ewrite("ดาวน์โหลด globalTypes ไม่สำเร็จ:\n" .. dl.stderr)
		process.exit(1)
	end
end

-- ── 3) analyze ───────────────────────────────────────────────────
stdio.write("▶ luau-lsp analyze …\n\n")
local result = process.exec("luau-lsp", ANALYZE_ARGS)

-- luau-lsp เขียนทุกอย่างลง stderr
local errors, warnings = 0, 0
local skipBlock = false

for line in string.gmatch(result.stderr, "[^\n]+") do
	if line:match("^%[INFO%]") then
		continue
	end

	-- header ของ diagnostic = มี "(บรรทัด,คอลัมน์):"
	local isHeader = line:match("%(%d+,%d+%):") ~= nil
	if isHeader then
		-- header ที่ annotate ด้วย [game/...] คือรายงานซ้ำจาก dependency -> ข้ามทั้ง block
		skipBlock = line:find("%[game/") ~= nil
		if not skipBlock then
			if line:find(": TypeError:") or line:find(": SyntaxError:") then
				errors += 1
			else
				warnings += 1
			end
		end
	end

	if not skipBlock then
		stdio.write(line .. "\n")
	end
end

stdio.write(`\n── {errors} error(s), {warnings} warning(s) ──\n`)
process.exit(if errors > 0 then 1 else 0)
