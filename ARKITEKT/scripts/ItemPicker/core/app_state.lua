-- @noindex
-- ItemPicker/core/app_state.lua
-- Centralized state management (single source of truth)

local Persistence = require("ItemPicker.data.persistence")
local Defaults = require("ItemPicker.defs.defaults")
local PreviewManager = require("ItemPicker.core.preview_manager")

local M = {}

package.loaded["ItemPicker.core.app_state"] = M

-- Settings (persisted) - initialize from defaults
M.settings = {}
for k, v in pairs(Defaults.SETTINGS) do
  M.settings[k] = v
end

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

-- Region filter state
M.selected_regions = {}  -- { [region_name] = true } for active filters
M.all_regions = {}  -- Cached list of {name, color} from GetAllProjectRegions()

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
M.preview_item_guid = nil  -- Track item by GUID for reliable comparison
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

  -- Initialize preview manager with settings
  PreviewManager.init(M.settings)
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
  -- Invalidate grid cache to refresh with new search filter
  if M.runtime_cache then
    M.runtime_cache.audio_filter_hash = nil
    M.runtime_cache.midi_filter_hash = nil
  end
end

-- Tile size management
function M.get_tile_width()
  return M.tile_sizes.width or M.config.TILE.DEFAULT_WIDTH
end

function M.get_tile_height()
  return M.tile_sizes.height or M.config.TILE.DEFAULT_HEIGHT
end

function M.set_tile_size(width, height)
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

-- Item cycling (uses shared pool_utils for filtering)
local pool_utils = require('ItemPicker.services.pool_utils')

function M.cycle_audio_item(filename, delta)
  local content = M.samples[filename]
  if not content or #content == 0 then return end

  -- Build filtered list using shared utility
  local is_disabled = M.disabled.audio[filename]
  local filtered = pool_utils.build_filtered_items(content, M.settings, is_disabled, M.settings.search_string)

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
end

function M.cycle_midi_item(item_name, delta)
  local content = M.midi_items[item_name]
  if not content or #content == 0 then return end

  -- Build filtered list using shared utility
  local is_disabled = M.disabled.midi[item_name]
  local filtered = pool_utils.build_filtered_items(content, M.settings, is_disabled, M.settings.search_string)

  if #filtered == 0 then return end

  -- Find current position in filtered list
  local current = M.box_current_midi_track[item_name] or 1
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

  M.box_current_midi_track[item_name] = filtered[current_pos].index
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
function M.start_drag(item, item_name, color, width, height, is_source_pooled)
  M.dragging = true
  M.item_to_add = item
  M.item_to_add_name = item_name
  M.item_to_add_color = color
  M.item_to_add_width = width
  M.item_to_add_height = height
  M.drag_waveform = nil
  -- Determine default pooled state:
  -- If source item is already pooled, default to pooled copies
  -- Otherwise, use the global toggle state
  if is_source_pooled then
    M.original_pooled_midi_state = true
  else
    M.original_pooled_midi_state = reaper.GetToggleCommandState(41071) == 1
  end
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
  M.waiting_for_new_click = nil
  M.mouse_was_pressed_after_drop = nil
  M.drop_completed = nil
  M.captured_shift = nil
  M.captured_ctrl = nil
  M.original_pooled_midi_state = nil
  M.alt_pool_mode = nil
  -- Don't clear should_close_after_drop here - it needs to persist to next frame

  -- Clear grid internal drag states to prevent visual artifacts when returning to picker
  if M.coordinator and M.coordinator.clear_grid_drag_states then
    M.coordinator:clear_grid_drag_states()
  end
end

function M.request_exit()
  M.exit = true
end

-- Preview management (delegated to PreviewManager)
function M.start_preview(item, force_mode)
  PreviewManager.start_preview(item, force_mode)
end

function M.stop_preview()
  PreviewManager.stop_preview()
end

function M.is_previewing(item)
  return PreviewManager.is_previewing(item)
end

function M.get_preview_progress()
  return PreviewManager.get_preview_progress()
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
