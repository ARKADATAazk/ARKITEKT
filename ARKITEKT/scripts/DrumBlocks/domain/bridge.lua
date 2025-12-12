-- @noindex
-- DrumBlocks/domain/bridge.lua
-- Communication bridge to DrumBlocks VST

local M = {}

-- Debug flag - set to true to enable console logging
local DEBUG = false
local function log(msg)
  if DEBUG then reaper.ShowConsoleMsg(msg) end
end

-- Decode XML/HTML entities in paths from VST chunk
local function decodeXmlEntities(str)
  if not str then return str end
  -- Named entities
  str = str:gsub('&amp;', '&')
  str = str:gsub('&lt;', '<')
  str = str:gsub('&gt;', '>')
  str = str:gsub('&quot;', '"')
  str = str:gsub('&apos;', "'")
  -- Numeric entities (decimal): &#8211; -> character
  str = str:gsub('&#(%d+);', function(n)
    local num = tonumber(n)
    if num and num < 256 then
      return string.char(num)
    elseif num then
      -- UTF-8 encode for higher codepoints
      if num < 0x80 then
        return string.char(num)
      elseif num < 0x800 then
        return string.char(0xC0 + math.floor(num / 64), 0x80 + (num % 64))
      elseif num < 0x10000 then
        return string.char(0xE0 + math.floor(num / 4096),
                           0x80 + math.floor((num % 4096) / 64),
                           0x80 + (num % 64))
      end
    end
    return ''
  end)
  -- Hex entities: &#x2013; -> character
  str = str:gsub('&#x(%x+);', function(h)
    local num = tonumber(h, 16)
    if num and num < 256 then
      return string.char(num)
    elseif num then
      if num < 0x80 then
        return string.char(num)
      elseif num < 0x800 then
        return string.char(0xC0 + math.floor(num / 64), 0x80 + (num % 64))
      elseif num < 0x10000 then
        return string.char(0xE0 + math.floor(num / 4096),
                           0x80 + math.floor((num % 4096) / 64),
                           0x80 + (num % 64))
      end
    end
    return ''
  end)
  return str
end

-- DrumBlocks constants (must match VST)
M.NUM_PADS = 128
M.NUM_VELOCITY_LAYERS = 4
M.NUM_OUTPUT_GROUPS = 16
M.PARAMS_PER_PAD = 30  -- Must match PadParam::COUNT in VST

-- Parameter layout indices (must match Parameters.h)
-- Layout: [per-pad params (30 × 128)] [global quality (1)] [playback progress (128)]
-- Per-pad params: 0 to 3839 (30 * 128 - 1)
-- Global quality: 3840
-- Playback progress: 3841 to 3968 (128 params, one per pad)
M.GLOBAL_QUALITY_PARAM_INDEX = M.PARAMS_PER_PAD * M.NUM_PADS  -- 3712
M.PLAYBACK_PROGRESS_BASE_INDEX = M.GLOBAL_QUALITY_PARAM_INDEX + 1  -- 3713

-- Parameter indices (must match DrumBlocks/Source/Parameters.h)
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
  FilterType = 9,         -- 0=LP, 1=HP, 2=BP
  KillGroup = 10,
  OutputGroup = 11,
  LoopMode = 12,          -- 0=OneShot, 1=Loop, 2=PingPong
  Reverse = 13,
  Normalize = 14,         -- Peak normalization
  SampleStart = 15,
  SampleEnd = 16,
  RoundRobinMode = 17,    -- 0=sequential, 1=random
  PitchEnvAmount = 18,    -- -24 to +24 semitones (pitch envelope depth)
  PitchEnvAttack = 19,    -- 0-100 ms (pitch envelope attack)
  PitchEnvDecay = 20,     -- 0-2000 ms (pitch envelope decay)
  PitchEnvSustain = 21,   -- 0-1 (pitch envelope sustain level)
  VelCrossfade = 22,      -- 0-1 (velocity layer crossfade width)
  VelCurve = 23,          -- 0-1 (velocity response: 0=soft, 0.5=linear, 1=hard)
  SaturationDrive = 24,   -- 0-1 (saturation amount, 0=off)
  SaturationType = 25,    -- 0=Soft, 1=Hard, 2=Tube, 3=Tape, 4=Fold, 5=Crush
  SaturationMix = 26,     -- 0-1 (dry/wet blend)
  TransientAttack = 27,   -- -1 to +1 (attack boost/cut)
  TransientSustain = 28,  -- -1 to +1 (sustain boost/cut)
  NoteOffMode = 29,       -- 0=Ignore, 1=Release, 2=Cut
}

-- Loop mode constants
M.LoopMode = {
  OneShot = 0,
  Loop = 1,
  PingPong = 2,
}

-- Filter type constants
M.FilterType = {
  LP = 0,   -- Lowpass
  HP = 1,   -- Highpass
  BP = 2,   -- Bandpass
}

-- Note-off mode constants
M.NoteOffMode = {
  Ignore = 0,   -- Note-off does nothing, sample plays to end (default for drums)
  Release = 1,  -- Note-off triggers ADSR release phase
  Cut = 2,      -- Note-off immediately stops the sample
}

-- ============================================================================
-- VST DETECTION
-- ============================================================================

function M.findDrumBlocks(track)
  if not track then return nil end
  local fx_count = reaper.TrackFX_GetCount(track)
  log('[Bridge] findDrumBlocks: scanning ' .. fx_count .. ' FX on track\n')
  for i = 0, fx_count - 1 do
    local _, name = reaper.TrackFX_GetFXName(track, i, '')
    log('[Bridge]   FX ' .. i .. ': ' .. name .. '\n')
    if name:match('DrumBlocks') then
      log('[Bridge] Found DrumBlocks at index ' .. i .. '\n')
      return i
    end
  end
  log('[Bridge] DrumBlocks not found on track\n')
  return nil
end

function M.insertDrumBlocks(track)
  if not track then return nil end
  local fx_index = reaper.TrackFX_AddByName(track, 'DrumBlocks', false, -1)
  if fx_index >= 0 then
    return fx_index
  end
  return nil
end

function M.getOrCreateDrumBlocks(track)
  local fx = M.findDrumBlocks(track)
  if fx then return fx end
  return M.insertDrumBlocks(track)
end

-- ============================================================================
-- PARAMETER ACCESS
-- ============================================================================

local function getParamIndex(pad, param)
  return pad * M.PARAMS_PER_PAD + param
end

-- Validate pad index is in valid range
local function isValidPad(pad)
  return pad and pad >= 0 and pad < M.NUM_PADS
end

-- Validate layer index is in valid range
local function isValidLayer(layer)
  return layer and layer >= 0 and layer < M.NUM_VELOCITY_LAYERS
end

function M.setParam(track, fx, pad, param, value)
  if not track or not fx or fx < 0 then return false end
  if not isValidPad(pad) then return false end
  local idx = getParamIndex(pad, param)
  return reaper.TrackFX_SetParam(track, fx, idx, value)
end

function M.getParam(track, fx, pad, param)
  if not track or not fx or fx < 0 then return nil end
  if not isValidPad(pad) then return nil end
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

function M.getVolume(track, fx, pad)
  return M.getParam(track, fx, pad, M.Param.Volume)
end

