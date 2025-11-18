-- @noindex
-- ItemPicker/core/app_state.lua
-- Centralized state management (single source of truth)

local Persistence = require("ItemPicker.data.persistence")

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
  split_midi_by_track = false,  -- Split MIDI items per item vs group by track
  group_items_by_name = true,  -- Group items with same name together (e.g., all "Kick" samples)
  focus_keyboard_on_init = true,
  search_string = "",
  tile_width = nil,
  tile_height = nil,
  separator_position = nil,  -- MIDI section height (nil = use default from config)
  sort_mode = "none",  -- Options: "none", "color", "name", "pool"
  waveform_quality = 1.0,  -- Waveform resolution multiplier (0.1-1.0, lower = better performance)
}

-- Runtime state (volatile)
M.samples = {}  -- { [filename] = { {item, name, track_muted, item_muted, uuid}, ...} }
M.sample_indexes = {}  -- Ordered list of filenames
M.midi_items = {}  -- { [take_name] = { {item, name, track_muted, item_muted, uuid}, ...} }
M.midi_indexes = {}  -- Ordered list of take names
M.audio_item_lookup = {}  -- { [uuid] = item_data } for O(1) access
M.midi_item_lookup = {}  -- { [uuid] = item_data } for O(1) access
M.needs_recollect = false  -- Flag to trigger item recollection

-- Loading state
M.is_loading = false
M.loading_progress = 0
M.incremental_loader = nil

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
M.previewing = false
M.preview_item = nil
M.preview_start_time = nil
M.preview_duration = nil

-- Rename state
M.rename_active = false
M.rename_uuid = nil
M.rename_text = ""
M.rename_is_audio = true
M.rename_focused = false  -- Track if input is focused
M.rename_queue = nil  -- For batch rename
M.rename_queue_index = 0

M.draw_list = nil

-- Runtime cache for waveforms/thumbnails (in-memory only, no disk I/O)
M.runtime_cache = {
  waveforms = {},
  midi_thumbnails = {},
  waveform_polylines = {},  -- Performance: Cache downsampled polyline points per uuid+width
  -- Filter cache to avoid recomputing filtered items every frame
  audio_filtered = nil,
  audio_filter_hash = nil,
  midi_filtered = nil,
  midi_filter_hash = nil,
}
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

function M.is_midi_disabled(item_name)
  return M.disabled.midi[item_name] == true
end

function M.toggle_audio_disabled(filename)
  if M.disabled.audio[filename] then
    M.disabled.audio[filename] = nil
  else
    M.disabled.audio[filename] = true
  end
  M.persist_disabled()
end

function M.toggle_midi_disabled(item_name)
  if M.disabled.midi[item_name] then
    M.disabled.midi[item_name] = nil
  else
    M.disabled.midi[item_name] = true
  end
  M.persist_disabled()
end

-- Favorites management
function M.is_audio_favorite(filename)
  return M.favorites.audio[filename] == true
end

function M.is_midi_favorite(item_name)
  return M.favorites.midi[item_name] == true
end

function M.toggle_audio_favorite(filename)
  if M.favorites.audio[filename] then
    M.favorites.audio[filename] = nil
  else
    M.favorites.audio[filename] = true
  end
  M.persist_favorites()
end

function M.toggle_midi_favorite(item_name)
  if M.favorites.midi[item_name] then
    M.favorites.midi[item_name] = nil
  else
    M.favorites.midi[item_name] = true
  end
  M.persist_favorites()
end

-- Item cycling
function M.cycle_audio_item(filename, delta)
  local content = M.samples[filename]
  if not content or #content == 0 then return end

  -- Build filtered list based on current settings
  local filtered = {}
  local seen_pools = {}  -- Track pool IDs to exclude pooled duplicates

  for i, entry in ipairs(content) do
    local should_include = true

    -- Exclude pooled duplicates (only show first occurrence of each pool)
    local pool_count = entry.pool_count or 1
    local pool_id = entry.pool_id
    if pool_count > 1 and pool_id then
      if seen_pools[pool_id] then
        should_include = false
      else
        seen_pools[pool_id] = true
      end
    end

    -- Apply disabled filter
    if not M.settings.show_disabled_items and M.disabled.audio[filename] then
      should_include = false
    end

    -- Apply mute filters
    local track_muted = entry.track_muted or false
    local item_muted = entry.item_muted or false
    if not M.settings.show_muted_tracks and track_muted then
      should_include = false
    end
    if not M.settings.show_muted_items and item_muted then
      should_include = false
    end

    -- Apply search filter
    local search = M.settings.search_string or ""
    if search ~= "" and entry[2] then
      if not item_name:lower():find(search:lower(), 1, true) then
        should_include = false
      end
    end

    if should_include then
      table.insert(filtered, {index = i, entry = entry})
    end
  end

  if #filtered == 0 then return end

  -- Find current position in filtered list
  local current = M.box_current_item[filename] or 1
  local current_pos = 1
  for i, item in ipairs(filtered) do
    if item.index == current then
      current_pos = i
      break
    end
  end

  -- Cycle through filtered list
  current_pos = current_pos + delta
  if current_pos > #filtered then current_pos = 1 end
  if current_pos < 1 then current_pos = #filtered end

  M.box_current_item[filename] = filtered[current_pos].index

  -- NOTE: We don't invalidate the cache here to prevent re-sorting
  -- The grid will pick up the new item on next frame without jumping position
  -- M.runtime_cache.audio_filter_hash = nil
end

