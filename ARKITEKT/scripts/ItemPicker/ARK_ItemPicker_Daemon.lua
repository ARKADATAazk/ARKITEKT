-- @noindex
-- ItemPicker Daemon - Lightweight background process
-- Monitors project changes and pre-generates thumbnails for instant ItemPicker startup

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

-- Load required modules
local cache_mgr = require('ItemPicker.domain.cache_manager')
local reaper_interface = require('ItemPicker.domain.reaper_interface')
local utils = require('ItemPicker.domain.utils')
local visualization = require('ItemPicker.domain.visualization')

-- Initialize modules
reaper_interface.init(utils)
visualization.init(utils, SCRIPT_DIRECTORY, cache_mgr)

-- Daemon state
local daemon_state = {
  running = false,
  last_change_count = -1,
  last_project_path = "",
  cache = nil,

  -- Incremental thumbnail generation state
  thumbnail_queue = {},
  queue_index = 1,
  thumbnails_per_cycle = 5,  -- Generate 5 per cycle (increased from 2)

  -- Timing
  idle_interval = 1.0,        -- 1 second when idle
  active_interval = 0.05,     -- 50ms when generating (faster than before)
  last_update = 0,
}

local function SetButtonState(set)
  local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  reaper.SetToggleCommandState(sec, cmd, set or 0)
  reaper.RefreshToolbar2(sec, cmd)
end

local function log(msg)
  reaper.ShowConsoleMsg("[ItemPicker Daemon] " .. msg .. "\n")
end

-- Check if project changed
local function has_project_changed()
  local current_change_count = reaper.GetProjectStateChangeCount(0)
  local current_project_path = reaper.GetProjectPath("")

  if daemon_state.last_change_count == -1 then
    -- First run
    daemon_state.last_change_count = current_change_count
    daemon_state.last_project_path = current_project_path
    return true
  end

  if current_change_count ~= daemon_state.last_change_count or
     current_project_path ~= daemon_state.last_project_path then
    daemon_state.last_change_count = current_change_count
    daemon_state.last_project_path = current_project_path
    return true
  end

  return false
end

-- Collect project items (minimal state for thumbnails)
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

  -- Get samples and MIDI items
  local samples, sample_indexes = reaper_interface.GetProjectSamples(settings, state)
  local midi_items, midi_indexes = reaper_interface.GetProjectMIDI(settings, state)

  state.samples = samples
  state.sample_indexes = sample_indexes
  state.midi_items = midi_items
  state.midi_indexes = midi_indexes

  return state
end

