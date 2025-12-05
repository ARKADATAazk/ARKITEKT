-- @noindex
-- DrumBlocks/domain/bridge.lua
-- Communication bridge to BlockSampler VST

local M = {}

-- BlockSampler constants (must match VST)
M.NUM_PADS = 128
M.NUM_VELOCITY_LAYERS = 4
M.NUM_OUTPUT_GROUPS = 16
M.PARAMS_PER_PAD = 13

-- Parameter indices (must match BlockSampler/Source/Parameters.h)
M.Param = {
  Volume = 0,
  Pan = 1,
  Tune = 2,
  Attack = 3,
  Decay = 4,
  Sustain = 5,
  Release = 6,
  FilterCutoff = 7,
  FilterReso = 8,
  KillGroup = 9,
  OutputGroup = 10,
  OneShot = 11,
  Reverse = 12,
}

-- ============================================================================
-- VST DETECTION
-- ============================================================================

function M.findBlockSampler(track)
  if not track then return nil end
  local fx_count = reaper.TrackFX_GetCount(track)
  for i = 0, fx_count - 1 do
    local _, name = reaper.TrackFX_GetFXName(track, i, '')
    if name:match('BlockSampler') then
      return i
    end
  end
  return nil
end

function M.insertBlockSampler(track)
  if not track then return nil end
  local fx_index = reaper.TrackFX_AddByName(track, 'BlockSampler', false, -1)
  if fx_index >= 0 then
    return fx_index
  end
  return nil
end

function M.getOrCreateBlockSampler(track)
  local fx = M.findBlockSampler(track)
  if fx then return fx end
  return M.insertBlockSampler(track)
end

-- ============================================================================
-- PARAMETER ACCESS
-- ============================================================================

local function getParamIndex(pad, param)
  return pad * M.PARAMS_PER_PAD + param
end

function M.setParam(track, fx, pad, param, value)
  if not track or not fx or fx < 0 then return false end
  local idx = getParamIndex(pad, param)
  return reaper.TrackFX_SetParam(track, fx, idx, value)
end

function M.getParam(track, fx, pad, param)
  if not track or not fx or fx < 0 then return 0 end
  local idx = getParamIndex(pad, param)
  local value, _, _ = reaper.TrackFX_GetParam(track, fx, idx)
  return value
end

-- Convenience functions
function M.setVolume(track, fx, pad, value)
  return M.setParam(track, fx, pad, M.Param.Volume, value)
end

function M.setPan(track, fx, pad, value)
  -- Pan is -1 to +1, normalize to 0-1 for VST
  return M.setParam(track, fx, pad, M.Param.Pan, (value + 1) / 2)
end

function M.setTune(track, fx, pad, semitones)
  -- Tune is -24 to +24, normalize to 0-1
  return M.setParam(track, fx, pad, M.Param.Tune, (semitones + 24) / 48)
end

function M.setAttack(track, fx, pad, ms)
  -- Attack is 0-2000ms, normalize to 0-1
  return M.setParam(track, fx, pad, M.Param.Attack, ms / 2000)
end

function M.setDecay(track, fx, pad, ms)
  return M.setParam(track, fx, pad, M.Param.Decay, ms / 2000)
end

function M.setSustain(track, fx, pad, value)
  return M.setParam(track, fx, pad, M.Param.Sustain, value)
end

function M.setRelease(track, fx, pad, ms)
  -- Release is 0-5000ms
  return M.setParam(track, fx, pad, M.Param.Release, ms / 5000)
end

function M.setFilterCutoff(track, fx, pad, hz)
  -- Cutoff is 20-20000Hz, log scale approximation
  local normalized = math.log(hz / 20) / math.log(1000)
  return M.setParam(track, fx, pad, M.Param.FilterCutoff, math.min(1, math.max(0, normalized)))
end

function M.setFilterReso(track, fx, pad, value)
  return M.setParam(track, fx, pad, M.Param.FilterReso, value)
end

function M.setKillGroup(track, fx, pad, group)
  -- Group is 0-8
  return M.setParam(track, fx, pad, M.Param.KillGroup, group / 8)
end

function M.setOutputGroup(track, fx, pad, group)
  -- Group is 0-16
  return M.setParam(track, fx, pad, M.Param.OutputGroup, group / 16)
end

function M.setOneShot(track, fx, pad, enabled)
  return M.setParam(track, fx, pad, M.Param.OneShot, enabled and 1 or 0)
end

function M.setReverse(track, fx, pad, enabled)
  return M.setParam(track, fx, pad, M.Param.Reverse, enabled and 1 or 0)
end

-- ============================================================================
-- SAMPLE LOADING (via chunk modification)
-- ============================================================================

-- XML parsing helpers
local function parseXmlTag(xml, tag)
  local pattern = '<' .. tag .. '[^>]*>(.-)</' .. tag .. '>'
  return xml:match(pattern)
end

local function xmlEscape(str)
  return str:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'):gsub('"', '&quot;')
end

-- Get VST chunk as XML string
local function getVstChunk(track, fx)
  local retval, chunk = reaper.TrackFX_GetFXChunk(track, fx)
  if not retval or not chunk then return nil end
  return chunk
end

-- Set VST chunk from XML string
local function setVstChunk(track, fx, chunk)
  return reaper.TrackFX_SetFXChunk(track, fx, chunk, false)