function M.cycle_midi_item(item_name, delta)
  local content = M.midi_items[item_name]
  if not content or #content == 0 then
    reaper.ShowConsoleMsg(string.format("[CYCLE_MIDI] No content for key: %s\n", tostring(item_name)))
    return
  end

  -- Build filtered list based on current settings
  local filtered = {}
  local seen_pools = {}  -- Track pool IDs to exclude pooled duplicates

  for i, entry in ipairs(content) do
    local should_include = true

    -- Exclude pooled duplicates (only show first occurrence of each pool)
    local pool_count = entry.pool_count or 1
    local pool_id = entry.pool_id
    if pool_count > 1 and pool_id then
      if seen_pools[pool_id] then
        should_include = false
      else
        seen_pools[pool_id] = true
      end
    end

    -- Apply disabled filter
    if not M.settings.show_disabled_items and M.disabled.midi[item_name] then
      should_include = false
    end

    -- Apply mute filters
    local track_muted = entry.track_muted or false
    local item_muted = entry.item_muted or false
    if not M.settings.show_muted_tracks and track_muted then
      should_include = false
    end
    if not M.settings.show_muted_items and item_muted then
      should_include = false
    end

    -- Apply search filter
    local search = M.settings.search_string or ""
    if search ~= "" and entry[2] then
      if not item_name_text:lower():find(search:lower(), 1, true) then
        should_include = false
      end
    end

    if should_include then
      table.insert(filtered, {index = i, entry = entry})
    end
  end

  if #filtered == 0 then
    reaper.ShowConsoleMsg("[CYCLE_MIDI] No items pass filters\n")
    return
  end

  reaper.ShowConsoleMsg(string.format("[CYCLE_MIDI] Group '%s' has %d items (%d after filters)\n", tostring(item_name), #content, #filtered))

  -- Find current position in filtered list
  local current = M.box_current_midi_track[item_name] or 1
  local current_pos = 1
  for i, item in ipairs(filtered) do
    if item.index == current then
      current_pos = i
      break
    end
  end

  reaper.ShowConsoleMsg(string.format("[CYCLE_MIDI] Current filtered position: %d/%d\n", current_pos, #filtered))

  -- Cycle through filtered list
  current_pos = current_pos + delta
  if current_pos > #filtered then current_pos = 1 end
  if current_pos < 1 then current_pos = #filtered end

  reaper.ShowConsoleMsg(string.format("[CYCLE_MIDI] New filtered position: %d/%d (absolute index: %d)\n", current_pos, #filtered, filtered[current_pos].index))

  M.box_current_midi_track[item_name] = filtered[current_pos].index

  -- NOTE: We don't invalidate the cache here to prevent re-sorting
  -- The grid will pick up the new item on next frame without jumping position
  -- M.runtime_cache.midi_filter_hash = nil
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

-- Preview management (using SWS extension commands)
function M.start_preview(item)
  if not item then return end

  -- Stop current preview
  M.stop_preview()

  -- Get item duration for progress tracking
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

  -- First, select the item for SWS commands to work
  reaper.SelectAllMediaItems(0, false)  -- Deselect all
  reaper.SetMediaItemSelected(item, true)

  -- Get currently selected track (if any)
  local selected_track = reaper.GetSelectedTrack(0, 0)

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
      M.previewing = true
      M.preview_item = item
      M.preview_start_time = reaper.time_precise()
      M.preview_duration = item_len
    end
  else
    -- Audio: Use SWS commands
    if selected_track then
      -- Preview through selected track with FX
      local cmd_id = reaper.NamedCommandLookup("_SWS_PREVIEWTRACK")
      if cmd_id and cmd_id ~= 0 then
        reaper.Main_OnCommand(cmd_id, 0)
        M.previewing = true
        M.preview_item = item
        M.preview_start_time = reaper.time_precise()
        M.preview_duration = item_len
      end
    else
      -- Direct preview (no FX, faster)
      local cmd_id = reaper.NamedCommandLookup("_XENAKIOS_ITEMASPCM1")
      if cmd_id and cmd_id ~= 0 then
        reaper.Main_OnCommand(cmd_id, 0)
        M.previewing = true
        M.preview_item = item
        M.preview_start_time = reaper.time_precise()
        M.preview_duration = item_len
      end
    end
  end
end

function M.stop_preview()
  if M.previewing then
    -- Stop SWS preview
    local cmd_id = reaper.NamedCommandLookup("_XENAKIOS_STOPITEMPREVIEW")
    if cmd_id and cmd_id ~= 0 then
      reaper.Main_OnCommand(cmd_id, 0)
    end
    M.previewing = false
    M.preview_item = nil
    M.preview_start_time = nil
    M.preview_duration = nil
  end
end

function M.is_previewing(item)
  return M.previewing and M.preview_item == item
end

function M.get_preview_progress()
  if not M.previewing or not M.preview_start_time or not M.preview_duration then
    return 0
  end

  local elapsed = reaper.time_precise() - M.preview_start_time
  local progress = elapsed / M.preview_duration

  -- Auto-stop when preview completes
  if progress >= 1.0 then
    M.stop_preview()
    return 1.0
  end

  return progress
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

  -- Skip disk cache flush - causes 5 second UI freeze
  -- Waveforms/MIDI will be regenerated on next open (fast with job queue)
  -- If you want persistent cache, uncomment the code below:
  -- local disk_cache_ok, disk_cache = pcall(require, 'ItemPicker.data.disk_cache')
  -- if disk_cache_ok and disk_cache.flush then
  --   disk_cache.flush()
  -- end

  -- Stop preview using SWS command
  M.stop_preview()
end

return M