function M.getPan(track, fx, pad)
  -- Pan is stored as 0-1, convert back to -1 to +1
  local normalized = M.getParam(track, fx, pad, M.Param.Pan)
  if not normalized then return nil end
  return normalized * 2 - 1
end

function M.getTune(track, fx, pad)
  -- Tune is stored as 0-1, convert back to -24 to +24 semitones
  local normalized = M.getParam(track, fx, pad, M.Param.Tune)
  if not normalized then return nil end
  return normalized * 48 - 24
end

function M.setAttack(track, fx, pad, ms)
  -- Attack is 0-2000ms with JUCE skew factor 0.3
  ms = math.max(0, math.min(2000, ms))
  local normalized = (ms / 2000) ^ 0.3
  return M.setParam(track, fx, pad, M.Param.Attack, normalized)
end

function M.setDecay(track, fx, pad, ms)
  -- Decay is 0-2000ms with JUCE skew factor 0.3
  ms = math.max(0, math.min(2000, ms))
  local normalized = (ms / 2000) ^ 0.3
  return M.setParam(track, fx, pad, M.Param.Decay, normalized)
end

function M.setSustain(track, fx, pad, value)
  return M.setParam(track, fx, pad, M.Param.Sustain, value)
end

function M.setRelease(track, fx, pad, ms)
  -- Release is 0-5000ms with JUCE skew factor 0.3
  ms = math.max(0, math.min(5000, ms))
  local normalized = (ms / 5000) ^ 0.3
  return M.setParam(track, fx, pad, M.Param.Release, normalized)
end

function M.getAttack(track, fx, pad)
  -- Reverse JUCE skew 0.3: ms = (normalized ^ (1/0.3)) * 2000
  local normalized = M.getParam(track, fx, pad, M.Param.Attack)
  if not normalized then return nil end
  return (normalized ^ (1/0.3)) * 2000
end

function M.getDecay(track, fx, pad)
  -- Reverse JUCE skew 0.3: ms = (normalized ^ (1/0.3)) * 2000
  local normalized = M.getParam(track, fx, pad, M.Param.Decay)
  if not normalized then return nil end
  return (normalized ^ (1/0.3)) * 2000
end

function M.getSustain(track, fx, pad)
  return M.getParam(track, fx, pad, M.Param.Sustain)
end

function M.getRelease(track, fx, pad)
  -- Reverse JUCE skew 0.3: ms = (normalized ^ (1/0.3)) * 5000
  local normalized = M.getParam(track, fx, pad, M.Param.Release)
  if not normalized then return nil end
  return (normalized ^ (1/0.3)) * 5000
end

function M.setFilterCutoff(track, fx, pad, hz)
  -- Cutoff is 20-20000Hz with JUCE skew factor 0.25
  -- JUCE formula: normalized = ((hz - min) / (max - min)) ^ skew
  hz = math.max(20, math.min(20000, hz))  -- Clamp to valid range
  local normalized = ((hz - 20) / 19980) ^ 0.25
  return M.setParam(track, fx, pad, M.Param.FilterCutoff, normalized)
end

function M.setFilterReso(track, fx, pad, value)
  return M.setParam(track, fx, pad, M.Param.FilterReso, value)
end

function M.setFilterType(track, fx, pad, filter_type)
  -- 0 = lowpass, 1 = highpass, 2 = bandpass
  return M.setParam(track, fx, pad, M.Param.FilterType, filter_type / 2)
end

function M.setFilterLP(track, fx, pad)
  return M.setFilterType(track, fx, pad, M.FilterType.LP)
end

function M.setFilterHP(track, fx, pad)
  return M.setFilterType(track, fx, pad, M.FilterType.HP)
end

function M.setFilterBP(track, fx, pad)
  return M.setFilterType(track, fx, pad, M.FilterType.BP)
end

function M.getFilterCutoff(track, fx, pad)
  -- Reverse JUCE skew 0.25: hz = 20 + (normalized ^ (1/0.25)) * 19980
  local normalized = M.getParam(track, fx, pad, M.Param.FilterCutoff)
  if not normalized then return nil end
  return 20 + (normalized ^ (1/0.25)) * 19980
end

function M.getFilterReso(track, fx, pad)
  return M.getParam(track, fx, pad, M.Param.FilterReso)
end

function M.getFilterType(track, fx, pad)
  -- Returns 0=LP, 1=HP, 2=BP
  local normalized = M.getParam(track, fx, pad, M.Param.FilterType)
  if not normalized then return nil end
  return math.floor(normalized * 2 + 0.5)
end

function M.setKillGroup(track, fx, pad, group)
  -- Group is 0-16 (0 = none)
  return M.setParam(track, fx, pad, M.Param.KillGroup, group / 16)
end

function M.setOutputGroup(track, fx, pad, group)
  -- Group is 0-16
  return M.setParam(track, fx, pad, M.Param.OutputGroup, group / 16)
end

function M.setLoopMode(track, fx, pad, mode)
  -- Mode: 0=OneShot, 1=Loop, 2=PingPong
  return M.setParam(track, fx, pad, M.Param.LoopMode, mode / 2)
end

-- Set playback mode from string ('oneshot', 'loop', 'pingpong')
-- Used by UI widgets that use string-based mode identifiers
function M.setPlaybackMode(track, fx, pad, mode_str)
  local mode_map = {
    oneshot = M.LoopMode.OneShot,
    loop = M.LoopMode.Loop,
    pingpong = M.LoopMode.PingPong,
  }
  local mode = mode_map[mode_str]
  if mode then
    return M.setLoopMode(track, fx, pad, mode)
  end
  return false
end

-- Get playback mode as string ('oneshot', 'loop', 'pingpong')
function M.getPlaybackMode(track, fx, pad)
  local mode = M.getLoopMode(track, fx, pad)
  local mode_strings = { [0] = 'oneshot', [1] = 'loop', [2] = 'pingpong' }
  return mode_strings[mode] or 'oneshot'
end

function M.setReverse(track, fx, pad, enabled)
  return M.setParam(track, fx, pad, M.Param.Reverse, enabled and 1 or 0)
end

function M.getKillGroup(track, fx, pad)
  local val = M.getParam(track, fx, pad, M.Param.KillGroup)
  return val and math.floor(val * 16 + 0.5) or 0
end

function M.getOutputGroup(track, fx, pad)
  local val = M.getParam(track, fx, pad, M.Param.OutputGroup)
  return val and math.floor(val * 16 + 0.5) or 0
end

function M.getLoopMode(track, fx, pad)
  local val = M.getParam(track, fx, pad, M.Param.LoopMode)
  return val and math.floor(val * 2 + 0.5) or M.LoopMode.OneShot
end

function M.getReverse(track, fx, pad)
  local val = M.getParam(track, fx, pad, M.Param.Reverse)
  return val and val > 0.5 or false
end

function M.setNoteOffMode(track, fx, pad, mode)
  -- Mode: 0=Ignore, 1=Release, 2=Cut
  return M.setParam(track, fx, pad, M.Param.NoteOffMode, mode / 2)
end

function M.getNoteOffMode(track, fx, pad)
  local val = M.getParam(track, fx, pad, M.Param.NoteOffMode)
  return val and math.floor(val * 2 + 0.5) or M.NoteOffMode.Ignore
end

