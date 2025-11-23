-- @noindex
-- Test script to recolor all regions to red

local function main()
  reaper.ShowConsoleMsg("\n=== RECOLOR ALL REGIONS TO RED TEST ===\n")

  local proj = 0  -- Current project
  local _, num_markers, num_regions = reaper.CountProjectMarkers(proj)

  reaper.ShowConsoleMsg(string.format("Found %d markers and %d regions\n", num_markers, num_regions))

  -- Red color: RGB(255, 0, 0)
  local red_native = reaper.ColorToNative(255, 0, 0)
  reaper.ShowConsoleMsg(string.format("Red ColorToNative(255,0,0) = %08X\n", red_native))

  -- Add the custom color flag
  local red_with_flag = red_native | 0x1000000
  reaper.ShowConsoleMsg(string.format("Red with flag = %08X\n", red_with_flag))

  reaper.Undo_BeginBlock()

  -- Iterate through all markers/regions
  local i = 0
  while true do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(proj, i)
    if retval == 0 then break end

    if isrgn then
      reaper.ShowConsoleMsg(string.format("\nRegion %d (index %d): '%s'\n", markrgnindexnumber, i, name))
      reaper.ShowConsoleMsg(string.format("  Current color: %08X\n", color or 0))

      -- Try to set it to red
      local success = reaper.SetProjectMarkerByIndex2(
        proj,
        i,                      -- index
        true,                   -- isrgn
        pos,                    -- position
        rgnend,                 -- region end
        markrgnindexnumber,     -- markrgnindexnumber - BEFORE name!
        name,                   -- name - AFTER markrgnindexnumber!
        red_with_flag,          -- color with flag
        0                       -- flags
      )

      reaper.ShowConsoleMsg(string.format("  SetProjectMarkerByIndex2 success: %s\n", tostring(success)))

      -- Verify the change
      local _, isrgn2, _, _, _, _, new_color = reaper.EnumProjectMarkers3(proj, i)
      reaper.ShowConsoleMsg(string.format("  New color after set: %08X\n", new_color or 0))
    end

    i = i + 1
  end

  reaper.Undo_EndBlock("Recolor all regions to red", -1)
  reaper.UpdateArrange()
  reaper.UpdateTimeline()

  reaper.ShowConsoleMsg("\n=== TEST COMPLETE ===\n")
end

main()
