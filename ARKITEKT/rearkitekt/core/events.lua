local Bus = {}
Bus.__index = Bus

function Bus.new()
  return setmetatable({ _map = {} }, Bus)
end

local function ensure_list(t, k)
  local v = t[k]
  if not v then
    v = {}
    t[k] = v
  end
  return v
end

function Bus:on(event, callback)
  if type(event) ~= 'string' or type(callback) ~= 'function' then
    return false
  end
  local list = ensure_list(self._map, event)
  list[#list + 1] = callback
  return true
end

function Bus:off(event, callback)
  local list = self._map[event]
  if not list then
    return false
  end
  local removed = false
  for i = #list, 1, -1 do
    if list[i] == callback then
      table.remove(list, i)
      removed = true
    end
  end
  if #list == 0 then
    self._map[event] = nil
  end
  return removed
end

function Bus:emit(event, ...)
  local list = self._map[event]
  if not list then
    return 0
  end
  local n = 0
  for i = 1, #list do
    local fn = list[i]
    if type(fn) == 'function' then
      fn(...)
      n = n + 1
    end
  end
  return n
end

local M = {}

function M.new()
  return Bus.new()
end

return M
