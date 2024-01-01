--[[
	Basic Enumerable
	
	Author: Estrol
]]

local Enumerable = {}
Enumerable.__index = Enumerable

function Enumerable.new(_table)
	return setmetatable({
		_current = nil,
		_table = _table,
		_index = 0
	}, Enumerable)
end

function Enumerable:First()
	return self._table[1]
end

function Enumerable:FirstWhile(Func)
	for i=1, #self._table do
		if Func(self._table[i]) then
			return self._table[i]
		end
	end
	
	return nil
end

function Enumerable:Peek()
	return self._table[self._index+1]
end

function Enumerable:Count()
	return #self._table
end

function Enumerable:Next()
	if self:Peek() == nil then
		return false
	end
	
	self._index += 1
	return true
end

function Enumerable:Dequeue()
	local value = self:Current()
	local index = table.find(self._table, value)
	table.remove(self._table, index)
	
	return value
end

function Enumerable:Current()
	if self._index == 0 then
		error("Enumerable is not initialized using :Next()")
	end
	
	return self._table[self._index]
end

function Enumerable:Reset()
	self._index = 0
	return true
end

return Enumerable