-- @noindex
-- Pool deduplication utilities
-- Shared logic for filtering pooled item duplicates

local M = {}

-- Check if an item is a pooled duplicate
-- Returns true if item should be excluded (is a duplicate)
-- Updates seen_pools table with this item's pool_id
function M.is_pooled_duplicate(entry, seen_pools)
  local pool_count = entry.pool_count or 1
  local pool_id = entry.pool_id

  if pool_count > 1 and pool_id then
    if seen_pools[pool_id] then
      return true  -- This is a duplicate
    else
      seen_pools[pool_id] = true
      return false  -- First occurrence
    end
  end

  return false  -- Not pooled or no pool_id
end

-- Filter items to exclude pooled duplicates
-- Returns new table with only first occurrence of each pool
function M.exclude_pooled_duplicates(items)
  if not items then return {} end

  local filtered = {}
  local seen_pools = {}

  for i, entry in ipairs(items) do
    if not M.is_pooled_duplicate(entry, seen_pools) then
      table.insert(filtered, entry)
    end
  end

  return filtered
end

-- Filter items with full filtering logic (pool, mute, disabled, search)
-- Returns table of {index = original_index, entry = entry}
function M.build_filtered_items(content, settings, is_disabled, search_string)
  if not content or #content == 0 then return {} end

  local filtered = {}
  local seen_pools = {}

  for i, entry in ipairs(content) do
    local should_include = true

    -- Exclude pooled duplicates (only show first occurrence of each pool)
    if M.is_pooled_duplicate(entry, seen_pools) then
      should_include = false
    end

    -- Apply disabled filter
    if should_include and not settings.show_disabled_items and is_disabled then
      should_include = false
    end

    -- Apply mute filters
    if should_include then
      local track_muted = entry.track_muted or false
      local item_muted = entry.item_muted or false
      if not settings.show_muted_tracks and track_muted then
        should_include = false
      end
      if not settings.show_muted_items and item_muted then
        should_include = false
      end
    end

    -- Apply search filter
    if should_include then
      local search = search_string or ""
      if search ~= "" and entry[2] then
        if not entry[2]:lower():find(search:lower(), 1, true) then
          should_include = false
        end
      end
    end

    if should_include then
      table.insert(filtered, {index = i, entry = entry})
    end
  end

  return filtered
end

-- Get first item from each pool (for grid display)
-- Returns items table and a mapping of pool_id -> count
function M.get_unique_pooled_items(items)
  if not items then return {}, {} end

  local unique = {}
  local seen_pools = {}
  local pool_counts = {}

  -- First pass: count items per pool
  for _, entry in ipairs(items) do
    local pool_id = entry.pool_id
    if pool_id then
      pool_counts[pool_id] = (pool_counts[pool_id] or 0) + 1
    end
  end

  -- Second pass: collect first occurrence of each pool
  for _, entry in ipairs(items) do
    if not M.is_pooled_duplicate(entry, seen_pools) then
      table.insert(unique, entry)
    end
  end

  return unique, pool_counts
end

return M
