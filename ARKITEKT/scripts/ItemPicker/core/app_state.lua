-- @noindex
-- ItemPicker/core/app_state.lua
-- Centralized state management (single source of truth)

local Persistence = require("ItemPicker.storage.persistence")

local M = {}

package.loaded["ItemPicker.core.app_state"] = M

-- Settings (persisted)
M.settings = {
  play_item_through_track = false,
  show_muted_tracks = false,
  show_muted_items = false,
  show_disabled_items = false,
  show_favorites_only = false,
  show_audio = true,
  show_midi = true,
  split_midi_by_track = false,  -- Show each MIDI item separately instead of grouped by track
  focus_keyboard_on_init = true,
  search_string = "",
  tile_width = nil,
  tile_height = nil,
  separator_position = nil,  -- MIDI section height (nil = use default from config)
  sort_mode = "none",  -- Options: "none", "color", "name"
}

-- Runtime state (volatile)
M.samples = {}  -- { [filename] = { {item, name, track_muted, item_muted, uuid}, ...} }
M.sample_indexes = {}  -- Ordered list of filenames
M.midi_items = {}  -- { [track_guid] = { {item, name, track_muted, item_muted, uuid}, ...} }
M.midi_indexes = {}  -- Ordered list of track GUIDs
M.audio_item_lookup = {}  -- { [uuid] = item_data } for O(1) access
M.midi_item_lookup = {}  -- { [uuid] = item_data } for O(1) access
M.needs_recollect = false  -- Flag to trigger item recollection

M.box_current_sample = {}  -- { [filename] = sample_index }
M.box_current_item = {}  -- { [filename] = item_index }
M.box_current_midi_track = {}  -- { [track_guid] = item_index }

M.disabled = { audio = {}, midi = {} }
M.favorites = { audio = {}, midi = {} }
M.track_chunks = {}
M.item_chunks = {}

M.tile_sizes = { width = nil, height = nil }  -- nil = use config default

-- Drag state
M.dragging = nil
M.item_to_add = nil
M.item_to_add_name = nil
M.item_to_add_color = nil
M.item_to_add_width = nil
M.item_to_add_height = nil
M.drag_waveform = nil
M.out_of_bounds = nil
M.dragging_keys = {}  -- All selected keys being dragged
M.dragging_is_audio = true

-- Selection state
M.audio_selection_count = 0
M.midi_selection_count = 0

-- Preview state
M.previewing = 0
M.preview_item = nil
M.preview_temp_item = nil
M.preview_track = nil
M.preview_start_time = nil
M.preview_duration = nil

-- Rename state
M.rename_active = false
M.rename_uuid = nil
M.rename_text = ""
M.rename_is_audio = true

M.draw_list = nil
M.overlay_alpha = 1.0
M.exit = false

-- Cache and async processing
M.cache = nil
M.cache_manager = nil
M.job_queue = nil
M.tile_animator = nil

-- Grid scroll state
M.scroll_y = {}

-- Pending operations (for animations)
M.pending_spawn = {}
M.pending_destroy = {}

-- Config reference (set during initialization)
M.config = nil

-- Initialization
function M.initialize(config)
  M.config = config
  M.settings = Persistence.load_settings()
  local disabled_data = Persistence.load_disabled_items()
  M.disabled = disabled_data or { audio = {}, midi = {} }
  local favorites_data = Persistence.load_favorites()
  M.favorites = favorites_data or { audio = {}, midi = {} }

  -- Restore tile sizes from settings
  if M.settings.tile_width then
    M.tile_sizes.width = M.settings.tile_width
  end
  if M.settings.tile_height then
    M.tile_sizes.height = M.settings.tile_height
  end
end

-- Settings getters/setters
function M.get_setting(key)
  return M.settings[key]
end

function M.set_setting(key, value)
  M.settings[key] = value
  M.persist_settings()
end

function M.get_search_filter()
  return M.settings.search_string or ""
end

function M.set_search_filter(filter)
  M.settings.search_string = filter or ""
  M.persist_settings()
end

-- Tile size management
function M:get_tile_width()
  return M.tile_sizes.width or M.config.TILE.DEFAULT_WIDTH
end

function M:get_tile_height()
  return M.tile_sizes.height or M.config.TILE.DEFAULT_HEIGHT
end

