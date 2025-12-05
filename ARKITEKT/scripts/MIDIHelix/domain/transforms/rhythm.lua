-- @noindex
-- MIDIHelix/domain/transforms/rhythm.lua
-- Rhythm transformations: Augment/Diminish, Quantize, Swing, Humanize

local M = {}

local PPQN = 960  -- Standard pulses per quarter note

-- ============================================================================
-- AUGMENT / DIMINISH
-- ============================================================================

--- Scale note timing by a factor (augment/diminish)
--- @param notes table Array of note tables
--- @param factor number Scale factor (0.25 to 4.0)
--- @param opts table Options { affect_durations, affect_positions, affect_velocities }
--- @return table Transformed notes
function M.augment_diminish(notes, factor, opts)
  opts = opts or {}
  local affect_durations = opts.affect_durations ~= false  -- default true
  local affect_positions = opts.affect_positions ~= false  -- default true
  local affect_velocities = opts.affect_velocities or false

  if #notes == 0 then return {} end

  local first_start = notes[1].start_ppq

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    if affect_positions then
      -- Scale position relative to first note
      local offset = note.start_ppq - first_start
      new_note.start_ppq = first_start + math.floor(offset * factor)
    end

    if affect_durations then
      local duration = note.end_ppq - note.start_ppq
      new_note.end_ppq = new_note.start_ppq + math.floor(duration * factor)
    else
      -- Keep original duration
      local duration = note.end_ppq - note.start_ppq
      new_note.end_ppq = new_note.start_ppq + duration
    end

    if affect_velocities then
      -- Scale velocity (clamped)
      new_note.velocity = math.max(1, math.min(127, math.floor(note.velocity * factor)))
    end

    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- QUANTIZE
-- ============================================================================

--- Quantize note positions to grid
--- @param notes table Array of note tables
--- @param grid_ppq number Grid size in PPQ
--- @param strength number Quantize strength (0.0 to 1.0)
--- @param quantize_ends boolean Also quantize note ends
--- @return table Transformed notes
function M.quantize(notes, grid_ppq, strength, quantize_ends)
  strength = strength or 1.0
  grid_ppq = grid_ppq or (PPQN / 4)  -- Default 1/16

  local function snap_to_grid(pos, grid, str)
    local nearest = math.floor(pos / grid + 0.5) * grid
    return math.floor(pos + (nearest - pos) * str)
  end

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    local duration = note.end_ppq - note.start_ppq
    new_note.start_ppq = snap_to_grid(note.start_ppq, grid_ppq, strength)

    if quantize_ends then
      new_note.end_ppq = snap_to_grid(note.end_ppq, grid_ppq, strength)
      -- Ensure minimum duration
      if new_note.end_ppq <= new_note.start_ppq then
        new_note.end_ppq = new_note.start_ppq + grid_ppq
      end
    else
      -- Preserve duration
      new_note.end_ppq = new_note.start_ppq + duration
    end

    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- SWING
-- ============================================================================

--- Apply swing to notes
--- @param notes table Array of note tables
--- @param amount number Swing amount (0.0 to 1.0, 0.5 = no swing)
--- @param grid_ppq number Grid size for swing calculation
--- @return table Transformed notes
function M.swing(notes, amount, grid_ppq)
  amount = amount or 0.66  -- Default swing
  grid_ppq = grid_ppq or (PPQN / 4)  -- Default 1/16

  -- Swing shifts every other grid position
  local swing_offset = math.floor(grid_ppq * (amount - 0.5))

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    -- Determine if this note is on an "off-beat" (odd grid position)
    local grid_pos = math.floor(note.start_ppq / grid_ppq + 0.5)
    local is_offbeat = (grid_pos % 2) == 1

    if is_offbeat then
      local duration = note.end_ppq - note.start_ppq
      new_note.start_ppq = note.start_ppq + swing_offset
      new_note.end_ppq = new_note.start_ppq + duration
    end

    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- HUMANIZE
-- ============================================================================

