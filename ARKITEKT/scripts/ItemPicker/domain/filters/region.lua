-- @noindex
-- ItemPicker/domain/filters/region.lua
-- Pure region filtering logic (no UI dependencies)

local M = {}

-- Check if any regions are actively selected for filtering
function M.has_active_filter(selected_regions)
  return selected_regions and next(selected_regions) ~= nil
end

-- Check if an item passes the region filter
-- @param selected_regions table Selected region names
-- @param item_regions table Regions the item belongs to
-- @param mode string 'or' (any match) or 'and' (all must match)
-- Returns true if:
--   - No regions are selected (filter disabled), OR
--   - Mode 'or': Item has at least one of the selected regions
--   - Mode 'and': Item has ALL of the selected regions
function M.passes_region_filter(selected_regions, item_regions, mode)
  -- No filter active = pass all items
  if not M.has_active_filter(selected_regions) then
    return true
  end

  -- No regions on item = doesn't pass filter
  if not item_regions then
    return false
  end

  -- Build lookup of item's regions for O(1) access
  local item_region_set = {}
  for _, region in ipairs(item_regions) do
    local region_name = type(region) == 'table' and region.name or region
    if selected_regions[region_name] then
      return true
    end
  end

  if mode == 'and' then
    -- AND mode: item must have ALL selected regions
    for region_name, _ in pairs(selected_regions) do
      if not item_region_set[region_name] then
        return false
      end
    end
    return true
  else
    -- OR mode (default): item must have at least one selected region
    for region_name, _ in pairs(selected_regions) do
      if item_region_set[region_name] then
        return true
      end
    end
    return false
  end
end

-- Initialize selected_regions with all regions selected
function M.select_all(all_regions, selected_regions)
  selected_regions = selected_regions or {}
  for _, region in ipairs(all_regions) do
    selected_regions[region.name] = true
  end
  return selected_regions
end

-- Clear all region selections
function M.select_none(selected_regions)
  for k in pairs(selected_regions) do
    selected_regions[k] = nil
  end
end

-- Toggle a region's selection state
function M.toggle_region(selected_regions, region_name)
  if selected_regions[region_name] then
    selected_regions[region_name] = nil
  else
    selected_regions[region_name] = true
  end
end

-- Count selected and total regions
function M.count_regions(all_regions, selected_regions)
  local total = #all_regions
  local selected = 0
  for _, region in ipairs(all_regions) do
    if selected_regions[region.name] then
      selected = selected + 1
    end
  end
  return total, selected
end

return M
