-- @noindex
-- DrumBlocks/domain/mx_render.lua
-- Media Explorer selection rendering - handles trimmed/rate-adjusted samples
-- Based on ReaDrum Machine by Suzuki

local M = {}

local r = reaper

-- Debug flag
local DEBUG = true
local function log(msg)
  if DEBUG then r.ShowConsoleMsg('[MX_Render] ' .. msg) end
end

-- ============================================================================
-- JS API CHECK
-- ============================================================================

local function hasJSAPI()
  return r.JS_Window_Find ~= nil
end

-- ============================================================================
-- MEDIA EXPLORER TIME SELECTION (from ReaDrum Machine)
-- ============================================================================

-- Get time selection from Media Explorer waveform display
-- Returns: has_selection, start_time, end_time
function M.getMXTimeSelection()
  if not hasJSAPI() then
    return false, 0, 0
  end

  local mx_title = r.JS_Localize('Media Explorer', 'common')
  local mx = r.JS_Window_Find(mx_title, true)
  if not mx then return false, 0, 0 end

  local x, y = r.GetMousePosition()
  local wave_hwnd = r.JS_Window_FindChildByID(mx, 1046)
  if not wave_hwnd then return false, 0, 0 end

  local c_x, c_y = r.JS_Window_ScreenToClient(wave_hwnd, x, y)
  r.JS_WindowMessage_Send(wave_hwnd, 'WM_MOUSEFIRST', c_y, 0, c_x, 0)

  local wave_info_hwnd = r.JS_Window_FindChildByID(mx, 1014)
  if not wave_info_hwnd then return false, 0, 0 end

  local wave_info = r.JS_Window_GetTitle(wave_info_hwnd)
  log('Wave info (1014): ' .. (wave_info or 'nil') .. '\n')

  -- ReaDrum pattern: ": ([^%s]+) .-: ([^%s]+)"
  local pattern = ': ([^%s]+) .-: ([^%s]+)'
  local start_timecode, end_timecode = wave_info:match(pattern)

  if not start_timecode then
    log('No selection pattern matched\n')
    return false, 0, 0
  end

  local start_mins, start_secs = start_timecode:match('^(.-):(.-)$')
  if not start_mins then return false, 0, 0 end
  start_secs = tonumber(start_secs) + tonumber(start_mins) * 60

  local end_mins, end_secs = end_timecode:match('^(.-):(.-)$')
  if not end_mins then return false, 0, 0 end
  end_secs = tonumber(end_secs) + tonumber(end_mins) * 60

  local has_selection = start_secs ~= end_secs
  log(string.format('Selection: %s, start=%.3f, end=%.3f\n', tostring(has_selection), start_secs, end_secs))

  return has_selection, start_secs, end_secs
end

-- ============================================================================
-- RENDER SELECTION
-- ============================================================================

-- Render Media Explorer selection/rate to a new file (based on ReaDrum MX_ApplyRate)
-- The key insight: command 41010 automatically applies MX selection and rate when inserting
-- Returns: rendered_filepath or original_filepath if MX not available
function M.renderMXSelection(filepath)
  if not filepath or filepath == '' then return filepath end
  if not hasJSAPI() then return filepath end

  -- Find Media Explorer window
  local mx_title = r.JS_Localize('Media Explorer', 'common')
  local mx = r.JS_Window_Find(mx_title, true)
  if not mx then
    log('Media Explorer not found, using original file\n')
    return filepath
  end

  log('Rendering via MX insert+glue: ' .. filepath .. '\n')

  -- Store current item selection
  local orig_items = {}
  for i = 0, r.CountSelectedMediaItems(0) - 1 do
    orig_items[#orig_items + 1] = r.GetSelectedMediaItem(0, i)
  end

  -- Deselect all items
  r.SelectAllMediaItems(0, false)

  -- Check and set "Insert on selected track" option (command 40063 in MX section 32063)
  local insert_sel_state = r.GetToggleCommandStateEx(32063, 40063)
  local insert_new = false
  if insert_sel_state ~= 1 then
    insert_new = true
    r.JS_WindowMessage_Send(mx, 'WM_COMMAND', 40063, 0, 0, 0)
  end

  -- Insert media from Media Explorer (command 41010)
  -- This automatically applies any selection/rate from MX preview
  r.JS_WindowMessage_Send(mx, 'WM_COMMAND', 41010, 0, 0, 0)

  -- Get inserted items
  local selectedmedia_num = r.CountSelectedMediaItems(0)
  if selectedmedia_num == 0 then
    log('Failed to insert item from MX\n')
    if insert_new then
      r.JS_WindowMessage_Send(mx, 'WM_COMMAND', 40063, 0, 0, 0)
    end
    -- Restore original selection
    for _, item in ipairs(orig_items) do
      if r.ValidatePtr(item, 'MediaItem*') then
        r.SetMediaItemSelected(item, true)
      end
    end
    return filepath
  end

  log('Inserted ' .. selectedmedia_num .. ' items from MX\n')

  -- Store GUIDs of inserted items
  local payload_num = {}
  for c = 1, selectedmedia_num do
    local item = r.GetSelectedMediaItem(0, c - 1)
    local item_guid = r.BR_GetMediaItemGUID(item)
    payload_num[c] = item_guid
  end

  r.SelectAllMediaItems(0, false)

  -- Glue each item and collect rendered paths
  local payload_name = {}
  for c = 1, selectedmedia_num do
    local item = r.BR_GetMediaItemByGUID(0, payload_num[c])
    if item then
      r.SetMediaItemSelected(item, true)
      r.Main_OnCommand(41588, 0)  -- Glue items

      local glued_item = r.GetSelectedMediaItem(0, 0)
      if glued_item then
        local take = r.GetActiveTake(glued_item)
        local take_src = r.GetMediaItemTake_Source(take)
        payload_name[c] = r.GetMediaSourceFileName(take_src)
        log('Glued item ' .. c .. ': ' .. (payload_name[c] or 'nil') .. '\n')

        local track = r.GetMediaItem_Track(glued_item)
        r.DeleteTrackMediaItem(track, glued_item)
      end
      r.SelectAllMediaItems(0, false)
    end
  end

  -- Restore "Insert on selected track" option
  if insert_new then
    r.JS_WindowMessage_Send(mx, 'WM_COMMAND', 40063, 0, 0, 0)
  end

  -- Restore original item selection
  for _, item in ipairs(orig_items) do
    if r.ValidatePtr(item, 'MediaItem*') then
      r.SetMediaItemSelected(item, true)
    end
  end

  local rendered_path = payload_name[1]
  if rendered_path and rendered_path ~= '' then
    log('Final rendered path: ' .. rendered_path .. '\n')
    return rendered_path
  end

  log('Render failed, using original file\n')
  return filepath
end

-- ============================================================================
-- BATCH RENDER
-- ============================================================================

-- Process multiple files, rendering MX selection for each if applicable
-- Returns: table of processed file paths
function M.processFiles(filepaths)
  if not filepaths or #filepaths == 0 then return {} end

  -- Only the first file can have MX selection (subsequent files are just paths)
  local results = {}
  for i, fp in ipairs(filepaths) do
    if i == 1 then
      -- First file might have MX selection
      results[i] = M.renderMXSelection(fp)
    else
      -- Subsequent files use original path
      results[i] = fp
    end
  end

  return results
end

-- ============================================================================
-- UTILITY
-- ============================================================================

-- Check if JS API is available
function M.isAvailable()
  return hasJSAPI()
end

return M
