-- @noindex
-- Blocks/blocks/drum_rack/rs5k_manager.lua
-- RS5K backend manager - handles REAPER track/FX operations
--
-- Architecture (per DECISION.md):
-- - Parent "Drum Rack" track receives all MIDI
-- - Each pad = child track with RS5K instance
-- - RS5K filters to specific MIDI note per pad
-- - REAPER is source of truth for state

local M = {}

-- RS5K parameter indices (from REAPER API)
-- Note: These are normalized 0-1 values
M.PARAMS = {
  FILE = 3,           -- Sample file path (named config: FILE0)
  PITCH = 15,         -- Pitch offset in semitones
  VOLUME = 0,         -- Output volume (0-2, 1=0dB)
  PAN = 1,            -- Pan (-1 to 1)
  NOTE_START = 4,     -- Note range start
  NOTE_END = 5,       -- Note range end
  MIN_VEL = 17,       -- Minimum velocity
  MAX_VEL = 18,       -- Maximum velocity
  OBEY_NOTE_OFF = 11, -- Obey note-offs (0 or 1)
  ATTACK = 9,         -- Attack time (0-1)
  DECAY = 24,         -- Decay time (0-1)
  SUSTAIN = 25,       -- Sustain level (0-1)
  RELEASE = 10,       -- Release time (0-1)
  SAMPLE_START = 13,  -- Sample start offset
  SAMPLE_END = 14,    -- Sample end offset
}

-- Track naming
M.PARENT_PREFIX = '[DrumRack] '
M.PAD_PREFIX = 'Pad '

-- Choke groups JSFX path (relative to this file)
local CHOKE_JSFX_NAME = 'DrumRack Choke Groups'

---Find or create the parent drum rack track
---@param name string? Optional name for the drum rack
---@return MediaTrack|nil parent_track
---@return boolean created True if track was created
function M.find_or_create_parent(name)
  name = name or 'Drum Rack'
  local full_name = M.PARENT_PREFIX .. name

  -- Search for existing parent track
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, track_name = reaper.GetTrackName(track)
    if track_name == full_name then
      return track, false
    end
  end

  -- Create new parent track
  reaper.Undo_BeginBlock()
  reaper.InsertTrackAtIndex(reaper.CountTracks(0), true)
  local parent = reaper.GetTrack(0, reaper.CountTracks(0) - 1)

  if parent then
    reaper.GetSetMediaTrackInfo_String(parent, 'P_NAME', full_name, true)
    -- Make it a folder
    reaper.SetMediaTrackInfo_Value(parent, 'I_FOLDERDEPTH', 1)
    -- Arm for MIDI recording
    reaper.SetMediaTrackInfo_Value(parent, 'I_RECARM', 1)
    reaper.SetMediaTrackInfo_Value(parent, 'I_RECINPUT', 4096 + 63) -- All MIDI
  end

  reaper.Undo_EndBlock('Create Drum Rack track', -1)
  return parent, true
end

