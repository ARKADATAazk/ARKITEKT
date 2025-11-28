-- @noindex
-- TemplateBrowser/domain/template/operations.lua
-- Template apply/insert operations

-- Dependencies (cached at module load per Lua Performance Guide)
local Logger = require('arkitekt.debug.logger')
local Persistence = require('TemplateBrowser.data.storage')

local M = {}

-- Apply template to selected track(s)
function M.apply_to_selected_track(template_path, template_uuid, state)
  local track_count = reaper.CountSelectedTracks(0)

  if track_count == 0 then
    state.set_status("No track selected. Please select a track first.", "warning")
    return false
  end

  -- Read template file
  local f, err = io.open(template_path, "r")
  if not f then
    Logger.error("TEMPLATE", "Failed to read: %s - %s", template_path, err or "unknown")
    state.set_status("Could not read template file", "error")
    return false
  end
  local chunk = f:read("*all")
  f:close()

  reaper.Undo_BeginBlock()

  for i = 0, track_count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    if track then
      reaper.SetTrackStateChunk(track, chunk, false)
    end
  end

  reaper.Undo_EndBlock("Apply Track Template", -1)
  reaper.UpdateArrange()

  -- Track usage
  if template_uuid and state.metadata then
    local tmpl_metadata = state.metadata.templates[template_uuid]
    if tmpl_metadata then
      local now = os.time()
      tmpl_metadata.usage_count = (tmpl_metadata.usage_count or 0) + 1
      tmpl_metadata.last_used = now
      -- Add to usage history for time-based statistics
      if not tmpl_metadata.usage_history then
        tmpl_metadata.usage_history = {}
      end
      tmpl_metadata.usage_history[#tmpl_metadata.usage_history + 1] = now
      Persistence.save_metadata(state.metadata)
    end
  end

  return true
end

-- Insert template as new track(s)
function M.insert_as_new_track(template_path, template_uuid, state)
  -- Get insertion point (after selected track, or at end)
  local sel_track = reaper.GetSelectedTrack(0, 0)
  local insert_idx = sel_track
    and reaper.GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER")
    or reaper.CountTracks(0)

  -- Read template file
  local f, err = io.open(template_path, "r")
  if not f then
    Logger.error("TEMPLATE", "Failed to read: %s - %s", template_path, err or "unknown")
    state.set_status("Could not read template file", "error")
    return false
  end
  local chunk = f:read("*all")
  f:close()

  reaper.Undo_BeginBlock()

  -- Count how many tracks are in the template
  local track_count = 0
  for line in chunk:gmatch("[^\r\n]+") do
    if line:match("^<TRACK") then
      track_count = track_count + 1
    end
  end

  if track_count == 0 then track_count = 1 end

  -- Insert first track at position
  reaper.InsertTrackAtIndex(insert_idx, true)
  local new_track = reaper.GetTrack(0, insert_idx)

  if new_track then
    reaper.SetTrackStateChunk(new_track, chunk, false)
    reaper.SetOnlyTrackSelected(new_track)
  end

  reaper.Undo_EndBlock("Insert Track Template", -1)
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(false)

  -- Track usage
  if template_uuid and state.metadata then
    local tmpl_metadata = state.metadata.templates[template_uuid]
    if tmpl_metadata then
      local now = os.time()
      tmpl_metadata.usage_count = (tmpl_metadata.usage_count or 0) + 1
      tmpl_metadata.last_used = now
      -- Add to usage history for time-based statistics
      if not tmpl_metadata.usage_history then
        tmpl_metadata.usage_history = {}
      end
      tmpl_metadata.usage_history[#tmpl_metadata.usage_history + 1] = now
      Persistence.save_metadata(state.metadata)
    end
  end

  return true
end

return M
