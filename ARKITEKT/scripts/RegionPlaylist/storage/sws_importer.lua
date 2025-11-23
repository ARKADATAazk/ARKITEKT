-- @noindex
-- RegionPlaylist/app/sws_importer.lua
-- Import playlists from SWS Region Playlist format

local RegionState = require("RegionPlaylist.storage.persistence")
local Colors = require("arkitekt.core.colors")

local M = {}

-- Constants
local SWS_REGION_FLAG = 0x40000000  -- Bit 30 indicates region in SWS format
local SWS_INFINITE_LOOP = -1
local ARK_INFINITE_LOOP_REPS = 999  -- ARK representation of infinite loop
local SWS_PLAYLIST_NAME_PREFIX = "[SWS] "

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
  ---@diagnostic disable-next-line: redundant-parameter
  local proj_path = reaper.GetProjectPath("")
  ---@diagnostic disable-next-line: redundant-parameter
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

-- Decode SWS region ID to region number
-- SWS uses bitfield format: 0x40000000 | region_number for regions
-- Returns: region number or nil
local function decode_sws_region_id(sws_id)
  if sws_id >= SWS_REGION_FLAG then
    return sws_id - SWS_REGION_FLAG
  end
  return nil
end

-- Find region by number and return ARK region index (1-based count of regions only)
-- Returns: ARK region number (1-based region count) or nil
local function get_ark_region_number(region_num)
  local idx = 0
  local region_count = 0

  while true do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(idx)
    if retval == 0 then
      break  -- No more markers/regions
    end

    if isrgn then
      region_count = region_count + 1
      -- markrgnindexnumber is the displayed region number
      if markrgnindexnumber == region_num then
        return region_count
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

-- Convert SWS loop count to ARK repeat count
-- Returns: reps (number), is_infinite (bool), is_valid (bool)
local function convert_loop_count(sws_loop_count)
  if sws_loop_count == SWS_INFINITE_LOOP then
    return ARK_INFINITE_LOOP_REPS, true, true
  elseif sws_loop_count == 0 then
    return 0, false, false  -- Invalid
  else
    return sws_loop_count, false, true
  end
end

-- Convert SWS playlist to ARK format
-- Returns: ARK playlist table, plus report data
local function convert_sws_playlist_to_ark(sws_playlist, playlist_num)
  local ark_playlist = {
    id = "SWS_" .. tostring(playlist_num),
    name = SWS_PLAYLIST_NAME_PREFIX .. sws_playlist.name,
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
    -- Decode SWS region ID to get the REAPER region number
    local reaper_region_num = decode_sws_region_id(sws_item.sws_rgn_id)

    -- Find the ARK region index (1-based count of regions only)
    local ark_region_num = nil
    if reaper_region_num then
      ark_region_num = get_ark_region_number(reaper_region_num)
    end

    if ark_region_num then
      -- Convert loop count
      local reps, is_infinite, is_valid = convert_loop_count(sws_item.sws_loop_count)

      if not is_valid then
        report.skipped_items = report.skipped_items + 1
        table.insert(report.skipped_rids, sws_item.sws_rgn_id)
        goto continue
      end

      if is_infinite then
        report.infinite_loops = report.infinite_loops + 1
      end

      table.insert(ark_playlist.items, {
        type = "region",
        rid = ark_region_num,
        reps = reps,
        enabled = true,
        key = generate_item_key(ark_region_num),
      })

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
      local ok, json_str = reaper.GetProjExtState(proj, "ARK_REGIONPLAYLIST", "playlists")
      if ok == 1 and json_str ~= "" then
        reaper.SetProjExtState(proj, "ARK_REGIONPLAYLIST", "playlists_backup", json_str)
        reaper.SetProjExtState(proj, "ARK_REGIONPLAYLIST", "playlists_backup_time", tostring(os.time()))
      end
    end
    RegionState.backup_current_state(0)
  end
  
  -- Import
  local success, ark_playlists, report, err = M.import_from_current_project(merge_mode)
  if not success then
    return false, report, err
  end

  -- Save to project (nil checks are defensive - data should be valid from parser)
  ---@diagnostic disable: need-check-nil
  if merge_mode then
    -- Merge with existing playlists (prepend SWS playlists to the beginning)
    local existing = RegionState.load_playlists(0)
    if not existing then existing = {} end

    -- Insert in reverse order so they appear in correct order at the beginning
    for i = #ark_playlists, 1, -1 do
      if ark_playlists[i] then
        table.insert(existing, 1, ark_playlists[i])
      end
    end
    RegionState.save_playlists(existing, 0)

    -- Set active playlist if SWS had one marked
    if report and report.active_playlist_idx then
      local target_idx = #existing - #ark_playlists + report.active_playlist_idx
      if existing[target_idx] and existing[target_idx].id then
        RegionState.save_active_playlist(existing[target_idx].id, 0)
      end
    end
  else
    -- Replace all playlists
    RegionState.save_playlists(ark_playlists, 0)

    -- Set active playlist
    if report and report.active_playlist_idx and ark_playlists[report.active_playlist_idx] then
      local playlist = ark_playlists[report.active_playlist_idx]
      if playlist and playlist.id then
        RegionState.save_active_playlist(playlist.id, 0)
      end
    elseif #ark_playlists > 0 and ark_playlists[1] and ark_playlists[1].id then
      RegionState.save_active_playlist(ark_playlists[1].id, 0)
    end
  end
  ---@diagnostic enable: need-check-nil
  
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