---Create a child pad track with RS5K
---@param parent MediaTrack Parent drum rack track
---@param pad_index number Pad index (1-16)
---@param midi_note number MIDI note number
---@param name string? Optional pad name
---@return MediaTrack|nil pad_track
function M.create_pad_track(parent, pad_index, midi_note, name)
  reaper.ShowConsoleMsg(string.format('[RS5K DEBUG] create_pad_track: parent=%s, pad_index=%s, midi_note=%s, name=%s\n',
    tostring(parent), tostring(pad_index), tostring(midi_note), tostring(name)))

  if not parent then
    reaper.ShowConsoleMsg('[RS5K DEBUG] create_pad_track: parent is nil!\n')
    return nil
  end

  local pad_name = name or (M.PAD_PREFIX .. pad_index)

  reaper.Undo_BeginBlock()

  -- Find parent index
  local parent_idx = nil
  for i = 0, reaper.CountTracks(0) - 1 do
    if reaper.GetTrack(0, i) == parent then
      parent_idx = i
      break
    end
  end
  if not parent_idx then
    reaper.ShowConsoleMsg('[RS5K DEBUG] create_pad_track: parent_idx not found!\n')
    reaper.Undo_EndBlock('Create drum pad (failed)', -1)
    return nil
  end
  reaper.ShowConsoleMsg(string.format('[RS5K DEBUG] create_pad_track: parent_idx=%d\n', parent_idx))

  -- Insert track after parent (will become child due to folder depth)
  reaper.InsertTrackAtIndex(parent_idx + 1, true)
  local pad_track = reaper.GetTrack(0, parent_idx + 1)
  reaper.ShowConsoleMsg(string.format('[RS5K DEBUG] create_pad_track: pad_track=%s\n', tostring(pad_track)))

  if pad_track then
    -- Set name
    reaper.GetSetMediaTrackInfo_String(pad_track, 'P_NAME', pad_name, true)

    -- Set as last child in folder
    reaper.SetMediaTrackInfo_Value(pad_track, 'I_FOLDERDEPTH', -1)

    -- Add RS5K
    local fx_idx = reaper.TrackFX_AddByName(pad_track, 'ReaSamplOmatic5000', false, -1)
    reaper.ShowConsoleMsg(string.format('[RS5K DEBUG] create_pad_track: fx_idx=%d\n', fx_idx))

    if fx_idx >= 0 then
      -- Configure RS5K for this MIDI note
      M.set_rs5k_note_range(pad_track, fx_idx, midi_note, midi_note)
      -- Enable obey note-offs by default
      reaper.TrackFX_SetParam(pad_track, fx_idx, M.PARAMS.OBEY_NOTE_OFF, 1)
      reaper.ShowConsoleMsg(string.format('[RS5K DEBUG] create_pad_track: RS5K configured for note %d\n', midi_note))
    else
      reaper.ShowConsoleMsg('[RS5K DEBUG] create_pad_track: Failed to add RS5K!\n')
    end

    -- Set MIDI input from parent
    reaper.SetMediaTrackInfo_Value(pad_track, 'I_RECINPUT', 4096 + 63) -- All MIDI
    reaper.SetMediaTrackInfo_Value(pad_track, 'I_RECMODE', 2) -- Record: MIDI overdub

    -- Receive MIDI from parent
    reaper.SetMediaTrackInfo_Value(pad_track, 'B_MAINSEND', 1)
  end

  reaper.Undo_EndBlock('Create drum pad: ' .. pad_name, -1)
  reaper.ShowConsoleMsg(string.format('[RS5K DEBUG] create_pad_track: returning %s\n', tostring(pad_track)))
  return pad_track
end

---Set RS5K note range
---@param track MediaTrack
---@param fx_idx number FX index
---@param note_start number Start note (0-127)
---@param note_end number End note (0-127)
function M.set_rs5k_note_range(track, fx_idx, note_start, note_end)
  -- RS5K uses 0-1 range for notes, mapped to 0-127
  local start_norm = note_start / 127
  local end_norm = note_end / 127
  reaper.TrackFX_SetParam(track, fx_idx, M.PARAMS.NOTE_START, start_norm)
  reaper.TrackFX_SetParam(track, fx_idx, M.PARAMS.NOTE_END, end_norm)
end

