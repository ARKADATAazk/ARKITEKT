-- @noindex
-- MIDIHelix/ui/views/melodic_view.lua
-- Melodic transformation view (Inversion, Retrograde, Transpose, etc.)

local M = {}

-- Dependencies
local Scales = require('scripts.MIDIHelix.domain.scales')
local MelodicTransforms = require('scripts.MIDIHelix.domain.transforms.melodic')
local MidiWriter = require('scripts.MIDIHelix.app.midi_writer')

-- Will be set on init
local Ark = nil
local ImGui = nil

-- Forward declaration
local apply_transform

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local NOTES = Scales.NOTES
local OCTAVES = { 0, 1, 2, 3, 4, 5, 6, 7 }

local TRANSFORMS = {
  { id = 'invert',     label = 'Invert' },
  { id = 'retrograde', label = 'Retrograde' },
  { id = 'retro_inv',  label = 'Retro-Inv' },
  { id = 'transpose',  label = 'Transpose' },
  { id = 'rotate',     label = 'Rotate' },
  { id = 'quantize',   label = 'Scale Qnt' },
  { id = 'octave_fold', label = 'Oct Fold' },
}

local QUANT_DIRECTIONS = { 'Nearest', 'Up', 'Down' }

-- Layout
local LAYOUT = {
  LEFT_PANEL = { X = 25 },
  TRANSFORM_SEL = { X = 160, Y = 25 },
  PARAMS = { X = 160, Y = 80 },
  BTN_APPLY = { X = 25, Y = 175, W = 110, H = 25 },
}

-- ============================================================================
-- STATE
-- ============================================================================

local state = {
  initialized = false,

  -- Transform selection
  transform_idx = 1,

  -- Common params
  selected_only = true,

  -- Inversion params
  pivot_key = 1,      -- 1-12 (C through B)
  pivot_octave = 4,
  diatonic_mode = false,

  -- Retrograde params
  preserve_timing = true,

  -- Transpose params
  transpose_semitones = 0,
  transpose_degrees = 0,
  transpose_diatonic = false,

  -- Rotate params
  rotate_amount = 1,

  -- Scale quantize params
  scale_idx = 2,  -- Major
  scale_root = 1, -- C
  quant_direction = 1,  -- Nearest

  -- Octave fold params
  target_octave = 4,

  -- Status
  message = '',
}

-- ============================================================================
-- LEFT PANEL
-- ============================================================================

local function draw_left_panel(ctx, base_x, base_y, tab_color)
  local Colors = Ark.Colors
  local lx = base_x + LAYOUT.LEFT_PANEL.X

  -- Source selection
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 10)
  ImGui.Text(ctx, 'Source')

  ImGui.SetCursorScreenPos(ctx, lx, base_y + 30)
  if ImGui.RadioButton(ctx, 'Selected', state.selected_only) then
    state.selected_only = true
  end

  ImGui.SetCursorScreenPos(ctx, lx, base_y + 50)
  if ImGui.RadioButton(ctx, 'All Notes', not state.selected_only) then
    state.selected_only = false
  end

  -- Scale selection (for diatonic operations)
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 85)
  ImGui.Text(ctx, 'Scale')
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 103)
  ImGui.SetNextItemWidth(ctx, 110)

  local scale_names = Scales.get_scale_names()
  if ImGui.BeginCombo(ctx, '##scale', scale_names[state.scale_idx]) then
    for i, name in ipairs(scale_names) do
      if ImGui.Selectable(ctx, name, i == state.scale_idx) then
        state.scale_idx = i
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Apply button
  local btn_x = base_x + LAYOUT.BTN_APPLY.X
  local btn_y = base_y + LAYOUT.BTN_APPLY.Y

  ImGui.SetCursorScreenPos(ctx, btn_x, btn_y)
  ImGui.PushStyleColor(ctx, ImGui.Col_Button, tab_color)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, Colors.AdjustBrightness(tab_color, 1.15))
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, Colors.AdjustBrightness(tab_color, 0.85))
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x202020FF)

  if ImGui.Button(ctx, 'Apply', LAYOUT.BTN_APPLY.W, LAYOUT.BTN_APPLY.H) then
    local transform = TRANSFORMS[state.transform_idx]
    local success, msg = apply_transform(transform.id)
    state.message = msg
  end

  ImGui.PopStyleColor(ctx, 4)
end

-- ============================================================================
-- TRANSFORM SELECTION
-- ============================================================================

local function draw_transform_selection(ctx, base_x, base_y, tab_color)
  local tx = base_x + LAYOUT.TRANSFORM_SEL.X
  local ty = base_y + LAYOUT.TRANSFORM_SEL.Y

  ImGui.SetCursorScreenPos(ctx, tx, ty)
  ImGui.Text(ctx, 'Transform')

  local btn_x = tx
  for i, transform in ipairs(TRANSFORMS) do
    ImGui.SetCursorScreenPos(ctx, btn_x, ty + 20)

    local is_selected = (i == state.transform_idx)
    if is_selected then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, tab_color)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x202020FF)
    end

    if ImGui.Button(ctx, transform.label, 75, 22) then
      state.transform_idx = i
    end

    if is_selected then
      ImGui.PopStyleColor(ctx, 2)
    end

    btn_x = btn_x + 80
  end
