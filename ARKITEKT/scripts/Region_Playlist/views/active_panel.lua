local ActivePanel = {}
ActivePanel.__index = ActivePanel

function ActivePanel.new(deps)
  deps = deps or {}

  local self = setmetatable({
    State = deps.State or deps.state,
    region_tiles = deps.region_tiles,
  }, ActivePanel)

  return self
end

function ActivePanel:get_filtered_items(playlist)
  if not playlist then return {} end

  local state = self.State and self.State.state or {}
  local filter = state.active_search_filter or ''

  if filter == '' then
    return playlist.items
  end

  local filtered = {}
  local filter_lower = filter:lower()

  for _, item in ipairs(playlist.items) do
    if item.type == 'playlist' then
      local playlist_data = self.State.get_playlist_by_id and self.State.get_playlist_by_id(item.playlist_id)
      local name_lower = playlist_data and playlist_data.name:lower() or ''
      if name_lower:find(filter_lower, 1, true) then
        filtered[#filtered + 1] = item
      end
    else
      local region_index = state.region_index or {}
      local region = region_index[item.rid]
      if region then
        local name_lower = region.name:lower()
        if name_lower:find(filter_lower, 1, true) then
          filtered[#filtered + 1] = item
        end
      end
    end
  end

  return filtered
end

function ActivePanel:draw(ctx, bounds, height)
  if not self.region_tiles then return end
  bounds = bounds or {}

  local playlist = bounds.playlist or bounds
  if not playlist then return end

  local size = height or bounds.height or bounds.size
  if not size then return end

  local items = bounds.items or playlist.items
  local display_playlist = {
    id = playlist.id,
    name = playlist.name,
    items = bounds.items or self:get_filtered_items({ id = playlist.id, name = playlist.name, items = items }),
  }

  return self.region_tiles:draw_active(ctx, display_playlist, size)
end

return ActivePanel