function M.getNoteOffModeString(track, fx, pad)
  local mode = M.getNoteOffMode(track, fx, pad)
  local mode_strings = {
    [M.NoteOffMode.Ignore] = 'ignore',
    [M.NoteOffMode.Release] = 'release',
    [M.NoteOffMode.Cut] = 'cut',
  }
  return mode_strings[mode] or 'ignore'
end

-- Convenience functions for note-off modes
function M.setNoteOffIgnore(track, fx, pad)
  return M.setNoteOffMode(track, fx, pad, M.NoteOffMode.Ignore)
end

function M.setNoteOffRelease(track, fx, pad)
  return M.setNoteOffMode(track, fx, pad, M.NoteOffMode.Release)
end

function M.setNoteOffCut(track, fx, pad)
  return M.setNoteOffMode(track, fx, pad, M.NoteOffMode.Cut)
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

function M.getSampleStart(track, fx, pad)
  return M.getParam(track, fx, pad, M.Param.SampleStart)
end

function M.getSampleEnd(track, fx, pad)
  local val = M.getParam(track, fx, pad, M.Param.SampleEnd)
  -- Default to 1 if not set (full sample)
  return val or 1
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
  -- Attack is 0-100ms with JUCE skew factor 0.5
  ms = math.max(0, math.min(100, ms))
  local normalized = (ms / 100) ^ 0.5
  return M.setParam(track, fx, pad, M.Param.PitchEnvAttack, normalized)
end

function M.setPitchEnvDecay(track, fx, pad, ms)
  -- Decay is 0-2000ms with JUCE skew factor 0.3
  ms = math.max(0, math.min(2000, ms))
  local normalized = (ms / 2000) ^ 0.3
  return M.setParam(track, fx, pad, M.Param.PitchEnvDecay, normalized)
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

function M.getPitchEnvAmount(track, fx, pad)
  -- Reverse: semitones = normalized * 48 - 24
  local normalized = M.getParam(track, fx, pad, M.Param.PitchEnvAmount)
  if not normalized then return nil end
  return normalized * 48 - 24
end

function M.getPitchEnvAttack(track, fx, pad)
  -- Reverse JUCE skew 0.5: ms = (normalized ^ (1/0.5)) * 100
  local normalized = M.getParam(track, fx, pad, M.Param.PitchEnvAttack)
  if not normalized then return nil end
  return (normalized ^ 2) * 100
end

function M.getPitchEnvDecay(track, fx, pad)
  -- Reverse JUCE skew 0.3: ms = (normalized ^ (1/0.3)) * 2000
  local normalized = M.getParam(track, fx, pad, M.Param.PitchEnvDecay)
  if not normalized then return nil end
  return (normalized ^ (1/0.3)) * 2000
end

function M.getPitchEnvSustain(track, fx, pad)
  return M.getParam(track, fx, pad, M.Param.PitchEnvSustain)
end

-- ============================================================================
-- VELOCITY LAYER CROSSFADE
-- ============================================================================

function M.setVelCrossfade(track, fx, pad, value)
  -- Value is 0-1:
  --   0 = hard switch between velocity layers (traditional behavior)
  --   1 = maximum crossfade zone (smooth blend near layer boundaries)
  return M.setParam(track, fx, pad, M.Param.VelCrossfade, math.min(1, math.max(0, value)))
end

function M.getVelCrossfade(track, fx, pad)
  return M.getParam(track, fx, pad, M.Param.VelCrossfade)
end

-- ============================================================================
-- VELOCITY CURVE (response shaping)
-- ============================================================================

function M.setVelCurve(track, fx, pad, value)
  -- Value is 0-1:
  --   0   = soft/logarithmic (quieter response, good for brushes/jazz)
  --   0.5 = linear (default, MIDI velocity as-is)
  --   1   = hard/exponential (punchy response, good for electronic/rock)
  return M.setParam(track, fx, pad, M.Param.VelCurve, math.min(1, math.max(0, value)))
end

function M.getVelCurve(track, fx, pad)
  return M.getParam(track, fx, pad, M.Param.VelCurve)
end

-- Convenience presets
function M.setVelCurveSoft(track, fx, pad)
  return M.setVelCurve(track, fx, pad, 0)
end

function M.setVelCurveLinear(track, fx, pad)
  return M.setVelCurve(track, fx, pad, 0.5)
end

function M.setVelCurveHard(track, fx, pad)
  return M.setVelCurve(track, fx, pad, 1)
end

-- ============================================================================
-- SATURATION
-- ============================================================================

-- Saturation type constants
M.SaturationType = {
  Soft = 0,
  Hard = 1,
  Tube = 2,
  Tape = 3,
  Fold = 4,
  Crush = 5,
}

-- Set saturation drive (0-1, 0=off)
function M.setSaturationDrive(track, fx, pad, value)
  return M.setParam(track, fx, pad, M.Param.SaturationDrive, value)
end

-- Set saturation type (0-5)
function M.setSaturationType(track, fx, pad, sat_type)
  return M.setParam(track, fx, pad, M.Param.SaturationType, sat_type / 5)
end

-- Set saturation mix (0-1, dry/wet)
function M.setSaturationMix(track, fx, pad, value)
  return M.setParam(track, fx, pad, M.Param.SaturationMix, value)
end

-- ============================================================================
-- TRANSIENT SHAPER
-- ============================================================================

-- Set transient attack boost/cut (-1 to +1)
function M.setTransientAttack(track, fx, pad, value)
  local normalized = (value + 1) / 2  -- Convert -1..+1 to 0..1
  return M.setParam(track, fx, pad, M.Param.TransientAttack, normalized)
end

-- Set transient sustain boost/cut (-1 to +1)
function M.setTransientSustain(track, fx, pad, value)
  local normalized = (value + 1) / 2  -- Convert -1..+1 to 0..1
  return M.setParam(track, fx, pad, M.Param.TransientSustain, normalized)
end

-- ============================================================================
-- SAMPLE LOADING (via JUCE binary chunk format)
-- ============================================================================

-- XML helpers
local function xmlEscape(str)
  return str:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'):gsub('"', '&quot;')
end

-- Create a JUCE-compatible binary chunk from XML string
-- JUCE format: 4-byte little-endian size + UTF-8 XML
local function createJuceChunk(xml_str)
  local size = #xml_str
  -- Little-endian 4-byte size
  local b1 = size % 256
  local b2 = math.floor(size / 256) % 256
  local b3 = math.floor(size / 65536) % 256
  local b4 = math.floor(size / 16777216) % 256
  return string.char(b1, b2, b3, b4) .. xml_str
end

-- Fast base64 decode using lookup table and chunk processing
local b64decode_lookup = {}
do
  local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  for i = 1, 64 do
    b64decode_lookup[chars:byte(i)] = i - 1
  end
end

