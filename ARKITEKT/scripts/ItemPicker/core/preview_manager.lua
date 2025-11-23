-- @noindex
-- Preview management for ItemPicker
-- Handles audio/MIDI preview playback using SWS extension

local M = {}

-- Preview state
local state = {
  previewing = false,
  preview_item = nil,
  preview_item_guid = nil,
  preview_start_time = nil,
  preview_duration = nil,
}

-- Reference to app settings (set during init)
local settings = nil

function M.init(app_settings)
  settings = app_settings
end

-- Start preview playback
-- force_mode: nil (use setting), "through_track" (force with FX), "direct" (force no FX)
function M.start_preview(item, force_mode)
  if not item then return end

  -- Stop current preview
  M.stop_preview()

  -- Get item GUID for reliable comparison
  local item_guid = reaper.BR_GetMediaItemGUID(item)

  -- Get item duration for progress tracking
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

  -- First, select the item for SWS commands to work
  reaper.SelectAllMediaItems(0, false)  -- Deselect all
  reaper.SetMediaItemSelected(item, true)

  -- Check if it's MIDI
  local take = reaper.GetActiveTake(item)
  if take and reaper.TakeIsMIDI(take) then
    -- MIDI requires timeline movement (limitation of Reaper API)
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    reaper.SetEditCurPos(item_pos, false, false)

    -- Use SWS preview through track (required for MIDI)
    local cmd_id = reaper.NamedCommandLookup("_SWS_PREVIEWTRACK")
    if cmd_id and cmd_id ~= 0 then
      reaper.Main_OnCommand(cmd_id, 0)
      state.previewing = true
      state.preview_item = item
      state.preview_item_guid = item_guid
      state.preview_start_time = reaper.time_precise()
      state.preview_duration = item_len
    end
  else
    -- Audio: Check force_mode or fall back to setting
    local use_through_track = settings and settings.play_item_through_track or false
    if force_mode == "through_track" then
      use_through_track = true
    elseif force_mode == "direct" then
      use_through_track = false
    end

    if use_through_track then
      -- Preview through track with FX
      local cmd_id = reaper.NamedCommandLookup("_SWS_PREVIEWTRACK")
      if cmd_id and cmd_id ~= 0 then
        reaper.Main_OnCommand(cmd_id, 0)
        state.previewing = true
        state.preview_item = item
        state.preview_item_guid = item_guid
        state.preview_start_time = reaper.time_precise()
        state.preview_duration = item_len
      end
    else
      -- Direct preview (no FX, faster)
      local cmd_id = reaper.NamedCommandLookup("_XENAKIOS_ITEMASPCM1")
      if cmd_id and cmd_id ~= 0 then
        reaper.Main_OnCommand(cmd_id, 0)
        state.previewing = true
        state.preview_item = item
        state.preview_item_guid = item_guid
        state.preview_start_time = reaper.time_precise()
        state.preview_duration = item_len
      end
    end
  end
end

function M.stop_preview()
  if state.previewing then
    -- Stop SWS preview
    local cmd_id = reaper.NamedCommandLookup("_SWS_STOPPREVIEW")
    if cmd_id and cmd_id ~= 0 then
      reaper.Main_OnCommand(cmd_id, 0)
    end
    state.previewing = false
    state.preview_item = nil
    state.preview_item_guid = nil
    state.preview_start_time = nil
    state.preview_duration = nil
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