---Load a sample file into RS5K
---@param track MediaTrack
---@param fx_idx number FX index
---@param file_path string Path to audio file
---@return boolean success
function M.load_sample(track, fx_idx, file_path)
  reaper.ShowConsoleMsg(string.format('[RS5K DEBUG] load_sample: track=%s, fx_idx=%d, file_path=%s\n',
    tostring(track), fx_idx, file_path or 'nil'))

  if not track or fx_idx < 0 or not file_path or file_path == '' then
    reaper.ShowConsoleMsg('[RS5K DEBUG] load_sample: invalid args, returning false\n')
    return false
  end

  -- Use named configuration value for file path
  local success = reaper.TrackFX_SetNamedConfigParm(track, fx_idx, 'FILE0', file_path)
  reaper.ShowConsoleMsg(string.format('[RS5K DEBUG] load_sample: SetNamedConfigParm(FILE0) = %s\n', tostring(success)))

  if success then
    -- Trigger RS5K to reload the file
    reaper.TrackFX_SetNamedConfigParm(track, fx_idx, 'DONE', '')
    reaper.ShowConsoleMsg('[RS5K DEBUG] load_sample: triggered DONE reload\n')
  end

  return success
end

---Get the sample file path from RS5K
---@param track MediaTrack
---@param fx_idx number FX index
---@return string|nil file_path
function M.get_sample_path(track, fx_idx)
  if not track or fx_idx < 0 then return nil end

  local retval, path = reaper.TrackFX_GetNamedConfigParm(track, fx_idx, 'FILE0')
  if retval and path and path ~= '' then
    return path
  end
  return nil
end

---Find RS5K FX on a track
---@param track MediaTrack
---@return number fx_idx (-1 if not found)
function M.find_rs5k(track)
  if not track then return -1 end

  local fx_count = reaper.TrackFX_GetCount(track)
  for i = 0, fx_count - 1 do
    local retval, fx_name = reaper.TrackFX_GetFXName(track, i)
    if retval and fx_name:find('ReaSamplOmatic5000') then
      return i
    end
  end
  return -1
end

---Get RS5K parameter value
---@param track MediaTrack
---@param fx_idx number
---@param param_idx number
---@return number|nil value
function M.get_param(track, fx_idx, param_idx)
  if not track or fx_idx < 0 then return nil end
  return reaper.TrackFX_GetParam(track, fx_idx, param_idx)
end

---Set RS5K parameter value
---@param track MediaTrack
---@param fx_idx number
---@param param_idx number
---@param value number
---@return boolean success
function M.set_param(track, fx_idx, param_idx, value)
  if not track or fx_idx < 0 then return false end
  return reaper.TrackFX_SetParam(track, fx_idx, param_idx, value)
end

---Get track volume (as dB)
---@param track MediaTrack
---@return number volume_db
function M.get_track_volume_db(track)
  if not track then return 0 end
  local vol = reaper.GetMediaTrackInfo_Value(track, 'D_VOL')
  return 20 * math.log(vol, 10)
end

---Set track volume (from dB)
---@param track MediaTrack
---@param db number Volume in dB
function M.set_track_volume_db(track, db)
  if not track then return end
  local vol = 10 ^ (db / 20)
  reaper.SetMediaTrackInfo_Value(track, 'D_VOL', vol)
end

---Get track pan (-1 to 1)
---@param track MediaTrack
---@return number pan
function M.get_track_pan(track)
  if not track then return 0 end
  return reaper.GetMediaTrackInfo_Value(track, 'D_PAN')
end

---Set track pan (-1 to 1)
---@param track MediaTrack
---@param pan number
function M.set_track_pan(track, pan)
  if not track then return end
  reaper.SetMediaTrackInfo_Value(track, 'D_PAN', math.max(-1, math.min(1, pan)))
end

---Get track color as 0xRRGGBBAA
---@param track MediaTrack
---@return number color (RGBA format for ImGui)
function M.get_track_color(track)
  if not track then return 0x505050FF end

  local color = reaper.GetTrackColor(track)
  if color == 0 then
    return 0x505050FF  -- Default gray if no color set
  end

  -- REAPER returns BGR, convert to RGBA for ImGui
  local r = (color >> 0) & 0xFF
  local g = (color >> 8) & 0xFF
  local b = (color >> 16) & 0xFF

  return (r << 24) | (g << 16) | (b << 8) | 0xFF
end

