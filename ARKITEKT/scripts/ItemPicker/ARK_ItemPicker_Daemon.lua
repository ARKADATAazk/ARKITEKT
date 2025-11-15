-- @noindex
-- ItemPicker Daemon - Always-on background process with preloaded UI
-- Use ARK_ItemPicker_Toggle.lua to show/hide instantly

-- Package path setup (following RegionPlaylist pattern)
local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path  -- Go up one level from ItemPicker
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path  -- Go up to ARKITEKT
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path  -- Go up to project root

-- Ensure root_path ends with a slash
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end

-- Add both module search paths
local arkitekt_path = root_path .. "ARKITEKT/"
local scripts_path = root_path .. "ARKITEKT/scripts/"
package.path = arkitekt_path.. "?.lua;" .. arkitekt_path.. "?/init.lua;" ..
               scripts_path .. "?.lua;" .. scripts_path .. "?/init.lua;" ..
               package.path

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

-- Check dependencies
local has_imgui, imgui_test = pcall(require, 'imgui')
if not has_imgui then
  reaper.MB("Missing dependency: ReaImGui extension.\nDownload it via Reapack ReaTeam extension repository.", "Error", 0)
  return false
end

local reaimgui_shim_file_path = reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua'
if reaper.file_exists(reaimgui_shim_file_path) then
  dofile(reaimgui_shim_file_path)('0.10')
end

-- Load required modules
local ImGui = require 'imgui' '0.10'
local Runtime = require('rearkitekt.app.runtime')
local OverlayManager = require('rearkitekt.gui.widgets.overlays.overlay.manager')

-- Load ItemPicker modules
local Config = require('ItemPicker.core.config')
local State = require('ItemPicker.core.app_state')
local Controller = require('ItemPicker.core.controller')
local GUI = require('ItemPicker.ui.gui')

-- Domain modules
local visualization = require('ItemPicker.domain.visualization')
local cache_mgr = require('ItemPicker.domain.cache_manager')
local reaper_interface = require('ItemPicker.domain.reaper_interface')
local utils = require('ItemPicker.domain.utils')
local drag_handler = require('ItemPicker.ui.views.drag_handler')

-- ============================================================================
-- ExtState Communication
-- ============================================================================

local ext_state_section = "ARK_ItemPicker_Daemon"
local ext_state_running = "daemon_running"
local ext_state_visible = "ui_visible"
local ext_state_toggle = "toggle_request"

-- ============================================================================
-- Daemon State
-- ============================================================================

local daemon = {
  running = false,
  ui_visible = false,

  -- Background processing
  last_change_count = -1,
  last_project_path = "",
  cache = nil,

  -- Thumbnail generation queue
  thumbnail_queue = {},
  queue_index = 1,
  thumbnails_per_cycle = 5,

  -- Timing
  idle_interval = 1.0,        -- 1 second when idle
  active_interval = 0.05,     -- 50ms when generating
  last_bg_update = 0,

  -- UI components (pre-loaded)
  ctx = nil,
  fonts = nil,
  overlay_mgr = nil,
  gui = nil,
}

-- ============================================================================
-- Helper Functions
-- ============================================================================

local function SetButtonState(set)
  local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  reaper.SetToggleCommandState(sec, cmd, set or 0)
  reaper.RefreshToolbar2(sec, cmd)
end

local function log(msg)
  reaper.ShowConsoleMsg("[ItemPicker Daemon] " .. msg .. "\n")
end

-- ============================================================================
-- Font Loading
-- ============================================================================