local function decodeBase64(str)
  if not str or str == '' then return nil end

  -- Remove whitespace
  str = str:gsub('%s', '')

  local len = #str
  -- Handle padding
  local pad = 0
  if str:sub(-1) == '=' then pad = pad + 1 end
  if str:sub(-2, -2) == '=' then pad = pad + 1 end

  -- Process in large chunks for speed
  local chunks = {}
  local chunk_size = 4096  -- Process 4KB at a time
  local char, band, rshift, lshift = string.char, bit and bit.band or function(a,b) return a % (b+1) end, bit and bit.rshift or function(a,b) return math.floor(a / 2^b) end, bit and bit.lshift or function(a,b) return a * 2^b end

  local lookup = b64decode_lookup
  local byte = string.byte

  for chunk_start = 1, len - pad, chunk_size do
    local chunk_end = math.min(chunk_start + chunk_size - 1, len - pad)
    local result = {}

    local i = chunk_start
    while i <= chunk_end - 3 do
      local b1 = lookup[byte(str, i)] or 0
      local b2 = lookup[byte(str, i + 1)] or 0
      local b3 = lookup[byte(str, i + 2)] or 0
      local b4 = lookup[byte(str, i + 3)] or 0

      -- Decode 4 base64 chars to 3 bytes
      result[#result + 1] = char(
        b1 * 4 + math.floor(b2 / 16),
        (b2 % 16) * 16 + math.floor(b3 / 4),
        (b3 % 4) * 64 + b4
      )
      i = i + 4
    end

    chunks[#chunks + 1] = table.concat(result)
  end

  local decoded = table.concat(chunks)

  -- Trim padding bytes
  if pad > 0 then
    decoded = decoded:sub(1, -(pad + 1))
  end

  return decoded
end

-- Decode JUCE binary chunk to XML string
-- Returns nil if invalid format
local function decodeJuceChunk(chunk)
  if not chunk or #chunk < 4 then return nil end
  -- Read little-endian 4-byte size
  local b1, b2, b3, b4 = chunk:byte(1, 4)
  local size = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
  if #chunk < 4 + size then return nil end
  return chunk:sub(5, 4 + size)
end

-- Get the real reaper API (bypasses any sandbox/proxy)
local function getRealReaper()
  -- Try multiple ways to get the real reaper API
  local r = rawget(_G, 'reaper') or _G.reaper or reaper
  return r
end

-- Check if SWS is available
local HAS_SWS = reaper.CF_GetClipboardBig ~= nil

-- Debug: Check what reaper API functions are available
local function debugReaperAPI()
  log('[Bridge] === REAPER API DEBUG ===\n')
  log('[Bridge] REAPER version: ' .. (reaper.GetAppVersion() or 'unknown') .. '\n')
  log('[Bridge] SWS Extension: ' .. (HAS_SWS and 'YES' or 'NO') .. '\n')

  -- Search for ANY chunk-related functions
  local found = {}
  for k, v in pairs(reaper) do
    if type(v) == 'function' and (k:lower():match('chunk') or k:lower():match('state') or k:lower():match('fxchain')) then
      table.insert(found, k)
    end
  end
  table.sort(found)
  log('[Bridge] Chunk/State/FXChain functions found:\n')
  for _, fname in ipairs(found) do
    log('[Bridge]   ' .. fname .. '\n')
  end
  log('[Bridge] === END DEBUG ===\n')
end

if DEBUG then debugReaperAPI() end

-- Get VST chunk and decode to XML
local function getVstChunkXml(track, fx)
  -- Use vst_chunk named config param (returns base64-encoded chunk)
  local retval, b64_chunk = reaper.TrackFX_GetNamedConfigParm(track, fx, 'vst_chunk')
  if not retval or not b64_chunk or b64_chunk == '' then
    return nil
  end

  -- Decode base64
  local chunk = decodeBase64(b64_chunk)
  if not chunk or #chunk == 0 then
    log('[Bridge] getVstChunkXml: base64 decode failed\n')
    return nil
  end

  -- Decode JUCE binary format to XML
  local xml = decodeJuceChunk(chunk)
  return xml
end

-- Set VST chunk from XML (tries JUCE binary format first, then raw XML)
local function setVstChunkXml(track, fx, xml)
  local r = getRealReaper()

  -- Check if function exists
  local fn = r and r.TrackFX_SetFXChunk
  if not fn then
    log('[Bridge] setVstChunkXml: TrackFX_SetFXChunk not found, trying direct call\n')
    -- Try calling it directly anyway
    local chunk = createJuceChunk(xml)
    local ok, result = pcall(function()
      return reaper.TrackFX_SetFXChunk(track, fx, chunk, false)
    end)
    if ok then
      log('[Bridge] setVstChunkXml: direct call result = ' .. tostring(result) .. '\n')
      return result
    end
    log('[Bridge] setVstChunkXml: direct call failed: ' .. tostring(result) .. '\n')
    return false
  end

  -- Try JUCE binary format first
  local chunk = createJuceChunk(xml)
  log('[Bridge] setVstChunkXml: trying JUCE format - xml_len=' .. #xml .. ' chunk_len=' .. #chunk .. '\n')

  local bytes = {}
  for i = 1, math.min(20, #chunk) do
    bytes[i] = string.format('%02X', chunk:byte(i))
  end
  log('[Bridge] setVstChunkXml: JUCE bytes = ' .. table.concat(bytes, ' ') .. '\n')

  local result = fn(track, fx, chunk, false)
  log('[Bridge] setVstChunkXml: JUCE format result = ' .. tostring(result) .. '\n')

  if result then return true end

  -- Fallback: try raw XML (REAPER might pass it through differently)
  log('[Bridge] setVstChunkXml: trying raw XML format\n')
  result = fn(track, fx, xml, false)
  log('[Bridge] setVstChunkXml: raw XML result = ' .. tostring(result) .. '\n')

  return result
end

-- ============================================================================
-- VST CHUNK-BASED COMMUNICATION
-- Uses REAPER's vst_chunk named config param to send commands to VST
-- ============================================================================

-- Base64 encoding (required for vst_chunk)
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64_encode(data)
  return ((data:gsub('.', function(x)
    local r, b = '', x:byte()
    for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
    return r
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if #x < 6 then return '' end
    local c = 0
    for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
    return b64chars:sub(c + 1, c + 1)
  end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local function base64_decode(data)
  data = data:gsub('[^' .. b64chars .. '=]', '')
  return (data:gsub('.', function(x)
    if x == '=' then return '' end
    local r, f = '', (b64chars:find(x) - 1)
    for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
    return r
  end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
    if #x ~= 8 then return '' end
    local c = 0
    for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
    return string.char(c)
  end))
end

-- VST3/JUCE chunk format:
-- Bytes 0-3:   Total size (little-endian)
-- Bytes 4-7:   Version (0x01000000)
-- Bytes 8-11:  Magic "VC2!"
-- Bytes 12-15: XML size (little-endian)
-- Bytes 16+:   UTF-8 XML

local function readLE32(binary, offset)
  local b1, b2, b3, b4 = binary:byte(offset, offset + 3)
  return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function writeLE32(value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  local b3 = math.floor(value / 65536) % 256
  local b4 = math.floor(value / 16777216) % 256
  return string.char(b1, b2, b3, b4)
end

local function decodeVst3Chunk(binary)
  if not binary or #binary < 16 then return nil end

  -- Check for "VC2!" magic at bytes 8-11
  local magic = binary:sub(9, 12)
  if magic == 'VC2!' then
    -- VST3 format: XML starts at byte 17
    local xml_size = readLE32(binary, 13)
    if #binary >= 16 + xml_size then
      return binary:sub(17, 16 + xml_size)
    end
  end

  -- Fallback: try simple JUCE format (4-byte size + XML)
  local size = readLE32(binary, 1)
  if #binary >= 4 + size and binary:sub(5, 9) == '<?xml' then
    return binary:sub(5, 4 + size)
  end

  return nil
end

local function encodeVst3Chunk(xml)
  local xml_size = #xml
  local total_size = xml_size + 12  -- 12 bytes of header after the first size field

  return writeLE32(total_size) ..       -- Total size
         writeLE32(1) ..                 -- Version
         'VC2!' ..                       -- Magic
         writeLE32(xml_size) ..          -- XML size
         xml
end

-- Send a command to the VST via chunk modification
local function sendVstCommand(track, fx, command_xml)
  -- Get current VST chunk
  local retval, current_chunk = reaper.TrackFX_GetNamedConfigParm(track, fx, 'vst_chunk')

  local xml
  if retval and current_chunk and current_chunk ~= '' then
    -- Decode base64 -> binary -> XML (JUCE format)
    local binary = base64_decode(current_chunk)
    log('[Bridge] Got chunk, binary length: ' .. #binary .. '\n')

    -- Show first 20 bytes as hex
    local hex = {}
    for i = 1, math.min(20, #binary) do
      hex[i] = string.format('%02X', binary:byte(i))
    end
    log('[Bridge] First 20 bytes: ' .. table.concat(hex, ' ') .. '\n')

    -- Decode VST3/JUCE format
    xml = decodeVst3Chunk(binary)
    if xml then
      log('[Bridge] VST3 chunk decoded, XML length: ' .. #xml .. '\n')
    else
      -- Maybe it's raw XML?
      log('[Bridge] Unknown format, treating as raw\n')
      xml = binary
    end

    -- Show first 200 chars of XML (filtering out non-printable)
    local printable = xml:gsub('[^%g%s]', '?'):sub(1, 200)
    log('[Bridge] XML content: ' .. printable .. '\n')
  else
    -- Create minimal valid chunk
    xml = '<DrumBlocksParams></DrumBlocksParams>'
    log('[Bridge] No existing chunk, creating new\n')
  end

  -- Insert command into XML
  -- Look for existing Commands section or create one
  local commands_start = xml:find('<Commands>')
  local commands_end = xml:find('</Commands>')

  if commands_start and commands_end then
    -- Insert command before </Commands>
    xml = xml:sub(1, commands_end - 1) .. command_xml .. xml:sub(commands_end)
  else
    -- Create Commands section before closing tag
    local close_tag = xml:find('</DrumBlocksParams>')
    if close_tag then
      xml = xml:sub(1, close_tag - 1) .. '<Commands>' .. command_xml .. '</Commands>' .. xml:sub(close_tag)
    else
      -- Malformed XML, wrap it
      log('[Bridge] Warning: malformed chunk, creating fresh\n')
      xml = '<DrumBlocksParams><Commands>' .. command_xml .. '</Commands></DrumBlocksParams>'
    end
  end

  log('[Bridge] New XML length: ' .. #xml .. '\n')

  -- Show the Commands section
  local cmd_start = xml:find('<Commands>')
  local cmd_end = xml:find('</Commands>')
  if cmd_start and cmd_end then
    local commands_section = xml:sub(cmd_start, cmd_end + 10)
    log('[Bridge] Commands section: ' .. commands_section .. '\n')
  end

  -- Encode: XML -> VST3 binary -> base64
  local binary = encodeVst3Chunk(xml)
  local encoded = base64_encode(binary)

  log('[Bridge] Encoded chunk size: ' .. #binary .. ' bytes\n')

  -- Method 1: Try vst_chunk (stores for later, doesn't apply immediately)
  local result = reaper.TrackFX_SetNamedConfigParm(track, fx, 'vst_chunk', encoded)
  log('[Bridge] vst_chunk result: ' .. tostring(result) .. '\n')

  -- Method 2: Force state reload by toggling FX offline/online
  if result then
    log('[Bridge] Forcing FX state reload...\n')
    -- Get current offline state
    local wasOffline = reaper.TrackFX_GetOffline(track, fx)
    -- Toggle offline to force reload
    reaper.TrackFX_SetOffline(track, fx, true)
    reaper.TrackFX_SetOffline(track, fx, wasOffline)
    log('[Bridge] FX toggled offline/online\n')
  end

  return result
end

-- Get command file path (must match VST's getCommandFile)
local function getCommandFilePath()
  local temp = os.getenv('TEMP') or os.getenv('TMP') or '/tmp'
  local sep = package.config:sub(1, 1)
  return temp .. sep .. 'DrumBlocks' .. sep .. 'commands.txt'
end

local function ensureCommandDir()
  local path = getCommandFilePath()
  local dir = path:match('(.+)[/\\][^/\\]+$')
  reaper.RecursiveCreateDirectory(dir, 0)
end

local function writeCommandToFile(cmd)
  ensureCommandDir()
  local path = getCommandFilePath()
  local f = io.open(path, 'a')
  if f then
    f:write(cmd .. '\n')
    f:close()
    return true
  end
  return false
end

-- Load sample via file-based command (primary) or vst_chunk (fallback)
function M.loadSample(track, fx, pad, layer, file_path)
  if not track or not fx or fx < 0 then
    log('[Bridge] loadSample: invalid track/fx\n')
    return false
  end
  if not isValidPad(pad) or not isValidLayer(layer) then
    log('[Bridge] loadSample: invalid pad/layer\n')
    return false
  end

  -- Primary method: File-based IPC
  local cmd = string.format('LOAD_SAMPLE|%d|%d|%s', pad, layer, file_path)
  local cmdPath = getCommandFilePath()
  log('[Bridge] loadSample: writing to ' .. cmdPath .. '\n')

  local result = writeCommandToFile(cmd)
  log('[Bridge] loadSample: file write result = ' .. tostring(result) .. '\n')

  -- Verify file was written
  local check = io.open(cmdPath, 'r')
  if check then
    local content = check:read('*a')
    check:close()
    log('[Bridge] loadSample: file content length = ' .. #content .. '\n')
  else
    log('[Bridge] loadSample: ERROR - could not read back file!\n')
  end

  return result
end

function M.clearSample(track, fx, pad, layer)
  return M.loadSample(track, fx, pad, layer, '')
end

-- Async sample loading (non-blocking, loads in background thread)
-- Returns immediately; sample becomes available after loading completes
function M.loadSampleAsync(track, fx, pad, layer, file_path)
  if not track or not fx or fx < 0 then return false end
  if not isValidPad(pad) or not isValidLayer(layer) then return false end

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
  if not isValidPad(pad) or not isValidLayer(layer) then return false end

  local param_name = string.format('P%d_L%d_RR_ASYNC', pad, layer)
  local result = reaper.TrackFX_SetNamedConfigParm(track, fx, param_name, file_path)
  return result or false
end

-- Clear round-robin samples from a layer (keeps primary sample)
function M.clearRoundRobin(track, fx, pad, layer)
  if not track or not fx or fx < 0 then return false end
  layer = layer or 0
  if not isValidPad(pad) or not isValidLayer(layer) then return false end

  local param_name = string.format('P%d_L%d_CLEAR_RR', pad, layer)
  local result = reaper.TrackFX_SetNamedConfigParm(track, fx, param_name, '')
  return result or false
end

-- Get round-robin sample count for a layer
-- Returns nil on error, 0+ on success
function M.getRoundRobinCount(track, fx, pad, layer)
  if not track or not fx or fx < 0 then return nil end
  layer = layer or 0
  if not isValidPad(pad) or not isValidLayer(layer) then return nil end

  local param_name = string.format('P%d_L%d_RR_COUNT', pad, layer)
  local retval, value = reaper.TrackFX_GetNamedConfigParm(track, fx, param_name)
  if retval then
    return tonumber(value) or 0
  end
  return 0  -- Valid: no round-robin samples loaded
end

-- Get sample duration in seconds
-- Returns nil on error, 0+ on success
function M.getSampleDuration(track, fx, pad, layer)
  if not track or not fx or fx < 0 then return nil end
  layer = layer or 0
  if not isValidPad(pad) or not isValidLayer(layer) then return nil end

  local param_name = string.format('P%d_L%d_DURATION', pad, layer)
  local retval, value = reaper.TrackFX_GetNamedConfigParm(track, fx, param_name)
  if retval then
    return tonumber(value) or 0
  end
  return 0  -- Valid: no sample loaded
end

-- Clear all samples from a pad
function M.clearPad(track, fx, pad)
  if not track or not fx or fx < 0 then return false end
  if not isValidPad(pad) then return false end

  -- Try named config param first
  local r = _G.reaper or reaper
  local param_name = string.format('P%d_CLEAR', pad)
  local result = r.TrackFX_SetNamedConfigParm(track, fx, param_name, '')
  if result then return true end

  -- Fallback: chunk modification with JUCE binary format
  local xml = getVstChunkXml(track, fx)
  if not xml then
    xml = '<DrumBlocksParams/>'
  end

  local cmd_xml = string.format('<ClearPad pad="%d"/>', pad)
  local insert_pos = xml:find('</DrumBlocksParams>')
  if insert_pos then
    local commands_section = '<Commands>' .. cmd_xml .. '</Commands>\n'
    xml = xml:sub(1, insert_pos - 1) .. commands_section .. xml:sub(insert_pos)
    return setVstChunkXml(track, fx, xml)
  end

  -- Fresh state with commands
  local fresh_xml = string.format(
    '<DrumBlocksParams><Commands>%s</Commands></DrumBlocksParams>',
    cmd_xml
  )
  return setVstChunkXml(track, fx, fresh_xml)
end

-- Get sample path from VST state
function M.getSamplePath(track, fx, pad, layer)
  if not track or not fx or fx < 0 then return nil end
  if not isValidPad(pad) or not isValidLayer(layer) then return nil end

  -- Try named config param first
  local param_name = string.format('P%d_L%d_SAMPLE', pad, layer)
  local retval, value = reaper.TrackFX_GetNamedConfigParm(track, fx, param_name)
  if retval and value ~= '' then
    return value
  end

  -- Fallback: parse from chunk (with JUCE binary decoding)
  local xml = getVstChunkXml(track, fx)
  if not xml then return nil end

  -- Look for Sample node with matching pad and layer
  local pattern = '<Sample pad="' .. pad .. '" layer="' .. layer .. '" path="([^"]*)"'
  local path = xml:match(pattern)
  return decodeXmlEntities(path)
end

-- Get ALL sample paths from VST state in one pass
-- Returns table keyed by "pad_layer" (e.g., "0_0", "1_0", "5_2")
-- This is much faster than calling getSamplePath() 512 times
function M.getAllSamplePaths(track, fx)
  if not track or not fx or fx < 0 then return nil end

  -- Parse VST chunk once
  local xml = getVstChunkXml(track, fx)
  if not xml then return {} end

  local samples = {}

  -- Match all Sample nodes: <Sample pad="X" layer="Y" path="..."/>
  for pad, layer, path in xml:gmatch('<Sample pad="(%d+)" layer="(%d+)" path="([^"]*)"') do
    if path and path ~= '' then
      local key = pad .. '_' .. layer
      samples[key] = decodeXmlEntities(path)
    end
  end

  return samples
end

-- Check if pad has any sample loaded
function M.hasSample(track, fx, pad)
  if not track or not fx or fx < 0 then return false end
  if not isValidPad(pad) then return false end

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

    -- Playback mode (string or numeric)
    if pad_data.playback_mode then
      M.setPlaybackMode(track, fx, pad_idx, pad_data.playback_mode)
    elseif pad_data.loop_mode ~= nil then
      M.setLoopMode(track, fx, pad_idx, pad_data.loop_mode)
    end

    if pad_data.reverse ~= nil then M.setReverse(track, fx, pad_idx, pad_data.reverse) end

    -- Pitch envelope (for 808-style sounds)
    if pad_data.pitch_env_amount then M.setPitchEnvAmount(track, fx, pad_idx, pad_data.pitch_env_amount) end
    if pad_data.pitch_env_attack then M.setPitchEnvAttack(track, fx, pad_idx, pad_data.pitch_env_attack) end
    if pad_data.pitch_env_decay then M.setPitchEnvDecay(track, fx, pad_idx, pad_data.pitch_env_decay) end
    if pad_data.pitch_env_sustain then M.setPitchEnvSustain(track, fx, pad_idx, pad_data.pitch_env_sustain) end

    -- Velocity layer crossfade
    if pad_data.vel_crossfade ~= nil then M.setVelCrossfade(track, fx, pad_idx, pad_data.vel_crossfade) end

    -- Velocity curve
    if pad_data.vel_curve ~= nil then M.setVelCurve(track, fx, pad_idx, pad_data.vel_curve) end
  end

  return true
end

-- ============================================================================
-- PREVIEW / PLAYBACK CONTROL
-- ============================================================================

-- Preview pad via MIDI (most reliable for real-time playback)
function M.previewPad(track, fx, pad, velocity)
  if not track or not fx or fx < 0 then
    log('[Bridge] previewPad: invalid track/fx\n')
    return false
  end
  if not isValidPad(pad) then
    log('[Bridge] previewPad: invalid pad ' .. tostring(pad) .. '\n')
    return false
  end
  velocity = velocity or 100

  -- DrumBlocks uses MIDI_NOTE_OFFSET = 0, so pad 0 = note 0
  local midi_note = pad

  log('[Bridge] previewPad: sending MIDI note ' .. midi_note .. ' vel=' .. velocity .. '\n')
  reaper.StuffMIDIMessage(0, 0x90, midi_note, velocity)

  return true
end

-- Stop pad playback via MIDI note-off
function M.stopPad(track, fx, pad)
  if not track or not fx or fx < 0 then return false end
  if not isValidPad(pad) then return false end

  -- DrumBlocks uses MIDI_NOTE_OFFSET = 0, so pad 0 = note 0
  local midi_note = pad
  reaper.StuffMIDIMessage(0, 0x80, midi_note, 0)  -- Note off
  return true
end

-- Stop all pads via MIDI all-notes-off
function M.stopAll(track, fx)
  if not track or not fx or fx < 0 then return false end

  -- Send all notes off (CC 123)
  reaper.StuffMIDIMessage(0, 0xB0, 123, 0)
  return true
end

-- Check if pad is currently playing (alias for isPadPlaying for backwards compatibility)
-- Uses parameter-based approach for VST3/CLAP compatibility
function M.isPlaying(track, fx, pad)
  return M.isPadPlaying(track, fx, pad)
end

-- Legacy MIDI preview (requires MIDI routing to track)
function M.triggerPad(pad, velocity)
  if not isValidPad(pad) then return end
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

-- ============================================================================
-- PAD COLORS (UI display colors, persisted in VST state)
-- ============================================================================

function M.setPadColor(track, fx, pad, color)
  if not track or not fx or fx < 0 then return false end
  if not isValidPad(pad) then return false end

  local param_name = string.format('pad_%d_color', pad)
  -- Color is 0xRRGGBBAA, pass as decimal string (nil/0 to clear)
  local value = tostring(color or 0)
  return reaper.TrackFX_SetNamedConfigParm(track, fx, param_name, value) or false
end

function M.getPadColor(track, fx, pad)
  if not track or not fx or fx < 0 then return nil end
  if not isValidPad(pad) then return nil end

  local param_name = string.format('pad_%d_color', pad)
  local retval, value = reaper.TrackFX_GetNamedConfigParm(track, fx, param_name)
  if retval and value ~= '' then
    local color = tonumber(value)
    return (color and color ~= 0) and color or nil
  end
  return nil
end

-- ============================================================================
-- WAVEFORM PEAKS (fetched from VST, computed on sample load)
-- ============================================================================

-- Parse comma-separated peak values from VST response
local function parsePeakString(peak_str)
  if not peak_str or peak_str == '' then return nil end

  local peaks = {}
  for val in peak_str:gmatch('[^,]+') do
    local num = tonumber(val)
    if num then
      peaks[#peaks + 1] = num
    end
  end

  return #peaks > 0 and peaks or nil
end

-- Get mini-resolution peaks for a pad/layer (64 max + 64 min = 128 values)
-- Returns: table of floats [max1..max64, min1..min64], or nil if not available
function M.getPeaksMini(track, fx, pad, layer)
  if not track or not fx or fx < 0 then return nil end
  layer = layer or 0
  if not isValidPad(pad) or not isValidLayer(layer) then return nil end

  local param_name = string.format('P%d_L%d_PEAKS_MINI', pad, layer)
  local retval, value = reaper.TrackFX_GetNamedConfigParm(track, fx, param_name)
  if retval and value and #value > 0 then
    return parsePeakString(value)
  end
  return nil
end

-- Get full-resolution peaks for a pad/layer (512 max + 512 min = 1024 values)
-- Returns: table of floats [max1..max512, min1..min512], or nil if not available
function M.getPeaksFull(track, fx, pad, layer)
  if not track or not fx or fx < 0 then return nil end
  layer = layer or 0
  if not isValidPad(pad) or not isValidLayer(layer) then return nil end

  local param_name = string.format('P%d_L%d_PEAKS_FULL', pad, layer)
  local retval, value = reaper.TrackFX_GetNamedConfigParm(track, fx, param_name)
  if retval then
    return parsePeakString(value)
  end
  return nil
end

-- ============================================================================
-- PLAYBACK STATE (for playback cursor display)
-- Uses VST parameters for cross-format compatibility (VST3/CLAP/AU)
-- Parameter value: -1 = not playing, 0.0-1.0 = progress within start/end region
-- ============================================================================

-- Get the parameter index for a pad's playback progress
local function getPlaybackProgressParamIndex(pad)
  return M.PLAYBACK_PROGRESS_BASE_INDEX + pad
end

-- Check if a pad is currently playing
-- Returns: true if playing, false otherwise
function M.isPadPlaying(track, fx, pad)
  if not track or not fx or fx < 0 then return false end
  if not isValidPad(pad) then return false end

  local param_idx = getPlaybackProgressParamIndex(pad)
  local value = reaper.TrackFX_GetParam(track, fx, param_idx)
  -- Simple: 0 = not playing, >0 = playing
  return value > 0
end

-- Get playback progress for a pad (0-1 within start/end region)
-- Returns: number 0-1 if playing, nil if not playing or error
-- Simple encoding: 0 = not playing, 0.001-1.0 = progress
function M.getPadPlayProgress(track, fx, pad)
  if not track or not fx or fx < 0 then return nil end
  if not isValidPad(pad) then return nil end

  local param_idx = getPlaybackProgressParamIndex(pad)
  local value = reaper.TrackFX_GetParam(track, fx, param_idx)
  -- 0 = not playing, >0 = progress
  if value > 0 then
    return value
  end
  return nil
end

-- Get playback state for visible pads only (optimization)
-- Returns: table { [pad_index] = progress } for playing pads in the given range
function M.getPlaybackStateForPads(track, fx, pad_list)
  if not track or not fx or fx < 0 then return {} end
  if not pad_list then return {} end

  local playing = {}
  for _, pad in ipairs(pad_list) do
    if isValidPad(pad) then
      local progress = M.getPadPlayProgress(track, fx, pad)
      if progress then
        playing[pad] = progress
      end
    end
  end
  return playing
end

-- Get playback state for all playing pads (use sparingly - 128 param reads)
-- Returns: table { [pad_index] = progress } for all pads currently playing
function M.getPlaybackState(track, fx)
  if not track or not fx or fx < 0 then return {} end

  local playing = {}
  for pad = 0, M.NUM_PADS - 1 do
    local progress = M.getPadPlayProgress(track, fx, pad)
    if progress then
      playing[pad] = progress
    end
  end
  return playing
end

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
  if preset.vel_crossfade ~= nil then M.setVelCrossfade(track, fx, pad, preset.vel_crossfade) end
  if preset.vel_curve ~= nil then M.setVelCurve(track, fx, pad, preset.vel_curve) end

  return true
end

-- ============================================================================
-- TIME-STRETCHING (via REAPER glue - like ReaDrum Machine)
-- Creates temp item with playrate, glues it, loads result into VST
-- ============================================================================

-- Pitch modes for stretching (REAPER I_PITCHMODE values)
M.PitchMode = {
  ElastiquePro = 0x00070000,       -- élastique Pro (best quality)
  ElastiqueEfficient = 0x00060000, -- élastique Efficient (lighter CPU)
  ElastiqueSoloist = 0x00080000,   -- élastique SOLOIST (monophonic, vocals)
  Rrreeeaaa = 0x00090000,          -- Rrreeeaaa (REAPER's own, extreme stretch)
  RubberBand = 0x00050000,         -- Rubber Band Library
  SoundTouch = 0x00030000,         -- SoundTouch
  Simple = 0x00020000,             -- Simple windowed sinc
}

-- Ordered list for UI dropdown
M.PitchModeList = {
  { id = 'ElastiquePro', name = 'élastique Pro', value = 0x00070000 },
  { id = 'ElastiqueEfficient', name = 'élastique Efficient', value = 0x00060000 },
  { id = 'ElastiqueSoloist', name = 'élastique SOLOIST', value = 0x00080000 },
  { id = 'Rrreeeaaa', name = 'Rrreeeaaa', value = 0x00090000 },
  { id = 'RubberBand', name = 'Rubber Band', value = 0x00050000 },
  { id = 'SoundTouch', name = 'SoundTouch', value = 0x00030000 },
  { id = 'Simple', name = 'Simple (fast)', value = 0x00020000 },
}

-- Get cache directory for stretched samples
local function getStretchCacheDir()
  local proj_path = reaper.GetProjectPath()
  if not proj_path or proj_path == '' then
    proj_path = reaper.GetResourcePath()
  end
  local cache_dir = proj_path .. '/DrumBlocks_StretchCache/'
  reaper.RecursiveCreateDirectory(cache_dir, 0)
  return cache_dir
end

-- Generate cache key for stretched sample
local function getStretchCacheKey(source_path, stretch_ratio, preserve_pitch, pitch_mode)
  local filename = source_path:match('([^/\\]+)$') or 'sample'
  local base = filename:gsub('%.[^.]+$', '')
  local pitch_flag = preserve_pitch and 'pp' or 'np'
  local mode_hex = string.format('%x', pitch_mode or M.PitchMode.ElastiquePro)
  return string.format('%s_x%.3f_%s_%s', base, stretch_ratio, pitch_flag, mode_hex)
end

-- Check if cached stretched file exists
local function getCachedStretchPath(source_path, stretch_ratio, preserve_pitch, pitch_mode)
  local cache_dir = getStretchCacheDir()
  local cache_key = getStretchCacheKey(source_path, stretch_ratio, preserve_pitch, pitch_mode)
  local cache_path = cache_dir .. cache_key .. '.wav'

  local f = io.open(cache_path, 'r')
  if f then
    f:close()
    return cache_path
  end
  return nil
end

-- Stretch a sample using REAPER's glue (like ReaDrum Machine)
-- Returns path to stretched file, or nil on failure
-- pitch_mode: one of M.PitchMode values (default: ElastiquePro)
function M.stretchSampleGlue(source_path, stretch_ratio, preserve_pitch, pitch_mode)
  if not source_path or source_path == '' then
    log('[Bridge] stretchSampleGlue: no source path\n')
    return nil
  end

  -- Default preserve pitch to true
  if preserve_pitch == nil then preserve_pitch = true end

  -- Default pitch mode to élastique Pro
  pitch_mode = pitch_mode or M.PitchMode.ElastiquePro

  -- No stretch needed
  if math.abs(stretch_ratio - 1.0) < 0.001 then
    return source_path
  end

  -- Check cache first
  local cached = getCachedStretchPath(source_path, stretch_ratio, preserve_pitch, pitch_mode)
  if cached then
    log('[Bridge] stretchSampleGlue: using cached ' .. cached .. '\n')
    return cached
  end

  log('[Bridge] stretchSampleGlue: stretching ' .. source_path .. ' by ' .. stretch_ratio .. 'x\n')

  -- Store current selection state
  local item_count = reaper.CountSelectedMediaItems(0)
  local selected_items = {}
  for i = 0, item_count - 1 do
    selected_items[i] = reaper.GetSelectedMediaItem(0, i)
  end

  -- Create temp track at end
  local track_count = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(track_count, false)
  local temp_track = reaper.GetTrack(0, track_count)

  if not temp_track then
    log('[Bridge] stretchSampleGlue: failed to create temp track\n')
    return nil
  end

  -- Insert source file as media item at position 0
  reaper.SetOnlyTrackSelected(temp_track)
  local item_count_before = reaper.CountMediaItems(0)
  reaper.InsertMedia(source_path, 0)  -- 0 = add to selected track

  -- Find the newly created item
  local item = nil
  for i = item_count_before, reaper.CountMediaItems(0) - 1 do
    local check_item = reaper.GetMediaItem(0, i)
    if reaper.GetMediaItemTrack(check_item) == temp_track then
      item = check_item
      break
    end
  end

  if not item then
    log('[Bridge] stretchSampleGlue: failed to insert media\n')
    reaper.DeleteTrack(temp_track)
    return nil
  end

  local take = reaper.GetActiveTake(item)
  if not take then
    log('[Bridge] stretchSampleGlue: no active take\n')
    reaper.DeleteTrack(temp_track)
    return nil
  end

  -- Get original length
  local source = reaper.GetMediaItemTake_Source(take)
  local src_length = source and reaper.GetMediaSourceLength(source) or 0

  if src_length <= 0 then
    log('[Bridge] stretchSampleGlue: invalid source length\n')
    reaper.DeleteTrack(temp_track)
    return nil
  end

  -- Apply stretch: playrate = 1 / stretch_ratio
  -- stretch 2.0 (twice as long) = playrate 0.5
  local playrate = 1.0 / stretch_ratio
  reaper.SetMediaItemTakeInfo_Value(take, 'D_PLAYRATE', playrate)

  -- Set pitch mode
  reaper.SetMediaItemTakeInfo_Value(take, 'I_PITCHMODE', pitch_mode)

  -- Set preserve pitch flag
  reaper.SetMediaItemTakeInfo_Value(take, 'B_PPITCH', preserve_pitch and 1 or 0)

  -- Update item length to match stretched duration
  local new_length = src_length * stretch_ratio
  reaper.SetMediaItemInfo_Value(item, 'D_LENGTH', new_length)

  -- Select only this item for glue
  reaper.SelectAllMediaItems(0, false)
  reaper.SetMediaItemSelected(item, true)

  -- Glue! (action 41588 = "Item: Glue items")
  reaper.Main_OnCommand(41588, 0)

  -- Get the glued item (should be the only selected item now)
  local glued_item = reaper.GetSelectedMediaItem(0, 0)
  local glued_path = nil

  if glued_item then
    local glued_take = reaper.GetActiveTake(glued_item)
    if glued_take then
      local glued_source = reaper.GetMediaItemTake_Source(glued_take)
      if glued_source then
        glued_path = reaper.GetMediaSourceFileName(glued_source)
      end
    end
  end

  -- Clean up: delete temp track (this also deletes the glued item)
  -- But first, copy the glued file to our cache
  if glued_path and glued_path ~= '' then
    local cache_dir = getStretchCacheDir()
    local cache_key = getStretchCacheKey(source_path, stretch_ratio, preserve_pitch, pitch_mode)
    local cache_path = cache_dir .. cache_key .. '.wav'

    -- Copy glued file to cache (glued file might be in project folder)
    local src_file = io.open(glued_path, 'rb')
    if src_file then
      local content = src_file:read('*a')
      src_file:close()

      local dst_file = io.open(cache_path, 'wb')
      if dst_file then
        dst_file:write(content)
        dst_file:close()
        glued_path = cache_path
        log('[Bridge] stretchSampleGlue: cached to ' .. cache_path .. '\n')
      end
    end
  end

  -- Delete temp track
  reaper.DeleteTrack(temp_track)

  -- Restore previous selection
  reaper.SelectAllMediaItems(0, false)
  for i = 0, #selected_items do
    if selected_items[i] and reaper.ValidatePtr2(0, selected_items[i], 'MediaItem*') then
      reaper.SetMediaItemSelected(selected_items[i], true)
    end
  end

  reaper.UpdateArrange()

  if glued_path then
    log('[Bridge] stretchSampleGlue: success -> ' .. glued_path .. '\n')
    return glued_path
  else
    log('[Bridge] stretchSampleGlue: failed to get glued path\n')
    return nil
  end
end

-- Clear stretch cache
function M.clearStretchCache(source_path)
  local cache_dir = getStretchCacheDir()

  if source_path then
    -- Clear only files for this source
    local cache_key = source_path:match('([^/\\]+)$') or ''
    cache_key = cache_key:gsub('%.[^.]+$', '')

    local i = 0
    while true do
      local file = reaper.EnumerateFiles(cache_dir, i)
      if not file then break end
      if file:find(cache_key, 1, true) then
        os.remove(cache_dir .. file)
      end
      i = i + 1
    end
  else
    -- Clear entire cache
    local i = 0
    while true do
      local file = reaper.EnumerateFiles(cache_dir, i)
      if not file then break end
      os.remove(cache_dir .. file)
      i = i + 1
    end
  end
end

return M
