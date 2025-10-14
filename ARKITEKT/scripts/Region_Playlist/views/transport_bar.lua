local M = {}
M.__index = M

function M.new(deps)
  return setmetatable({ deps = deps or {} }, M)
end

function M:draw(ctx, render)
  if render then return render() end
  local gui = self.deps and self.deps.gui
  if gui and self.deps.original_transport then
    return self.deps.original_transport(gui, ctx)
  end
end

return M