end

-- ============================================================================
-- TRANSFORM PARAMETERS
-- ============================================================================

local function draw_invert_params(ctx, px, py)
  -- Pivot note
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Pivot')

  ImGui.SetCursorScreenPos(ctx, px + 50, py)
  ImGui.SetNextItemWidth(ctx, 50)
  if ImGui.BeginCombo(ctx, '##pivot_key', NOTES[state.pivot_key]) then
    for i, note in ipairs(NOTES) do
      if ImGui.Selectable(ctx, note, i == state.pivot_key) then
        state.pivot_key = i
      end
    end
    ImGui.EndCombo(ctx)
  end

  ImGui.SetCursorScreenPos(ctx, px + 110, py)
  ImGui.SetNextItemWidth(ctx, 40)
  if ImGui.BeginCombo(ctx, '##pivot_oct', tostring(state.pivot_octave)) then
    for _, oct in ipairs(OCTAVES) do
      if ImGui.Selectable(ctx, tostring(oct), oct == state.pivot_octave) then
        state.pivot_octave = oct
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Mode
  ImGui.SetCursorScreenPos(ctx, px, py + 30)
  if ImGui.RadioButton(ctx, 'Chromatic', not state.diatonic_mode) then
    state.diatonic_mode = false
  end
  ImGui.SetCursorScreenPos(ctx, px + 100, py + 30)
  if ImGui.RadioButton(ctx, 'Diatonic', state.diatonic_mode) then
    state.diatonic_mode = true
  end
end

local function draw_retrograde_params(ctx, px, py)
  ImGui.SetCursorScreenPos(ctx, px, py)
  local _, pt = ImGui.Checkbox(ctx, 'Preserve Timing', state.preserve_timing)
  state.preserve_timing = pt

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, state.preserve_timing and '(Reverse pitches only)' or '(Reverse notes + timing)')
end

local function draw_transpose_params(ctx, px, py)
  -- Mode
  ImGui.SetCursorScreenPos(ctx, px, py)
  if ImGui.RadioButton(ctx, 'Chromatic', not state.transpose_diatonic) then
    state.transpose_diatonic = false
  end
  ImGui.SetCursorScreenPos(ctx, px + 100, py)
  if ImGui.RadioButton(ctx, 'Diatonic', state.transpose_diatonic) then
    state.transpose_diatonic = true
  end

  -- Amount
  ImGui.SetCursorScreenPos(ctx, px, py + 30)
  ImGui.Text(ctx, state.transpose_diatonic and 'Degrees' or 'Semitones')

  ImGui.SetCursorScreenPos(ctx, px + 80, py + 30)
  ImGui.SetNextItemWidth(ctx, 100)

  if state.transpose_diatonic then
    local _, deg = ImGui.SliderInt(ctx, '##trans_deg', state.transpose_degrees, -12, 12)
    state.transpose_degrees = deg
  else
    local _, semi = ImGui.SliderInt(ctx, '##trans_semi', state.transpose_semitones, -24, 24)
    state.transpose_semitones = semi
  end
end

local function draw_rotate_params(ctx, px, py)
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Positions')

  ImGui.SetCursorScreenPos(ctx, px + 80, py)
  ImGui.SetNextItemWidth(ctx, 100)
  local _, amt = ImGui.SliderInt(ctx, '##rotate', state.rotate_amount, -8, 8)
  state.rotate_amount = amt

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, 'Rotate pitches while keeping timing')
end

local function draw_quantize_params(ctx, px, py)
  -- Root
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Root')
  ImGui.SetCursorScreenPos(ctx, px + 50, py)
  ImGui.SetNextItemWidth(ctx, 50)
  if ImGui.BeginCombo(ctx, '##qroot', NOTES[state.scale_root]) then
    for i, note in ipairs(NOTES) do
      if ImGui.Selectable(ctx, note, i == state.scale_root) then
        state.scale_root = i
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Direction
  ImGui.SetCursorScreenPos(ctx, px + 120, py)
  ImGui.Text(ctx, 'Dir')
  ImGui.SetCursorScreenPos(ctx, px + 150, py)
  ImGui.SetNextItemWidth(ctx, 80)
  if ImGui.BeginCombo(ctx, '##qdir', QUANT_DIRECTIONS[state.quant_direction]) then
    for i, dir in ipairs(QUANT_DIRECTIONS) do
      if ImGui.Selectable(ctx, dir, i == state.quant_direction) then
        state.quant_direction = i
      end
    end
    ImGui.EndCombo(ctx)
  end
end

local function draw_octave_fold_params(ctx, px, py)
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Target Octave')

  ImGui.SetCursorScreenPos(ctx, px + 100, py)
  ImGui.SetNextItemWidth(ctx, 50)
  if ImGui.BeginCombo(ctx, '##target_oct', tostring(state.target_octave)) then
    for _, oct in ipairs(OCTAVES) do
      if ImGui.Selectable(ctx, tostring(oct), oct == state.target_octave) then
        state.target_octave = oct
      end
    end
    ImGui.EndCombo(ctx)
  end

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, 'Fold all notes into one octave')
end

