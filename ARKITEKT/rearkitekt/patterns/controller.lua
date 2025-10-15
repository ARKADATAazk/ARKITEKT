local M = {}
M.__index = M

local pack = table.pack
local unpack = table.unpack

function M:with_undo(op)
  assert(type(op) == 'function', 'with_undo expects a function')

  self:capture_snapshot()

  local results = pack(pcall(op))
  local ok = results[1]

  if ok then
    self:commit()
    return true, unpack(results, 2, results.n)
  end

  self:rollback()
  return false, results[2]
end

return M
