-- @noindex
-- ItemPicker/domain/preview/manager.lua
-- Preview management for ItemPicker
-- Uses CF_Preview API for audio (with fade-out support)
-- Falls back to SWS commands for MIDI (timeline-based)
-- @migrated 2024-11-27 from core/preview_manager.lua

local M = {}

-- Debug flag - set to false to disable console output
local DEBUG = true

local function log(...)
  if DEBUG then
    reaper.ShowConsoleMsg('[Preview] ' .. string.format(...) .. '\n')
  end
end

-- Preview state
local state = {
  previewing = false,
  preview_item = nil,
  preview_item_guid = nil,
  preview_start_time = nil,
  preview_duration = nil,
  preview_handle = nil,  -- CF_Preview handle for audio
  preview_source = nil,  -- PCM_Source reference (must be kept alive)
  is_midi = false,       -- Track if current preview is MIDI (uses SWS fallback)
}

-- Reference to app settings (set during init)
local settings = nil

-- Default fade-out in seconds (5ms)
local DEFAULT_FADEOUT_SEC = 0.005

function M.init(app_settings)
  settings = app_settings
end

-- Get fade-out duration in seconds from settings
local function get_fadeout_sec()
  local ms = settings and settings.preview_fadeout_ms or 5
  return ms / 1000
end