local function load_fonts(ctx)
  local SEP = package.config:sub(1,1)
  local src = debug.getinfo(1, 'S').source:sub(2)
  local this_dir = src:match('(.*'..SEP..')') or ('.'..SEP)
  local parent = this_dir:match('^(.*'..SEP..')[^'..SEP..']*'..SEP..'$') or this_dir
  local fontsdir = parent .. 'rearkitekt' .. SEP .. 'fonts' .. SEP

  local regular = fontsdir .. 'Inter_18pt-Regular.ttf'
  local bold = fontsdir .. 'Inter_18pt-SemiBold.ttf'
  local mono = fontsdir .. 'JetBrainsMono-Regular.ttf'

  local function exists(p)
    local f = io.open(p, 'rb')
    if f then f:close(); return true end
  end

  local fonts = {
    default = exists(regular) and ImGui.CreateFont(regular, 14) or ImGui.CreateFont('sans-serif', 14),
    default_size = 14,
    title = exists(bold) and ImGui.CreateFont(bold, 24) or ImGui.CreateFont('sans-serif', 24),
    title_size = 24,
    monospace = exists(mono) and ImGui.CreateFont(mono, 14) or ImGui.CreateFont('sans-serif', 14),
    monospace_size = 14,
  }

  for _, font in pairs(fonts) do
    if font and type(font) ~= "number" then
      ImGui.Attach(ctx, font)
    end
  end

  return fonts
end

-- ============================================================================
-- Background Processing
-- ============================================================================

local function has_project_changed()
  local current_change_count = reaper.GetProjectStateChangeCount(0)
  local current_project_path = reaper.GetProjectPath("")

  if daemon.last_change_count == -1 then
    daemon.last_change_count = current_change_count
    daemon.last_project_path = current_project_path
    return true
  end

  if current_change_count ~= daemon.last_change_count or
     current_project_path ~= daemon.last_project_path then
    daemon.last_change_count = current_change_count
    daemon.last_project_path = current_project_path
    return true
  end

  return false
end

local function collect_project_items()
  local settings = {
    play_item_through_track = false,
    show_muted_tracks = false,
    show_muted_items = false,
    show_disabled_items = false,
    split_midi_by_track = false,
  }

  local state = {
    settings = settings,
  }

  state.track_chunks = reaper_interface.GetAllTrackStateChunks()
  state.item_chunks = reaper_interface.GetAllCleanedItemChunks()

  local samples, sample_indexes = reaper_interface.GetProjectSamples(settings, state)
  local midi_items, midi_indexes = reaper_interface.GetProjectMIDI(settings, state)

  state.samples = samples
  state.sample_indexes = sample_indexes
  state.midi_items = midi_items
  state.midi_indexes = midi_indexes

  return state
end

