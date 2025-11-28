-- @noindex
-- RegionPlaylist/domain/region.lua
-- Manages region data cache and pool ordering

local Logger = require('arkitekt.debug.logger')

local M = {}

-- Set to true for verbose domain logging
local DEBUG_DOMAIN = false

--- Create a new region domain
--- @return table domain The region domain instance
function M.new()
  local domain = {
    region_index = {},  -- Map: RID (number) -> region object {rid, guid, name, color, ...}
    guid_index = {},    -- Map: GUID (string) -> region object (for stable lookups)
    name_index = {},    -- Map: name (string) -> region object (fallback for renumbering)
    pool_order = {},    -- Array of RIDs defining custom pool order
  }

  if DEBUG_DOMAIN then
    Logger.debug("REGION", "Domain initialized")
  end

  --- Get region by RID
  --- @param rid number Region ID
  --- @return table|nil region Region object or nil if not found
  function domain:get_region_by_rid(rid)
    return self.region_index[rid]
  end

  --- Get region by GUID (stable identifier that survives renumbering)
  --- @param guid string Region GUID
  --- @return table|nil region Region object or nil if not found
  function domain:get_region_by_guid(guid)
    if not guid then return nil end
    return self.guid_index[guid]
  end

  --- Get region by name (fallback for renumbering when GUID changes)
  --- @param name string Region name
  --- @return table|nil region Region object or nil if not found
  function domain:get_region_by_name(name)
    if not name or name == "" then return nil end
    return self.name_index[name]
  end

  --- Resolve a region reference (tries GUID → Name → RID)
  --- @param guid string|nil Region GUID (preferred)
  --- @param rid number|nil Region ID (fallback)
  --- @param name string|nil Region name (fallback when GUID changes on renumber)
  --- @return table|nil region Region object or nil if not found
  function domain:resolve_region(guid, rid, name)
    -- Try GUID first (stable for normal edits, but changes on renumber)
    if guid then
      local region = self.guid_index[guid]
      if region then return region end
    end
    -- Try name (stable across renumbering if user didn't rename)
    if name and name ~= "" then
      local region = self.name_index[name]
      if region then return region end
    end
    -- Fall back to RID (least stable)
    if rid then
      return self.region_index[rid]
    end
    return nil
  end

  --- Get full region index
  --- @return table region_index Map of RID -> region object
  function domain:get_region_index()
    return self.region_index
  end

  --- Get pool order
  --- @return table pool_order Array of RIDs
  function domain:get_pool_order()
    return self.pool_order
  end

  --- Set pool order
  --- @param new_order table Array of RIDs
  function domain:set_pool_order(new_order)
    self.pool_order = new_order
    if DEBUG_DOMAIN then
      Logger.debug("REGION", "Pool order updated: %d regions", #new_order)
    end
  end

  --- Refresh regions from bridge
  --- @param regions table Array of region objects from bridge
  function domain:refresh_from_bridge(regions)
    -- Clear existing data
    self.region_index = {}
    self.guid_index = {}
    self.name_index = {}
    self.pool_order = {}

    -- Rebuild from bridge data
    for _, region in ipairs(regions) do
      self.region_index[region.rid] = region
      -- Index by GUID for stable lookups
      if region.guid then
        self.guid_index[region.guid] = region
      end
      -- Index by name (only if non-empty, first one wins for duplicates)
      if region.name and region.name ~= "" and not self.name_index[region.name] then
        self.name_index[region.name] = region
      end
      self.pool_order[#self.pool_order + 1] = region.rid
    end

    if DEBUG_DOMAIN then
      Logger.debug("REGION", "Refreshed from bridge: %d regions loaded", #regions)
    end
  end

  --- Count regions
  --- @return number count Number of regions in index
  function domain:count()
    local count = 0
    for _ in pairs(self.region_index) do
      count = count + 1
    end
    return count
  end

  return domain
end

return M
