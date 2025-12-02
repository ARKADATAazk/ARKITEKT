-- @noindex
-- MIDIHelix/ui/euclidean_view.lua
-- Euclidean generator UI view

local M = {}

-- DEPENDENCIES
local Euclidean = require('scripts.MIDIHelix.domain.euclidean')
local MidiWriter = require('scripts.MIDIHelix.app.midi_writer')
local Defaults = require('scripts.MIDIHelix.defs.defaults')

-- STATE
local state = {
  pulses = Defaults.EUCLIDEAN.PULSES,
  steps = Defaults.EUCLIDEAN.STEPS,
  rotation = Defaults.EUCLIDEAN.ROTATION,
  note = Defaults.EUCLIDEAN.NOTE,
  velocity = Defaults.EUCLIDEAN.VELOCITY,
  grid_division = Defaults.EUCLIDEAN.GRID_DIVISION,
  note_length = Defaults.EUCLIDEAN.NOTE_LENGTH,
  pattern = {},
  message = '',
}

--- Initialize view
function M.init(Ark)
  M.Ark = Ark
  -- Generate initial pattern
  state.pattern = Euclidean.generate(state.pulses, state.steps, state.rotation)
end

--- Draw the view
function M.Draw(ctx)
  local Ark = M.Ark
  local ImGui = Ark.ImGui

  -- Header
  ImGui.Text(ctx, 'Euclidean Rhythm Generator')
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Pattern controls
  ImGui.Text(ctx, 'Pattern:')
  local changed = false

  local c1, p = ImGui.SliderInt(ctx, 'Pulses', state.pulses, 0, 32)
  state.pulses = p
  changed = changed or c1

  local c2, s = ImGui.SliderInt(ctx, 'Steps', state.steps, 1, 32)
  state.steps = s
  changed = changed or c2

  local c3, r = ImGui.SliderInt(ctx, 'Rotation', state.rotation, 0, 31)
  state.rotation = r
  changed = changed or c3

  -- Clamp pulses to steps
  if state.pulses and state.steps and state.pulses > state.steps then
    state.pulses = state.steps
    changed = true
  end

  -- Regenerate pattern if changed
  if changed then
    state.pattern = Euclidean.generate(state.pulses, state.steps, state.rotation)
  end

  ImGui.Spacing(ctx)

  -- Pattern visualization
  local pattern_str = Euclidean.visualize(state.pattern)
  local desc = Euclidean.describe(state.pulses, state.steps, state.rotation)
  ImGui.Text(ctx, string.format('%s: %s', desc, pattern_str))

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Note controls
  ImGui.Text(ctx, 'MIDI Output:')
  _, state.note = ImGui.SliderInt(ctx, 'Note', state.note, 0, 127)
  _, state.velocity = ImGui.SliderInt(ctx, 'Velocity', state.velocity, 1, 127)

  ImGui.Spacing(ctx)

  -- Grid controls
  ImGui.Text(ctx, 'Timing:')
  local grid_changed
  grid_changed, state.grid_division = ImGui.SliderDouble(ctx, 'Grid Division', state.grid_division, 0.0625, 1.0, '%.4f')
  _, state.note_length = ImGui.SliderDouble(ctx, 'Note Length', state.note_length, 0.0625, 1.0, '%.4f')

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Action buttons
  if ImGui.Button(ctx, 'Generate Pattern', 150, 30) then
    local success, msg = MidiWriter.write_pattern(state.pattern, {
      note = state.note,
      velocity = state.velocity,
      grid_division = state.grid_division,
      note_length = state.note_length,
    })
    state.message = msg
  end

  ImGui.SameLine(ctx)

  if ImGui.Button(ctx, 'Clear Notes', 150, 30) then
    local success, msg = MidiWriter.clear_notes()
    state.message = msg
  end

  -- Status message
  if state.message ~= '' then
    ImGui.Spacing(ctx)
    ImGui.Text(ctx, state.message)
  end
end

return M
