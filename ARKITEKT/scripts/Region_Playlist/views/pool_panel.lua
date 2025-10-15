local PoolPanel = {}
PoolPanel.__index = PoolPanel

function PoolPanel.new(deps)
  deps = deps or {}

  local self = setmetatable({
    State = deps.State or deps.state,
    region_tiles = deps.region_tiles,
  }, PoolPanel)

  return self
end

function PoolPanel:get_pool_data()
  if not self.State then
    return {}
  end

  local mode = self.State.state and self.State.state.pool_mode or 'regions'

  if mode == 'playlists' then
    if self.State.get_playlists_for_pool then
      return self.State.get_playlists_for_pool()
    end
    return {}
  end

  if self.State.get_filtered_pool_regions then
    return self.State.get_filtered_pool_regions()
  end

  return {}
end

function PoolPanel:draw(ctx, data, height)
  if not self.region_tiles then return end

  local payload = data or self:get_pool_data()
  if not payload then return end

  return self.region_tiles:draw_pool(ctx, payload, height)
end

return PoolPanel