---Set track color from 0xRRGGBBAA
---@param track MediaTrack
---@param color number RGBA format
function M.set_track_color(track, color)
  if not track then return end

  -- Convert RGBA to REAPER BGR
  local r = (color >> 24) & 0xFF
  local g = (color >> 16) & 0xFF
  local b = (color >> 8) & 0xFF

  local bgr = (b << 16) | (g << 8) | r
  reaper.SetTrackColor(track, bgr)
end

---Get track playback offset (delay) in milliseconds
---@param track MediaTrack
---@return number delay_ms
function M.get_track_delay(track)
  if not track then return 0 end
  -- D_PLAY_OFFSET is in seconds
  local offset = reaper.GetMediaTrackInfo_Value(track, 'D_PLAY_OFFSET')
  return offset * 1000  -- Convert to ms
end

---Set track playback offset (delay) in milliseconds
---@param track MediaTrack
---@param delay_ms number Delay in milliseconds (-500 to +500 typical range)
function M.set_track_delay(track, delay_ms)
  if not track then return end
  -- Clamp to reasonable range
  delay_ms = math.max(-500, math.min(500, delay_ms))
  reaper.SetMediaTrackInfo_Value(track, 'D_PLAY_OFFSET', delay_ms / 1000)
end

---Get pitch offset from RS5K (in semitones)
---@param track MediaTrack
---@param fx_idx number
---@return number semitones
function M.get_pitch(track, fx_idx)
  local val = M.get_param(track, fx_idx, M.PARAMS.PITCH)
  if val then
    -- RS5K pitch is 0-1 mapped to -96 to +96 semitones
    return (val - 0.5) * 192
  end
  return 0
end

---Set pitch offset in RS5K (in semitones)
---@param track MediaTrack
---@param fx_idx number
---@param semitones number (-96 to +96)
function M.set_pitch(track, fx_idx, semitones)
  -- Clamp and normalize
  semitones = math.max(-96, math.min(96, semitones))
  local norm = (semitones / 192) + 0.5
  M.set_param(track, fx_idx, M.PARAMS.PITCH, norm)
end

---Scan for existing drum rack structure
---@return table|nil rack_info { parent = track, pads = { {track, fx_idx, note, name}, ... } }
function M.scan_existing_rack()
  local parent = nil

  -- Find parent track
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)
    if name:find(M.PARENT_PREFIX, 1, true) == 1 then
      parent = track
      break
    end
  end

  if not parent then return nil end

  -- Find parent index
  local parent_idx = nil
  for i = 0, reaper.CountTracks(0) - 1 do
    if reaper.GetTrack(0, i) == parent then
      parent_idx = i
      break
    end
  end

  -- Collect child tracks with RS5K
  local pads = {}
  local folder_depth = 1

  for i = parent_idx + 1, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local depth = reaper.GetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH')

    -- Check if still in folder
    folder_depth = folder_depth + depth
    if folder_depth <= 0 then break end

    -- Check for RS5K
    local fx_idx = M.find_rs5k(track)
    if fx_idx >= 0 then
      local _, track_name = reaper.GetTrackName(track)
      local note_start = M.get_param(track, fx_idx, M.PARAMS.NOTE_START)
      local midi_note = note_start and math.floor(note_start * 127 + 0.5) or 36

      table.insert(pads, {
        track = track,
        fx_idx = fx_idx,
        note = midi_note,
        name = track_name,
        sample_path = M.get_sample_path(track, fx_idx),
      })
    end
  end

  return {
    parent = parent,
    pads = pads,
  }
end

-- Active preview notes (for note-off scheduling)
local active_previews = {}

