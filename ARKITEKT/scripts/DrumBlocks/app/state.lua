-- @noindex
-- DrumBlocks/app/state.lua
-- State management for DrumBlocks

local Bridge = require('DrumBlocks.domain.bridge')

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

  -- Load UI preferences
  state.current_bank = settings:get('current_bank', 0)
  state.hot_swap_enabled = settings:get('hot_swap_enabled', true)
  state.browser_path = settings:get('browser_path', reaper.GetResourcePath() .. '/Data')

  -- Initialize empty pad data
  for i = 0, Bridge.NUM_PADS - 1 do
    state.kit.pads[i] = M.createEmptyPad()
  end

  -- Try to find DrumBlocks on selected track
  M.refreshTrack()
end

function M.createEmptyPad()
  return {
    samples = {},      -- [layer] = file_path
    name = nil,        -- Display name (derived from sample)
    volume = 0.8,
    pan = 0,
    tune = 0,
    attack = 0,
    decay = 100,
    sustain = 1,
    release = 200,
    filter_cutoff = 20000,
    filter_reso = 0,
    kill_group = 0,
    output_group = 0,
    one_shot = true,
    reverse = false,
  }
end

-- ============================================================================
-- TRACK MANAGEMENT
-- ============================================================================

function M.refreshTrack()
  state.track = reaper.GetSelectedTrack(0, 0)
  if state.track then
    state.fx_index = Bridge.findDrumBlocks(state.track)
  else
    state.fx_index = nil
  end
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
-- PERSISTENCE
-- ============================================================================

function M.save()
  if state.settings and state.settings.flush then
    state.settings:flush()
  end
end

return M