local function build_thumbnail_queue(state)
  daemon.thumbnail_queue = {}
  daemon.queue_index = 1

  -- Queue audio waveforms
  if state.samples and state.sample_indexes then
    for _, key in ipairs(state.sample_indexes) do
      local sample_data = state.samples[key]
      if sample_data and sample_data[1] and sample_data[1].item then
        local uuid = sample_data[1].uuid
        local sig = cache_mgr.get_item_signature(sample_data[1].item, uuid)
        if sig then
          local cached = cache_mgr.load_waveform_from_disk(sig)
          if not cached then
            table.insert(daemon.thumbnail_queue, {
              type = "audio",
              item = sample_data[1].item,
              key = key,
              uuid = uuid,
            })
          end
        end
      end
    end
  end

  -- Queue MIDI thumbnails
  if state.midi_items and state.midi_indexes then
    for _, key in ipairs(state.midi_indexes) do
      local midi_data = state.midi_items[key]
      if midi_data and midi_data[1] and midi_data[1].item then
        local uuid = midi_data[1].uuid
        local sig = cache_mgr.get_item_signature(midi_data[1].item, uuid)
        if sig then
          local cached = cache_mgr.load_midi_thumbnail_from_disk(sig)
          if not cached then
            table.insert(daemon.thumbnail_queue, {
              type = "midi",
              item = midi_data[1].item,
              key = key,
              uuid = uuid,
            })
          end
        end
      end
    end
  end

  if #daemon.thumbnail_queue > 0 then
    log(string.format("Queued %d visualizations for generation", #daemon.thumbnail_queue))
  end
end

local function process_thumbnail_batch()
  if daemon.queue_index > #daemon.thumbnail_queue then
    return false
  end

  local batch_count = 0
  while batch_count < daemon.thumbnails_per_cycle and
        daemon.queue_index <= #daemon.thumbnail_queue do

    local job = daemon.thumbnail_queue[daemon.queue_index]

    if job.type == "audio" then
      visualization.GetItemWaveform(daemon.cache, job.item, job.uuid)
    elseif job.type == "midi" then
      local cache_w, cache_h = cache_mgr.get_midi_cache_size()
      visualization.GenerateMidiThumbnail(daemon.cache, job.item, cache_w, cache_h, job.uuid)
    end

    daemon.queue_index = daemon.queue_index + 1
    batch_count = batch_count + 1
  end

  return true
end

local function background_processing()
  local current_time = reaper.time_precise()
  local has_work = #daemon.thumbnail_queue > 0 and
                   daemon.queue_index <= #daemon.thumbnail_queue

  local interval = has_work and daemon.active_interval or daemon.idle_interval

  if current_time - daemon.last_bg_update < interval then
    return
  end

  daemon.last_bg_update = current_time

  -- Check for project changes
  if has_project_changed() then
    log("Project changed, updating cache...")

    local state = collect_project_items()
    cache_mgr.save_project_state_to_disk(state)
    build_thumbnail_queue(state)

    -- Also trigger UI recollection if visible
    if daemon.ui_visible then
      State.needs_recollect = true
    end
  end

  -- Process thumbnail batch
  if has_work then
    process_thumbnail_batch()
  end
end

-- ============================================================================
-- UI Show/Hide
-- ============================================================================

local function show_ui()
  if daemon.ui_visible then return end

  daemon.ui_visible = true
  reaper.SetExtState(ext_state_section, ext_state_visible, "1", false)

  -- Push overlay onto stack
  local Colors = require('rearkitekt.core.colors')
  daemon.overlay_mgr:push({
    id = "item_picker_main",
    use_viewport = true,
    fade_duration = 0.2,  -- Faster fade for instant feel
    fade_curve = 'ease_out_quad',
    scrim_color = Colors.hexrgb("#101010"),
    scrim_opacity = 0.92,
    show_close_button = true,
    close_on_background_click = false,
    close_on_background_right_click = true,
    close_on_scrim = false,
    esc_to_close = false,
    close_button_size = 32,
    close_button_margin = 16,
    close_button_proximity = 150,
    content_padding = 20,

    render = function(ctx, alpha_val, bounds)
      ImGui.PushFont(ctx, daemon.fonts.default, daemon.fonts.default_size)

      local overlay_state = {
        x = bounds.x,
        y = bounds.y,
        width = bounds.w,
        height = bounds.h,
        alpha = alpha_val,
      }

      if daemon.gui and daemon.gui.draw then
        daemon.gui:draw(ctx, {
          fonts = daemon.fonts,
          overlay_state = overlay_state,
          overlay = { alpha = { value = function() return alpha_val end } },
          is_overlay_mode = true,
        })
      end

      ImGui.PopFont(ctx)
    end,

    on_close = function()
      hide_ui()
    end,
  })

  log("UI shown")
end

local function hide_ui()
  if not daemon.ui_visible then return end

  daemon.ui_visible = false
  reaper.SetExtState(ext_state_section, ext_state_visible, "0", false)
  daemon.overlay_mgr:pop("item_picker_main")

  -- Cleanup preview
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_STOPPREVIEW"), 0)

  log("UI hidden")
end

local function toggle_ui()
  if daemon.ui_visible then
    hide_ui()
  else
    show_ui()
  end
end

local function check_toggle_request()
  local toggle_req = reaper.GetExtState(ext_state_section, ext_state_toggle)
  if toggle_req == "1" then
    -- Clear the toggle request
    reaper.SetExtState(ext_state_section, ext_state_toggle, "", false)
    -- Toggle UI
    toggle_ui()
  end
end

-- ============================================================================
-- Initialization
-- ============================================================================

local function initialize()
  log("Initializing daemon...")

  -- Initialize state
  State.initialize(Config)

  -- Initialize domain modules
  reaper_interface.init(utils)
  visualization.init(utils, SCRIPT_DIRECTORY, cache_mgr)

  -- Initialize controller
  Controller.init(reaper_interface, utils)

  -- Create cache for background processing
  daemon.cache = cache_mgr.new(500)

  -- Create ImGui context (always running)
  daemon.ctx = ImGui.CreateContext("Item Picker Daemon")
  daemon.fonts = load_fonts(daemon.ctx)

  -- Create overlay manager
  daemon.overlay_mgr = OverlayManager.new()

  -- Create GUI (pre-initialized)
  daemon.gui = GUI.new(Config, State, Controller, visualization, cache_mgr, drag_handler)

  -- Pre-load cached state for instant startup
  local cached_state = cache_mgr.load_project_state_from_disk()
  local current_change_count = reaper.GetProjectStateChangeCount(0)

  if cached_state and cached_state.change_count == current_change_count then
    -- Use cached state for instant startup
    State.sample_indexes = cached_state.sample_indexes or {}
    State.midi_indexes = cached_state.midi_indexes or {}
    State.last_change_count = current_change_count
    log("Loaded cached state - instant startup ready")

    -- Pre-initialize GUI with cached data
    -- This ensures first show is instant (no collection work on first frame)
    daemon.gui:initialize_once(daemon.ctx)
  else
    -- No cache or outdated - do full initialization upfront
    log("No cache found - initializing from scratch...")
    daemon.gui:initialize_once(daemon.ctx)
  end

  -- Trigger initial background processing
  daemon.last_change_count = -1

  log("Daemon ready - use Toggle script to show/hide UI")
end

-- ============================================================================
-- Main Loop
-- ============================================================================

local function main_loop()
  if not daemon.running then return end

  -- Check for toggle requests from Toggle script
  check_toggle_request()

  -- Background processing (always runs)
  background_processing()

  -- UI rendering (only when visible or dragging)
  if State.dragging then
    -- When dragging, skip overlay and just render drag handlers
    ImGui.PushFont(daemon.ctx, daemon.fonts.default, daemon.fonts.default_size)
    daemon.gui:draw(daemon.ctx, {
      fonts = daemon.fonts,
      overlay_state = {},
      overlay = daemon.overlay_mgr,
      is_overlay_mode = true,
    })
    ImGui.PopFont(daemon.ctx)
  elseif daemon.ui_visible then
    -- Normal mode: let overlay manager handle rendering
    daemon.overlay_mgr:render(daemon.ctx)

    -- Check if overlay was closed
    if not daemon.overlay_mgr:is_active() then
      daemon.ui_visible = false
      reaper.SetExtState(ext_state_section, ext_state_visible, "0", false)
    end
  end

  reaper.defer(main_loop)
end

-- ============================================================================
-- Cleanup
-- ============================================================================

local function cleanup()
  daemon.running = false
  SetButtonState(0)

  if daemon.ui_visible then
    hide_ui()
  end

  -- Clean up ExtState
  reaper.DeleteExtState(ext_state_section, ext_state_running, false)
  reaper.DeleteExtState(ext_state_section, ext_state_visible, false)
  reaper.DeleteExtState(ext_state_section, ext_state_toggle, false)

  State.cleanup()
  log("Daemon stopped")
end

-- ============================================================================
-- Entry Point
-- ============================================================================

-- Mark daemon as running
reaper.SetExtState(ext_state_section, ext_state_running, "1", false)
reaper.SetExtState(ext_state_section, ext_state_visible, "0", false)

SetButtonState(1)
daemon.running = true

initialize()

-- Register cleanup
reaper.atexit(cleanup)

-- Start main loop
main_loop()
