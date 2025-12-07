-- @noindex
-- DrumBlocks/domain/bridge.lua
-- Communication bridge to BlockSampler VST

local M = {}

-- BlockSampler constants (must match VST)
M.NUM_PADS = 128
M.NUM_VELOCITY_LAYERS = 4
M.NUM_OUTPUT_GROUPS = 16
M.PARAMS_PER_PAD = 22  -- Updated: was 18, now 22 with pitch envelope

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
  FilterType = 9,       -- 0=LP, 1=HP
  KillGroup = 10,
  OutputGroup = 11,
  LoopMode = 12,        -- 0=OneShot, 1=Loop, 2=PingPong (replaces OneShot)
  Reverse = 13,
  Normalize = 14,       -- Peak normalization
  SampleStart = 15,
  SampleEnd = 16,
  RoundRobinMode = 17,  -- 0=sequential, 1=random
  PitchEnvAmount = 18,  -- -24 to +24 semitones (pitch envelope depth)
  PitchEnvAttack = 19,  -- 0-100 ms (pitch envelope attack)
  PitchEnvDecay = 20,   -- 0-2000 ms (pitch envelope decay)
  PitchEnvSustain = 21, -- 0-1 (pitch envelope sustain level)
}

-- Loop mode constants
M.LoopMode = {
  OneShot = 0,
  Loop = 1,
  PingPong = 2,
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

function M.setFilterType(track, fx, pad, filter_type)
  -- 0 = lowpass, 1 = highpass
  return M.setParam(track, fx, pad, M.Param.FilterType, filter_type)
end

function M.setFilterLP(track, fx, pad)
  return M.setFilterType(track, fx, pad, 0)
end

function M.setFilterHP(track, fx, pad)
  return M.setFilterType(track, fx, pad, 1)
end

function M.setKillGroup(track, fx, pad, group)
  -- Group is 0-8
  return M.setParam(track, fx, pad, M.Param.KillGroup, group / 8)
end

function M.setOutputGroup(track, fx, pad, group)
  -- Group is 0-16
  return M.setParam(track, fx, pad, M.Param.OutputGroup, group / 16)
end

function M.setLoopMode(track, fx, pad, mode)
  -- Mode: 0=OneShot, 1=Loop, 2=PingPong
  return M.setParam(track, fx, pad, M.Param.LoopMode, mode / 2)
end

function M.setOneShot(track, fx, pad, enabled)
  -- Legacy compatibility: maps to LoopMode.OneShot or LoopMode.Loop
  return M.setLoopMode(track, fx, pad, enabled and M.LoopMode.OneShot or M.LoopMode.Loop)
end

function M.setReverse(track, fx, pad, enabled)
  return M.setParam(track, fx, pad, M.Param.Reverse, enabled and 1 or 0)
end

function M.setNormalize(track, fx, pad, enabled)
  -- Enable/disable peak normalization
  return M.setParam(track, fx, pad, M.Param.Normalize, enabled and 1 or 0)
end

function M.setSampleStart(track, fx, pad, normalized)
  -- Start is 0-1 normalized position
  return M.setParam(track, fx, pad, M.Param.SampleStart, math.min(1, math.max(0, normalized)))
end

function M.setSampleEnd(track, fx, pad, normalized)
  -- End is 0-1 normalized position
  return M.setParam(track, fx, pad, M.Param.SampleEnd, math.min(1, math.max(0, normalized)))
end

function M.setSampleRange(track, fx, pad, start_pos, end_pos)
  M.setSampleStart(track, fx, pad, start_pos)
  M.setSampleEnd(track, fx, pad, end_pos)
end

function M.setRoundRobinMode(track, fx, pad, mode)
  -- 0 = sequential, 1 = random
  return M.setParam(track, fx, pad, M.Param.RoundRobinMode, mode)
end

function M.setRoundRobinSequential(track, fx, pad)
  return M.setRoundRobinMode(track, fx, pad, 0)
end

function M.setRoundRobinRandom(track, fx, pad)
  return M.setRoundRobinMode(track, fx, pad, 1)
end

-- ============================================================================
-- PITCH ENVELOPE (for 808-style pitch drops)
-- ============================================================================

function M.setPitchEnvAmount(track, fx, pad, semitones)
  -- Amount is -24 to +24 semitones, normalize to 0-1
  -- Negative values = pitch drop (classic 808 kick), positive = pitch rise
  return M.setParam(track, fx, pad, M.Param.PitchEnvAmount, (semitones + 24) / 48)
end

function M.setPitchEnvAttack(track, fx, pad, ms)
  -- Attack is 0-100ms, normalize to 0-1
  return M.setParam(track, fx, pad, M.Param.PitchEnvAttack, ms / 100)
end

function M.setPitchEnvDecay(track, fx, pad, ms)
  -- Decay is 0-2000ms, normalize to 0-1
  return M.setParam(track, fx, pad, M.Param.PitchEnvDecay, ms / 2000)
end

function M.setPitchEnvSustain(track, fx, pad, value)
  -- Sustain is 0-1 (0 = full sweep to base pitch, 1 = no sweep)
  return M.setParam(track, fx, pad, M.Param.PitchEnvSustain, value)
end

-- Configure complete pitch envelope with one call
-- Classic 808 kick: amount=-12 to -24, attack=0, decay=50-200, sustain=0
function M.setPitchEnvelope(track, fx, pad, amount, attack, decay, sustain)
  M.setPitchEnvAmount(track, fx, pad, amount or 0)
  M.setPitchEnvAttack(track, fx, pad, attack or 0)
  M.setPitchEnvDecay(track, fx, pad, decay or 50)
  M.setPitchEnvSustain(track, fx, pad, sustain or 0)
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
-- Note: For async loading, use loadSampleAsync() if supported
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

-- Async sample loading (non-blocking, loads in background thread)
-- Returns immediately; sample becomes available after loading completes
function M.loadSampleAsync(track, fx, pad, layer, file_path)
  if not track or not fx or fx < 0 then return false end

  -- Use ASYNC suffix for named config param to trigger async loading
  local param_name = string.format('P%d_L%d_SAMPLE_ASYNC', pad, layer)
  local result = reaper.TrackFX_SetNamedConfigParm(track, fx, param_name, file_path)
  if result then return true end

  -- Fallback to sync load if async not supported
  return M.loadSample(track, fx, pad, layer, file_path)
end

-- Add round-robin sample to a pad/layer (async)
function M.addRoundRobin(track, fx, pad, layer, file_path)
  if not track or not fx or fx < 0 then return false end

  local param_name = string.format('P%d_L%d_RR_ASYNC', pad, layer)
  local result = reaper.TrackFX_SetNamedConfigParm(track, fx, param_name, file_path)
  return result or false
end

-- Clear round-robin samples from a layer (keeps primary sample)
function M.clearRoundRobin(track, fx, pad, layer)
  if not track or not fx or fx < 0 then return false end
  layer = layer or 0

  local param_name = string.format('P%d_L%d_CLEAR_RR', pad, layer)
  local result = reaper.TrackFX_SetNamedConfigParm(track, fx, param_name, '')
  return result or false
end

-- Get round-robin sample count for a layer
function M.getRoundRobinCount(track, fx, pad, layer)
  if not track or not fx or fx < 0 then return 0 end
  layer = layer or 0

  local param_name = string.format('P%d_L%d_RR_COUNT', pad, layer)
  local retval, value = reaper.TrackFX_GetNamedConfigParm(track, fx, param_name)
  if retval then
    return tonumber(value) or 0
  end
  return 0
end

-- Get sample duration in seconds
function M.getSampleDuration(track, fx, pad, layer)
  if not track or not fx or fx < 0 then return 0 end
  layer = layer or 0

  local param_name = string.format('P%d_L%d_DURATION', pad, layer)
  local retval, value = reaper.TrackFX_GetNamedConfigParm(track, fx, param_name)
  if retval then
    return tonumber(value) or 0
  end
  return 0
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

    -- Loop mode (new) or legacy one_shot
    if pad_data.loop_mode ~= nil then
      M.setLoopMode(track, fx, pad_idx, pad_data.loop_mode)
    elseif pad_data.one_shot ~= nil then
      M.setOneShot(track, fx, pad_idx, pad_data.one_shot)
    end

    if pad_data.reverse ~= nil then M.setReverse(track, fx, pad_idx, pad_data.reverse) end

    -- Pitch envelope (for 808-style sounds)
    if pad_data.pitch_env_amount then M.setPitchEnvAmount(track, fx, pad_idx, pad_data.pitch_env_amount) end
    if pad_data.pitch_env_attack then M.setPitchEnvAttack(track, fx, pad_idx, pad_data.pitch_env_attack) end
    if pad_data.pitch_env_decay then M.setPitchEnvDecay(track, fx, pad_idx, pad_data.pitch_env_decay) end
    if pad_data.pitch_env_sustain then M.setPitchEnvSustain(track, fx, pad_idx, pad_data.pitch_env_sustain) end
  end

  return true
end

-- ============================================================================
-- PREVIEW / PLAYBACK CONTROL
-- ============================================================================

-- Preview pad via named config param (doesn't require MIDI routing)
function M.previewPad(track, fx, pad, velocity)
  if not track or not fx or fx < 0 then return false end
  velocity = velocity or 100
  local param_name = string.format('P%d_PREVIEW', pad)
  return reaper.TrackFX_SetNamedConfigParm(track, fx, param_name, tostring(velocity))
end

-- Stop pad playback
function M.stopPad(track, fx, pad)
  if not track or not fx or fx < 0 then return false end
  local param_name = string.format('P%d_STOP', pad)
  return reaper.TrackFX_SetNamedConfigParm(track, fx, param_name, '')
end

-- Stop all pads
function M.stopAll(track, fx)
  if not track or not fx or fx < 0 then return false end
  return reaper.TrackFX_SetNamedConfigParm(track, fx, 'STOP_ALL', '')
end

-- Check if pad is currently playing
function M.isPlaying(track, fx, pad)
  if not track or not fx or fx < 0 then return false end
  local param_name = string.format('P%d_IS_PLAYING', pad)
  local retval, value = reaper.TrackFX_GetNamedConfigParm(track, fx, param_name)
  return retval and value == '1'
end

-- Legacy MIDI preview (requires MIDI routing to track)
function M.triggerPad(pad, velocity)
  velocity = velocity or 100
  -- Send MIDI note to trigger pad (pad index = MIDI note)
  reaper.StuffMIDIMessage(0, 0x90, pad, velocity)  -- Note on
  -- Note off after short delay handled by one-shot mode
end

-- ============================================================================
-- 808 PRESET PATTERNS
-- Classic TR-808 style settings for common drum sounds
-- ============================================================================

M.Presets = {}

-- Classic 808 kick with pitch drop
-- Apply to any pad that has a kick sample
M.Presets.Kick808 = {
  pitch_env_amount = -12,   -- Drop 1 octave (classic 808 boing)
  pitch_env_attack = 0,     -- Instant attack
  pitch_env_decay = 80,     -- 80ms decay (adjust for "boing" length)
  pitch_env_sustain = 0,    -- Full sweep to base pitch
  attack = 0,               -- Instant attack
  decay = 500,              -- Medium decay
  sustain = 0.3,            -- Low sustain
  release = 200,            -- Medium release
}

-- Deep 808 sub kick (more extreme pitch drop)
M.Presets.SubKick808 = {
  pitch_env_amount = -24,   -- Drop 2 octaves (deep sub)
  pitch_env_attack = 0,
  pitch_env_decay = 150,    -- Longer decay for sub
  pitch_env_sustain = 0,
  attack = 0,
  decay = 800,
  sustain = 0.4,
  release = 300,
}

-- Punchy 808 kick (short pitch sweep)
M.Presets.PunchyKick808 = {
  pitch_env_amount = -8,    -- Subtle pitch drop
  pitch_env_attack = 0,
  pitch_env_decay = 30,     -- Very fast decay (punchy)
  pitch_env_sustain = 0,
  attack = 0,
  decay = 200,
  sustain = 0.1,
  release = 100,
}

-- 808 snare with slight pitch
M.Presets.Snare808 = {
  pitch_env_amount = -4,    -- Subtle pitch drop
  pitch_env_attack = 0,
  pitch_env_decay = 20,     -- Very fast
  pitch_env_sustain = 0,
  attack = 0,
  decay = 150,
  sustain = 0.2,
  release = 150,
}

-- 808 tom (melodic pitch drop)
M.Presets.Tom808 = {
  pitch_env_amount = -5,    -- Slight pitch drop
  pitch_env_attack = 0,
  pitch_env_decay = 100,
  pitch_env_sustain = 0,
  attack = 0,
  decay = 400,
  sustain = 0.3,
  release = 200,
}

-- Hi-hat (no pitch envelope, tight response)
M.Presets.HiHat808 = {
  pitch_env_amount = 0,     -- No pitch envelope
  pitch_env_attack = 0,
  pitch_env_decay = 0,
  pitch_env_sustain = 0,
  attack = 0,
  decay = 50,
  sustain = 0,
  release = 50,
}

-- Open hi-hat (longer decay)
M.Presets.OpenHat808 = {
  pitch_env_amount = 0,
  pitch_env_attack = 0,
  pitch_env_decay = 0,
  pitch_env_sustain = 0,
  attack = 0,
  decay = 300,
  sustain = 0.5,
  release = 200,
}

-- Clap (no pitch envelope)
M.Presets.Clap808 = {
  pitch_env_amount = 0,
  pitch_env_attack = 0,
  pitch_env_decay = 0,
  pitch_env_sustain = 0,
  attack = 0,
  decay = 200,
  sustain = 0.1,
  release = 200,
}

-- Cowbell (slight pitch drop for "ding")
M.Presets.Cowbell808 = {
  pitch_env_amount = -2,
  pitch_env_attack = 0,
  pitch_env_decay = 30,
  pitch_env_sustain = 0,
  attack = 0,
  decay = 300,
  sustain = 0.4,
  release = 150,
}

-- Apply a preset to a pad
function M.applyPreset(track, fx, pad, preset)
  if not track or not fx or fx < 0 then return false end
  if not preset then return false end

  if preset.pitch_env_amount then M.setPitchEnvAmount(track, fx, pad, preset.pitch_env_amount) end
  if preset.pitch_env_attack then M.setPitchEnvAttack(track, fx, pad, preset.pitch_env_attack) end
  if preset.pitch_env_decay then M.setPitchEnvDecay(track, fx, pad, preset.pitch_env_decay) end
  if preset.pitch_env_sustain then M.setPitchEnvSustain(track, fx, pad, preset.pitch_env_sustain) end
  if preset.attack then M.setAttack(track, fx, pad, preset.attack) end
  if preset.decay then M.setDecay(track, fx, pad, preset.decay) end
  if preset.sustain then M.setSustain(track, fx, pad, preset.sustain) end
  if preset.release then M.setRelease(track, fx, pad, preset.release) end
  if preset.tune then M.setTune(track, fx, pad, preset.tune) end
  if preset.volume then M.setVolume(track, fx, pad, preset.volume) end

  return true
end

return M