---Trigger a preview note (sends MIDI to the track)
---@param track MediaTrack
---@param note number MIDI note
---@param velocity number? Velocity (1-127), default 100
---@param duration number? Duration in seconds, default 0.3
function M.preview_note(track, note, velocity, duration)
  if not track then return end

  velocity = velocity or 100
  duration = duration or 0.3

  -- Send note-off for any existing preview of this note
  if active_previews[note] then
    reaper.StuffMIDIMessage(0, 0x80, note, 0)
  end

  -- Send note on (mode 0 = Virtual MIDI Keyboard)
  reaper.StuffMIDIMessage(0, 0x90, note, velocity)

  -- Schedule note off
  local start_time = reaper.time_precise()
  active_previews[note] = start_time

  local function check_noteoff()
    -- Only send note-off if this is still our preview
    if active_previews[note] == start_time then
      local elapsed = reaper.time_precise() - start_time
      if elapsed >= duration then
        reaper.StuffMIDIMessage(0, 0x80, note, 0)
        active_previews[note] = nil
      else
        reaper.defer(check_noteoff)
      end
    end
  end

  reaper.defer(check_noteoff)
end

---Stop all preview notes immediately
function M.stop_all_previews()
  for note, _ in pairs(active_previews) do
    reaper.StuffMIDIMessage(0, 0x80, note, 0)
  end
  active_previews = {}
end

---Clear sample from RS5K (keep track, remove sample)
---@param track MediaTrack
---@param fx_idx number
---@return boolean success
function M.clear_sample(track, fx_idx)
  if not track or fx_idx < 0 then return false end

  -- Clear file path
  local success = reaper.TrackFX_SetNamedConfigParm(track, fx_idx, 'FILE0', '')
  if success then
    reaper.TrackFX_SetNamedConfigParm(track, fx_idx, 'DONE', '')
  end
  return success
end

---Delete a pad track entirely
---@param track MediaTrack
---@return boolean success
function M.delete_pad_track(track)
  if not track then return false end
  if not reaper.ValidatePtr2(0, track, 'MediaTrack*') then return false end

  reaper.Undo_BeginBlock()

  -- Get track index
  local track_idx = nil
  for i = 0, reaper.CountTracks(0) - 1 do
    if reaper.GetTrack(0, i) == track then
      track_idx = i
      break
    end
  end

  if track_idx then
    reaper.DeleteTrack(track)
    reaper.Undo_EndBlock('Delete drum pad track', -1)
    return true
  end

  reaper.Undo_EndBlock('Delete drum pad (failed)', -1)
  return false
end

---Open FX window for a track
---@param track MediaTrack
---@param fx_idx number? Specific FX to show (optional)
function M.show_fx_window(track, fx_idx)
  if not track then return end

  if fx_idx and fx_idx >= 0 then
    -- Show specific FX
    reaper.TrackFX_Show(track, fx_idx, 3)  -- 3 = show floating window
  else
    -- Show FX chain
    reaper.TrackFX_Show(track, 0, 1)  -- 1 = show chain
  end
end

-- ============================================================================
-- CHOKE GROUPS
-- ============================================================================

---Get the path to the choke groups JSFX
---@return string path
local function get_choke_jsfx_path()
  local source = debug.getinfo(1, 'S').source:sub(2)
  local dir = source:match('(.*[/\\])')
  return dir .. 'jsfx/DrumRack_ChokeGroups.jsfx'
end

---Find choke groups JSFX on parent track
---@param track MediaTrack
---@return number fx_idx (-1 if not found)
function M.find_choke_fx(track)
  if not track then return -1 end

  local fx_count = reaper.TrackFX_GetCount(track)
  for i = 0, fx_count - 1 do
    local retval, fx_name = reaper.TrackFX_GetFXName(track, i)
    if retval and fx_name:find('DrumRack Choke') then
      return i
    end
  end
  return -1
end

