-- @noindex
-- DrumBlocks/app/state.lua
-- State management for DrumBlocks
-- VST handles its own persistence - Lua queries VST state on startup/track change

local Bridge = require('DrumBlocks.domain.bridge')
local WaveformCache = require('DrumBlocks.domain.waveform_cache')

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

M.PADS_PER_BANK = 16
M.NUM_BANKS = 8  -- 8 banks × 16 pads = 128 total
M.GRID_COLS = 4
M.GRID_ROWS = 4

-- ============================================================================
-- STATE
-- ============================================================================

local state = {
  settings = nil,

  -- Current track/FX
  track = nil,
  fx_index = nil,
  instance_id = nil,  -- Unique ID for current DrumBlocks instance

  -- UI state
  current_bank = 0,        -- 0-7
  selected_pad = nil,      -- 0-127
  hot_swap_enabled = true,
  hot_swap_original = nil, -- Original sample when hot-swapping

  -- Kit data (in-memory representation)
  kit = {
    name = 'Untitled Kit',
    pads = {},  -- [pad_index] = { samples = {}, volume, pan, ... }
  },

  -- Browser state
  browser_path = nil,
  browser_files = {},
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function M.initialize(settings)
  state.settings = settings

  -- Load UI preferences (global, not per-instance)
  state.current_bank = settings:get('current_bank', 0)
  state.hot_swap_enabled = settings:get('hot_swap_enabled', true)
  state.browser_path = settings:get('browser_path', reaper.GetResourcePath() .. '/Data')

  -- Initialize empty pad data
  for i = 0, Bridge.NUM_PADS - 1 do
    state.kit.pads[i] = M.createEmptyPad()
  end

  -- Find DrumBlocks on selected track (this will load per-instance state)
  M.refreshTrack()
end

function M.createEmptyPad()
  return {
    samples = {},      -- [layer] = file_path (primary sample per layer)
    round_robin = {    -- [layer] = { path1, path2, ... } (RR samples per layer)
      [0] = {}, [1] = {}, [2] = {}, [3] = {},
    },
    name = nil,        -- Display name (derived from sample)
    color = nil,       -- Custom UI color (0xRRGGBBAA) or nil for default
    volume = 0.8,
    pan = 0,
    tune = 0,
    filter_cutoff = 20000,
    filter_reso = 0,
    kill_group = 0,
    output_group = 0,
    playback_mode = 'oneshot',  -- 'oneshot', 'loop', 'pingpong'
    note_off_mode = 'ignore',   -- 'ignore', 'release', 'cut'
    reverse = false,
    start_point = 0,   -- Sample start (0-1 normalized)
    end_point = 1,     -- Sample end (0-1 normalized)
    -- Time-stretch settings (uses REAPER's élastique offline render)
    stretch_ratio = 1.0,    -- 1.0 = no change, 2.0 = twice as long, 0.5 = half
    pitch_preserve = true,  -- Preserve pitch when stretching
    -- Original sample path (before stretching) - nil if not stretched
    original_sample = nil,
    -- Freeform envelopes (array of {x, y} points, normalized 0-1)
    -- Volume: 0.5 = 0dB (unity), 0 = silence, 1 = +6dB
    volume_envelope = { { x = 0, y = 0.5 }, { x = 1, y = 0.5 } },
    filter_envelope = { { x = 0, y = 1 }, { x = 1, y = 1 } },
    pitch_envelope = { { x = 0, y = 0.5 }, { x = 1, y = 0.5 } },
    -- Velocity layer settings
    vel_crossfade = 0,   -- 0-1: blend zone width between velocity layers
    vel_curve = 0.5,     -- 0-1: soft/linear/hard velocity response
    rr_mode = 0,         -- 0=sequential, 1=random
  }
end

-- ============================================================================
-- INSTANCE IDENTIFICATION
-- ============================================================================

-- Generate unique instance ID from track GUID + FX GUID
local function getInstanceId(track, fx_index)
  if not track or not fx_index then return nil end

  local track_guid = reaper.GetTrackGUID(track)
  local fx_guid = reaper.TrackFX_GetFXGUID(track, fx_index)

  if track_guid and fx_guid then
    -- Use both GUIDs for unique identification
    return track_guid .. '_' .. fx_guid
  elseif track_guid then
    -- Fallback to track GUID + FX index
    return track_guid .. '_fx' .. fx_index
  end

  return nil
end

-- ============================================================================
-- TRACK MANAGEMENT
-- ============================================================================

function M.refreshTrack()
  local old_instance = state.instance_id

  -- Get new track/fx info
  local new_track = reaper.GetSelectedTrack(0, 0)
  local new_fx = nil
  if new_track then
    new_fx = Bridge.findDrumBlocks(new_track)
  end

  -- Get new instance ID
  local new_instance = getInstanceId(new_track, new_fx)

  -- Update state
  state.track = new_track
  state.fx_index = new_fx
  state.instance_id = new_instance

  -- Update waveform cache connection (no-op now, peaks computed locally)
  if new_track and new_fx then
    WaveformCache.setVST(new_track, new_fx)
  else
    WaveformCache.clearVST()
  end

  -- If instance changed, sync UI state from VST
  if new_instance ~= old_instance then
    -- Clear waveform cache for old instance (pad_to_file is global, not per-instance)
    WaveformCache.clearAll()

    if new_instance then
      -- VST has its own state - query it to populate Lua UI state
      -- Force sync since we cleared the cache
      M.syncFromVST(true)
    else
      -- No DrumBlocks found, reset to empty kit
      M.resetKit()
    end
  end
end

function M.getInstanceId()
  return state.instance_id
end

function M.getTrack()
  return state.track
end

function M.getFxIndex()
  return state.fx_index
end

function M.hasDrumBlocks()
  return state.track ~= nil and state.fx_index ~= nil
end

function M.insertDrumBlocks()
  if not state.track then
    state.track = reaper.GetSelectedTrack(0, 0)
  end
  if state.track then
    state.fx_index = Bridge.insertDrumBlocks(state.track)
    return state.fx_index ~= nil
  end
  return false
end


-- ============================================================================
-- PAD STATE
-- ============================================================================

function M.getCurrentBank()
  return state.current_bank
end

function M.setCurrentBank(bank)
  state.current_bank = math.max(0, math.min(M.NUM_BANKS - 1, bank))
  if state.settings then
    state.settings:set('current_bank', state.current_bank)
  end
end

function M.getSelectedPad()
  return state.selected_pad
end

function M.setSelectedPad(pad)
  state.selected_pad = pad
end

function M.getPadIndexForGrid(row, col)
  -- Convert grid position to absolute pad index
  local bank_offset = state.current_bank * M.PADS_PER_BANK
  local grid_index = row * M.GRID_COLS + col
  return bank_offset + grid_index
end

function M.getPadData(pad_index)
  return state.kit.pads[pad_index] or M.createEmptyPad()
end

function M.setPadSample(pad_index, layer, file_path)
  local pad = state.kit.pads[pad_index]
  if not pad then
    pad = M.createEmptyPad()
    state.kit.pads[pad_index] = pad
  end

  pad.samples[layer] = file_path

  -- Derive name from filename
  if file_path and file_path ~= '' then
    local name = file_path:match('([^/\\]+)$')  -- Get filename
    name = name:match('(.+)%.[^.]+$') or name   -- Remove extension
    pad.name = name
  else
    pad.name = nil
  end

  -- Send to VST
  if M.hasDrumBlocks() then
    Bridge.loadSample(state.track, state.fx_index, pad_index, layer, file_path or '')

    -- Extract waveform peaks from audio file
    if file_path and file_path ~= '' then
      WaveformCache.extractAndCache(pad_index, layer, file_path)
    else
      WaveformCache.clearPeaks(pad_index, layer)
    end
  end

end

function M.getPadSample(pad_index, layer)
  local pad = state.kit.pads[pad_index]
  if pad and pad.samples then
    return pad.samples[layer]
  end
  return nil
end

function M.hasSample(pad_index)
  local pad = state.kit.pads[pad_index]
  if pad and pad.samples then
    for _, sample in pairs(pad.samples) do
      if sample and sample ~= '' then
        return true
      end
    end
  end
  return false
end

-- Get waveform peaks for a pad/layer
-- tier: 'mini', 'low', 'medium', 'high', or 'full' (legacy alias for medium)
-- Returns best available, triggers async if requested tier not cached
function M.getPadPeaks(pad_index, layer, tier)
  layer = layer or 0
  tier = tier or 'mini'

  -- For mini, just return directly (always computed on load)
  if tier == 'mini' then
    return WaveformCache.getPeaks(pad_index, layer, 'mini')
  end

  -- For other tiers, use requestTier which handles async + fallback
  local filepath = WaveformCache.getFilepath(pad_index, layer)
  if not filepath then return nil end

  return WaveformCache.requestTier(filepath, tier)
end

-- Get peaks optimized for display width (auto-selects resolution tier)
-- Returns best available immediately, triggers async computation for better resolution
function M.getPadPeaksForDisplay(pad_index, layer, display_width, callback)
  layer = layer or 0
  display_width = display_width or 200
  return WaveformCache.getPeaksForDisplay(pad_index, layer, display_width, callback)
end

-- Get peaks for waveform editor with duration-based tier selection
-- visible_duration: seconds of audio currently visible
function M.getPadPeaksForEditor(pad_index, layer, visible_duration, callback)
  layer = layer or 0
  visible_duration = visible_duration or 1
  return WaveformCache.getPeaksForEditor(pad_index, layer, visible_duration, callback)
end

function M.hasPadPeaks(pad_index, layer)
  return WaveformCache.hasPeaks(pad_index, layer or 0)
end

-- Get sample duration in seconds
function M.getSampleDuration(pad_index, layer)
  return WaveformCache.getSampleDuration(pad_index, layer or 0)
end

-- Check if async computation is in progress
function M.isPeakProcessing()
  return WaveformCache.isProcessing()
end

-- ============================================================================
-- PAD PARAMETERS
-- ============================================================================

function M.setPadVolume(pad_index, value)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.volume = value
    if M.hasDrumBlocks() then
      Bridge.setVolume(state.track, state.fx_index, pad_index, value)
    end

  end
end

function M.setPadPan(pad_index, value)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.pan = value
    if M.hasDrumBlocks() then
      Bridge.setPan(state.track, state.fx_index, pad_index, value)
    end

  end
end

function M.setPadTune(pad_index, semitones)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.tune = semitones
    if M.hasDrumBlocks() then
      Bridge.setTune(state.track, state.fx_index, pad_index, semitones)
    end

  end
end

function M.setPadKillGroup(pad_index, group)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.kill_group = group
    if M.hasDrumBlocks() then
      Bridge.setKillGroup(state.track, state.fx_index, pad_index, group)
    end

  end
end

function M.setPadOutputGroup(pad_index, group)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.output_group = group
    if M.hasDrumBlocks() then
      Bridge.setOutputGroup(state.track, state.fx_index, pad_index, group)
    end

  end
end

-- Filter setters
function M.setPadFilterCutoff(pad_index, hz)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.filter_cutoff = hz
    if M.hasDrumBlocks() then
      Bridge.setFilterCutoff(state.track, state.fx_index, pad_index, hz)
    end

  end
end

function M.setPadFilterReso(pad_index, value)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.filter_reso = value
    if M.hasDrumBlocks() then
      Bridge.setFilterReso(state.track, state.fx_index, pad_index, value)
    end

  end
end

-- Playback mode / Reverse setters
function M.setPadPlaybackMode(pad_index, mode)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.playback_mode = mode
    if M.hasDrumBlocks() then
      Bridge.setPlaybackMode(state.track, state.fx_index, pad_index, mode)
    end
  end
end

function M.setPadReverse(pad_index, enabled)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.reverse = enabled
    if M.hasDrumBlocks() then
      Bridge.setReverse(state.track, state.fx_index, pad_index, enabled)
    end

  end
end

-- Start/End point setters
function M.setPadStartPoint(pad_index, value)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.start_point = math.max(0, math.min(value, pad.end_point - 0.01))
    if M.hasDrumBlocks() then
      Bridge.setSampleStart(state.track, state.fx_index, pad_index, pad.start_point)
    end
  end
end

function M.setPadEndPoint(pad_index, value)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.end_point = math.max(pad.start_point + 0.01, math.min(1, value))
    if M.hasDrumBlocks() then
      Bridge.setSampleEnd(state.track, state.fx_index, pad_index, pad.end_point)
    end
  end
end

-- Stretch ratio setter - uses REAPER glue to create stretched sample
-- This runs quickly via REAPER's optimized glue, result is cached
-- pitch_mode: one of Bridge.PitchMode values (default: ElastiquePro)
function M.setPadStretch(pad_index, ratio, preserve_pitch, pitch_mode)
  local pad = state.kit.pads[pad_index]
  if not pad then return false end

  -- Clamp ratio to reasonable range (0.25x to 4x)
  ratio = math.max(0.25, math.min(4.0, ratio))

  -- Get the original sample path (before any stretching)
  local source_path = pad.original_sample or pad.samples[0]
  if not source_path or source_path == '' then
    return false  -- No sample to stretch
  end

  -- Store original if not already stored
  if not pad.original_sample then
    pad.original_sample = source_path
  end

  -- Update local state
  pad.stretch_ratio = ratio
  pad.pitch_preserve = preserve_pitch
  pad.pitch_mode = pitch_mode

  -- If ratio is 1.0, restore original sample
  if math.abs(ratio - 1.0) < 0.01 then
    if pad.samples[0] ~= pad.original_sample then
      pad.samples[0] = pad.original_sample
      -- Derive name from original
      local name = pad.original_sample:match('([^/\\]+)$')
      pad.name = name and (name:match('(.+)%.[^.]+$') or name) or nil

      if M.hasDrumBlocks() then
        Bridge.loadSample(state.track, state.fx_index, pad_index, 0, pad.original_sample)
        WaveformCache.clearPeaks(pad_index, 0)
      end
    end
    return true
  end

  -- Stretch via REAPER glue (fast, cached)
  local stretched_path = Bridge.stretchSampleGlue(pad.original_sample, ratio, preserve_pitch, pitch_mode)

  if stretched_path then
    -- Update pad with stretched sample
    pad.samples[0] = stretched_path

    -- Update name to show stretch
    local orig_name = pad.original_sample:match('([^/\\]+)$')
    orig_name = orig_name and (orig_name:match('(.+)%.[^.]+$') or orig_name) or 'sample'
    pad.name = string.format('%s (x%.2f)', orig_name, ratio)

    -- Load stretched sample to VST
    if M.hasDrumBlocks() then
      Bridge.loadSample(state.track, state.fx_index, pad_index, 0, stretched_path)
      -- Clear peaks cache - they'll be fetched from VST on next access
      WaveformCache.clearPeaks(pad_index, 0)
    end

    return true
  end

  return false
end

-- Get stretch ratio for a pad
function M.getPadStretchRatio(pad_index)
  local pad = state.kit.pads[pad_index]
  return pad and pad.stretch_ratio or 1.0
end

-- Get pitch preserve setting for a pad
function M.getPadPitchPreserve(pad_index)
  local pad = state.kit.pads[pad_index]
  return pad and pad.pitch_preserve ~= false  -- Default true
end

-- Color getter/setter (for UI display, persisted in VST)
function M.getPadColor(pad_index)
  local pad = state.kit.pads[pad_index]
  return pad and pad.color
end

function M.setPadColor(pad_index, color)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.color = color
    if M.hasDrumBlocks() then
      Bridge.setPadColor(state.track, state.fx_index, pad_index, color)
    end
  end
end

-- ============================================================================
-- PAD COPY / SWAP
-- ============================================================================

-- Deep copy pad data (for internal use)
local function deepCopyPad(pad)
  if not pad then return M.createEmptyPad() end
  local copy = {}
  for k, v in pairs(pad) do
    if type(v) == 'table' then
      copy[k] = {}
      for k2, v2 in pairs(v) do
        copy[k][k2] = v2
      end
    else
      copy[k] = v
    end
  end
  return copy
end

-- Apply pad data to VST (sync all parameters)
local function syncPadToVST(pad_index)
  if not M.hasDrumBlocks() then return end
  local pad = state.kit.pads[pad_index]
  if not pad then return end

  local track, fx = state.track, state.fx_index

  -- Sync sample (layer 0)
  local sample = pad.samples and pad.samples[0]
  if sample and sample ~= '' then
    Bridge.loadSample(track, fx, pad_index, 0, sample)
    -- Clear peaks cache - they'll be fetched from VST on next access
    WaveformCache.clearPeaks(pad_index, 0)
  else
    Bridge.clearSample(track, fx, pad_index, 0)
    WaveformCache.clearPeaks(pad_index, 0)
  end

  -- Sync parameters
  Bridge.setVolume(track, fx, pad_index, pad.volume or 0.8)
  Bridge.setPan(track, fx, pad_index, pad.pan or 0)
  Bridge.setTune(track, fx, pad_index, pad.tune or 0)
  Bridge.setFilterCutoff(track, fx, pad_index, pad.filter_cutoff or 20000)
  Bridge.setFilterReso(track, fx, pad_index, pad.filter_reso or 0)
  Bridge.setKillGroup(track, fx, pad_index, pad.kill_group or 0)
  Bridge.setOutputGroup(track, fx, pad_index, pad.output_group or 0)
  Bridge.setPlaybackMode(track, fx, pad_index, pad.playback_mode or 'oneshot')
  Bridge.setReverse(track, fx, pad_index, pad.reverse or false)
  Bridge.setSampleStart(track, fx, pad_index, pad.start_point or 0)
  Bridge.setSampleEnd(track, fx, pad_index, pad.end_point or 1)
  Bridge.setPadColor(track, fx, pad_index, pad.color)
end

--- Copy pad from one index to another (overwrites target)
--- @param from_index number Source pad index
--- @param to_index number Target pad index
function M.copyPad(from_index, to_index)
  if from_index == to_index then return end

  local source = state.kit.pads[from_index]
  state.kit.pads[to_index] = deepCopyPad(source)

  -- Sync target to VST
  syncPadToVST(to_index)
end

--- Swap data between two pads
--- @param index_a number First pad index
--- @param index_b number Second pad index
function M.swapPads(index_a, index_b)
  if index_a == index_b then return end

  local pad_a = deepCopyPad(state.kit.pads[index_a])
  local pad_b = deepCopyPad(state.kit.pads[index_b])

  state.kit.pads[index_a] = pad_b
  state.kit.pads[index_b] = pad_a

  -- Sync both to VST
  syncPadToVST(index_a)
  syncPadToVST(index_b)
end

--- Clear a pad (reset to empty)
--- @param pad_index number Pad index to clear
function M.clearPad(pad_index)
  state.kit.pads[pad_index] = M.createEmptyPad()

  if M.hasDrumBlocks() then
    Bridge.clearSample(state.track, state.fx_index, pad_index, 0)
    WaveformCache.clearPeaks(pad_index, 0)
  end
end

-- ============================================================================
-- HOT-SWAP
-- ============================================================================

function M.isHotSwapEnabled()
  return state.hot_swap_enabled
end

function M.setHotSwapEnabled(enabled)
  state.hot_swap_enabled = enabled
  if state.settings then
    state.settings:set('hot_swap_enabled', enabled)
  end
end

function M.beginHotSwap(pad_index)
  if state.selected_pad then
    state.hot_swap_original = M.getPadSample(pad_index, 0)
  end
end

function M.previewSample(file_path)
  if not state.hot_swap_enabled or not state.selected_pad then return end

  -- Load sample temporarily
  M.setPadSample(state.selected_pad, 0, file_path)
end

function M.confirmHotSwap()
  state.hot_swap_original = nil
end

function M.cancelHotSwap()
  if state.hot_swap_original and state.selected_pad then
    M.setPadSample(state.selected_pad, 0, state.hot_swap_original)
  end
  state.hot_swap_original = nil
end

-- ============================================================================
-- BROWSER
-- ============================================================================

function M.getBrowserPath()
  return state.browser_path
end

function M.setBrowserPath(path)
  state.browser_path = path
  if state.settings then
    state.settings:set('browser_path', path)
  end
  M.scanBrowserPath()
end

function M.scanBrowserPath()
  state.browser_files = {}
  local path = state.browser_path
  if not path then return end

  local i = 0
  repeat
    local file = reaper.EnumerateFiles(path, i)
    if file then
      local ext = file:match('%.([^.]+)$')
      if ext then
        ext = ext:lower()
        if ext == 'wav' or ext == 'mp3' or ext == 'ogg' or ext == 'flac' or ext == 'aif' or ext == 'aiff' then
          table.insert(state.browser_files, {
            name = file,
            path = path .. '/' .. file,
          })
        end
      end
    end
    i = i + 1
  until not file

  -- Sort alphabetically
  table.sort(state.browser_files, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
end

function M.getBrowserFiles()
  return state.browser_files
end

function M.navigateBrowserUp()
  local path = state.browser_path
  if path then
    local parent = path:match('(.+)[/\\][^/\\]+$')
    if parent and parent ~= '' then
      M.setBrowserPath(parent)
    end
  end
end

-- ============================================================================
-- KIT MANAGEMENT
-- ============================================================================

function M.getKitName()
  return state.kit.name
end

function M.setKitName(name)
  state.kit.name = name

end

function M.newKit()
  state.kit.name = 'Untitled Kit'
  for i = 0, Bridge.NUM_PADS - 1 do
    state.kit.pads[i] = M.createEmptyPad()
  end
  -- Clear VST
  if M.hasDrumBlocks() then
    for i = 0, Bridge.NUM_PADS - 1 do
      for layer = 0, Bridge.NUM_VELOCITY_LAYERS - 1 do
        Bridge.clearSample(state.track, state.fx_index, i, layer)
      end
    end
  end
end

function M.getKitData()
  return state.kit
end

function M.loadKitData(kit_data)
  state.kit = kit_data
  -- Sync to VST
  if M.hasDrumBlocks() then
    Bridge.loadKit(state.track, state.fx_index, kit_data)
  end
end

-- ============================================================================
-- SYNC FROM VST (VST is source of truth)
-- ============================================================================

-- Reset kit to empty state
function M.resetKit()
  state.kit.name = 'Untitled Kit'
  for i = 0, Bridge.NUM_PADS - 1 do
    state.kit.pads[i] = M.createEmptyPad()
  end
  WaveformCache.clearAll()
end

-- Queue for lazy waveform extraction (one per frame to avoid UI freeze)
local waveform_queue = {}

-- Track which instances we've already synced (avoid redundant syncs)
local synced_instances = {}

-- Pending sync state for incremental loading
local pending_sync = nil

-- Sync Lua UI state FROM VST
-- VST handles its own persistence - we just query it to populate UI
function M.syncFromVST(force)
  if not M.hasDrumBlocks() then return end

  -- Skip if we've already synced this instance (unless forced)
  local instance_id = state.instance_id
  if not force and instance_id and synced_instances[instance_id] then
    return
  end

  -- Reset local state first
  M.resetKit()
  waveform_queue = {}  -- Clear pending extractions

  local track = state.track
  local fx = state.fx_index
  local found_samples = 0

  -- Get ALL sample paths at once (avoids 512 redundant chunk parses)
  local all_samples = Bridge.getAllSamplePaths(track, fx)

  -- Apply sample paths to pads
  if all_samples then
    for key, sample_path in pairs(all_samples) do
      local pad_idx, layer_idx = key:match('(%d+)_(%d+)')
      pad_idx = tonumber(pad_idx)
      layer_idx = tonumber(layer_idx)

      if pad_idx and layer_idx and state.kit.pads[pad_idx] then
        local pad = state.kit.pads[pad_idx]
        found_samples = found_samples + 1
        pad.samples[layer_idx] = sample_path

        -- Derive name from filename
        local name = sample_path:match('([^/\\]+)$')
        name = name and (name:match('(.+)%.[^.]+$') or name) or ''
        if layer_idx == 0 then
          pad.name = name
        end

        -- Queue waveform extraction (deferred, one per frame)
        table.insert(waveform_queue, { pad = pad_idx, layer = layer_idx, path = sample_path })
      end
    end
  end

  -- Query parameters and colors from VST
  for i = 0, Bridge.NUM_PADS - 1 do
    local pad = state.kit.pads[i]

    -- Always sync color (even for empty pads)
    pad.color = Bridge.getPadColor(track, fx, i)

    -- Only query other parameters for pads that have samples (optimization)
    if pad.samples[0] then
      pad.volume = Bridge.getVolume(track, fx, i) or 0.8
      pad.pan = Bridge.getPan(track, fx, i) or 0
      pad.tune = Bridge.getTune(track, fx, i) or 0
      pad.filter_cutoff = Bridge.getFilterCutoff(track, fx, i) or 20000
      pad.filter_reso = Bridge.getFilterReso(track, fx, i) or 0
      pad.kill_group = Bridge.getKillGroup(track, fx, i) or 0
      pad.output_group = Bridge.getOutputGroup(track, fx, i) or 0
      pad.playback_mode = Bridge.getPlaybackMode(track, fx, i)
      pad.note_off_mode = Bridge.getNoteOffModeString(track, fx, i) or 'ignore'
      pad.reverse = Bridge.getReverse(track, fx, i)
      pad.start_point = Bridge.getSampleStart(track, fx, i) or 0
      pad.end_point = Bridge.getSampleEnd(track, fx, i) or 1
      -- Note: Envelopes are UI-only for now (not stored in VST)
    end
  end

  -- Mark this instance as synced
  if instance_id then
    synced_instances[instance_id] = true
  end
end

-- Force a re-sync (e.g., after loading a new sample)
function M.invalidateSync()
  if state.instance_id then
    synced_instances[state.instance_id] = nil
  end
end

-- Process one queued waveform extraction per frame (call from GUI loop)
function M.processWaveformQueue()
  if #waveform_queue == 0 then return false end

  local item = table.remove(waveform_queue, 1)
  -- Extract peaks from audio file (local computation using REAPER's PCM_Source_GetPeaks)
  if item.path and item.path ~= '' then
    WaveformCache.extractAndCache(item.pad, item.layer, item.path)
  end
  return #waveform_queue > 0  -- Returns true if more items pending
end

-- Check if waveform extraction is pending
function M.hasWaveformsPending()
  return #waveform_queue > 0
end

-- Save UI preferences (called on close)
-- Note: VST handles its own kit persistence - we only save UI prefs
function M.save()
  if state.settings and state.settings.flush then
    state.settings:flush()
  end
end

-- ============================================================================
-- PLAYBACK STATE (for playback cursor display)
-- ============================================================================

-- Check if a specific pad is playing
function M.isPadPlaying(pad_index)
  if not M.hasDrumBlocks() then return false end
  return Bridge.isPadPlaying(state.track, state.fx_index, pad_index)
end

-- Get playback progress for a specific pad (0-1 within start/end region)
function M.getPadPlayProgress(pad_index)
  if not M.hasDrumBlocks() then return nil end
  return Bridge.getPadPlayProgress(state.track, state.fx_index, pad_index)
end

-- Get playback state for all pads in current bank
-- Returns: table { [pad_index] = progress } for playing pads
function M.getBankPlaybackState()
  if not M.hasDrumBlocks() then return {} end

  local playing = {}
  local bank_start = state.current_bank * 16
  local bank_end = bank_start + 15

  for pad = bank_start, bank_end do
    if Bridge.isPadPlaying(state.track, state.fx_index, pad) then
      playing[pad] = Bridge.getPadPlayProgress(state.track, state.fx_index, pad) or 0
    end
  end
  return playing
end

-- Get playback state for all pads (for bank overview)
-- Returns: table { [pad_index] = progress } for all playing pads
function M.getAllPlaybackState()
  if not M.hasDrumBlocks() then return {} end
  return Bridge.getPlaybackState(state.track, state.fx_index)
end

-- ============================================================================
-- VELOCITY PANEL STATE
-- ============================================================================

local velocity_panel_state = {
  expanded = false,
  visible_columns = 4,
  selected_sample = nil,  -- {layer, rr_index} or nil
}

function M.getVelocityPanelState()
  return velocity_panel_state
end

function M.setVelocityPanelExpanded(expanded)
  velocity_panel_state.expanded = expanded
end

function M.setVelocityVisibleColumns(cols)
  velocity_panel_state.visible_columns = math.max(1, math.min(4, cols))
end

-- ============================================================================
-- VELOCITY / ROUND-ROBIN HELPERS
-- ============================================================================

-- Add round-robin sample to a pad layer
function M.addRoundRobinSample(pad_index, layer, file_path)
  local pad = state.kit.pads[pad_index]
  if not pad then return false end

  -- Initialize round_robin table if needed
  if not pad.round_robin then
    pad.round_robin = { [0] = {}, [1] = {}, [2] = {}, [3] = {} }
  end
  if not pad.round_robin[layer] then
    pad.round_robin[layer] = {}
  end

  -- Add to local state
  table.insert(pad.round_robin[layer], file_path)

  -- Send to VST
  if M.hasDrumBlocks() then
    Bridge.addRoundRobin(state.track, state.fx_index, pad_index, layer, file_path)
  end
  return true
end

-- Clear all round-robin samples from a layer (keeps primary)
function M.clearRoundRobinLayer(pad_index, layer)
  local pad = state.kit.pads[pad_index]
  if not pad then return end

  if pad.round_robin and pad.round_robin[layer] then
    pad.round_robin[layer] = {}
  end

  if M.hasDrumBlocks() then
    Bridge.clearRoundRobin(state.track, state.fx_index, pad_index, layer)
  end
end

-- Get round-robin count for a layer
function M.getRoundRobinCount(pad_index, layer)
  local pad = state.kit.pads[pad_index]
  if pad and pad.round_robin and pad.round_robin[layer] then
    return #pad.round_robin[layer]
  end
  return 0
end

-- Set velocity crossfade for a pad
function M.setPadVelCrossfade(pad_index, value)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.vel_crossfade = value
    if M.hasDrumBlocks() then
      Bridge.setVelCrossfade(state.track, state.fx_index, pad_index, value)
    end
  end
end

-- Set velocity curve for a pad
function M.setPadVelCurve(pad_index, value)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.vel_curve = value
    if M.hasDrumBlocks() then
      Bridge.setVelCurve(state.track, state.fx_index, pad_index, value)
    end
  end
end

-- Set round-robin mode for a pad
function M.setPadRoundRobinMode(pad_index, mode)
  local pad = state.kit.pads[pad_index]
  if pad then
    pad.rr_mode = mode
    if M.hasDrumBlocks() then
      Bridge.setRoundRobinMode(state.track, state.fx_index, pad_index, mode)
    end
  end
end

-- Check if pad has samples in multiple velocity layers
function M.hasMultiLayerSamples(pad_index)
  local pad = state.kit.pads[pad_index]
  if not pad or not pad.samples then return false end

  local layer_count = 0
  for layer = 0, 3 do
    if pad.samples[layer] and pad.samples[layer] ~= '' then
      layer_count = layer_count + 1
    end
  end
  return layer_count > 1
end

return M
