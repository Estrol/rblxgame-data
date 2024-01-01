local Enumerable = require("enumerable.lua")
local Helper = {}

function Helper:copytable(datatable)
	local tblRes={}
	if type(datatable)=="table" then
		for k,v in pairs(datatable) do tblRes[k]=Helper:copytable(v) end
	else
		tblRes=datatable
	end
	return tblRes
end

function Helper:tablecontains(data, value)
	for i,v in pairs(data) do
		if v == value then
			return true, i
		end
	end

	return false, -1
end

function Helper:GetSpritePosition(offset: number, initialPos: number, hitPosition: number, scrollSpeed: number)
	return (hitPosition + ((initialPos - offset) * -scrollSpeed / 100)) / 1000
end

function Helper:HasFlagsAll(int, ...)
	local all = bit32.bxor(...)
	return bit32.band(int, all) == all
end

function Helper:HasFlags(flags, flag)
	return bit32.band(flag, flags) == flag
end

function Helper:Trim(input)
	return (string.gsub(input, "^%s*(.-)%s*$", "%1"))
end

function Helper:StartsWith(input, check)
	return string.sub(input, 1, string.len(check)) == check
end

function Helper:EndsWith(input, check)
	return check == "" or string.sub(input, -#check) == check
end

function Helper:TableFind(data, elementOrFunction)
	if elementOrFunction == nil then elementOrFunction = function() end end
	
	for i, v in pairs(data) do
		if typeof(elementOrFunction) == "function" then
			if elementOrFunction(v) then
				return i
			end
		else
			if v == elementOrFunction then
				return i
			end
		end
	end
	
	return -1
end

--
function Helper:Lerp(a, b, c)
	if typeof(a) == "UDim2" then
		return a:Lerp(b, c)
	end
	
	if typeof(a) == "Vector2" then
		return a:Lerp(b, c)
	end
	
	return a + ((b - a) * c)
end

function Helper:InverseLerp(min, max, num)
	return ((num - min) / (max - min))
end

function Helper:Portions(value, percent)
	return (percent / 100) * value
end

function Helper:ShouldDraw(Position, Length)
	local viewport = workspace.Camera.ViewportSize
	
	local Top = (0 - Helper:Portions(viewport.Y, 5))
	local Bot = (viewport.Y + Helper:Portions(viewport.Y, 5))
	
	if Position < Top and Position > Bot then
		return false
	else
		if Length ~= nil then
			if Position - Length < Top and Position - Length > Bot then
				return false
			end
		end
		
		return true
	end
end

function Helper:ShouldDrawScale(Scale, Length)
	if Scale < -0.15 or Scale > 1.15 then
		return false
	else
		if Length ~= nil then
			if Scale - Length < -0.15 or Scale - Length > 1.15 then
				return false
			end
		end
		
		return true
	end
end

function Helper:RoundToDecimal(value)
	value *= 100
	value = math.floor(value)
	return value / 100
end

function toBits(num)
	local t={}
	local rest = 0;

	while num>0 do
		rest = math.fmod(num,2)
		t[#t+1]=rest
		num=(num-rest)/2
	end

	local bits = {}
	local lpad = 8 - #t
	if lpad > 0 then
		for c = 1,lpad do table.insert(bits,0) end
	end
	-- Reverse the values in t
	for i = #t,1,-1 do table.insert(bits,t[i]) end

	return table.concat(bits)
end

local key = toBits(math.random(180, 240), 8)

function toDec(bits)
	local bmap = {128,64,32,16,8,4,2,1} --binary map

	local bitt = {}
	for c in bits:gmatch(".") do table.insert(bitt,c) end

	local result = 0

	for i = 1,#bitt do
		if bitt[i] == "1" then result = result + bmap[i] end
	end

	return result
end

function xor(a,b)
	local r = 0
	local f = math.floor
	for i = 0, 31 do
		local x = a / 2 + b / 2
		if x ~= f(x) then
			r = r + 2^i
		end
		a = f(a / 2)
		b = f(b / 2)
	end
	return r
end

function Helper:cryptStr(str)
	local ciphert = {}
	for c in key:gmatch(".") do table.insert(ciphert,c) end

	--split string into a table containing only binary numbers of each character
	local block = {}
	for ch in str:gmatch(".") do
		local c = toBits(string.byte(ch))
		table.insert(block,c)
	end

	--for each binary number perform xor transformation
	for i = 1,#block do
		local bitt = {}
		local bit = block[i]
		for c in bit:gmatch(".") do table.insert(bitt,c) end

		local result = {}
		for i = 1,8,1 do
			table.insert(result,xor(ciphert[i],bitt[i]))
		end

		block[i] = string.char(toDec(table.concat(result)))
	end

	return table.concat(block)
end

function Helper:convertToMHS(seconds)
	local mins = (seconds - seconds % 60) / 60
	seconds = seconds - mins * 60
	
	return ("%02i:%02i"):format(mins, seconds)
end

local DOUBLE_EPSILON = 1e-7
function Helper:DefinitelyBigger(value1, value2, acceptableDifference)
	if acceptableDifference == nil then acceptableDifference = DOUBLE_EPSILON end

	return value1 - acceptableDifference > value2
end

function Helper:DebugBegin(name)
	debug.profilebegin(name)
end

function Helper:DebugEnd()
	debug.profileend()
end

function Helper:AbsoluteSize(parentViewport: Vector2, udim: UDim2)
	return Vector2.new(
		parentViewport.X * udim.X.Scale + udim.X.Offset,
		parentViewport.Y * udim.Y.Scale + udim.Y.Offset
	)
end

local charset = {}
for i = 48,  57 do table.insert(charset, string.char(i)) end
for i = 65,  90 do table.insert(charset, string.char(i)) end
for i = 97, 122 do table.insert(charset, string.char(i)) end

function Helper:random(length)
	math.randomseed(os.time())

	if length > 0 then
		return Helper:random(length - 1) .. charset[math.random(1, #charset)]
	else
		return ""
	end
end

function Helper:Switch(val)
	local switchInstance = {}
	local switchList = {
		["__default"] = function() end
	}

	function switchInstance:case(compar: any, _callback: () -> ())
		switchList[compar] = _callback or function() end
		return self
	end

	function switchInstance:default(_callback: () -> ())
		switchList["__default"] = _callback or function() end
		return self
	end

	function switchInstance:executed(): any
		if switchList[val] then
			return switchList[val]()
		else
			return switchList["__default"]()
		end
	end

	return switchInstance
end

function Helper:RunDebounce(func: () -> nil)
	if _G.ButtonGlobalDebounce ~= true then
		_G.ButtonGlobalDebounce = true
		
		func()
		
		_G.ButtonGlobalDebounce = false
	end
end

function Helper:SaveTweenSize(instance: GuiBase2d, size: UDim2, style: Enum.EasingStyle, direction: Enum.EasingDirection, length: number, override: boolean)
	if not pcall(instance, instance.TweenSize, size, style, direction, length, override) then
		instance.Size = size
	end
end

return Helper