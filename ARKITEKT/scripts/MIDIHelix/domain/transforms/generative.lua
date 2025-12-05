-- @noindex
-- MIDIHelix/domain/transforms/generative.lua
-- Advanced generative/algorithmic transformations
-- Negative harmony, Markov chains, 12-tone, cellular automata, etc.

local M = {}

local Scales = require('scripts.MIDIHelix.domain.scales')

-- ============================================================================
-- NEGATIVE HARMONY (Ernst Levy)
-- Mirror melody around axis between root and fifth
-- ============================================================================

--- Apply negative harmony transformation
--- @param notes table Array of note tables
--- @param root number Root note (0-11, where 0=C)
--- @param axis_type string 'tonic_dominant' (between 1 and 5) or 'chromatic' (around single pitch)
--- @return table Transformed notes
function M.negative_harmony(notes, root, axis_type)
  -- Negative harmony mirrors around an axis
  -- Traditional axis: between root and 5th (e.g., between E and Eb for C major)
  -- This is 3.5 semitones above root (between major and minor 3rd)

  local axis
  if axis_type == 'chromatic' then
    -- Simple chromatic mirror around the root
    axis = root
  else
    -- Tonic-dominant axis: between 3rd and b3rd scale degrees
    -- For C: axis is between E (4) and Eb (3), so 3.5 semitones above C
    -- Formula: mirror_pitch = 2 * axis - original_pitch
    axis = root + 3.5
  end

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    -- Mirror around axis: new = 2*axis - old
    local mirrored = math.floor(2 * axis - note.pitch + 0.5)

    -- Keep in same octave range (optional - can disable for true negative harmony)
    local orig_octave = math.floor(note.pitch / 12)
    local new_pc = mirrored % 12
    new_note.pitch = orig_octave * 12 + new_pc

    new_note.pitch = math.max(0, math.min(127, new_note.pitch))
    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- INTERVAL EXPANSION / CONTRACTION
-- Multiply intervals by a factor (can create wild microtonal-ish results)
-- ============================================================================