local function draw_params(ctx, base_x, base_y)
  local px = base_x + LAYOUT.PARAMS.X
  local py = base_y + LAYOUT.PARAMS.Y

  local transform = TRANSFORMS[state.transform_idx]

  if transform.id == 'invert' or transform.id == 'retro_inv' then
    draw_invert_params(ctx, px, py)
  elseif transform.id == 'retrograde' then
    draw_retrograde_params(ctx, px, py)
  elseif transform.id == 'transpose' then
    draw_transpose_params(ctx, px, py)
  elseif transform.id == 'rotate' then
    draw_rotate_params(ctx, px, py)
  elseif transform.id == 'quantize' then
    draw_quantize_params(ctx, px, py)
  elseif transform.id == 'octave_fold' then
    draw_octave_fold_params(ctx, px, py)
  end
end

-- ============================================================================
-- APPLY TRANSFORM
-- ============================================================================

apply_transform = function(transform_id)
  local scale = Scales.get_scale_by_index(state.scale_idx)
  local pivot = (state.pivot_octave + 1) * 12 + (state.pivot_key - 1)
  local root = state.scale_root - 1  -- 0-11

  local transform_fn
  local undo_name

  if transform_id == 'invert' then
    undo_name = 'Invert Notes'
    if state.diatonic_mode and scale then
      transform_fn = function(notes)
        return MelodicTransforms.invert_diatonic(notes, pivot, scale, root)
      end
    else
      transform_fn = function(notes)
        return MelodicTransforms.invert_chromatic(notes, pivot)
      end
    end

  elseif transform_id == 'retrograde' then
    undo_name = 'Retrograde'
    transform_fn = function(notes)
      return MelodicTransforms.retrograde(notes, state.preserve_timing)
    end

  elseif transform_id == 'retro_inv' then
    undo_name = 'Retrograde Inversion'
    transform_fn = function(notes)
      return MelodicTransforms.retrograde_inversion(notes, pivot, state.preserve_timing)
    end

  elseif transform_id == 'transpose' then
    undo_name = 'Transpose Notes'
    if state.transpose_diatonic and scale then
      transform_fn = function(notes)
        return MelodicTransforms.transpose_diatonic(notes, state.transpose_degrees, scale, root)
      end
    else
      transform_fn = function(notes)
        return MelodicTransforms.transpose_chromatic(notes, state.transpose_semitones)
      end
    end

  elseif transform_id == 'rotate' then
    undo_name = 'Rotate Pitches'
    transform_fn = function(notes)
      return MelodicTransforms.rotate_pitches(notes, state.rotate_amount)
    end

  elseif transform_id == 'quantize' then
    undo_name = 'Scale Quantize'
    local dir = string.lower(QUANT_DIRECTIONS[state.quant_direction])
    transform_fn = function(notes)
      return MelodicTransforms.scale_quantize(notes, scale, root, dir)
    end

  elseif transform_id == 'octave_fold' then
    undo_name = 'Octave Fold'
    transform_fn = function(notes)
      return MelodicTransforms.octave_fold(notes, state.target_octave)
    end
  end

  if transform_fn then
    return MidiWriter.apply_transform(transform_fn, state.selected_only, undo_name)
  end

  return false, 'Unknown transform'
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function M.init(ark_instance)
  if state.initialized then return end
  Ark = ark_instance
  ImGui = Ark.ImGui
  state.initialized = true
end

function M.Draw(ctx, opts)
  if not state.initialized then return end

  opts = opts or {}
  local base_x = opts.x or 0
  local base_y = opts.y or 0
  local win_w = opts.w or 900
  local win_h = opts.h or 200
  local tab_color = opts.tab_color or 0x00CED1FF

  draw_left_panel(ctx, base_x, base_y, tab_color)
  draw_transform_selection(ctx, base_x, base_y, tab_color)
  draw_params(ctx, base_x, base_y)

  -- Status message
  if state.message ~= '' then
    ImGui.SetCursorScreenPos(ctx, base_x + 160, base_y + win_h - 30)
    ImGui.TextColored(ctx, 0x80FF80FF, state.message)
  end
end

function M.get_state()
  return {
    transform_idx = state.transform_idx,
    selected_only = state.selected_only,
    pivot_key = state.pivot_key,
    pivot_octave = state.pivot_octave,
    diatonic_mode = state.diatonic_mode,
    preserve_timing = state.preserve_timing,
    transpose_semitones = state.transpose_semitones,
    transpose_degrees = state.transpose_degrees,
    transpose_diatonic = state.transpose_diatonic,
    rotate_amount = state.rotate_amount,
    scale_idx = state.scale_idx,
    scale_root = state.scale_root,
    quant_direction = state.quant_direction,
    target_octave = state.target_octave,
  }
end

function M.set_state(new_state)
  if not new_state then return end
  for k, v in pairs(new_state) do
    if state[k] ~= nil then
      state[k] = v
    end
  end
end

return M
