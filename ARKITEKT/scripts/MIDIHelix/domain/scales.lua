-- @noindex
-- MIDIHelix/domain/scales.lua
-- Scale definitions and utilities

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

M.NOTES = { 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B' }

-- Scale definitions: intervals from root (0 = root, 12 = octave)
M.SCALES = {
  { name = 'Chromatic',      intervals = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 } },
  { name = 'Major',          intervals = { 0, 2, 4, 5, 7, 9, 11 } },
  { name = 'Minor',          intervals = { 0, 2, 3, 5, 7, 8, 10 } },
  { name = 'Dorian',         intervals = { 0, 2, 3, 5, 7, 9, 10 } },
  { name = 'Phrygian',       intervals = { 0, 1, 3, 5, 7, 8, 10 } },
  { name = 'Lydian',         intervals = { 0, 2, 4, 6, 7, 9, 11 } },
  { name = 'Mixolydian',     intervals = { 0, 2, 4, 5, 7, 9, 10 } },
  { name = 'Locrian',        intervals = { 0, 1, 3, 5, 6, 8, 10 } },
  { name = 'Harmonic Minor', intervals = { 0, 2, 3, 5, 7, 8, 11 } },
  { name = 'Melodic Minor',  intervals = { 0, 2, 3, 5, 7, 9, 11 } },
  { name = 'Pentatonic Maj', intervals = { 0, 2, 4, 7, 9 } },
  { name = 'Pentatonic Min', intervals = { 0, 3, 5, 7, 10 } },
  { name = 'Blues',          intervals = { 0, 3, 5, 6, 7, 10 } },
  { name = 'Whole Tone',     intervals = { 0, 2, 4, 6, 8, 10 } },
  { name = 'Diminished',     intervals = { 0, 2, 3, 5, 6, 8, 9, 11 } },
}

-- ============================================================================
-- UTILITIES
-- ============================================================================

--- Get scale names list
--- @return table List of scale names
function M.get_scale_names()
  local names = {}
  for i, scale in ipairs(M.SCALES) do
    names[i] = scale.name
  end
  return names
end

--- Get scale by name
--- @param name string Scale name
--- @return table|nil Scale definition or nil
function M.get_scale(name)
  for _, scale in ipairs(M.SCALES) do
    if scale.name == name then
      return scale
    end
  end
  return nil
end

--- Get scale by index
--- @param index number Scale index (1-based)
--- @return table|nil Scale definition or nil
function M.get_scale_by_index(index)
  return M.SCALES[index]
end

--- Get note name from MIDI note number
--- @param midi_note number MIDI note (0-127)
--- @return string Note name (e.g., 'C#4')
function M.midi_to_name(midi_note)
  local octave = math.floor(midi_note / 12) - 1
  local note_idx = (midi_note % 12) + 1
  return M.NOTES[note_idx] .. tostring(octave)
end

--- Get MIDI note from note name
--- @param name string Note name (e.g., 'C#4')
--- @return number|nil MIDI note or nil
function M.name_to_midi(name)
  local note_name = name:match('^([A-G]#?)')
  local octave = tonumber(name:match('(-?%d+)$'))
  if not note_name or not octave then return nil end

  local note_idx = nil
  for i, n in ipairs(M.NOTES) do
    if n == note_name then
      note_idx = i - 1
      break
    end
  end
  if not note_idx then return nil end

  return (octave + 1) * 12 + note_idx
end

--- Check if a note is in a scale
--- @param midi_note number MIDI note
--- @param root number Root note (0-11)
--- @param scale table Scale definition
--- @return boolean
function M.note_in_scale(midi_note, root, scale)
  local interval = (midi_note - root) % 12
  for _, int in ipairs(scale.intervals) do
    if int == interval then
      return true
    end
  end
  return false
end

--- Get scale notes for a given root
--- @param root number Root note (0-11, where 0=C)
--- @param scale table Scale definition
--- @param octave number Octave (default 4)
--- @return table List of MIDI notes
function M.get_scale_notes(root, scale, octave)
  octave = octave or 4
  local base = (octave + 1) * 12 + root
  local notes = {}
  for i, interval in ipairs(scale.intervals) do
    notes[i] = base + interval
  end
  return notes
end

--- Create a boolean mask for which notes are in a scale (12 values)
--- @param scale table Scale definition
--- @return table Boolean array [1-12] = true/false
function M.get_scale_mask(scale)
  local mask = {}
  for i = 1, 12 do
    mask[i] = false
  end
  for _, interval in ipairs(scale.intervals) do
    mask[interval + 1] = true
  end
  return mask
end

return M