--- Expand or contract intervals between notes
--- @param notes table Array of note tables
--- @param factor number Interval multiplier (0.5 = half, 2 = double, -1 = invert)
--- @param anchor string 'first', 'center', or 'last' - which note stays fixed
--- @return table Transformed notes
function M.interval_multiply(notes, factor, anchor)
  if #notes == 0 then return {} end

  anchor = anchor or 'first'

  -- Find anchor pitch
  local anchor_pitch
  if anchor == 'last' then
    anchor_pitch = notes[#notes].pitch
  elseif anchor == 'center' then
    local sum = 0
    for _, note in ipairs(notes) do sum = sum + note.pitch end
    anchor_pitch = sum / #notes
  else
    anchor_pitch = notes[1].pitch
  end

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    -- Calculate interval from anchor and multiply
    local interval = note.pitch - anchor_pitch
    local new_interval = interval * factor
    new_note.pitch = math.floor(anchor_pitch + new_interval + 0.5)
    new_note.pitch = math.max(0, math.min(127, new_note.pitch))

    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- MARKOV CHAIN MELODY GENERATION
-- Analyze note transitions and generate new sequence
-- ============================================================================

--- Build Markov transition matrix from notes
--- @param notes table Array of note tables
--- @param order number Markov order (1 = single note, 2 = pairs)
--- @return table Transition matrix
local function build_markov_matrix(notes, order)
  order = order or 1
  local matrix = {}

  for i = 1, #notes - order do
    -- Build state key from previous notes
    local state = {}
    for j = 0, order - 1 do
      state[#state + 1] = notes[i + j].pitch % 12  -- Use pitch class
    end
    local key = table.concat(state, ',')

    -- Record transition
    local next_pc = notes[i + order].pitch % 12
    matrix[key] = matrix[key] or {}
    matrix[key][next_pc] = (matrix[key][next_pc] or 0) + 1
  end

  return matrix
end

--- Generate melody using Markov chain
--- @param notes table Source notes to analyze
--- @param length number Number of notes to generate
--- @param order number Markov order (1 or 2)
--- @param seed number Optional seed pitch
--- @return table Generated notes
function M.markov_generate(notes, length, order, seed)
  if #notes < order + 1 then return notes end

  order = order or 1
  length = length or #notes

  local matrix = build_markov_matrix(notes, order)

  -- Start with seed or random note from source
  local result = {}
  local current_state = {}

  if seed then
    for i = 1, order do
      current_state[i] = seed % 12
    end
  else
    -- Use first 'order' notes as seed
    for i = 1, math.min(order, #notes) do
      current_state[i] = notes[i].pitch % 12
    end
  end

  -- Calculate average octave from source
  local avg_octave = 0
  for _, note in ipairs(notes) do
    avg_octave = avg_octave + math.floor(note.pitch / 12)
  end
  avg_octave = math.floor(avg_octave / #notes)

  -- Use timing from original notes or generate evenly spaced
  local ppq_per_note = 240  -- Default 1/16 at 960 PPQN
  if #notes >= 2 then
    ppq_per_note = (notes[#notes].start_ppq - notes[1].start_ppq) / (#notes - 1)
  end
  local start_ppq = notes[1] and notes[1].start_ppq or 0

  -- Generate
  for i = 1, length do
    local key = table.concat(current_state, ',')
    local transitions = matrix[key]

    local next_pc
    if transitions then
      -- Weighted random selection
      local total = 0
      for _, count in pairs(transitions) do total = total + count end
      local r = math.random() * total
      local cumulative = 0
      for pc, count in pairs(transitions) do
        cumulative = cumulative + count
        if r <= cumulative then
          next_pc = pc
          break
        end
      end
    else
      -- Fallback to random pitch class from source
      next_pc = notes[math.random(#notes)].pitch % 12
    end

    -- Create note
    local new_note = {
      pitch = avg_octave * 12 + next_pc,
      velocity = notes[math.random(#notes)].velocity,
      start_ppq = start_ppq + (i - 1) * ppq_per_note,
      end_ppq = start_ppq + (i - 1) * ppq_per_note + ppq_per_note * 0.9,
    }
    result[i] = new_note

    -- Update state
    table.remove(current_state, 1)
    current_state[#current_state + 1] = next_pc
  end

  return result
end

--- Transform existing notes using Markov probabilities
--- @param notes table Notes to transform
--- @param chaos number Amount of randomization (0-1)
--- @return table Transformed notes
function M.markov_transform(notes, chaos)
  if #notes < 3 then return notes end

  chaos = chaos or 0.5
  local matrix = build_markov_matrix(notes, 1)

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    if math.random() < chaos and i > 1 then
      -- Use Markov probability to pick new pitch
      local prev_pc = notes[i - 1].pitch % 12
      local key = tostring(prev_pc)
      local transitions = matrix[key]

      if transitions then
        local total = 0
        for _, count in pairs(transitions) do total = total + count end
        local r = math.random() * total
        local cumulative = 0
        for pc, count in pairs(transitions) do
          cumulative = cumulative + count
          if r <= cumulative then
            local octave = math.floor(note.pitch / 12)
            new_note.pitch = octave * 12 + pc
            break
          end
        end
      end
    end

    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- 12-TONE / SERIAL TECHNIQUES
-- ============================================================================

--- Generate a 12-tone row
--- @param seed table Optional starting pitches
--- @return table 12-element array of pitch classes (0-11)
function M.generate_tone_row(seed)
  local row = {}
  local used = {}

  -- If seed provided, start with those
  if seed then
    for _, pc in ipairs(seed) do
      if not used[pc % 12] then
        row[#row + 1] = pc % 12
        used[pc % 12] = true
      end
    end
  end

  -- Fill remaining with random order
  local remaining = {}
  for pc = 0, 11 do
    if not used[pc] then
      remaining[#remaining + 1] = pc
    end
  end

  -- Fisher-Yates shuffle
  for i = #remaining, 2, -1 do
    local j = math.random(i)
    remaining[i], remaining[j] = remaining[j], remaining[i]
  end

  for _, pc in ipairs(remaining) do
    row[#row + 1] = pc
  end

  return row
end

--- Get serial transformation of tone row
--- @param row table 12-tone row
--- @param form string 'P' (prime), 'I' (inversion), 'R' (retrograde), 'RI' (retrograde inversion)
--- @param transposition number Semitones to transpose (0-11)
--- @return table Transformed row
function M.serial_transform(row, form, transposition)
  transposition = transposition or 0
  local result = {}

  if form == 'R' then
    -- Retrograde
    for i = #row, 1, -1 do
      result[#result + 1] = (row[i] + transposition) % 12
    end
  elseif form == 'I' then
    -- Inversion (mirror intervals)
    local first = row[1]
    for i, pc in ipairs(row) do
      local interval = pc - first
      result[i] = (first - interval + transposition) % 12
    end
  elseif form == 'RI' then
    -- Retrograde Inversion
    local inverted = M.serial_transform(row, 'I', 0)
    for i = #inverted, 1, -1 do
      result[#result + 1] = (inverted[i] + transposition) % 12
    end
  else
    -- Prime (P)
    for i, pc in ipairs(row) do
      result[i] = (pc + transposition) % 12
    end
  end

  return result
end

--- Apply 12-tone row to existing notes
--- @param notes table Notes to transform
--- @param row table 12-tone row (or nil to generate)
--- @param form string P/I/R/RI
--- @param transposition number Semitones
--- @return table Transformed notes
function M.apply_tone_row(notes, row, form, transposition)
  if #notes == 0 then return {} end

  row = row or M.generate_tone_row()
  local transformed_row = M.serial_transform(row, form, transposition)

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    -- Map note index to row position (cycling)
    local row_idx = ((i - 1) % 12) + 1
    local octave = math.floor(note.pitch / 12)
    new_note.pitch = octave * 12 + transformed_row[row_idx]

    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- CELLULAR AUTOMATA
-- Use CA rules for pitch/rhythm generation
-- ============================================================================

--- Apply 1D cellular automaton rule
--- @param state table Current state (array of 0/1)
--- @param rule number Rule number (0-255)
--- @return table Next state
local function ca_step(state, rule)
  local next_state = {}
  local n = #state

  for i = 1, n do
    -- Get neighborhood (with wrapping)
    local left = state[((i - 2) % n) + 1]
    local center = state[i]
    local right = state[(i % n) + 1]

    -- Calculate rule index (binary: left*4 + center*2 + right)
    local idx = left * 4 + center * 2 + right

    -- Extract bit from rule number
    next_state[i] = math.floor(rule / (2 ^ idx)) % 2
  end

  return next_state
end

--- Generate melody using cellular automaton
--- @param notes table Source notes (used for timing/velocity)
--- @param rule number CA rule (30, 90, 110 are interesting)
--- @param generations number Number of CA generations
--- @param scale table Scale to map to
--- @param root number Scale root
--- @return table Generated notes
function M.cellular_automata(notes, rule, generations, scale, root)
  if #notes == 0 then return {} end

  rule = rule or 30  -- Rule 30 is chaotic/interesting
  generations = generations or #notes
  scale = scale or { intervals = { 0, 2, 4, 5, 7, 9, 11 } }  -- Major
  root = root or 0

  -- Initialize CA state from note pitches
  local width = math.max(12, #notes)
  local state = {}
  for i = 1, width do
    if notes[i] then
      state[i] = notes[i].pitch % 2  -- Use LSB of pitch
    else
      state[i] = math.random(0, 1)
    end
  end

  -- Run CA for specified generations, collecting states
  local history = { state }
  for g = 1, generations - 1 do
    state = ca_step(state, rule)
    history[#history + 1] = state
  end

  -- Map CA states to pitches
  local result = {}
  local base_octave = 4
  if notes[1] then
    base_octave = math.floor(notes[1].pitch / 12)
  end

  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    -- Use CA state to determine scale degree
    local gen = ((i - 1) % #history) + 1
    local cell_state = history[gen]

    -- Count active cells in neighborhood to get scale degree
    local sum = 0
    local center = ((i - 1) % #cell_state) + 1
    for j = -2, 2 do
      local idx = ((center + j - 1) % #cell_state) + 1
      sum = sum + cell_state[idx]
    end

    -- Map sum (0-5) to scale degree
    local degree = (sum % #scale.intervals) + 1
    local octave_offset = math.floor(sum / #scale.intervals)

    new_note.pitch = root + (base_octave + octave_offset) * 12 + scale.intervals[degree]
    new_note.pitch = math.max(0, math.min(127, new_note.pitch))

    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- MELODIC CONTOUR MAPPING
-- Apply shape of one melody to another's pitches
-- ============================================================================

--- Extract melodic contour (normalized shape)
--- @param notes table Notes to analyze
--- @return table Contour as array of values 0-1
local function extract_contour(notes)
  if #notes == 0 then return {} end

  local min_pitch, max_pitch = 127, 0
  for _, note in ipairs(notes) do
    min_pitch = math.min(min_pitch, note.pitch)
    max_pitch = math.max(max_pitch, note.pitch)
  end

  local range = max_pitch - min_pitch
  if range == 0 then range = 1 end

  local contour = {}
  for i, note in ipairs(notes) do
    contour[i] = (note.pitch - min_pitch) / range
  end

  return contour
end

--- Apply contour to target pitches
--- @param notes table Notes to transform
--- @param contour_source table Notes to extract contour from
--- @param pitch_source table Notes to get pitch set from (or nil to use scale)
--- @param scale table Scale to use if pitch_source is nil
--- @param root number Scale root
--- @return table Transformed notes
function M.contour_map(notes, contour_source, pitch_source, scale, root)
  if #notes == 0 then return {} end

  -- Extract contour from source
  local contour = extract_contour(contour_source or notes)

  -- Get available pitches
  local pitches = {}
  if pitch_source and #pitch_source > 0 then
    for _, note in ipairs(pitch_source) do
      pitches[#pitches + 1] = note.pitch
    end
    table.sort(pitches)
  else
    -- Use scale
    scale = scale or { intervals = { 0, 2, 4, 5, 7, 9, 11 } }
    root = root or 0
    local base_octave = notes[1] and math.floor(notes[1].pitch / 12) or 4
    for oct = base_octave - 1, base_octave + 1 do
      for _, interval in ipairs(scale.intervals) do
        pitches[#pitches + 1] = root + oct * 12 + interval
      end
    end
  end

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    -- Get contour value (interpolate if needed)
    local contour_idx = 1 + (i - 1) * (#contour - 1) / math.max(1, #notes - 1)
    local c_floor = math.floor(contour_idx)
    local c_ceil = math.min(math.ceil(contour_idx), #contour)
    local t = contour_idx - c_floor

    local contour_val
    if c_floor == c_ceil or #contour == 1 then
      contour_val = contour[c_floor] or 0.5
    else
      contour_val = contour[c_floor] * (1 - t) + contour[c_ceil] * t
    end

    -- Map contour value to pitch
    local pitch_idx = math.floor(contour_val * (#pitches - 1) + 1.5)
    pitch_idx = math.max(1, math.min(#pitches, pitch_idx))
    new_note.pitch = pitches[pitch_idx]

    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- FIBONACCI / GOLDEN RATIO
-- ============================================================================

local FIB_CACHE = { 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144 }

--- Apply Fibonacci-based transformation
--- @param notes table Notes to transform
--- @param mode string 'rhythm', 'pitch', or 'both'
--- @param scale table Scale for pitch mapping
--- @param root number Scale root
--- @return table Transformed notes
function M.fibonacci_transform(notes, mode, scale, root)
  if #notes == 0 then return {} end

  mode = mode or 'pitch'
  scale = scale or { intervals = { 0, 2, 4, 5, 7, 9, 11 } }
  root = root or 0

  local base_octave = math.floor(notes[1].pitch / 12)
  local base_ppq = notes[1].start_ppq

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    local fib_idx = ((i - 1) % #FIB_CACHE) + 1
    local fib = FIB_CACHE[fib_idx]

    if mode == 'pitch' or mode == 'both' then
      -- Use Fibonacci to determine scale degree
      local degree = (fib % #scale.intervals) + 1
      local octave_offset = math.floor(fib / #scale.intervals) % 3 - 1
      new_note.pitch = root + (base_octave + octave_offset) * 12 + scale.intervals[degree]
      new_note.pitch = math.max(0, math.min(127, new_note.pitch))
    end

    if mode == 'rhythm' or mode == 'both' then
      -- Use Fibonacci for timing (golden ratio spacing)
      local golden = 1.618033988749
      local time_offset = 0
      for j = 1, i - 1 do
        local f_idx = ((j - 1) % #FIB_CACHE) + 1
        time_offset = time_offset + FIB_CACHE[f_idx] * 60  -- Scale factor
      end
      local duration = fib * 60
      new_note.start_ppq = base_ppq + time_offset
      new_note.end_ppq = new_note.start_ppq + duration
    end

    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- BROWNIAN MOTION / RANDOM WALK
-- ============================================================================

--- Apply Brownian motion to melody
--- @param notes table Notes to transform
--- @param step_size number Max step size in semitones
--- @param gravity number Pull toward center (0-1)
--- @param center number Center pitch to gravitate toward
--- @return table Transformed notes
function M.brownian_motion(notes, step_size, gravity, center)
  if #notes == 0 then return {} end

  step_size = step_size or 3
  gravity = gravity or 0.1
  center = center or 60

  local result = {}
  local current_pitch = notes[1].pitch

  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    if i > 1 then
      -- Random step
      local step = (math.random() * 2 - 1) * step_size

      -- Gravity pull toward center
      local pull = (center - current_pitch) * gravity

      current_pitch = current_pitch + step + pull
      current_pitch = math.max(24, math.min(108, current_pitch))  -- Keep in reasonable range
    end

    new_note.pitch = math.floor(current_pitch + 0.5)
    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- SPECTRAL / OVERTONE MAPPING
-- ============================================================================

--- Map notes to overtone series
--- @param notes table Notes to transform
--- @param fundamental number Fundamental frequency as MIDI note
--- @param max_partial number Maximum partial to use
--- @return table Transformed notes
function M.overtone_map(notes, fundamental, max_partial)
  if #notes == 0 then return {} end

  fundamental = fundamental or 36  -- C2
  max_partial = max_partial or 16

  -- Calculate overtone pitches (equal temperament approximation)
  local overtones = {}
  for n = 1, max_partial do
    -- Frequency ratio n:1, convert to semitones: 12 * log2(n)
    local semitones = 12 * math.log(n) / math.log(2)
    overtones[n] = fundamental + math.floor(semitones + 0.5)
  end

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    -- Map note position to overtone
    local partial = ((i - 1) % max_partial) + 1
    new_note.pitch = math.max(0, math.min(127, overtones[partial]))

    result[i] = new_note
  end

  return result
end

--- Snap notes to nearest overtone of a fundamental
--- @param notes table Notes to transform
--- @param fundamental number Fundamental as MIDI note
--- @param max_partial number Max partial to consider
--- @return table Transformed notes
function M.overtone_quantize(notes, fundamental, max_partial)
  if #notes == 0 then return {} end

  fundamental = fundamental or 36
  max_partial = max_partial or 16

  -- Build overtone lookup
  local overtones = {}
  for n = 1, max_partial do
    local semitones = 12 * math.log(n) / math.log(2)
    overtones[n] = fundamental + semitones
  end

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    -- Find nearest overtone
    local min_dist = 127
    local nearest = note.pitch
    for _, ot in ipairs(overtones) do
      local dist = math.abs(note.pitch - ot)
      if dist < min_dist then
        min_dist = dist
        nearest = math.floor(ot + 0.5)
      end
    end

    new_note.pitch = math.max(0, math.min(127, nearest))
    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- PERMUTATION / COMBINATORICS
-- ============================================================================

--- Apply pitch permutation
--- @param notes table Notes to transform
--- @param permutation table Permutation indices or 'random'
--- @return table Transformed notes
function M.permute_pitches(notes, permutation)
  if #notes == 0 then return {} end

  local pitches = {}
  for i, note in ipairs(notes) do
    pitches[i] = note.pitch
  end

  -- Generate random permutation if needed
  if permutation == 'random' or not permutation then
    permutation = {}
    for i = 1, #pitches do
      permutation[i] = i
    end
    -- Fisher-Yates shuffle
    for i = #permutation, 2, -1 do
      local j = math.random(i)
      permutation[i], permutation[j] = permutation[j], permutation[i]
    end
  end

  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    local perm_idx = ((permutation[i] or i) - 1) % #pitches + 1
    new_note.pitch = pitches[perm_idx]

    result[i] = new_note
  end

  return result
end

return M
