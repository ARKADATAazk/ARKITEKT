-- @noindex
-- MIDIHelix/domain/transforms/melodic.lua
-- Melodic transformations: Inversion, Retrograde, Transpose, Rotation

local M = {}

local Scales = require('scripts.MIDIHelix.domain.scales')

-- ============================================================================
-- INVERSION
-- ============================================================================

--- Invert notes around a pivot point (chromatic)
--- @param notes table Array of note tables with .pitch
--- @param pivot number Pivot MIDI note
--- @return table Transformed notes
function M.invert_chromatic(notes, pivot)
  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end
    -- Chromatic inversion: new_pitch = pivot - (old_pitch - pivot) = 2*pivot - old_pitch
    new_note.pitch = 2 * pivot - note.pitch
    -- Clamp to MIDI range
    new_note.pitch = math.max(0, math.min(127, new_note.pitch))
    result[i] = new_note
  end
  return result
end

--- Invert notes around a pivot point (diatonic - stays in scale)
--- @param notes table Array of note tables with .pitch
--- @param pivot number Pivot MIDI note
--- @param scale table Scale definition
--- @param root number Scale root (0-11)
--- @return table Transformed notes
function M.invert_diatonic(notes, pivot, scale, root)
  -- Get scale degree of pivot
  local function pitch_to_degree(pitch, scale_intervals, root)
    local octave = math.floor((pitch - root) / 12)
    local pc = (pitch - root) % 12
    for deg, interval in ipairs(scale_intervals) do
      if interval == pc then
        return (octave * #scale_intervals) + deg
      end
    end
    -- Not in scale, find nearest
    local min_dist = 12
    local nearest_deg = 1
    for deg, interval in ipairs(scale_intervals) do
      local dist = math.abs(interval - pc)
      if dist < min_dist then
        min_dist = dist
        nearest_deg = deg
      end
    end
    return (octave * #scale_intervals) + nearest_deg
  end

  local function degree_to_pitch(degree, scale_intervals, root)
    local num_notes = #scale_intervals
    local octave = math.floor((degree - 1) / num_notes)
    local idx = ((degree - 1) % num_notes) + 1
    return root + octave * 12 + scale_intervals[idx]
  end

  local pivot_degree = pitch_to_degree(pivot, scale.intervals, root)

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end
    local degree = pitch_to_degree(note.pitch, scale.intervals, root)
    local inverted_degree = 2 * pivot_degree - degree
    new_note.pitch = degree_to_pitch(inverted_degree, scale.intervals, root)
    new_note.pitch = math.max(0, math.min(127, new_note.pitch))
    result[i] = new_note
  end
  return result
end

-- ============================================================================
-- RETROGRADE
-- ============================================================================

--- Reverse the order of notes (retrograde)
--- @param notes table Array of note tables
--- @param preserve_timing boolean Keep original start times (reverse pitches only)
--- @return table Transformed notes
function M.retrograde(notes, preserve_timing)
  if #notes == 0 then return {} end

  local result = {}

  if preserve_timing then
    -- Reverse pitches only, keep timing
    local pitches = {}
    for i, note in ipairs(notes) do
      pitches[i] = note.pitch
    end
    -- Reverse pitches
    for i = 1, #pitches / 2 do
      pitches[i], pitches[#pitches - i + 1] = pitches[#pitches - i + 1], pitches[i]
    end
    -- Apply reversed pitches
    for i, note in ipairs(notes) do
      local new_note = {}
      for k, v in pairs(note) do
        new_note[k] = v
      end
      new_note.pitch = pitches[i]
      result[i] = new_note
    end
  else
    -- Reverse everything, recalculate timing
    local total_end = notes[#notes].end_ppq
    local first_start = notes[1].start_ppq

    for i = #notes, 1, -1 do
      local note = notes[i]
      local new_note = {}
      for k, v in pairs(note) do
        new_note[k] = v
      end
      -- Mirror timing
      local duration = note.end_ppq - note.start_ppq
      new_note.start_ppq = total_end - note.end_ppq + first_start
      new_note.end_ppq = new_note.start_ppq + duration
      result[#result + 1] = new_note
    end
  end

  return result
end

--- Retrograde inversion (reverse + invert)
--- @param notes table Array of note tables
--- @param pivot number Pivot MIDI note
--- @param preserve_timing boolean Keep original start times
--- @return table Transformed notes
function M.retrograde_inversion(notes, pivot, preserve_timing)
  local inverted = M.invert_chromatic(notes, pivot)
  return M.retrograde(inverted, preserve_timing)
end

-- ============================================================================
-- TRANSPOSE
-- ============================================================================

--- Transpose notes by interval (chromatic)
--- @param notes table Array of note tables
--- @param semitones number Semitones to transpose (-24 to +24)
--- @return table Transformed notes
function M.transpose_chromatic(notes, semitones)
  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end
    new_note.pitch = math.max(0, math.min(127, note.pitch + semitones))
    result[i] = new_note
  end
  return result
end

--- Transpose notes by scale degrees (diatonic)
--- @param notes table Array of note tables
--- @param degrees number Scale degrees to transpose
--- @param scale table Scale definition
--- @param root number Scale root (0-11)
--- @return table Transformed notes
function M.transpose_diatonic(notes, degrees, scale, root)
  local function pitch_to_degree(pitch, scale_intervals, root)
    local octave = math.floor((pitch - root) / 12)
    local pc = (pitch - root) % 12
    for deg, interval in ipairs(scale_intervals) do
      if interval == pc then
        return (octave * #scale_intervals) + deg
      end
    end
    -- Find nearest scale degree
    local min_dist = 12
    local nearest_deg = 1
    for deg, interval in ipairs(scale_intervals) do
      local dist = math.abs(interval - pc)
      if dist < min_dist then
        min_dist = dist
        nearest_deg = deg
      end
    end
    return (octave * #scale_intervals) + nearest_deg
  end

  local function degree_to_pitch(degree, scale_intervals, root)
    local num_notes = #scale_intervals
    local octave = math.floor((degree - 1) / num_notes)
    local idx = ((degree - 1) % num_notes) + 1
    if idx < 1 then idx = idx + num_notes; octave = octave - 1 end
    return root + octave * 12 + scale_intervals[idx]
  end

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end
    local degree = pitch_to_degree(note.pitch, scale.intervals, root)
    local new_degree = degree + degrees
    new_note.pitch = degree_to_pitch(new_degree, scale.intervals, root)
    new_note.pitch = math.max(0, math.min(127, new_note.pitch))
    result[i] = new_note
  end
  return result
end

-- ============================================================================
-- ROTATION (Pitch Rotation)
-- ============================================================================

--- Rotate pitches (shift pitches while keeping timing)
--- @param notes table Array of note tables
--- @param amount number Number of positions to rotate (positive = right)
--- @return table Transformed notes
function M.rotate_pitches(notes, amount)
  if #notes == 0 then return {} end

  local pitches = {}
  for i, note in ipairs(notes) do
    pitches[i] = note.pitch
  end

  -- Rotate pitches array
  local n = #pitches
  amount = amount % n
  if amount < 0 then amount = amount + n end

  local rotated = {}
  for i = 1, n do
    local src_idx = ((i - 1 - amount) % n) + 1
    rotated[i] = pitches[src_idx]
  end

  -- Apply rotated pitches
  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end
    new_note.pitch = rotated[i]
    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- SCALE QUANTIZE
-- ============================================================================

--- Quantize notes to nearest scale degree
--- @param notes table Array of note tables
--- @param scale table Scale definition
--- @param root number Scale root (0-11)
--- @param direction string 'nearest', 'up', or 'down'
--- @return table Transformed notes
function M.scale_quantize(notes, scale, root, direction)
  direction = direction or 'nearest'

  local function quantize_pitch(pitch, scale_intervals, root, dir)
    local pc = (pitch - root) % 12
    local octave = math.floor((pitch - root) / 12)

    -- Check if already in scale
    for _, interval in ipairs(scale_intervals) do
      if interval == pc then
        return pitch
      end
    end

    -- Find nearest scale note
    if dir == 'up' then
      for _, interval in ipairs(scale_intervals) do
        if interval > pc then
          return root + octave * 12 + interval
        end
      end
      -- Wrap to next octave
      return root + (octave + 1) * 12 + scale_intervals[1]
    elseif dir == 'down' then
      for i = #scale_intervals, 1, -1 do
        if scale_intervals[i] < pc then
          return root + octave * 12 + scale_intervals[i]
        end
      end
      -- Wrap to previous octave
      return root + (octave - 1) * 12 + scale_intervals[#scale_intervals]
    else
      -- Nearest
      local min_dist = 12
      local nearest = pitch
      for _, interval in ipairs(scale_intervals) do
        local scale_pitch = root + octave * 12 + interval
        local dist = math.abs(pitch - scale_pitch)
        if dist < min_dist then
          min_dist = dist
          nearest = scale_pitch
        end
        -- Also check adjacent octaves
        scale_pitch = root + (octave + 1) * 12 + interval
        dist = math.abs(pitch - scale_pitch)
        if dist < min_dist then
          min_dist = dist
          nearest = scale_pitch
        end
        scale_pitch = root + (octave - 1) * 12 + interval
        dist = math.abs(pitch - scale_pitch)
        if dist < min_dist then
          min_dist = dist
          nearest = scale_pitch
        end
      end
      return nearest
    end
  end

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end
    new_note.pitch = quantize_pitch(note.pitch, scale.intervals, root, direction)
    new_note.pitch = math.max(0, math.min(127, new_note.pitch))
    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- OCTAVE FOLD
-- ============================================================================

--- Fold all notes into a single octave
--- @param notes table Array of note tables
--- @param target_octave number Target octave (0-8)
--- @return table Transformed notes
function M.octave_fold(notes, target_octave)
  local base = (target_octave + 1) * 12

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end
    local pc = note.pitch % 12
    new_note.pitch = base + pc
    result[i] = new_note
  end

  return result
end

return M
