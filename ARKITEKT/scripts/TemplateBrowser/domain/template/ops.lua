-- @noindex
-- TemplateBrowser/domain/template/ops.lua
-- Template apply/insert operations

-- Dependencies (cached at module load per Lua Performance Guide)
local Logger = require('arkitekt.debug.logger')
local Persistence = require('TemplateBrowser.data.storage')

local M = {}

-- Apply template to selected track(s)
function M.apply_to_selected_track(template_path, template_uuid, state)
  local track_count = reaper.CountSelectedTracks(0)

  if track_count == 0 then
    Logger.warn("TEMPLATE", "apply_to_selected_track: No track selected")
    if state and state.set_status then
      state.set_status("No track selected. Please select a track first.", "warning")
    else
      reaper.MB("No track selected. Please select a track first.", "Template Browser", 0)
    end
    return false
  end

  -- Read template file once (with error protection)
  local ok, chunk = pcall(function()
    local f, err = io.open(template_path, "r")
    if not f then
      error("Could not open file: " .. (err or "unknown error"))
    end
    local content = f:read("*all")
    f:close()
    return content
  end)

  if not ok or not chunk then
    Logger.error("TEMPLATE", "apply_to_selected_track: Failed to read template: %s", template_path)
    if state and state.set_status then
      state.set_status("Could not read template file", "error")
    else
      reaper.MB("Could not read template file: " .. template_path, "Template Browser", 0)
    end
    return false
  end

  reaper.Undo_BeginBlock()

  for i = 0, track_count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    if track then
      -- Set track chunk (applies template)
      reaper.SetTrackStateChunk(track, chunk, false)
    end
  end

  reaper.Undo_EndBlock("Apply Track Template", -1)
  reaper.UpdateArrange()

  -- Track usage
  if template_uuid and state and state.metadata then
    local tmpl_metadata = state.metadata.templates[template_uuid]
    if tmpl_metadata then
      tmpl_metadata.usage_count = (tmpl_metadata.usage_count or 0) + 1
      tmpl_metadata.last_used = os.time()

      -- Save metadata
      Persistence.save_metadata(state.metadata)
      Logger.debug("TEMPLATE", "Updated usage stats for template: %s", template_uuid)
    end
  end

  return true
end

-- Insert template as new track(s)
function M.insert_as_new_track(template_path, template_uuid, state)
  -- Get insertion point (after selected track, or at end)
  local sel_track = reaper.GetSelectedTrack(0, 0)
  local insert_idx = 0

  if sel_track then
    insert_idx = reaper.GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER")
  else
    insert_idx = reaper.CountTracks(0)
  end

  -- Read template file (with error protection)
  local ok, chunk = pcall(function()
    local f, err = io.open(template_path, "r")
    if not f then
      error("Could not open file: " .. (err or "unknown error"))
    end
    local content = f:read("*all")
    f:close()
    return content
  end)

  if not ok or not chunk then
    Logger.error("TEMPLATE", "insert_as_new_track: Failed to read template: %s", template_path)
    if state and state.set_status then
      state.set_status("Could not read template file", "error")
    else
      reaper.MB("Could not read template file: " .. template_path, "Template Browser", 0)
    end
    return false
  end

  reaper.Undo_BeginBlock()

  -- Count how many tracks are in the template
  local track_count = 0
  for line in chunk:gmatch("[^\r\n]+") do
    if line:match("^<TRACK") then
      track_count = track_count + 1
    end
  end

  -- Insert new track(s) and apply template
  if track_count == 0 then track_count = 1 end

  -- Insert first track at position
  reaper.InsertTrackAtIndex(insert_idx, true)
  local new_track = reaper.GetTrack(0, insert_idx)

  if new_track then
    -- Apply template chunk to track
    reaper.SetTrackStateChunk(new_track, chunk, false)

    -- Select the new track
    reaper.SetOnlyTrackSelected(new_track)
  end

  reaper.Undo_EndBlock("Insert Track Template", -1)
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(false)

  -- Track usage
  if template_uuid and state and state.metadata then
    local tmpl_metadata = state.metadata.templates[template_uuid]
    if tmpl_metadata then
      tmpl_metadata.usage_count = (tmpl_metadata.usage_count or 0) + 1
      tmpl_metadata.last_used = os.time()

      -- Save metadata
      Persistence.save_metadata(state.metadata)
      Logger.debug("TEMPLATE", "Updated usage stats for template: %s", template_uuid)
    end
  end

  return true
end

return M
