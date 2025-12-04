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

return M
