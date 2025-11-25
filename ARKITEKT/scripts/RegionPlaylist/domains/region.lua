-- @noindex
-- RegionPlaylist/domains/region.lua
-- Manages region data cache and pool ordering

local M = {}

--- Create a new region domain
--- @return table domain The region domain instance
function M.new()
  local domain = {
    region_index = {},  -- Map: RID (number) -> region object {rid, name, color, ...}
    pool_order = {},    -- Array of RIDs defining custom pool order
  }

  reaper.ShowConsoleMsg("[REGION] Domain initialized\n")

  --- Get region by RID
  --- @param rid number Region ID
  --- @return table|nil region Region object or nil if not found
  function domain:get_region_by_rid(rid)
    return self.region_index[rid]
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
    reaper.ShowConsoleMsg(string.format("[REGION] Pool order updated: %d regions\n", #new_order))
  end

  --- Refresh regions from bridge
  --- @param regions table Array of region objects from bridge
  function domain:refresh_from_bridge(regions)
    -- Clear existing data
    self.region_index = {}
    self.pool_order = {}

    -- Rebuild from bridge data
    for _, region in ipairs(regions) do
      self.region_index[region.rid] = region
      self.pool_order[#self.pool_order + 1] = region.rid
    end

    reaper.ShowConsoleMsg(string.format("[REGION] Refreshed from bridge: %d regions loaded\n", #regions))
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