end

-- Load sample by modifying VST chunk with a Commands node
function M.loadSample(track, fx, pad, layer, file_path)
  if not track or not fx or fx < 0 then return false end

  -- Try TrackFX_SetNamedConfigParm first (simpler if supported)
  local param_name = string.format('P%d_L%d_SAMPLE', pad, layer)
  local result = reaper.TrackFX_SetNamedConfigParm(track, fx, param_name, file_path)
  if result then return true end

  -- Fallback: chunk modification
  local chunk = getVstChunk(track, fx)
  if not chunk then return false end

  -- Build command XML
  local cmd_xml = string.format(
    '<LoadSample pad="%d" layer="%d" path="%s"/>',
    pad, layer, xmlEscape(file_path)
  )

  -- Insert Commands node into chunk
  -- Look for </BlockSamplerParams> or similar closing tag
  local insert_pos = chunk:find('</BlockSamplerParams>')
  if insert_pos then
    local commands_section = '<Commands>' .. cmd_xml .. '</Commands>\n'
    chunk = chunk:sub(1, insert_pos - 1) .. commands_section .. chunk:sub(insert_pos)
    return setVstChunk(track, fx, chunk)
  end

  return false
end

function M.clearSample(track, fx, pad, layer)
  return M.loadSample(track, fx, pad, layer, '')
end

-- Clear all samples from a pad
function M.clearPad(track, fx, pad)
  if not track or not fx or fx < 0 then return false end

  local chunk = getVstChunk(track, fx)
  if not chunk then return false end

  local cmd_xml = string.format('<ClearPad pad="%d"/>', pad)
  local insert_pos = chunk:find('</BlockSamplerParams>')
  if insert_pos then
    local commands_section = '<Commands>' .. cmd_xml .. '</Commands>\n'
    chunk = chunk:sub(1, insert_pos - 1) .. commands_section .. chunk:sub(insert_pos)
    return setVstChunk(track, fx, chunk)
  end

  return false
end

-- Get sample path from VST state
function M.getSamplePath(track, fx, pad, layer)
  if not track or not fx or fx < 0 then return nil end

  -- Try named config param first
  local param_name = string.format('P%d_L%d_SAMPLE', pad, layer)
  local retval, value = reaper.TrackFX_GetNamedConfigParm(track, fx, param_name)
  if retval and value ~= '' then
    return value
  end

  -- Fallback: parse from chunk
  local chunk = getVstChunk(track, fx)
  if not chunk then return nil end

  -- Look for Sample node with matching pad and layer
  local pattern = '<Sample pad="' .. pad .. '" layer="' .. layer .. '" path="([^"]*)"'
  local path = chunk:match(pattern)
  return path
end

-- Check if pad has any sample loaded
function M.hasSample(track, fx, pad)
  if not track or not fx or fx < 0 then return false end

  -- Try named config param first
  local param_name = string.format('P%d_HAS_SAMPLE', pad)
  local retval, value = reaper.TrackFX_GetNamedConfigParm(track, fx, param_name)
  if retval then
    return value == '1'
  end

  -- Fallback: check each layer
  for layer = 0, M.NUM_VELOCITY_LAYERS - 1 do
    local path = M.getSamplePath(track, fx, pad, layer)
    if path and path ~= '' then
      return true
    end
  end

  return false
end

-- ============================================================================
-- BULK OPERATIONS
-- ============================================================================

function M.loadKit(track, fx, kit_data)
  if not track or not fx or fx < 0 then return false end

  for pad_idx, pad_data in pairs(kit_data.pads or {}) do
    -- Load samples
    for layer_idx, sample_path in pairs(pad_data.samples or {}) do
      M.loadSample(track, fx, pad_idx, layer_idx, sample_path)
    end

    -- Set parameters
    if pad_data.volume then M.setVolume(track, fx, pad_idx, pad_data.volume) end
    if pad_data.pan then M.setPan(track, fx, pad_idx, pad_data.pan) end
    if pad_data.tune then M.setTune(track, fx, pad_idx, pad_data.tune) end
    if pad_data.attack then M.setAttack(track, fx, pad_idx, pad_data.attack) end
    if pad_data.decay then M.setDecay(track, fx, pad_idx, pad_data.decay) end
    if pad_data.sustain then M.setSustain(track, fx, pad_idx, pad_data.sustain) end
    if pad_data.release then M.setRelease(track, fx, pad_idx, pad_data.release) end
    if pad_data.kill_group then M.setKillGroup(track, fx, pad_idx, pad_data.kill_group) end
    if pad_data.output_group then M.setOutputGroup(track, fx, pad_idx, pad_data.output_group) end
    if pad_data.one_shot ~= nil then M.setOneShot(track, fx, pad_idx, pad_data.one_shot) end
    if pad_data.reverse ~= nil then M.setReverse(track, fx, pad_idx, pad_data.reverse) end
  end

  return true
end

-- ============================================================================
-- MIDI PREVIEW
-- ============================================================================

function M.triggerPad(pad, velocity)
  velocity = velocity or 100
  -- Send MIDI note to trigger pad (pad index = MIDI note)
  reaper.StuffMIDIMessage(0, 0x90, pad, velocity)  -- Note on
  -- Note off after short delay handled by one-shot mode
end

return M
