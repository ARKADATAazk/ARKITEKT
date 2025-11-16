-- @noindex
-- ThemeAdjuster/packages/image_map.lua
-- Image map for package resolution preview

local M = {}

-- Current resolved map (key -> {path, provider, is_strip, pinned})
local current_map = {}

-- Statistics
local stats = {
  total_keys = 0,
  active_providers = {},
  last_updated = nil,
}

-- ============================================================================
-- APPLY RESOLVED MAP
-- ============================================================================

function M.apply(resolved_map)
  if not resolved_map then
    current_map = {}
    stats.total_keys = 0
    stats.active_providers = {}
    stats.last_updated = os.time()
    return
  end

  -- Atomically swap the map
  current_map = resolved_map

  -- Update statistics
  stats.total_keys = 0
  stats.active_providers = {}

  for key, entry in pairs(resolved_map) do
    stats.total_keys = stats.total_keys + 1

    local provider = entry.provider
    if provider then
      stats.active_providers[provider] = (stats.active_providers[provider] or 0) + 1
    end
  end

  stats.last_updated = os.time()
end

-- ============================================================================
-- QUERY INTERFACE
-- ============================================================================

function M.get_path(key)
  local entry = current_map[key]
  return entry and entry.path or nil
end

function M.get_provider(key)
  local entry = current_map[key]
  return entry and entry.provider or nil
end

function M.is_pinned(key)
  local entry = current_map[key]
  return entry and entry.pinned or false
end

function M.get_all()
  return current_map
end

function M.get_stats()
  return {
    total_keys = stats.total_keys,
    active_providers = stats.active_providers,
    last_updated = stats.last_updated,
  }
end

-- ============================================================================
-- CLEAR
-- ============================================================================

function M.clear()
  current_map = {}
  stats.total_keys = 0
  stats.active_providers = {}
  stats.last_updated = nil
end

return M