-- Start preview playback
-- force_mode: nil (use setting), 'through_track' (force with FX), 'direct' (force no FX)
function M.start_preview(item, force_mode)
  if not item then
    log('SKIP: item is nil')
    return
  end

  -- Stop current preview
  M.stop_preview()

  -- Get item GUID for reliable comparison
  local item_guid = reaper.BR_GetMediaItemGUID(item)

  -- Get item duration for progress tracking
  local item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')

  local take = reaper.GetActiveTake(item)
  if not take then
    log('SKIP: no active take for item')
    return
  end

  -- Get take name for logging
  local _, take_name = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)

  -- Check if it's MIDI
  if reaper.TakeIsMIDI(take) then
    log('MIDI: "%s" (len=%.2fs)', take_name, item_len)
    -- MIDI: Use SWS fallback (CF_Preview doesn't support MIDI)
    -- MIDI requires timeline movement (limitation of Reaper API)
    local item_pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    reaper.SetEditCurPos(item_pos, false, false)

    -- Select item for SWS command
    reaper.SelectAllMediaItems(0, false)
    reaper.SetMediaItemSelected(item, true)

    -- Use SWS preview through track (required for MIDI)
    local cmd_id = reaper.NamedCommandLookup('_SWS_PREVIEWTRACK')
    if cmd_id and cmd_id ~= 0 then
      reaper.Main_OnCommand(cmd_id, 0)
      state.previewing = true
      state.preview_item = item
      state.preview_item_guid = item_guid
      state.preview_start_time = reaper.time_precise()
      state.preview_duration = item_len
      state.is_midi = true
      log('  -> SWS preview started (cmd=%d)', cmd_id)
    else
      log('  -> FAIL: _SWS_PREVIEWTRACK not found (cmd=%d)', cmd_id or -1)
    end
  else
    log('AUDIO: "%s" (len=%.2fs)', take_name, item_len)
    -- Audio: Use CF_Preview API with fade-out support
    local source = reaper.GetMediaItemTake_Source(take)
    if not source then
      log('  -> FAIL: GetMediaItemTake_Source returned nil')
      return
    end

    -- Check source type
    local source_type = reaper.GetMediaSourceType(source, '')
    log('  -> Source type: %s', source_type or 'unknown')

    -- For SECTION sources, fall back to SWS (handles sections correctly)
    -- CF_Preview would play the whole parent file, not just the section
    if source_type == 'SECTION' then
      log('  -> Section source: using SWS fallback')
      reaper.SelectAllMediaItems(0, false)
      reaper.SetMediaItemSelected(item, true)
      local cmd_id = reaper.NamedCommandLookup('_XENAKIOS_ITEMASPCM1')
      if cmd_id and cmd_id ~= 0 then
        reaper.Main_OnCommand(cmd_id, 0)
        state.previewing = true
        state.preview_item = item
        state.preview_item_guid = item_guid
        state.preview_start_time = reaper.time_precise()
        state.preview_duration = item_len
        state.is_midi = false
        state.preview_handle = nil
        state.preview_source = nil
        log('  -> SWS preview started (no fade-out for sections)')
      end
      return
    end

    -- Regular audio: use CF_Preview with fade-out
    local filename = reaper.GetMediaSourceFileName(source)
    if not filename or filename == '' then
      log('  -> FAIL: No filename for non-section source')
      return
    end
    log('  -> File: %s', filename)

    local preview_source = reaper.PCM_Source_CreateFromFile(filename)
    if not preview_source then
      log('  -> FAIL: Could not create preview source')
      return
    end

    local preview = reaper.CF_CreatePreview(preview_source)
    if not preview then
      log('  -> FAIL: CF_CreatePreview returned nil')
      reaper.PCM_Source_Destroy(preview_source)
      return
    end

    -- Configure preview
    local fadeout = get_fadeout_sec()
    reaper.CF_Preview_SetValue(preview, 'D_FADEOUTLEN', fadeout)
    reaper.CF_Preview_SetValue(preview, 'D_VOLUME', 1.0)

    -- Route through track if requested
    local use_through_track = settings and settings.play_item_through_track or false
    if force_mode == 'through_track' then
      use_through_track = true
    elseif force_mode == 'direct' then
      use_through_track = false
    end

    if use_through_track then
      local track = reaper.GetMediaItem_Track(item)
      if track then
        reaper.CF_Preview_SetOutputTrack(preview, 0, track)
        log('  -> Routing through track')
      end
    end

    -- Start playback
    reaper.CF_Preview_Play(preview)

    state.previewing = true
    state.preview_item = item
    state.preview_item_guid = item_guid
    state.preview_start_time = reaper.time_precise()
    state.preview_duration = item_len
    state.preview_handle = preview
    state.preview_source = preview_source
    state.is_midi = false
    log('  -> CF_Preview started (fadeout=%.1fms)', fadeout * 1000)
  end
end

function M.stop_preview()
  if state.previewing then
    if state.preview_handle then
      -- CF_Preview: fade-out is automatic
      reaper.CF_Preview_Stop(state.preview_handle)
      log('STOP: Audio (CF_Preview with fadeout)')
      state.preview_handle = nil
      if state.preview_source then
        reaper.PCM_Source_Destroy(state.preview_source)
        state.preview_source = nil
      end
    else
      -- SWS fallback (MIDI or SECTION audio)
      local cmd_id = reaper.NamedCommandLookup('_SWS_STOPPREVIEW')
      if cmd_id and cmd_id ~= 0 then
        reaper.Main_OnCommand(cmd_id, 0)
        log('STOP: SWS fallback (%s)', state.is_midi and 'MIDI' or 'SECTION')
      end
    end

    state.previewing = false
    state.preview_item = nil
    state.preview_item_guid = nil
    state.preview_start_time = nil
    state.preview_duration = nil
    state.is_midi = false
  end
end

function M.is_previewing(item)
  if not state.previewing or not item then return false end
  local item_guid = reaper.BR_GetMediaItemGUID(item)
  return state.preview_item_guid == item_guid
end

function M.get_preview_progress()
  if not state.previewing or not state.preview_start_time or not state.preview_duration then
    return 0
  end

  -- For CF_Preview, we can get actual position
  if state.preview_handle and not state.is_midi then
    local ok_pos, pos = reaper.CF_Preview_GetValue(state.preview_handle, 'D_POSITION')
    local ok_len, len = reaper.CF_Preview_GetValue(state.preview_handle, 'D_LENGTH')
    if ok_pos and ok_len and len > 0 then
      local progress = pos / len
      if progress >= 1.0 then
        M.stop_preview()
        return 1.0
      end
      return progress
    end
  end

  -- Fallback: time-based progress
  local elapsed = reaper.time_precise() - state.preview_start_time
  local progress = elapsed / state.preview_duration

  -- Auto-stop when preview completes
  if progress >= 1.0 then
    M.stop_preview()
    return 1.0
  end

  return progress
end

-- Check if any preview is active
function M.is_active()
  return state.previewing
end

-- Get currently previewing item
function M.get_preview_item()
  return state.preview_item
end

return M
