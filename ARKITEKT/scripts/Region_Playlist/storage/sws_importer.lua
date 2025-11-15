-- @noindex
-- Region_Playlist/app/sws_importer.lua
-- Import playlists from SWS Region Playlist format

local RegionState = require("Region_Playlist.storage.persistence")
local Colors = require("rearkitekt.core.colors")

local M = {}

-- Parse a single SWS playlist section from RPP lines
-- Returns: playlist table or nil on error
local function parse_sws_playlist_section(lines, start_idx)
  local playlist = {
    items = {},
    name = "Imported",
    is_active = false,
  }

  -- Parse header line: <S&M_RGN_PLAYLIST "Name" [0|1] or <S&M_RGN_PLAYLIST Name [0|1]
  local header = lines[start_idx]

  -- Try quoted name first
  local name = header:match('<S&M_RGN_PLAYLIST%s+"([^"]+)"')
  if not name then
    -- Try unquoted name (everything between PLAYLIST and the number or end of line)
    name = header:match('<S&M_RGN_PLAYLIST%s+([^%s]+)')
  end
  if name then
    playlist.name = name
  end

  -- Extract active flag (0 or 1 at end)
  local is_active = header:match('%s+(%d+)%s*$')
  if is_active == "1" then
    playlist.is_active = true
  end

  -- Parse items until we hit '>'
  local idx = start_idx + 1
  while idx <= #lines do
    local line = lines[idx]

    -- End of playlist section (allow leading whitespace)
    if line:match('^%s*>%s*$') then
      return playlist, idx
    end

    -- Parse item line: regionId loopCount (allow leading whitespace)
    local rgn_id, loop_count = line:match('^%s*(%d+)%s+(-?%d+)%s*$')
    if rgn_id and loop_count then
      table.insert(playlist.items, {
        sws_rgn_id = tonumber(rgn_id),
        sws_loop_count = tonumber(loop_count),
      })
    end

    idx = idx + 1
  end

  return playlist, idx
end

-- Read current project file as text
-- Returns: lines table or nil on error
local function read_project_file()
  local proj_path = reaper.GetProjectPath("")
  local proj_name = reaper.GetProjectName(0, "")
  if proj_path == "" or proj_name == "" then
    return nil, "No project file found (project not saved)"
  end

  local filepath = proj_path .. "/" .. proj_name
  local file = io.open(filepath, "r")
  if not file then
    return nil, "Could not open project file: " .. filepath
  end
  
  local lines = {}
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()
  
  return lines
end

-- Parse all SWS playlists from RPP file lines
-- Returns: array of playlist tables
local function parse_sws_playlists(lines)
  local playlists = {}
  local idx = 1

  while idx <= #lines do
    local line = lines[idx]

    -- Found a playlist section (allow leading whitespace)
    if line:match('<S&M_RGN_PLAYLIST') then
      local playlist, end_idx = parse_sws_playlist_section(lines, idx)
      if playlist then
        table.insert(playlists, playlist)
        idx = end_idx
      end
    end

    idx = idx + 1
  end

  return playlists
end

-- Convert SWS region ID (internal) to REAPER region number
-- Returns: region number or nil
local function get_region_number_from_sws_id(sws_rgn_id)
  local idx = 0
  local num_markers = reaper.CountProjectMarkers(0)
  
  while idx < num_markers do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(idx)
    if retval > 0 and isrgn then
      -- SWS stores the internal ID (markrgnindexnumber)
      if markrgnindexnumber == sws_rgn_id then
        -- Get the actual region number (1-based display number)
        local region_num = 0
        local count = 0
        for i = 0, idx do
          local ret, is_rgn = reaper.EnumProjectMarkers(i)
          if ret > 0 and is_rgn then
            count = count + 1
            if i == idx then
              region_num = count
              break
            end
          end
        end
        return region_num
      end
    end
    idx = idx + 1
  end
  
  return nil
end

-- Generate unique item key
local key_counter = 0
local function generate_item_key(rid)
  key_counter = key_counter + 1
  return "imported_" .. tostring(rid) .. "_" .. reaper.time_precise() .. "_" .. key_counter
end

-- Convert SWS playlist to ARK format
-- Returns: ARK playlist table, plus report data
local function convert_sws_playlist_to_ark(sws_playlist, playlist_num)
  local ark_playlist = {
    id = "SWS_" .. tostring(playlist_num),
    name = sws_playlist.name,
    items = {},
    chip_color = RegionState.generate_chip_color(),
  }
  
  local report = {
    total_items = #sws_playlist.items,
    converted_items = 0,
    skipped_items = 0,
    infinite_loops = 0,
    skipped_rids = {},
  }
  
  for _, sws_item in ipairs(sws_playlist.items) do
    -- Convert SWS region ID to region number
    local region_num = get_region_number_from_sws_id(sws_item.sws_rgn_id)
    
    if region_num then
      -- Handle loop count
      local reps = sws_item.sws_loop_count
      if reps < 0 then
        -- SWS infinite loop: convert to large number
        -- ARK doesn't have true infinite loops, use 999 as "effectively infinite"
        reps = 999
        report.infinite_loops = report.infinite_loops + 1
      elseif reps == 0 then
        -- Invalid, skip
        report.skipped_items = report.skipped_items + 1
        table.insert(report.skipped_rids, sws_item.sws_rgn_id)
        goto continue
      end
      
      local ark_item = {
        type = "region",
        rid = region_num,
        reps = reps,
        enabled = true,
        key = generate_item_key(region_num),
      }
      
      table.insert(ark_playlist.items, ark_item)
      report.converted_items = report.converted_items + 1
    else
      -- Region not found (deleted or ID mismatch)
      report.skipped_items = report.skipped_items + 1
      table.insert(report.skipped_rids, sws_item.sws_rgn_id)
    end
    
    ::continue::
  end
  
  return ark_playlist, report
