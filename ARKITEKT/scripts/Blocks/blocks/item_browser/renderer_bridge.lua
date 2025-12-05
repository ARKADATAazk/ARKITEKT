-- @noindex
-- Blocks/blocks/item_browser/renderer_bridge.lua
-- Bridge to use ItemPicker's tile renderers directly
-- This ensures item_browser tiles look identical to ItemPicker

local M = {}

-- Setup package.path to find ItemPicker modules (in case loaded before init.lua)
local function setup_itempicker_paths()
  local source = debug.getinfo(1,'S').source:sub(2)
  local scripts_path = source:match('(.-scripts[/\\])')
  if scripts_path and not package.path:find(scripts_path, 1, true) then
    local sep = package.config:sub(1,1)
    package.path = scripts_path .. '?.lua;' .. scripts_path .. '?' .. sep .. 'init.lua;' .. package.path
  end
end
setup_itempicker_paths()

-- Try to require ItemPicker's modules
local AudioRenderer, MidiRenderer, BaseRenderer, Config, Palette
local ItemPickerState

local function ensure_deps()
  if AudioRenderer then return true end

  -- Try to load ItemPicker's renderer modules
  local ok1, ar = pcall(require, 'ItemPicker.ui.grids.renderers.audio')
  local ok2, mr = pcall(require, 'ItemPicker.ui.grids.renderers.midi')
  local ok3, br = pcall(require, 'ItemPicker.ui.grids.renderers.base')
  local ok4, cfg = pcall(require, 'ItemPicker.config.constants')
  local ok5, pal = pcall(require, 'ItemPicker.config.palette')

  if ok1 and ok2 and ok3 and ok4 then
    AudioRenderer = ar
    MidiRenderer = mr
    BaseRenderer = br
    Config = cfg
    Palette = ok5 and pal or nil

    -- Try to get ItemPicker state for shared waveform cache
    local ok_state, state = pcall(require, 'ItemPicker.app.state')
    if ok_state then
      ItemPickerState = state
    end

    return true
  end

  return false
end

---Check if ItemPicker renderers are available
---@return boolean
function M.available()
  return ensure_deps()
end

---Build minimal state object for renderers
---@param block_state table item_browser's state
---@param storage table Storage module reference
---@return table State object compatible with ItemPicker renderers
local function build_renderer_state(block_state, storage)
  -- Load favorites from shared storage
  local favorites = storage.load_favorites()

  return {
    -- Favorites and disabled (from shared storage)
    favorites = favorites,
    disabled = { audio = {}, midi = {} },

    -- Settings (minimal)
    settings = {
      show_disabled_items = true,
      show_duration = true,
      show_region_tags = false,
      waveform_quality = 0.3,
      waveform_filled = true,
    },

    -- Runtime cache - use ItemPicker's if available, else create empty
    runtime_cache = ItemPickerState and ItemPickerState.runtime_cache or {
      waveforms = {},
      midi_thumbnails = {},
      waveform_polylines = {},
    },

    -- Job queue for waveform generation (if ItemPicker available)
    job_queue = ItemPickerState and ItemPickerState.job_queue or nil,

    -- Overlay alpha (1.0 = fully visible)
    overlay_alpha = 1.0,

    -- Selection counts (for marching ants LOD)
    audio_selection_count = block_state.selected_key and 1 or 0,
    midi_selection_count = 0,

    -- Preview state (disabled for now)
    is_previewing = function() return false end,
    get_preview_progress = function() return 0 end,

    -- Icon font (not used in simplified mode)
    icon_font = nil,
    icon_font_size = 14,
  }
end

---Convert item_browser item to ItemPicker item_data format
---@param item table item_browser item
---@param index number Item index in filtered list
---@param total number Total items
---@param item_type string 'audio' or 'midi'
---@return table ItemPicker-compatible item_data
local function convert_item_data(item, index, total, item_type)
  return {
    -- Core identifiers
    key = item.key,
    uuid = item.key,  -- Use key as UUID
    filename = item.filename or item.key,

    -- Display info
    name = item.name,
    track_name = item.track_name,
    color = item.color or 0x606060FF,

    -- Pool/cycle info
    index = index,
    total = total,
    pool_count = 1,

    -- State
    track_muted = false,
    item_muted = false,

    -- REAPER references
    item = item.item,
    take = item.take,

    -- Duration (cached)
    duration = item.duration or 0,

    -- Regions (empty for now)
    regions = {},
  }
end

---Begin frame - must be called before rendering tiles
---@param ctx userdata ImGui context
---@param block_state table item_browser's state
---@param storage table Storage module
function M.begin_frame(ctx, block_state, storage)
  if not ensure_deps() then return end

  -- Cache config for this frame
  BaseRenderer.cache_config(Config)

  -- Build renderer state
  M._state = build_renderer_state(block_state, storage)

  -- Call audio renderer's begin_frame
  if AudioRenderer.begin_frame then
    AudioRenderer.begin_frame(ctx, Config, M._state)
  end
  if MidiRenderer and MidiRenderer.begin_frame then
    MidiRenderer.begin_frame(ctx, Config, M._state)
  end
end

---Render an audio tile using ItemPicker's renderer
---@param ctx userdata ImGui context
---@param dl userdata DrawList
---@param rect table {x1, y1, x2, y2}
---@param item table item_browser item
---@param index number Item index
---@param total number Total items
---@param is_selected boolean Whether tile is selected
---@param is_hovered boolean Whether tile is hovered
function M.render_audio_tile(ctx, dl, rect, item, index, total, is_selected, is_hovered)
  if not ensure_deps() then return end

  local item_data = convert_item_data(item, index, total, 'audio')
  local tile_state = {
    selected = is_selected,
    hover = is_hovered,
  }

  -- No animator or visualization for simplified mode
  -- This gives us the base tile rendering without waveforms
  AudioRenderer.render(
    ctx, dl, rect, item_data, tile_state,
    Config,
    nil,  -- animator (disabled)
    {},   -- visualization (empty)
    M._state,
    {},   -- badge_rects
    nil   -- disable_animator
  )
end

---Render a MIDI tile using ItemPicker's renderer
---@param ctx userdata ImGui context
---@param dl userdata DrawList
---@param rect table {x1, y1, x2, y2}
---@param item table item_browser item
---@param index number Item index
---@param total number Total items
---@param is_selected boolean Whether tile is selected
---@param is_hovered boolean Whether tile is hovered
function M.render_midi_tile(ctx, dl, rect, item, index, total, is_selected, is_hovered)
  if not ensure_deps() then return end

  local item_data = convert_item_data(item, index, total, 'midi')
  item_data.track_guid = item.track_guid

  local tile_state = {
    selected = is_selected,
    hover = is_hovered,
  }

  MidiRenderer.render(
    ctx, dl, rect, item_data, tile_state,
    Config,
    nil,  -- animator
    {},   -- visualization
    M._state,
    {},   -- badge_rects
    nil   -- disable_animator
  )
end

---Get ItemPicker's config (for consistent sizing)
---@return table|nil Config or nil if not available
function M.get_config()
  if ensure_deps() then
    return Config
  end
  return nil
end

return M