-- Build thumbnail generation queue
local function build_thumbnail_queue(state)
  daemon_state.thumbnail_queue = {}
  daemon_state.queue_index = 1

  -- Queue audio waveforms for generation
  if state.samples and state.sample_indexes then
    for _, key in ipairs(state.sample_indexes) do
      local sample_data = state.samples[key]
      if sample_data and sample_data[1] and sample_data[1].item then
        -- Check if waveform already exists in disk cache
        local sig = cache_mgr.get_item_signature(sample_data[1].item)
        if sig then
          local cached = cache_mgr.load_waveform_from_disk(sig)
          if not cached then
            -- Not cached, add to queue
            table.insert(daemon_state.thumbnail_queue, {
              type = "audio",
              item = sample_data[1].item,
              key = key,
            })
          end
        end
      end
    end
  end

  -- Queue MIDI items for thumbnail generation
  if state.midi_items and state.midi_indexes then
    for _, key in ipairs(state.midi_indexes) do
      local midi_data = state.midi_items[key]
      if midi_data and midi_data[1] and midi_data[1].item then
        -- Check if thumbnail already exists in disk cache
        local sig = cache_mgr.get_item_signature(midi_data[1].item)
        if sig then
          local cached = cache_mgr.load_midi_thumbnail_from_disk(sig)
          if not cached then
            -- Not cached, add to queue
            table.insert(daemon_state.thumbnail_queue, {
              type = "midi",
              item = midi_data[1].item,
              key = key,
            })
          end
        end
      end
    end
  end

  log(string.format("Queued %d visualizations for generation (%d audio + %d MIDI)",
    #daemon_state.thumbnail_queue,
    state.sample_indexes and #state.sample_indexes or 0,
    state.midi_indexes and #state.midi_indexes or 0))
end

-- Process a batch of thumbnails
local function process_thumbnail_batch()
  if daemon_state.queue_index > #daemon_state.thumbnail_queue then
    return false  -- Done
  end

  local batch_count = 0
  while batch_count < daemon_state.thumbnails_per_cycle and
        daemon_state.queue_index <= #daemon_state.thumbnail_queue do

    local job = daemon_state.thumbnail_queue[daemon_state.queue_index]

    if job.type == "audio" then
      -- Generate audio waveform
      visualization.GetItemWaveform(daemon_state.cache, job.item)
    elseif job.type == "midi" then
      -- Generate MIDI thumbnail
      local cache_w, cache_h = cache_mgr.get_midi_cache_size()
      visualization.GenerateMidiThumbnail(daemon_state.cache, job.item, cache_w, cache_h)
    end

    daemon_state.queue_index = daemon_state.queue_index + 1
    batch_count = batch_count + 1
  end

  return true  -- More to process
end

-- Save daemon state to disk
local function save_daemon_state()
  local sep = package.config:sub(1,1)
  local cache_dir = cache_mgr.get_cache_dir()
  local state_file = cache_dir .. "daemon_state.lua"

  reaper.RecursiveCreateDirectory(cache_dir, 0)

  local file = io.open(state_file, "w")
  if not file then return false end

  file:write("return {\n")
  file:write("  running = true,\n")
  file:write("  last_update = " .. reaper.time_precise() .. ",\n")
  file:write("  project_path = " .. string.format("%q", daemon_state.last_project_path) .. ",\n")
  file:write("  change_count = " .. daemon_state.last_change_count .. ",\n")
  file:write("  thumbnails_generated = " .. (daemon_state.queue_index - 1) .. ",\n")
  file:write("  thumbnails_total = " .. #daemon_state.thumbnail_queue .. ",\n")
  file:write("}\n")
  file:close()

  return true
end

-- Main daemon loop
local function daemon_loop()
  if not daemon_state.running then return end

  local current_time = reaper.time_precise()
  local has_work = #daemon_state.thumbnail_queue > 0 and
                   daemon_state.queue_index <= #daemon_state.thumbnail_queue

  -- Determine interval based on workload
  local interval = has_work and daemon_state.active_interval or daemon_state.idle_interval

  if current_time - daemon_state.last_update < interval then
    reaper.defer(daemon_loop)
    return
  end

  daemon_state.last_update = current_time

  -- Check for project changes
  if has_project_changed() then
    log("Project changed, recollecting items...")

    -- Collect items
    local state = collect_project_items()

    -- Save project state to disk
    cache_mgr.save_project_state_to_disk(state)

    -- Build thumbnail queue
    build_thumbnail_queue(state)
  end

  -- Process thumbnail batch
  if has_work then
    local still_processing = process_thumbnail_batch()

    -- Log progress periodically
    if daemon_state.queue_index % 20 == 0 or not still_processing then
      local progress = math.floor((daemon_state.queue_index - 1) / #daemon_state.thumbnail_queue * 100)
      log(string.format("Thumbnail generation: %d%%", progress))
    end

    -- Save state
    save_daemon_state()
  end

  -- Continue loop
  reaper.defer(daemon_loop)
end

-- Startup
local function start_daemon()
  daemon_state.running = true
  daemon_state.cache = cache_mgr.new(500)  -- Larger cache for daemon

  SetButtonState(1)
  log("ItemPicker Daemon started")
  log("Monitoring project for changes...")

  -- Trigger initial collection
  daemon_state.last_change_count = -1

  daemon_loop()
end

-- Cleanup
local function cleanup()
  daemon_state.running = false
  SetButtonState(0)
  log("ItemPicker Daemon stopped")

  -- Clear daemon state file
  local sep = package.config:sub(1,1)
  local cache_dir = cache_mgr.get_cache_dir()
  local state_file = cache_dir .. "daemon_state.lua"

  local file = io.open(state_file, "w")
  if file then
    file:write("return { running = false }\n")
    file:close()
  end
end

-- Register atexit
reaper.atexit(cleanup)

-- Start
start_daemon()