function M:set_tile_size(width, height)
  local config = M.config
  local clamped_width = math.max(config.TILE.MIN_WIDTH, math.min(config.TILE.MAX_WIDTH, width))
  local clamped_height = math.max(config.TILE.MIN_HEIGHT, math.min(config.TILE.MAX_HEIGHT, height))

  M.tile_sizes.width = clamped_width
  M.tile_sizes.height = clamped_height

  M.settings.tile_width = clamped_width
  M.settings.tile_height = clamped_height

  M.persist_settings()
end

-- Separator position management
function M.get_separator_position()
  return M.settings.separator_position or M.config.SEPARATOR.default_midi_height
end

function M.set_separator_position(height)
  M.settings.separator_position = height
  M.persist_settings()
end

-- View mode management (derived from checkboxes)
function M.get_view_mode()
  local show_audio = M.settings.show_audio
  local show_midi = M.settings.show_midi

  if show_audio and show_midi then
    return "MIXED"
  elseif show_midi then
    return "MIDI"
  elseif show_audio then
    return "AUDIO"
  else
    -- If both are off, default to MIXED
    return "MIXED"
  end
end

-- Disabled items management
function M.is_audio_disabled(filename)
  return M.disabled.audio[filename] == true
end

function M.is_midi_disabled(track_guid)
  return M.disabled.midi[track_guid] == true
end

function M.toggle_audio_disabled(filename)
  if M.disabled.audio[filename] then
    M.disabled.audio[filename] = nil
  else
    M.disabled.audio[filename] = true
  end
  M.persist_disabled()
end

function M.toggle_midi_disabled(track_guid)
  if M.disabled.midi[track_guid] then
    M.disabled.midi[track_guid] = nil
  else
    M.disabled.midi[track_guid] = true
  end
  M.persist_disabled()
end

-- Favorites management
function M.is_audio_favorite(filename)
  return M.favorites.audio[filename] == true
end

function M.is_midi_favorite(track_guid)
  return M.favorites.midi[track_guid] == true
end

function M.toggle_audio_favorite(filename)
  if M.favorites.audio[filename] then
    M.favorites.audio[filename] = nil
  else
    M.favorites.audio[filename] = true
  end
  M.persist_favorites()
end

function M.toggle_midi_favorite(track_guid)
  if M.favorites.midi[track_guid] then
    M.favorites.midi[track_guid] = nil
  else
    M.favorites.midi[track_guid] = true
  end
  M.persist_favorites()
end

-- Item cycling
function M.cycle_audio_item(filename, delta)
  local content = M.samples[filename]
  if not content or #content == 0 then return end

  local current = M.box_current_item[filename] or 1
  current = current + delta

  if current > #content then current = 1 end
  if current < 1 then current = #content end

  M.box_current_item[filename] = current
end

function M.cycle_midi_item(track_guid, delta)
  local content = M.midi_items[track_guid]
  if not content or #content == 0 then return end

  local current = M.box_current_midi_track[track_guid] or 1
  current = current + delta

  if current > #content then current = 1 end
  if current < 1 then current = #content end

  M.box_current_midi_track[track_guid] = current
end

-- Pending operations (for animations)
function M.add_pending_spawn(key)
  table.insert(M.pending_spawn, key)
end

function M.add_pending_destroy(key)
  table.insert(M.pending_destroy, key)
end

function M.get_pending_spawn()
  return M.pending_spawn
end

function M.get_pending_destroy()
  return M.pending_destroy
end

function M.clear_pending()
  M.pending_spawn = {}
  M.pending_destroy = {}
end

-- Drag state
function M.start_drag(item, item_name, color, width, height)
  M.dragging = true
  M.item_to_add = item
  M.item_to_add_name = item_name
  M.item_to_add_color = color
  M.item_to_add_width = width
  M.item_to_add_height = height
  M.drag_waveform = nil
end

function M.end_drag()
  M.dragging = nil
  M.item_to_add = nil
  M.item_to_add_name = nil
  M.item_to_add_color = nil
  M.item_to_add_width = nil
  M.item_to_add_height = nil
  M.drag_waveform = nil
  M.out_of_bounds = nil
end

function M.request_exit()
  M.exit = true
end