--- Humanize notes with random variations
--- @param notes table Array of note tables
--- @param opts table { timing_var, velocity_var, length_var } (all in percent 0-100)
--- @return table Transformed notes
function M.humanize(notes, opts)
  opts = opts or {}
  local timing_var = (opts.timing_var or 10) / 100  -- Default 10%
  local velocity_var = (opts.velocity_var or 10) / 100
  local length_var = (opts.length_var or 0) / 100

  local timing_range = PPQN / 8  -- Max ~1/32 note variation

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    -- Timing variation
    if timing_var > 0 then
      local max_offset = math.floor(timing_range * timing_var)
      local offset = math.random(-max_offset, max_offset)
      local duration = note.end_ppq - note.start_ppq
      new_note.start_ppq = math.max(0, note.start_ppq + offset)
      new_note.end_ppq = new_note.start_ppq + duration
    end

    -- Velocity variation
    if velocity_var > 0 then
      local max_var = math.floor(127 * velocity_var)
      local var = math.random(-max_var, max_var)
      new_note.velocity = math.max(1, math.min(127, note.velocity + var))
    end

    -- Length variation
    if length_var > 0 then
      local duration = new_note.end_ppq - new_note.start_ppq
      local max_var = math.floor(duration * length_var)
      local var = math.random(-max_var, max_var)
      new_note.end_ppq = new_note.start_ppq + math.max(10, duration + var)
    end

    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- TIME SHIFT
-- ============================================================================

--- Shift all notes by a fixed amount
--- @param notes table Array of note tables
--- @param offset_ppq number Offset in PPQ (positive = later)
--- @return table Transformed notes
function M.time_shift(notes, offset_ppq)
  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end
    new_note.start_ppq = math.max(0, note.start_ppq + offset_ppq)
    new_note.end_ppq = math.max(new_note.start_ppq + 1, note.end_ppq + offset_ppq)
    result[i] = new_note
  end
  return result
end

-- ============================================================================
-- VELOCITY SCALE
-- ============================================================================

--- Scale velocities by a factor or compress/expand dynamics
--- @param notes table Array of note tables
--- @param factor number Scale factor (0.5 to 2.0)
--- @param center number Center point for scaling (default 64)
--- @return table Transformed notes
function M.velocity_scale(notes, factor, center)
  center = center or 64

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end
    -- Scale around center
    local offset = note.velocity - center
    new_note.velocity = math.max(1, math.min(127, math.floor(center + offset * factor)))
    result[i] = new_note
  end
  return result
end

-- ============================================================================
-- LEGATO
-- ============================================================================

--- Make notes legato (extend to next note start)
--- @param notes table Array of note tables
--- @param gap number Gap to leave between notes (default 0)
--- @return table Transformed notes
function M.legato(notes, gap)
  gap = gap or 0

  -- Sort by start time
  local sorted = {}
  for i, note in ipairs(notes) do
    sorted[i] = { idx = i, start = note.start_ppq }
  end
  table.sort(sorted, function(a, b) return a.start < b.start end)

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end
    result[i] = new_note
  end

  -- Extend each note to the next
  for i = 1, #sorted - 1 do
    local curr_idx = sorted[i].idx
    local next_idx = sorted[i + 1].idx
    local next_start = notes[next_idx].start_ppq
    result[curr_idx].end_ppq = math.max(result[curr_idx].start_ppq + 1, next_start - gap)
  end

  return result
end

-- ============================================================================
-- STACCATO
-- ============================================================================

--- Make notes staccato (shorten to percentage of original)
--- @param notes table Array of note tables
--- @param percentage number Percentage to keep (10-90)
--- @return table Transformed notes
function M.staccato(notes, percentage)
  percentage = math.max(10, math.min(90, percentage or 50)) / 100

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end
    local duration = note.end_ppq - note.start_ppq
    new_note.end_ppq = note.start_ppq + math.max(10, math.floor(duration * percentage))
    result[i] = new_note
  end
  return result
end

return M
