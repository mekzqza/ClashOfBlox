--!strict
--[[
	Roblox test harness สำหรับ Lune
	-----------------------------------
	รันโมดูล Luau ของโปรเจ็ค "นอก Roblox Studio" โดย:
	  1) อ่าน sourcemap.json (สร้างด้วย `rojo sourcemap`) เพื่อสร้าง fake DataModel
	     ที่ map ชื่อ Instance -> ไฟล์จริงในดิสก์
	  2) แทน global `game` ด้วย fake DataModel นั้น
	  3) แทน global `require` ด้วยตัว resolver ที่:
	        - ถ้าโมดูลถูก mock ไว้ -> คืน mock
	        - ถ้าไม่ -> อ่าน source แล้วรันด้วย luau.load (custom environment)

	การใช้งาน (ดูตัวอย่างที่ tests/BuildingStore.test.luau):
		local Harness = require("./harness")
		local h = Harness.new()
		h:mock("ReplicatedStorage.Shared.Events", { FOO = "FOO" })
		local Mod = h:require("StarterPlayer.StarterPlayerScripts.Core.BuildingStore")
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local SOURCEMAP_PATH = "sourcemap.json"

-- ── fake Instance ────────────────────────────────────────────────
export type Node = {
	Name: string,
	ClassName: string,
	__children: { [string]: Node },
	__file: string?,
	__fullName: string,
	[any]: any,
}

-- forward declarations (มี circular dependency: methods -> newNode -> nodeMeta -> methods)
local newNode: (name: string, className: string, fullName: string) -> Node
local nodeMeta

local methods = {}

function methods.GetService(self: Node, name: string): Node
	local existing = self.__children[name]
	if existing then
		return existing
	end
	-- service ที่ไม่มีใน sourcemap (เช่น Players, RunService) -> สร้าง node ว่างให้
	-- index ลูกที่ไม่มีจะคืน nil อย่างปลอดภัย (ไม่ crash ตอน GetService)
	local full = if self.__fullName == "" then name else `{self.__fullName}.{name}`
	local created = newNode(name, name, full)
	self.__children[name] = created
	return created
end

function methods.FindFirstChild(self: Node, name: string): Node?
	return self.__children[name]
end

function methods.WaitForChild(self: Node, name: string): Node?
	return self.__children[name]
end

function methods.GetChildren(self: Node): { Node }
	local out = {}
	for _, child in self.__children do
		table.insert(out, child)
	end
	return out
end

function methods.IsA(self: Node, className: string): boolean
	return self.ClassName == className
end

nodeMeta = {
	__index = function(node: Node, key: any): any
		local m = methods[key]
		if m ~= nil then
			return m
		end
		return node.__children[key]
	end,
	__tostring = function(node: Node): string
		return node.__fullName ~= "" and node.__fullName or "game"
	end,
}

function newNode(name: string, className: string, fullName: string): Node
	return setmetatable({
		Name = name,
		ClassName = className,
		__children = {},
		__file = nil,
		__fullName = fullName,
	}, nodeMeta) :: any
end

-- ── สร้าง tree จาก sourcemap ─────────────────────────────────────
local function normalize(path: string): string
	return (path:gsub("\\", "/"))
end

local function pickScriptFile(filePaths: { string }?): string?
	if not filePaths then
		return nil
	end
	for _, fp in filePaths do
		local n = normalize(fp)
		if n:match("%.luau$") or n:match("%.lua$") then
			return n
		end
	end
	return nil
end

local function build(node: Node, sm: any, fullName: string)
	node.__file = pickScriptFile(sm.filePaths)
	if sm.children then
		for _, childSm in sm.children do
			local childFull = if fullName == "" then childSm.name else `{fullName}.{childSm.name}`
			local child = newNode(childSm.name, childSm.className, childFull)
			build(child, childSm, childFull)
			node.__children[childSm.name] = child
		end
	end
end

-- ── Harness ──────────────────────────────────────────────────────
local Harness = {}
Harness.__index = Harness

export type Harness = typeof(setmetatable(
	{} :: {
		_game: Node,
		_cache: { [Node]: any },
		_mocks: { [string]: any },
	},
	Harness
))

function Harness.new(): Harness
	local raw = fs.readFile(SOURCEMAP_PATH)
	local sm = serde.decode("json", raw)

	local game = newNode("game", sm.className or "DataModel", "")
	build(game, sm, "")

	return setmetatable({
		_game = game,
		_cache = {},
		_mocks = {},
	}, Harness)
end

-- ลงทะเบียน mock ให้ require คืนค่านี้แทนการรันไฟล์จริง
-- path = full path ไม่รวม "game." เช่น "ReplicatedStorage.Shared.Events"
function Harness.mock(self: Harness, path: string, value: any): Harness
	self._mocks[path] = value
	return self
end

function Harness.getGame(self: Harness): Node
	return self._game
end

function Harness._resolve(self: Harness, path: string): Node?
	local node: Node = self._game
	local cleaned = (path:gsub("^game%.", ""))
	for part in string.gmatch(cleaned, "[^.]+") do
		if part == "game" then
			continue
		end
		local nextNode = node.__children[part]
		if not nextNode then
			return nil
		end
		node = nextNode
	end
	return node
end

function Harness._makeEnv(self: Harness, scriptNode: Node): { [string]: any }
	return {
		game = self._game,
		script = scriptNode,
		workspace = self._game:GetService("Workspace"),
		require = function(target: any): any
			return self:require(target)
		end,
	}
end

-- require โมดูล: รับได้ทั้ง fake Instance (Node) หรือ string path
function Harness.require(self: Harness, target: any): any
	local node: Node
	if type(target) == "string" then
		local resolved = self:_resolve(target)
		if not resolved then
			error(`[harness] resolve ไม่เจอ path: '{target}'`, 2)
		end
		node = resolved
	elseif type(target) == "table" then
		node = target
	else
		error(`[harness] require() รับได้เฉพาะ string path หรือ fake Instance, ได้ {type(target)}`, 2)
	end

	-- mock ก่อน
	if self._mocks[node.__fullName] ~= nil then
		return self._mocks[node.__fullName]
	end

	-- cache
	local cached = self._cache[node]
	if cached ~= nil then
		return cached
	end

	local file = node.__file
	if not file then
		error(
			`[harness] '{node.__fullName}' (class={node.ClassName}) ไม่มีไฟล์สคริปต์ — `
				.. `อาจต้อง mock มันด้วย h:mock(path, value)`,
			2
		)
	end

	local source = fs.readFile(file)
	local bytecode = luau.compile(source)
	local fn = luau.load(bytecode, {
		environment = self:_makeEnv(node),
		injectGlobals = true,
		debugName = file,
	})
	local result = fn()
	self._cache[node] = result
	return result
end

return Harness
