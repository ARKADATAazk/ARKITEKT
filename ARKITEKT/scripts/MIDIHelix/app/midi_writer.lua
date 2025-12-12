-- @noindex
-- MIDIHelix/app/midi_writer.lua
-- MIDI note reading/writing to REAPER items
-- Works with MIDI Editor open OR just a selected MIDI item

local M = {}

-- ============================================================================
-- HELPERS
-- ============================================================================

--- Get active MIDI take (from MIDI Editor or selected item)
-- @return take, item, error_message
local function get_active_take()
  -- First try: active MIDI editor
  local editor = reaper.MIDIEditor_GetActive()
  if editor then
    local take = reaper.MIDIEditor_GetTake(editor)
    if take and reaper.ValidatePtr2(0, take, 'MediaItem_Take*') then
      local item = reaper.GetMediaItemTake_Item(take)
      return take, item, nil
    end
  end

  -- Second try: selected MIDI item
  local item = reaper.GetSelectedMediaItem(0, 0)
  if not item then
    return nil, nil, 'No MIDI editor or selected item'
  end

  local take = reaper.GetActiveTake(item)
  if not take then
    return nil, nil, 'Selected item has no active take'
  end

  if not reaper.TakeIsMIDI(take) then
    return nil, nil, 'Selected item is not MIDI'
  end

  return take, item, nil
end

--- Check if item is Ghost/Pooled (would cause hangs)
local function is_pooled_item(item)
  return reaper.GetMediaItemInfo_Value(item, 'B_LOOPSRC') > 0.5
end

--- Get all notes from take
-- @param take MIDI take
-- @param selected_only boolean Only get selected notes
-- @return table Array of note objects { pitch, vel, start_ppq, end_ppq, chan, selected, muted, idx }
local function get_notes(take, selected_only)
  local notes = {}
  local _, note_count = reaper.MIDI_CountEvts(take)

  for i = 0, note_count - 1 do
    local retval, selected, muted, start_ppq, end_ppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if retval then
      if not selected_only or selected then
        table.insert(notes, {
          pitch = pitch,
          vel = vel,
          start_ppq = start_ppq,
          end_ppq = end_ppq,
          chan = chan,
          selected = selected,
          muted = muted,
          idx = i,
        })
      end
    end
  end

  return notes
end

--- Delete notes by index (must delete in reverse order)
local function delete_notes(take, note_indices)
  table.sort(note_indices, function(a, b) return a > b end)
  for _, idx in ipairs(note_indices) do
    reaper.MIDI_DeleteNote(take, idx)
  end
end

--- Insert notes from array
local function insert_notes(take, notes)
  for _, note in ipairs(notes) do
    reaper.MIDI_InsertNote(
      take,
      note.selected or false,
      note.muted or false,
      note.start_ppq,
      note.end_ppq,
      note.chan or 0,
      note.pitch,
      note.vel,
      true  -- no sort
    )
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Write Euclidean pattern as MIDI notes
-- @param pattern table Array of 1s (pulse) and 0s (rest)
-- @param opts table Options: note, velocity, grid_division, note_length
-- @return boolean, string Success status and message
function M.write_pattern(pattern, opts)
  opts = opts or {}

  local note_pitch = opts.note or 60
  local velocity = opts.velocity or 96
  local grid_div = opts.grid_division or 0.25
  local note_length = opts.note_length or grid_div

  local take, item, err = get_active_take()
  if not take then
    return false, err
  end

  if is_pooled_item(item) then
    return false, 'Cannot write to Ghost/Pooled MIDI items'
  end

  local qn_per_step = grid_div
  local cursor_pos = reaper.GetCursorPosition()
  local start_qn = reaper.TimeMap2_timeToQN(0, cursor_pos)

  reaper.Undo_BeginBlock()

  local note_count = 0
  for i, pulse in ipairs(pattern) do
    if pulse == 1 then
      local start_pos_qn = start_qn + (i - 1) * qn_per_step
      local end_pos_qn = start_pos_qn + note_length

      local start_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, start_pos_qn)
      local end_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, end_pos_qn)

      reaper.MIDI_InsertNote(take, false, false, start_ppq, end_ppq, 0, note_pitch, velocity, true)
      note_count = note_count + 1
    end
  end

  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock('Insert Euclidean Pattern', -1)

  return true, string.format('Inserted %d notes', note_count)
end

--- Write notes array to MIDI take
-- @param notes table Array of note objects { pitch, vel, start_ppq, end_ppq, chan }
-- @param replace boolean Clear existing notes first
-- @return boolean, string Success status and message
function M.write_notes(notes, replace)
  local take, item, err = get_active_take()
  if not take then
    return false, err
  end

  if is_pooled_item(item) then
    return false, 'Cannot write to Ghost/Pooled MIDI items'
  end

  reaper.Undo_BeginBlock()

  -- Clear existing notes if replacing
  if replace then
    local _, note_count = reaper.MIDI_CountEvts(take)
    for i = note_count - 1, 0, -1 do
      reaper.MIDI_DeleteNote(take, i)
    end
  end

  -- Insert new notes
  insert_notes(take, notes)

  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock('Write MIDI Notes', -1)

  return true, string.format('Wrote %d notes', #notes)
end

--- Apply transform function to notes
-- @param transform_fn function Takes notes array, returns transformed notes
-- @param selected_only boolean Only transform selected notes
-- @param undo_name string Name for undo block
-- @return boolean, string Success status and message
function M.apply_transform(transform_fn, selected_only, undo_name)
  local take, item, err = get_active_take()
  if not take then
    return false, err
  end

  if is_pooled_item(item) then
    return false, 'Cannot modify Ghost/Pooled MIDI items'
  end

  -- Get notes
  local notes = get_notes(take, selected_only)
  if #notes == 0 then
    return false, selected_only and 'No selected notes' or 'No notes in item'
  end

  -- Transform
  local transformed = transform_fn(notes)
  if not transformed or #transformed == 0 then
    return false, 'Transform returned no notes'
  end

  reaper.Undo_BeginBlock()

  -- Delete original notes
  local indices = {}
  for _, note in ipairs(notes) do
    table.insert(indices, note.idx)
  end
  delete_notes(take, indices)

  -- Insert transformed notes
  insert_notes(take, transformed)

  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock(undo_name or 'Transform Notes', -1)

  return true, string.format('Transformed %d notes', #transformed)
end

--- Apply randomize function to notes (alias for apply_transform with clearer semantics)
-- @param transform_fn function Takes notes array, returns transformed notes
-- @param selected_only boolean Only transform selected notes
-- @return boolean, string Success status and message
function M.randomize_notes(transform_fn, selected_only)
  return M.apply_transform(transform_fn, selected_only, 'Randomize Notes')
end

--- Clear all notes in active MIDI take
-- @return boolean, string Success status and message
function M.clear_notes()
  local take, item, err = get_active_take()
  if not take then
    return false, err
  end

  reaper.Undo_BeginBlock()

  local _, note_count = reaper.MIDI_CountEvts(take)
  for i = note_count - 1, 0, -1 do
    reaper.MIDI_DeleteNote(take, i)
  end

  reaper.Undo_EndBlock('Clear MIDI Notes', -1)

  return true, 'Cleared all notes'
end

--- Get item length in PPQ (for sequencer)
-- @return number|nil Item length in PPQ, or nil if no active take
function M.get_item_length_ppq()
  local take, item, err = get_active_take()
  if not take then
    return nil
  end

  local item_length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
  local item_start = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
  local item_end = item_start + item_length

  local start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, item_start)
  local end_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, item_end)

  return end_ppq - start_ppq
end

return M
