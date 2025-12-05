-- @noindex
-- MIDIHelix/domain/sequencer.lua
-- Probability-based monophonic sequence generation

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

M.NOTE_LENGTHS = {
  { label = '1/16', qn = 0.25 },
  { label = '1/8',  qn = 0.5 },
  { label = '1/4',  qn = 1.0 },
  { label = 'Rest', qn = -1 },  -- -1 indicates rest
}

local PPQN = 960  -- Standard pulses per quarter note

-- ============================================================================
-- PROBABILITY TABLE GENERATION
-- ============================================================================

--- Generate probability table from note length weights
--- @param weights table Array of 4 weights { 1/16, 1/8, 1/4, Rest }
--- @return table Probability table (array of QN values, -1 for rest)
function M.generate_length_prob_table(weights)
  local prob_table = {}

  for i, length_def in ipairs(M.NOTE_LENGTHS) do
    local weight = weights[i] or 0
    for _ = 1, weight do
      prob_table[#prob_table + 1] = length_def.qn
    end
  end

  return prob_table
end

--- Generate accent probability table
--- @param normal_vel number Normal velocity
--- @param accent_vel number Accent velocity
--- @param accent_prob number Accent probability (0-10)
--- @return table Probability table of velocities
function M.generate_accent_prob_table(normal_vel, accent_vel, accent_prob)
  local prob_table = {}

  -- Normal velocity entries
  for _ = 1, (10 - accent_prob) do
    prob_table[#prob_table + 1] = normal_vel
  end

  -- Accent velocity entries
  for _ = 1, accent_prob do
    prob_table[#prob_table + 1] = accent_vel
  end

  return prob_table
end

--- Generate legato probability table
--- @param legato_prob number Legato probability (0-10)
--- @param legato_offset number Offset for non-legato notes (negative, e.g., -10)
--- @return table Probability table of offsets
function M.generate_legato_prob_table(legato_prob, legato_offset)
  local prob_table = {}
  legato_offset = legato_offset or -10

  -- Non-legato entries (short notes)
  for _ = 1, (10 - legato_prob) do
    prob_table[#prob_table + 1] = legato_offset
  end

  -- Legato entries (full length)
  for _ = 1, legato_prob do
    prob_table[#prob_table + 1] = 0
  end

  return prob_table
end

-- ============================================================================
-- SEQUENCE GENERATION
-- ============================================================================

--- Generate a monophonic sequence
--- @param opts table Generation options
--- @return table Array of note tables
function M.generate_sequence(opts)
  local item_length_ppq = opts.item_length_ppq or (4 * PPQN)  -- Default 1 bar
  local grid_qn = opts.grid_qn or 0.25  -- Default 1/16
  local root = opts.root or 60
  local length_weights = opts.length_weights or { 4, 4, 2, 2 }
  local accent_enabled = opts.accent_enabled or false
  local normal_vel = opts.normal_vel or 96
  local accent_vel = opts.accent_vel or 127
  local accent_prob = opts.accent_prob or 3
  local legato_enabled = opts.legato_enabled or false
  local legato_prob = opts.legato_prob or 3
  local legato_offset = opts.legato_offset or -10
  local first_note_always = opts.first_note_always or true
  local randomize_notes = opts.randomize_notes or false
  local note_weights = opts.note_weights
  local scale_root = opts.scale_root or root

  -- Generate probability tables
  local length_prob = M.generate_length_prob_table(length_weights)
  local accent_prob_table = M.generate_accent_prob_table(normal_vel, accent_vel, accent_prob)
  local legato_prob_table = M.generate_legato_prob_table(legato_prob, legato_offset)

  if #length_prob == 0 then
    return {}  -- No valid lengths
  end

  local notes = {}
  local pos = 0
  local grid_ppq = grid_qn * PPQN

  while pos < item_length_ppq do
    local note_qn

    -- First note handling
    if #notes == 0 and first_note_always then
      -- Keep picking until we get a non-rest
      repeat
        note_qn = length_prob[math.random(1, #length_prob)]
      until note_qn > 0
    else
      note_qn = length_prob[math.random(1, #length_prob)]
    end

    if note_qn < 0 then
      -- Rest - advance by grid size
      pos = pos + grid_ppq
    else
      -- Note
      local note_len_ppq = note_qn * PPQN
      local note_start = pos
      local note_end = pos + note_len_ppq

      -- Clamp to item length
      if note_end > item_length_ppq then
        note_end = item_length_ppq
        note_len_ppq = note_end - note_start
      end

      -- Apply legato
      if legato_enabled and #legato_prob_table > 0 then
        note_end = note_end + legato_prob_table[math.random(1, #legato_prob_table)]
      else
        note_end = note_end + legato_offset
      end

      -- Determine velocity
      local vel
      if accent_enabled and #accent_prob_table > 0 then
        vel = accent_prob_table[math.random(1, #accent_prob_table)]
      else
        vel = normal_vel
      end

      -- Determine pitch
      local pitch = root
      if randomize_notes and note_weights then
        local Randomizer = require('scripts.MIDIHelix.domain.randomizer')
        pitch = Randomizer.get_random_note(note_weights, scale_root, false, 0)
      end

      notes[#notes + 1] = {
        pitch = pitch,
        velocity = vel,
        start_ppq = note_start,
        end_ppq = note_end,
        channel = 0,
        selected = true,
        muted = false,
      }

      pos = pos + note_len_ppq
    end
  end

  return notes
end

--- Get item length in PPQ from active MIDI editor
--- @return number|nil Item length in PPQ, or nil if no active take
function M.get_item_length_ppq()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take then return nil end

  local item = reaper.GetMediaItemTake_Item(take)
  if not item then return nil end

  -- Use BR_GetMidiSourceLenPPQ for accurate length
  local ppq_len = reaper.BR_GetMidiSourceLenPPQ(take)
  return ppq_len
end

--- Get current grid size from MIDI editor
--- @return number Grid size in QN (quarter notes)
function M.get_grid_qn()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take then return 0.25 end  -- Default 1/16

  local grid_qn = reaper.MIDI_GetGrid(take)
  return grid_qn
end

return M
