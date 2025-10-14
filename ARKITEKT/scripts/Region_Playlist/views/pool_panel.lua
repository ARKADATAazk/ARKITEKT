local M = {}
M.__index = M

function M.new(deps)
  return setmetatable({ deps = deps or {} }, M)
end

function M:draw(ctx, payload)
  if payload and payload.render then
    return payload.render()
  end

  local gui = self.deps and self.deps.gui
  if not (gui and gui.region_tiles and self.deps.original_pool) then return end

  local data = payload and payload.data
  local size = payload and payload.size
  if not (data and size) then return end

  return self.deps.original_pool(gui.region_tiles, ctx, data, size)
end

return M
