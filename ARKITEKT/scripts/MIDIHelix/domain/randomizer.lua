-- @noindex
-- MIDIHelix/domain/randomizer.lua
-- Scale-weighted note randomization logic

local M = {}

local Scales = require('scripts.MIDIHelix.domain.scales')

-- ============================================================================
-- PROBABILITY TABLE GENERATION
-- ============================================================================

--- Generate a weighted probability table from note weights
--- @param weights table Array of 12 weights (0-10 each for C through B)
--- @param root number Root note offset (0-11)
--- @return table Probability table (array of intervals to pick from)
function M.generate_probability_table(weights, root)
  local prob_table = {}
  root = root or 0

  for i = 1, 12 do
    local weight = weights[i] or 0
    local interval = (i - 1)  -- 0-11 interval from C

    -- Add this interval 'weight' times to the probability table
    for _ = 1, weight do
      prob_table[#prob_table + 1] = interval
    end
  end

  return prob_table
end

--- Generate note weights from a scale (preset weights)
--- @param scale table Scale definition
--- @param default_weight number Weight for notes in scale (default 5)
--- @return table Array of 12 weights
function M.weights_from_scale(scale, default_weight)
  default_weight = default_weight or 5
  local weights = {}

  for i = 1, 12 do
    weights[i] = 0
  end

  for _, interval in ipairs(scale.intervals) do
    weights[interval + 1] = default_weight
  end

  return weights
end

-- ============================================================================
-- RANDOMIZATION
-- ============================================================================

--- Get a random note based on weights
--- @param weights table Array of 12 weights
--- @param root number Root MIDI note (e.g., 60 for C4)
--- @param octave_double boolean Enable octave doubling
--- @param octave_prob number Octave double probability (0-10)
--- @return number MIDI note number
function M.get_random_note(weights, root, octave_double, octave_prob)
  local prob_table = M.generate_probability_table(weights, 0)

  if #prob_table == 0 then
    return root  -- Fallback to root if no weights
  end

  local interval = prob_table[math.random(1, #prob_table)]
  local note = root + interval

  -- Octave doubling
  if octave_double and octave_prob and octave_prob > 0 then
    if math.random(1, 10) <= octave_prob then
      note = note + 12
    end
  end

  return note
end

--- Randomize a list of notes based on weights
--- @param notes table Array of note tables { pitch, ... }
--- @param weights table Array of 12 weights
--- @param root number Root MIDI note
--- @param opts table Options { first_is_root, octave_double, octave_prob, selected_only }
--- @return table Randomized notes
function M.randomize_notes(notes, weights, root, opts)
  opts = opts or {}
  local first_is_root = opts.first_is_root or false
  local octave_double = opts.octave_double or false
  local octave_prob = opts.octave_prob or 0
  local selected_only = opts.selected_only or false

  local result = {}

  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end

    local should_randomize = not selected_only or note.selected

    if should_randomize then
      if i == 1 and first_is_root then
        new_note.pitch = root
      else
        new_note.pitch = M.get_random_note(weights, root, octave_double, octave_prob)
      end
    end

    result[i] = new_note
  end

  return result
end

-- ============================================================================
-- SHUFFLE (FISHER-YATES)
-- ============================================================================

--- Shuffle pitches of notes using Fisher-Yates algorithm
--- @param notes table Array of note tables { pitch, ... }
--- @param selected_only boolean Only shuffle selected notes
--- @return table Notes with shuffled pitches
function M.shuffle_notes(notes, selected_only)
  -- Extract pitches to shuffle
  local pitches = {}
  local indices = {}

  for i, note in ipairs(notes) do
    if not selected_only or note.selected then
      pitches[#pitches + 1] = note.pitch
      indices[#indices + 1] = i
    end
  end

  -- Fisher-Yates shuffle
  for i = #pitches, 2, -1 do
    local j = math.random(1, i)
    pitches[i], pitches[j] = pitches[j], pitches[i]
  end

  -- Apply shuffled pitches back
  local result = {}
  for i, note in ipairs(notes) do
    local new_note = {}
    for k, v in pairs(note) do
      new_note[k] = v
    end
    result[i] = new_note
  end

  for i, idx in ipairs(indices) do
    result[idx].pitch = pitches[i]
  end

  return result
end

-- ============================================================================
-- NOTE GENERATION
-- ============================================================================

--- Generate random notes to fill a time span
--- @param opts table { count, root, weights, velocity, start_time, grid_division, note_length, first_is_root, octave_double, octave_prob }
--- @return table Array of note tables
function M.generate_random_notes(opts)
  local count = opts.count or 8
  local root = opts.root or 60
  local weights = opts.weights
  local velocity = opts.velocity or 96
  local start_time = opts.start_time or 0
  local grid_division = opts.grid_division or 0.25
  local note_length = opts.note_length or 0.25
  local first_is_root = opts.first_is_root or false
  local octave_double = opts.octave_double or false
  local octave_prob = opts.octave_prob or 0

  local notes = {}
  local ppqn = 960  -- Standard PPQN

  for i = 1, count do
    local pitch
    if i == 1 and first_is_root then
      pitch = root
    else
      pitch = M.get_random_note(weights, root, octave_double, octave_prob)
    end

    local note_start = start_time + (i - 1) * (grid_division * ppqn)

    notes[i] = {
      pitch = pitch,
      velocity = velocity,
      start_ppq = note_start,
      end_ppq = note_start + (note_length * ppqn),
      channel = 0,
      selected = true,
      muted = false,
    }
  end

  return notes
end

return M