---Add choke groups JSFX to parent track
---@param track MediaTrack Parent drum rack track
---@return number fx_idx (-1 if failed)
function M.add_choke_fx(track)
  if not track then return -1 end

  -- Check if already exists
  local existing = M.find_choke_fx(track)
  if existing >= 0 then return existing end

  -- Try to add by full path first
  local jsfx_path = get_choke_jsfx_path()
  local fx_idx = reaper.TrackFX_AddByName(track, jsfx_path, false, -1)

  if fx_idx < 0 then
    -- Try by name (if installed in REAPER's Effects folder)
    fx_idx = reaper.TrackFX_AddByName(track, 'JS: ' .. CHOKE_JSFX_NAME, false, -1)
  end

  if fx_idx >= 0 then
    -- Move to first slot (before any other FX) so it processes MIDI first
    if fx_idx > 0 then
      reaper.TrackFX_CopyToTrack(track, fx_idx, track, 0, true)
      fx_idx = 0
    end
    reaper.ShowConsoleMsg('[DrumRack] Added choke groups JSFX\n')
  else
    reaper.ShowConsoleMsg('[DrumRack] Warning: Could not add choke groups JSFX\n')
  end

  return fx_idx
end

---Configure a choke group
---@param track MediaTrack Parent track with choke JSFX
---@param group number Group number (1-4)
---@param notes table Array of MIDI note numbers
---@return boolean success
function M.set_choke_group(track, group, notes)
  if not track or group < 1 or group > 4 then return false end

  local fx_idx = M.find_choke_fx(track)
  if fx_idx < 0 then return false end

  -- Each group has 8 slider slots
  -- Group 1: sliders 1-8, Group 2: sliders 9-16, etc.
  local base_param = (group - 1) * 8

  -- Set notes (pad with 0 for unused slots)
  for i = 1, 8 do
    local note = notes[i] or 0
    local param_idx = base_param + (i - 1)
    -- Normalize note to 0-1 range (slider range is 0-127)
    reaper.TrackFX_SetParam(track, fx_idx, param_idx, note / 127)
  end

  return true
end

---Get choke group configuration
---@param track MediaTrack Parent track with choke JSFX
---@param group number Group number (1-4)
---@return table|nil notes Array of MIDI note numbers
function M.get_choke_group(track, group)
  if not track or group < 1 or group > 4 then return nil end

  local fx_idx = M.find_choke_fx(track)
  if fx_idx < 0 then return nil end

  local base_param = (group - 1) * 8
  local notes = {}

  for i = 1, 8 do
    local param_idx = base_param + (i - 1)
    local val = reaper.TrackFX_GetParam(track, fx_idx, param_idx)
    local note = math.floor(val * 127 + 0.5)
    if note > 0 then
      table.insert(notes, note)
    end
  end

  return notes
end

---Add a note to a choke group
---@param track MediaTrack
---@param group number Group number (1-4)
---@param note number MIDI note to add
---@return boolean success
function M.add_note_to_choke_group(track, group, note)
  local notes = M.get_choke_group(track, group) or {}

  -- Check if note already in group
  for _, n in ipairs(notes) do
    if n == note then return true end
  end

  -- Add note if there's room
  if #notes >= 8 then return false end
  table.insert(notes, note)

  return M.set_choke_group(track, group, notes)
end

---Remove a note from a choke group
---@param track MediaTrack
---@param group number Group number (1-4)
---@param note number MIDI note to remove
---@return boolean success
function M.remove_note_from_choke_group(track, group, note)
  local notes = M.get_choke_group(track, group)
  if not notes then return false end

  local new_notes = {}
  for _, n in ipairs(notes) do
    if n ~= note then
      table.insert(new_notes, n)
    end
  end

  return M.set_choke_group(track, group, new_notes)
end

-- ============================================================================
-- VELOCITY LAYERS
-- ============================================================================

---Get all RS5K instances on a track (for velocity layers)
---@param track MediaTrack
---@return table layers Array of {fx_idx, vel_min, vel_max, sample_path}
function M.get_velocity_layers(track)
  if not track then return {} end

  local layers = {}
  local fx_count = reaper.TrackFX_GetCount(track)

  for i = 0, fx_count - 1 do
    local retval, fx_name = reaper.TrackFX_GetFXName(track, i)
    if retval and fx_name:find('ReaSamplOmatic5000') then
      local vel_min = M.get_param(track, i, M.PARAMS.MIN_VEL)
      local vel_max = M.get_param(track, i, M.PARAMS.MAX_VEL)
      local sample_path = M.get_sample_path(track, i)

      table.insert(layers, {
        fx_idx = i,
        vel_min = vel_min and math.floor(vel_min * 127 + 0.5) or 0,
        vel_max = vel_max and math.floor(vel_max * 127 + 0.5) or 127,
        sample_path = sample_path,
      })
    end
  end

  return layers
end

---Add a velocity layer to a pad track
---@param track MediaTrack
---@param vel_min number Minimum velocity (0-127)
---@param vel_max number Maximum velocity (0-127)
---@param sample_path string? Optional sample to load
---@return number fx_idx (-1 if failed)
function M.add_velocity_layer(track, vel_min, vel_max, sample_path)
  if not track then return -1 end

  -- Add new RS5K instance
  local fx_idx = reaper.TrackFX_AddByName(track, 'ReaSamplOmatic5000', false, -1)
  if fx_idx < 0 then return -1 end

  -- Set velocity range
  reaper.TrackFX_SetParam(track, fx_idx, M.PARAMS.MIN_VEL, vel_min / 127)
  reaper.TrackFX_SetParam(track, fx_idx, M.PARAMS.MAX_VEL, vel_max / 127)

  -- Copy note range from first RS5K
  local first_rs5k = M.find_rs5k(track)
  if first_rs5k >= 0 and first_rs5k ~= fx_idx then
    local note_start = M.get_param(track, first_rs5k, M.PARAMS.NOTE_START)
    local note_end = M.get_param(track, first_rs5k, M.PARAMS.NOTE_END)
    if note_start then
      reaper.TrackFX_SetParam(track, fx_idx, M.PARAMS.NOTE_START, note_start)
    end
    if note_end then
      reaper.TrackFX_SetParam(track, fx_idx, M.PARAMS.NOTE_END, note_end)
    end
  end

  -- Enable obey note-offs
  reaper.TrackFX_SetParam(track, fx_idx, M.PARAMS.OBEY_NOTE_OFF, 1)

  -- Load sample if provided
  if sample_path and sample_path ~= '' then
    M.load_sample(track, fx_idx, sample_path)
  end

  return fx_idx
end

---Remove a velocity layer
---@param track MediaTrack
---@param fx_idx number FX index to remove
---@return boolean success
function M.remove_velocity_layer(track, fx_idx)
  if not track or fx_idx < 0 then return false end

  -- Don't remove if it's the only RS5K
  local layers = M.get_velocity_layers(track)
  if #layers <= 1 then return false end

  reaper.TrackFX_Delete(track, fx_idx)
  return true
end

---Set velocity range for an RS5K layer
---@param track MediaTrack
---@param fx_idx number
---@param vel_min number (0-127)
---@param vel_max number (0-127)
function M.set_velocity_range(track, fx_idx, vel_min, vel_max)
  if not track or fx_idx < 0 then return end
  reaper.TrackFX_SetParam(track, fx_idx, M.PARAMS.MIN_VEL, vel_min / 127)
  reaper.TrackFX_SetParam(track, fx_idx, M.PARAMS.MAX_VEL, vel_max / 127)
end

---Auto-distribute velocity ranges across layers
---@param track MediaTrack
function M.auto_distribute_velocity(track)
  local layers = M.get_velocity_layers(track)
  if #layers <= 1 then return end

  local range_per_layer = 127 / #layers
  for i, layer in ipairs(layers) do
    local vel_min = math.floor((i - 1) * range_per_layer)
    local vel_max = math.floor(i * range_per_layer) - 1
    if i == #layers then vel_max = 127 end  -- Ensure last layer reaches 127

    M.set_velocity_range(track, layer.fx_idx, vel_min, vel_max)
  end
end

-- ============================================================================
-- VISIBILITY CONTROLS
-- ============================================================================

---Check if folder is collapsed
---@param track MediaTrack
---@return boolean collapsed
function M.is_folder_collapsed(track)
  if not track then return false end
  local state = reaper.GetMediaTrackInfo_Value(track, 'I_FOLDERCOMPACT')
  return state == 2  -- 2 = fully collapsed (small), 1 = partially collapsed, 0 = expanded
end

---Collapse or expand folder
---@param track MediaTrack
---@param collapsed boolean
function M.set_folder_collapsed(track, collapsed)
  if not track then return end
  reaper.SetMediaTrackInfo_Value(track, 'I_FOLDERCOMPACT', collapsed and 2 or 0)
end

---Toggle folder collapsed state
---@param track MediaTrack
---@return boolean new_state
function M.toggle_folder_collapsed(track)
  local collapsed = M.is_folder_collapsed(track)
  M.set_folder_collapsed(track, not collapsed)
  return not collapsed
end

---Check if track is visible in TCP (arrange)
---@param track MediaTrack
---@return boolean visible
function M.is_visible_in_tcp(track)
  if not track then return false end
  return reaper.GetMediaTrackInfo_Value(track, 'B_SHOWINTCP') == 1
end

---Set track visibility in TCP
---@param track MediaTrack
---@param visible boolean
function M.set_visible_in_tcp(track, visible)
  if not track then return end
  reaper.SetMediaTrackInfo_Value(track, 'B_SHOWINTCP', visible and 1 or 0)
end

---Check if track is visible in MCP (mixer)
---@param track MediaTrack
---@return boolean visible
function M.is_visible_in_mcp(track)
  if not track then return false end
  return reaper.GetMediaTrackInfo_Value(track, 'B_SHOWINMIXER') == 1
end

---Set track visibility in MCP
---@param track MediaTrack
---@param visible boolean
function M.set_visible_in_mcp(track, visible)
  if not track then return end
  reaper.SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', visible and 1 or 0)
end

---Get all child tracks of a folder
---@param parent MediaTrack
---@return table children Array of child tracks
function M.get_child_tracks(parent)
  if not parent then return {} end

  local children = {}
  local parent_idx = nil

  -- Find parent index
  for i = 0, reaper.CountTracks(0) - 1 do
    if reaper.GetTrack(0, i) == parent then
      parent_idx = i
      break
    end
  end

  if not parent_idx then return children end

  -- Collect children
  local folder_depth = 1
  for i = parent_idx + 1, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local depth = reaper.GetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH')

    folder_depth = folder_depth + depth
    if folder_depth <= 0 then break end

    table.insert(children, track)
  end

  return children
end

---Show all pad tracks in mixer
---@param parent MediaTrack
function M.show_all_in_mixer(parent)
  local children = M.get_child_tracks(parent)
  for _, track in ipairs(children) do
    M.set_visible_in_mcp(track, true)
  end
end

---Hide all pad tracks from mixer
---@param parent MediaTrack
function M.hide_all_from_mixer(parent)
  local children = M.get_child_tracks(parent)
  for _, track in ipairs(children) do
    M.set_visible_in_mcp(track, false)
  end
end

---Show all pad tracks in arrange
---@param parent MediaTrack
function M.show_all_in_arrange(parent)
  local children = M.get_child_tracks(parent)
  for _, track in ipairs(children) do
    M.set_visible_in_tcp(track, true)
  end
end

---Hide all pad tracks from arrange
---@param parent MediaTrack
function M.hide_all_from_arrange(parent)
  local children = M.get_child_tracks(parent)
  for _, track in ipairs(children) do
    M.set_visible_in_tcp(track, false)
  end
end

return M