-- Preview management
function M.start_preview(item)
  if not item then return end

  -- Stop current preview
  M.stop_preview()

  -- Get the currently selected/active track
  local target_track = reaper.GetSelectedTrack(0, 0)

  if not target_track then
    -- No track selected, use regular preview
    local take = reaper.GetActiveTake(item)
    if take then
      local source = reaper.GetMediaItemTake_Source(take)
      if source then
        M.previewing = reaper.PlayPreview(source)
        M.preview_item = item
      end
    end
    return
  end

  -- Preview through selected track by creating a temporary item
  local take = reaper.GetActiveTake(item)
  if not take then return end

  -- Get item position and length
  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

  -- Get current edit cursor position
  local cursor_pos = reaper.GetCursorPosition()

  -- Create temporary item on selected track
  local temp_item = reaper.AddMediaItemToTrack(target_track)
  reaper.SetMediaItemInfo_Value(temp_item, "D_POSITION", cursor_pos)
  reaper.SetMediaItemInfo_Value(temp_item, "D_LENGTH", item_len)

  -- Copy the take to the temporary item
  local temp_take = reaper.AddTakeToMediaItem(temp_item)
  local source = reaper.GetMediaItemTake_Source(take)

  if source then
    reaper.SetMediaItemTake_Source(temp_take, source)

    -- Copy take properties
    local take_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    reaper.SetMediaItemTakeInfo_Value(temp_take, "D_STARTOFFS", take_offset)

    -- Copy item volume
    local item_vol = reaper.GetMediaItemInfo_Value(item, "D_VOL")
    reaper.SetMediaItemInfo_Value(temp_item, "D_VOL", item_vol)

    -- Make it active take
    reaper.SetActiveTake(temp_take)

    -- Update timeline
    reaper.UpdateItemInProject(temp_item)

    -- Start playback from cursor position
    reaper.SetEditCurPos(cursor_pos, false, false)
    reaper.OnPlayButton()

    -- Store preview state
    M.preview_item = item
    M.preview_temp_item = temp_item
    M.preview_track = target_track
    M.preview_start_time = reaper.time_precise()
    M.preview_duration = item_len
    M.previewing = 1  -- Flag to indicate preview is active
  else
    -- Failed to get source, clean up
    reaper.DeleteTrackMediaItem(target_track, temp_item)
  end
end

function M.stop_preview()
  if M.previewing and M.previewing ~= 0 then
    reaper.StopPreview(M.previewing)
    M.previewing = 0
  end

  -- Clean up temporary preview item
  if M.preview_temp_item then
    -- Stop playback if it's still playing
    local play_state = reaper.GetPlayState()
    if play_state & 1 == 1 then  -- Check if playing
      reaper.OnStopButton()
    end

    -- Delete temporary item
    if M.preview_track and reaper.ValidatePtr2(0, M.preview_track, "MediaTrack*") then
      if reaper.ValidatePtr2(0, M.preview_temp_item, "MediaItem*") then
        reaper.DeleteTrackMediaItem(M.preview_track, M.preview_temp_item)
      end
    end

    M.preview_temp_item = nil
  end

  M.preview_item = nil
  M.preview_track = nil
  M.preview_start_time = nil
  M.preview_duration = nil
end

function M.is_previewing(item)
  if not M.previewing or M.previewing == 0 then
    return false
  end

  -- Check if using temp item (track preview)
  if M.preview_temp_item then
    -- Check if playback is still active and within duration
    local play_state = reaper.GetPlayState()
    if play_state & 1 == 0 then
      -- Playback stopped, clean up
      M.stop_preview()
      return false
    end

    -- Check if preview duration exceeded
    if M.preview_start_time and M.preview_duration then
      local elapsed = reaper.time_precise() - M.preview_start_time
      if elapsed >= M.preview_duration then
        M.stop_preview()
        return false
      end
    end
  end

  return M.preview_item == item
end

-- Persistence
function M.persist_settings()
  Persistence.save_settings(M.settings)
end

function M.persist_disabled()
  Persistence.save_disabled_items(M.disabled)
end

function M.persist_favorites()
  Persistence.save_favorites(M.favorites)
end

function M.persist_all()
  M.persist_settings()
  M.persist_disabled()
  M.persist_favorites()
end

-- Cleanup
function M.cleanup()
  M.persist_all()

  -- Stop preview
  if M.previewing and M.previewing ~= 0 then
    reaper.StopPreview(M.previewing)
    M.previewing = 0
  end
end

return M
