-- @noindex
-- ReArkitekt/reaper/regions.lua
-- REAPER Region API wrapper - uses native markrgnindexnumber as stable RID

local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

local FALLBACK_COLOR = hexrgb("#4A5A6A")

local function convert_reaper_color_to_rgba(native_color)
  if not native_color or native_color == 0 then
    return FALLBACK_COLOR
  end

  local color_int = native_color | 0x1000000
  local r, g, b = reaper.ColorFromNative(color_int)

  return (r << 24) | (g << 16) | (b << 8) | 0xFF
end

local function convert_rgba_to_reaper_color(rgba_color)
  -- Extract RGB from RGBA (drop alpha channel)
  local r = (rgba_color >> 24) & 0xFF
  local g = (rgba_color >> 16) & 0xFF
  local b = (rgba_color >> 8) & 0xFF

  -- Convert to native Reaper color format
  return reaper.ColorToNative(r, g, b) | 0x1000000
end

function M.scan_project_regions(proj)
  proj = proj or 0
  local regions = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(proj)
  
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = 
      reaper.EnumProjectMarkers3(proj, i)
    
    if isrgn then
      regions[#regions + 1] = {
        rid = markrgnindexnumber,
        index = i,
        name = name,
        start = pos,
        ["end"] = rgnend,
        color = convert_reaper_color_to_rgba(color),
      }
    end
  end
  
  return regions
end

function M.get_region_by_rid(proj, target_rid)
  proj = proj or 0
  local _, num_markers, num_regions = reaper.CountProjectMarkers(proj)
  
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = 
      reaper.EnumProjectMarkers3(proj, i)
    
    if isrgn and markrgnindexnumber == target_rid then
      return {
        rid = markrgnindexnumber,
        index = i,
        name = name,
        start = pos,
        ["end"] = rgnend,
        color = convert_reaper_color_to_rgba(color),
      }
    end
  end
  
  return nil
end

-- NEW (Seamless) Implementation using native API function
function M.go_to_region(proj, target_rid)
  proj = proj or 0
  local rgn = M.get_region_by_rid(proj, target_rid)
  if not rgn then return false end

  -- The core REAPER API function that performs a smooth seek to the region's start.
  -- The rgn.index (the internal marker index number) is the required 'region_index'.
  -- The 'false' argument tells REAPER to use the assigned region number, not the timeline order.
  -- This single call handles the smooth seek on its own, similar to the C++ extension.
  reaper.GoToRegion(proj, rgn.index, false)

  reaper.UpdateTimeline()
  return true
end

--- Set the color of a region by RID
--- @param proj number Project (0 for current)
--- @param target_rid number Region ID (markrgnindexnumber)
--- @param rgba_color number Color in RGBA format
--- @return boolean success Whether the operation succeeded
function M.set_region_color(proj, target_rid, rgba_color)
  proj = proj or 0

  -- Get the current region data
  local rgn = M.get_region_by_rid(proj, target_rid)
  if not rgn then
    return false
  end

  -- Convert RGBA to native Reaper color
  local native_color = convert_rgba_to_reaper_color(rgba_color)

  -- Update the region with new color using SetProjectMarker4
  -- Parameters: proj, index, isrgn, pos, rgnend, name, markrgnindexnumber, color, flags
  reaper.SetProjectMarker4(
    proj,
    rgn.index,        -- marker/region index
    true,             -- isrgn (true for region)
    rgn.start,        -- position
    rgn["end"],       -- region end
    rgn.name,         -- name
    target_rid,       -- markrgnindexnumber (RID)
    native_color,     -- color
    0                 -- flags
  )

  reaper.UpdateTimeline()
  return true
end

return M