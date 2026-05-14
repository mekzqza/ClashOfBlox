-- สร้างไฟล์ Utils/TableUtils.lua ก็ได้
local function Dump(value, depth)
	depth = depth or 0
	local t = typeof(value)

	if t == "table" then
		local indent = string.rep("  ", depth)
		local output = "{\n"

		for k, v in pairs(value) do
			-- จัดรูปแบบ Key
			local keyString = tostring(k)
			if typeof(k) == "string" then
				keyString = '["' .. k .. '"]'
			else
				keyString = "[" .. keyString .. "]"
			end

			-- เรียกตัวเองซ้ำ (Recursion) เพื่อเจาะเข้าไปใน Table ชั้นถัดไป
			output = output .. indent .. "  " .. keyString .. " = " .. Dump(v, depth + 1) .. ",\n"
		end

		return output .. indent .. "}"
	elseif t == "string" then
		return '"' .. value .. '"'
	else
		return tostring(value)
	end
end

return Dump
