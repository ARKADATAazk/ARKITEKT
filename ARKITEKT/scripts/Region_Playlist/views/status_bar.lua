local M = {}
M.__index = M

function M.new(deps)
  return setmetatable({ deps = deps or {} }, M)
end

function M:draw(ctx)
  local status = self.deps and self.deps.status_bar
  if status and status.draw then
    return status:draw(ctx)
  end
end

return M
