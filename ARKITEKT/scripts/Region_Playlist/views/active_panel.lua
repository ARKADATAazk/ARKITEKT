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
  if not (gui and gui.region_tiles and self.deps.original_active) then return end

  local playlist = payload and payload.playlist
  local size = payload and payload.size
  if not (playlist and size) then return end

  return self.deps.original_active(gui.region_tiles, ctx, playlist, size)
end

return M