end

-- Main import function
-- Returns: success (bool), ark_playlists (table), report (table), error_msg (string)
function M.import_from_current_project(merge_mode)
  merge_mode = merge_mode or false -- false = replace, true = merge
  
  -- Read project file
  local lines, err = read_project_file()
  if not lines then
    return false, nil, nil, err
  end
  
  -- Parse SWS playlists
  local sws_playlists = parse_sws_playlists(lines)
  if #sws_playlists == 0 then
    return false, nil, nil, "No SWS Region Playlists found in project"
  end
  
  -- Convert to ARK format
  local ark_playlists = {}
  local overall_report = {
    sws_playlists_found = #sws_playlists,
    ark_playlists_created = 0,
    total_items = 0,
    converted_items = 0,
    skipped_items = 0,
    infinite_loops = 0,
    active_playlist_idx = nil,
    per_playlist = {},
  }
  
  for i, sws_playlist in ipairs(sws_playlists) do
    local ark_playlist, report = convert_sws_playlist_to_ark(sws_playlist, i)
    
    -- Only add if at least one item was converted
    if #ark_playlist.items > 0 then
      table.insert(ark_playlists, ark_playlist)
      overall_report.ark_playlists_created = overall_report.ark_playlists_created + 1
      
      -- Track which playlist was active in SWS
      if sws_playlist.is_active then
        overall_report.active_playlist_idx = #ark_playlists
      end
      
      -- Aggregate stats
      overall_report.total_items = overall_report.total_items + report.total_items
      overall_report.converted_items = overall_report.converted_items + report.converted_items
      overall_report.skipped_items = overall_report.skipped_items + report.skipped_items
      overall_report.infinite_loops = overall_report.infinite_loops + report.infinite_loops
      
      table.insert(overall_report.per_playlist, {
        name = ark_playlist.name,
        report = report,
      })
    end
  end
  
  if #ark_playlists == 0 then
    return false, nil, overall_report, "No valid items found in SWS playlists (all regions may have been deleted)"
  end
  
  return true, ark_playlists, overall_report, nil
end

-- Execute import and save to project
-- Returns: success (bool), report (table), error_msg (string)
function M.execute_import(merge_mode, backup)
  merge_mode = merge_mode or false
  backup = backup ~= false -- default true
  
  -- Backup current state
  if backup then
    RegionState.backup_current_state = RegionState.backup_current_state or function(proj)
      local ok, json_str = reaper.GetProjExtState(proj, "ReArkitekt_RegionPlaylist", "playlists")
      if ok == 1 and json_str ~= "" then
        reaper.SetProjExtState(proj, "ReArkitekt_RegionPlaylist", "playlists_backup", json_str)
        reaper.SetProjExtState(proj, "ReArkitekt_RegionPlaylist", "playlists_backup_time", tostring(os.time()))
      end
    end
    RegionState.backup_current_state(0)
  end
  
  -- Import
  local success, ark_playlists, report, err = M.import_from_current_project(merge_mode)
  if not success then
    return false, report, err
  end
  
  -- Save to project
  if merge_mode then
    -- Merge with existing playlists
    local existing = RegionState.load_playlists(0)
    for _, pl in ipairs(ark_playlists) do
      table.insert(existing, pl)
    end
    RegionState.save_playlists(existing, 0)
    
    -- Set active playlist if SWS had one marked
    if report.active_playlist_idx then
      local new_active_id = existing[#existing - #ark_playlists + report.active_playlist_idx].id
      RegionState.save_active_playlist(new_active_id, 0)
    end
  else
    -- Replace all playlists
    RegionState.save_playlists(ark_playlists, 0)
    
    -- Set active playlist
    if report.active_playlist_idx and ark_playlists[report.active_playlist_idx] then
      RegionState.save_active_playlist(ark_playlists[report.active_playlist_idx].id, 0)
    elseif #ark_playlists > 0 then
      RegionState.save_active_playlist(ark_playlists[1].id, 0)
    end
  end
  
  return true, report, nil
end

-- Format report for display
function M.format_report(report)
  if not report then
    return "No report available"
  end
  
  local lines = {}
  
  table.insert(lines, string.format("SWS Playlists Found: %d", report.sws_playlists_found))
  table.insert(lines, string.format("ARK Playlists Created: %d", report.ark_playlists_created))
  table.insert(lines, "")
  table.insert(lines, string.format("Total Items: %d", report.total_items))
  table.insert(lines, string.format("Converted: %d", report.converted_items))
  
  if report.skipped_items > 0 then
    table.insert(lines, string.format("Skipped: %d (regions not found)", report.skipped_items))
  end
  
  if report.infinite_loops > 0 then
    table.insert(lines, string.format("Infinite loops converted to 999 reps: %d", report.infinite_loops))
  end
  
  if report.per_playlist then
    table.insert(lines, "")
    table.insert(lines, "Per Playlist:")
    for i, pl_report in ipairs(report.per_playlist) do
      table.insert(lines, string.format("  %d. \"%s\": %d/%d items", 
        i, pl_report.name, pl_report.report.converted_items, pl_report.report.total_items))
    end
  end
  
  return table.concat(lines, "\n")
end

-- Check if project has SWS playlists (quick check)
function M.has_sws_playlists()
  local lines, err = read_project_file()
  if not lines then
    return false
  end

  for _, line in ipairs(lines) do
    -- Allow leading whitespace
    if line:match('<S&M_RGN_PLAYLIST') then
      return true
    end
  end

  return false
end

return M
