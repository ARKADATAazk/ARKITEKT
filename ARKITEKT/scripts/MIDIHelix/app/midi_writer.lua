-- @noindex
-- MIDIHelix/app/midi_writer.lua
-- MIDI note writing to REAPER items

local M = {}

--- Write Euclidean pattern as MIDI notes
-- @param pattern table Array of 1s (pulse) and 0s (rest)
-- @param opts table Options: note, velocity, grid_division, note_length
-- @return boolean, string Success status and message
function M.write_pattern(pattern, opts)
  opts = opts or {}

  local note_pitch = opts.note or 60  -- Middle C default
  local velocity = opts.velocity or 96
  local grid_div = opts.grid_division or 0.25  -- 16th notes default
  local note_length = opts.note_length or grid_div  -- Full length default

  -- Get active MIDI take
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take then
    return false, 'No active MIDI editor or take'
  end

  -- Check for Ghost/Pooled MIDI items (causes hangs in original)
  local item = reaper.GetMediaItemTake_Item(take)
  if reaper.GetMediaItemInfo_Value(item, 'B_LOOPSRC') > 0.5 then
    return false, 'Cannot write to Ghost/Pooled MIDI items (this would hang REAPER)'
  end

  -- Get grid division in QN
  local qn_per_step = grid_div

  -- Start from cursor or item start
  local cursor_pos = reaper.GetCursorPosition()
  local item_start = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
  local start_qn = reaper.TimeMap2_timeToQN(0, cursor_pos)

  -- Write pattern
  reaper.Undo_BeginBlock()

  for i, pulse in ipairs(pattern) do
    if pulse == 1 then
      local start_pos_qn = start_qn + (i - 1) * qn_per_step
      local end_pos_qn = start_pos_qn + note_length

      -- Convert to PPQ for MIDI API
      local start_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, start_pos_qn)
      local end_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, end_pos_qn)

      -- Insert note
      reaper.MIDI_InsertNote(
        take,
        false,  -- selected
        false,  -- muted
        start_ppq,
        end_ppq,
        0,  -- channel
        note_pitch,
        velocity,
        true  -- no sort
      )
    end
  end

  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock('Insert Euclidean Pattern', -1)

  return true, string.format('Inserted %d notes', #pattern)
end

--- Clear all notes in active MIDI take
-- @return boolean, string Success status and message
function M.clear_notes()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take then
    return false, 'No active MIDI editor or take'
  end

  reaper.Undo_BeginBlock()

  local _, note_count = reaper.MIDI_CountEvts(take)
  for i = note_count - 1, 0, -1 do
    reaper.MIDI_DeleteNote(take, i)
  end

  reaper.Undo_EndBlock('Clear MIDI Notes', -1)

  return true, 'Cleared all notes'
end

--- Get notes from active MIDI take
-- @param selected_only boolean Only get selected notes
-- @return table|nil, string Notes array or nil, message
function M.get_notes(selected_only)
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take then
    return nil, 'No active MIDI editor or take'
  end

  local _, note_count = reaper.MIDI_CountEvts(take)
  local notes = {}

  for i = 0, note_count - 1 do
    local _, selected, muted, start_ppq, end_ppq, channel, pitch, velocity = reaper.MIDI_GetNote(take, i)

    if not selected_only or selected then
      notes[#notes + 1] = {
        index = i,
        selected = selected,
        muted = muted,
        start_ppq = start_ppq,
        end_ppq = end_ppq,
        channel = channel,
        pitch = pitch,
        velocity = velocity,
      }
    end
  end

  return notes, string.format('Got %d notes', #notes)
end

--- Write notes to active MIDI take (replaces existing)
-- @param notes table Array of note tables
-- @param clear_first boolean Clear existing notes first
-- @return boolean, string Success status and message
function M.write_notes(notes, clear_first)
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take then
    return false, 'No active MIDI editor or take'
  end

  -- Check for Ghost/Pooled MIDI items
  local item = reaper.GetMediaItemTake_Item(take)
  if reaper.GetMediaItemInfo_Value(item, 'B_LOOPSRC') > 0.5 then
    return false, 'Cannot write to Ghost/Pooled MIDI items'
  end

  reaper.Undo_BeginBlock()

  if clear_first then
    local _, note_count = reaper.MIDI_CountEvts(take)
    for i = note_count - 1, 0, -1 do
      reaper.MIDI_DeleteNote(take, i)
    end
  end

  for _, note in ipairs(notes) do
    reaper.MIDI_InsertNote(
      take,
      note.selected or false,
      note.muted or false,
      note.start_ppq,
      note.end_ppq,
      note.channel or 0,
      note.pitch,
      note.velocity or 96,
      true  -- no sort
    )
  end

  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock('Write MIDI Notes', -1)

  return true, string.format('Wrote %d notes', #notes)
end

--- Randomize pitches of existing notes in active MIDI take
-- @param randomizer_fn function Function that takes notes array and returns randomized notes
-- @param selected_only boolean Only randomize selected notes
-- @return boolean, string Success status and message
function M.randomize_notes(randomizer_fn, selected_only)
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take then
    return false, 'No active MIDI editor or take'
  end

  -- Check for Ghost/Pooled MIDI items
  local item = reaper.GetMediaItemTake_Item(take)
  if reaper.GetMediaItemInfo_Value(item, 'B_LOOPSRC') > 0.5 then
    return false, 'Cannot write to Ghost/Pooled MIDI items'
  end

  -- Get all notes
  local _, note_count = reaper.MIDI_CountEvts(take)
  local notes = {}

  for i = 0, note_count - 1 do
    local _, selected, muted, start_ppq, end_ppq, channel, pitch, velocity = reaper.MIDI_GetNote(take, i)
    notes[#notes + 1] = {
      index = i,
      selected = selected,
      muted = muted,
      start_ppq = start_ppq,
      end_ppq = end_ppq,
      channel = channel,
      pitch = pitch,
      velocity = velocity,
    }
  end

  if #notes == 0 then
    return false, 'No notes to randomize'
  end

  -- Apply randomization
  local randomized = randomizer_fn(notes)

  reaper.Undo_BeginBlock()

  -- Update pitches (modify in place to preserve note ordering)
  for i, note in ipairs(notes) do
    local should_update = not selected_only or note.selected
    if should_update and randomized[i] then
      reaper.MIDI_SetNote(
        take, note.index,
        nil, nil,  -- selected, muted (unchanged)
        nil, nil,  -- start, end (unchanged)
        nil,       -- channel (unchanged)
        randomized[i].pitch,
        nil,       -- velocity (unchanged)
        true       -- no sort
      )
    end
  end

  reaper.MIDI_Sort(take)
  reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40435)  -- All notes off
  reaper.Undo_EndBlock('Randomize MIDI Notes', -1)

  local count = 0
  for _, note in ipairs(notes) do
    if not selected_only or note.selected then
      count = count + 1
    end
  end

  return true, string.format('Randomized %d notes', count)
end

--- Apply a transform to existing notes in active MIDI take
--- @param transform_fn function Function that takes notes array and returns transformed notes
--- @param selected_only boolean Only transform selected notes
--- @param undo_name string Name for undo block
--- @return boolean, string Success status and message
function M.apply_transform(transform_fn, selected_only, undo_name)
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take then
    return false, 'No active MIDI editor or take'
  end

  -- Check for Ghost/Pooled MIDI items
  local item = reaper.GetMediaItemTake_Item(take)
  if reaper.GetMediaItemInfo_Value(item, 'B_LOOPSRC') > 0.5 then
    return false, 'Cannot modify Ghost/Pooled MIDI items'
  end

  -- Get all notes
  local _, note_count = reaper.MIDI_CountEvts(take)
  local notes = {}
  local indices_to_update = {}

  for i = 0, note_count - 1 do
    local _, selected, muted, start_ppq, end_ppq, channel, pitch, velocity = reaper.MIDI_GetNote(take, i)
    local note = {
      index = i,
      selected = selected,
      muted = muted,
      start_ppq = start_ppq,
      end_ppq = end_ppq,
      channel = channel,
      pitch = pitch,
      velocity = velocity,
    }
    notes[#notes + 1] = note

    if not selected_only or selected then
      indices_to_update[#indices_to_update + 1] = #notes
    end
  end

  if #indices_to_update == 0 then
    return false, 'No notes to transform'
  end

  -- Get only notes to transform
  local notes_to_transform = {}
  for _, idx in ipairs(indices_to_update) do
    notes_to_transform[#notes_to_transform + 1] = notes[idx]
  end

  -- Apply transform
  local transformed = transform_fn(notes_to_transform)

  reaper.Undo_BeginBlock()

  -- Update notes
  for i, idx in ipairs(indices_to_update) do
    local orig = notes[idx]
    local trans = transformed[i]
    if trans then
      reaper.MIDI_SetNote(
        take, orig.index,
        nil,  -- selected (unchanged)
        nil,  -- muted (unchanged)
        trans.start_ppq,
        trans.end_ppq,
        nil,  -- channel (unchanged)
        trans.pitch,
        trans.velocity,
        true  -- no sort
      )
    end
  end

  reaper.MIDI_Sort(take)
  reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40435)  -- All notes off
  reaper.Undo_EndBlock(undo_name or 'Transform MIDI Notes', -1)

  return true, string.format('Transformed %d notes', #indices_to_update)
end

return M
