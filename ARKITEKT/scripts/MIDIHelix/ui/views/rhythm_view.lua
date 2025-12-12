-- @noindex
-- MIDIHelix/ui/views/rhythm_view.lua
-- Rhythm transformation view (Augment, Diminish, Quantize, Swing, Humanize, etc.)

local M = {}

-- Dependencies
local RhythmTransforms = require('scripts.MIDIHelix.domain.transforms.rhythm')
local MidiWriter = require('scripts.MIDIHelix.app.midi_writer')

-- Will be set on init
local Ark = nil
local ImGui = nil

-- Forward declaration
local apply_transform

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local PPQN = 960  -- Standard pulses per quarter note

local TRANSFORMS = {
  { id = 'augment',   label = 'Aug/Dim' },
  { id = 'quantize',  label = 'Quantize' },
  { id = 'swing',     label = 'Swing' },
  { id = 'humanize',  label = 'Humanize' },
  { id = 'legato',    label = 'Legato' },
  { id = 'staccato',  label = 'Staccato' },
  { id = 'velocity',  label = 'Velocity' },
  { id = 'shift',     label = 'Time Shift' },
}

local GRID_OPTIONS = {
  { label = '1/32',  ppq = PPQN / 8 },
  { label = '1/16',  ppq = PPQN / 4 },
  { label = '1/8',   ppq = PPQN / 2 },
  { label = '1/4',   ppq = PPQN },
  { label = '1/2',   ppq = PPQN * 2 },
}

local FACTOR_PRESETS = {
  { label = '4x',    value = 4.0 },
  { label = '2x',    value = 2.0 },
  { label = '1.5x',  value = 1.5 },
  { label = '1x',    value = 1.0 },
  { label = '0.75x', value = 0.75 },
  { label = '0.5x',  value = 0.5 },
  { label = '0.25x', value = 0.25 },
}

-- Layout
local LAYOUT = {
  LEFT_PANEL = { X = 25 },
  TRANSFORM_SEL = { X = 160, Y = 25 },
  PARAMS = { X = 160, Y = 80 },
  BTN_ROW = { X = 25, Y = 175, W = 54, H = 25, GAP = 4 },
}

-- ============================================================================
-- STATE
-- ============================================================================

local state = {
  initialized = false,

  -- Transform selection
  transform_idx = 1,

  -- Augment/Diminish params
  aug_factor_idx = 4,  -- 1.0x default
  aug_affect_positions = true,
  aug_affect_durations = true,
  aug_affect_velocities = false,

  -- Quantize params
  quant_grid_idx = 2,  -- 1/16
  quant_strength = 100,  -- 100%
  quant_ends = false,

  -- Swing params
  swing_amount = 66,  -- 0-100 (50 = no swing)
  swing_grid_idx = 2,  -- 1/16

  -- Humanize params
  humanize_timing = 10,
  humanize_velocity = 10,
  humanize_length = 0,

  -- Legato params
  legato_gap = 0,

  -- Staccato params
  staccato_percent = 50,

  -- Velocity params
  velocity_factor = 100,  -- 100% = no change
  velocity_center = 64,

  -- Time shift params
  shift_grid_idx = 2,  -- 1/16
  shift_amount = 0,  -- Number of grid steps

  -- Status
  message = '',
}

-- ============================================================================
-- LEFT PANEL
-- ============================================================================

local function draw_left_panel(ctx, base_x, base_y, tab_color)
  local Colors = Ark.Colors
  local lx = base_x + LAYOUT.LEFT_PANEL.X

  -- Grid selection (used by multiple transforms)
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 10)
  ImGui.Text(ctx, 'Grid')
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 28)
  ImGui.SetNextItemWidth(ctx, 60)

  local transform = TRANSFORMS[state.transform_idx]
  local grid_idx = state.quant_grid_idx
  if transform.id == 'swing' then
    grid_idx = state.swing_grid_idx
  elseif transform.id == 'shift' then
    grid_idx = state.shift_grid_idx
  end

  if ImGui.BeginCombo(ctx, '##grid', GRID_OPTIONS[grid_idx].label) then
    for i, g in ipairs(GRID_OPTIONS) do
      if ImGui.Selectable(ctx, g.label, i == grid_idx) then
        if transform.id == 'swing' then
          state.swing_grid_idx = i
        elseif transform.id == 'shift' then
          state.shift_grid_idx = i
        else
          state.quant_grid_idx = i
        end
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Apply buttons (Sel / All)
  local row = LAYOUT.BTN_ROW
  local btn_x = base_x + row.X
  local btn_y = base_y + row.Y

  ImGui.PushStyleColor(ctx, ImGui.Col_Button, tab_color)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, Colors.AdjustBrightness(tab_color, 1.15))
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, Colors.AdjustBrightness(tab_color, 0.85))
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x202020FF)

  ImGui.SetCursorScreenPos(ctx, btn_x, btn_y)
  if ImGui.Button(ctx, 'Apply Sel', row.W, row.H) then
    local success, msg = apply_transform(transform.id, true)
    state.message = msg
  end

  ImGui.SetCursorScreenPos(ctx, btn_x + row.W + row.GAP, btn_y)
  if ImGui.Button(ctx, 'Apply All', row.W, row.H) then
    local success, msg = apply_transform(transform.id, false)
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
    -- Wrap to second row after 4 buttons
    if i == 5 then
      btn_x = tx
    end

    local row = (i <= 4) and 0 or 1
    ImGui.SetCursorScreenPos(ctx, btn_x, ty + 20 + row * 26)

    local is_selected = (i == state.transform_idx)
    if is_selected then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, tab_color)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x202020FF)
    end

    if ImGui.Button(ctx, transform.label, 70, 22) then
      state.transform_idx = i
    end

    if is_selected then
      ImGui.PopStyleColor(ctx, 2)
    end

    btn_x = btn_x + 75
  end
end

-- ============================================================================
-- TRANSFORM PARAMETERS
-- ============================================================================

local function draw_augment_params(ctx, px, py)
  -- Factor presets
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Factor')

  ImGui.SetCursorScreenPos(ctx, px + 50, py)
  ImGui.SetNextItemWidth(ctx, 70)
  if ImGui.BeginCombo(ctx, '##factor', FACTOR_PRESETS[state.aug_factor_idx].label) then
    for i, preset in ipairs(FACTOR_PRESETS) do
      if ImGui.Selectable(ctx, preset.label, i == state.aug_factor_idx) then
        state.aug_factor_idx = i
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Affect options
  ImGui.SetCursorScreenPos(ctx, px + 140, py)
  local _, pos = ImGui.Checkbox(ctx, 'Positions', state.aug_affect_positions)
  state.aug_affect_positions = pos

  ImGui.SetCursorScreenPos(ctx, px + 240, py)
  local _, dur = ImGui.Checkbox(ctx, 'Durations', state.aug_affect_durations)
  state.aug_affect_durations = dur

  ImGui.SetCursorScreenPos(ctx, px + 340, py)
  local _, vel = ImGui.Checkbox(ctx, 'Velocities', state.aug_affect_velocities)
  state.aug_affect_velocities = vel
end

local function draw_quantize_params(ctx, px, py)
  -- Strength
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Strength')

  ImGui.SetCursorScreenPos(ctx, px + 70, py)
  ImGui.SetNextItemWidth(ctx, 150)
  local _, str = ImGui.SliderInt(ctx, '##qstrength', state.quant_strength, 0, 100, '%d%%')
  state.quant_strength = str

  -- Quantize ends
  ImGui.SetCursorScreenPos(ctx, px + 240, py)
  local _, ends = ImGui.Checkbox(ctx, 'Quantize Ends', state.quant_ends)
  state.quant_ends = ends
end

local function draw_swing_params(ctx, px, py)
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Amount')

  ImGui.SetCursorScreenPos(ctx, px + 60, py)
  ImGui.SetNextItemWidth(ctx, 200)
  local _, amt = ImGui.SliderInt(ctx, '##swing', state.swing_amount, 50, 75, '%d%%')
  state.swing_amount = amt

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, '50% = straight, 66% = triplet feel')
end

local function draw_humanize_params(ctx, px, py)
  -- Timing variation
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Timing')
  ImGui.SetCursorScreenPos(ctx, px + 60, py)
  ImGui.SetNextItemWidth(ctx, 80)
  local _, tim = ImGui.SliderInt(ctx, '##htiming', state.humanize_timing, 0, 50, '%d%%')
  state.humanize_timing = tim

  -- Velocity variation
  ImGui.SetCursorScreenPos(ctx, px + 160, py)
  ImGui.Text(ctx, 'Velocity')
  ImGui.SetCursorScreenPos(ctx, px + 220, py)
  ImGui.SetNextItemWidth(ctx, 80)
  local _, vel = ImGui.SliderInt(ctx, '##hvel', state.humanize_velocity, 0, 50, '%d%%')
  state.humanize_velocity = vel

  -- Length variation
  ImGui.SetCursorScreenPos(ctx, px + 320, py)
  ImGui.Text(ctx, 'Length')
  ImGui.SetCursorScreenPos(ctx, px + 370, py)
  ImGui.SetNextItemWidth(ctx, 80)
  local _, len = ImGui.SliderInt(ctx, '##hlen', state.humanize_length, 0, 50, '%d%%')
  state.humanize_length = len
end

local function draw_legato_params(ctx, px, py)
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Gap (ticks)')

  ImGui.SetCursorScreenPos(ctx, px + 80, py)
  ImGui.SetNextItemWidth(ctx, 100)
  local _, gap = ImGui.SliderInt(ctx, '##lgap', state.legato_gap, 0, 120)
  state.legato_gap = gap

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, 'Extend notes to next note start')
end

local function draw_staccato_params(ctx, px, py)
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Length %')

  ImGui.SetCursorScreenPos(ctx, px + 70, py)
  ImGui.SetNextItemWidth(ctx, 150)
  local _, pct = ImGui.SliderInt(ctx, '##staccato', state.staccato_percent, 10, 90, '%d%%')
  state.staccato_percent = pct

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, 'Shorten notes to percentage of original')
end

local function draw_velocity_params(ctx, px, py)
  -- Factor
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Scale')
  ImGui.SetCursorScreenPos(ctx, px + 50, py)
  ImGui.SetNextItemWidth(ctx, 120)
  local _, fac = ImGui.SliderInt(ctx, '##vfactor', state.velocity_factor, 25, 200, '%d%%')
  state.velocity_factor = fac

  -- Center point
  ImGui.SetCursorScreenPos(ctx, px + 200, py)
  ImGui.Text(ctx, 'Center')
  ImGui.SetCursorScreenPos(ctx, px + 260, py)
  ImGui.SetNextItemWidth(ctx, 80)
  local _, cen = ImGui.SliderInt(ctx, '##vcenter', state.velocity_center, 1, 127)
  state.velocity_center = cen

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, 'Compress/expand dynamics around center')
end

local function draw_shift_params(ctx, px, py)
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Steps')

  ImGui.SetCursorScreenPos(ctx, px + 50, py)
  ImGui.SetNextItemWidth(ctx, 120)
  local _, amt = ImGui.SliderInt(ctx, '##shift_amt', state.shift_amount, -16, 16)
  state.shift_amount = amt

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  local grid_label = GRID_OPTIONS[state.shift_grid_idx].label
  ImGui.TextColored(ctx, 0x808080FF, string.format('Shift all notes by %d x %s', state.shift_amount, grid_label))
end

local function draw_params(ctx, base_x, base_y)
  local px = base_x + LAYOUT.PARAMS.X
  local py = base_y + LAYOUT.PARAMS.Y + 26  -- Extra offset for second row of buttons

  local transform = TRANSFORMS[state.transform_idx]

  if transform.id == 'augment' then
    draw_augment_params(ctx, px, py)
  elseif transform.id == 'quantize' then
    draw_quantize_params(ctx, px, py)
  elseif transform.id == 'swing' then
    draw_swing_params(ctx, px, py)
  elseif transform.id == 'humanize' then
    draw_humanize_params(ctx, px, py)
  elseif transform.id == 'legato' then
    draw_legato_params(ctx, px, py)
  elseif transform.id == 'staccato' then
    draw_staccato_params(ctx, px, py)
  elseif transform.id == 'velocity' then
    draw_velocity_params(ctx, px, py)
  elseif transform.id == 'shift' then
    draw_shift_params(ctx, px, py)
  end
end

-- ============================================================================
-- APPLY TRANSFORM
-- ============================================================================

apply_transform = function(transform_id, selected_only)
  local transform_fn
  local undo_name

  if transform_id == 'augment' then
    undo_name = 'Augment/Diminish'
    local factor = FACTOR_PRESETS[state.aug_factor_idx].value
    transform_fn = function(notes)
      return RhythmTransforms.augment_diminish(notes, factor, {
        affect_positions = state.aug_affect_positions,
        affect_durations = state.aug_affect_durations,
        affect_velocities = state.aug_affect_velocities,
      })
    end

  elseif transform_id == 'quantize' then
    undo_name = 'Quantize'
    local grid_ppq = GRID_OPTIONS[state.quant_grid_idx].ppq
    local strength = state.quant_strength / 100
    transform_fn = function(notes)
      return RhythmTransforms.quantize(notes, grid_ppq, strength, state.quant_ends)
    end

  elseif transform_id == 'swing' then
    undo_name = 'Apply Swing'
    local grid_ppq = GRID_OPTIONS[state.swing_grid_idx].ppq
    local amount = state.swing_amount / 100
    transform_fn = function(notes)
      return RhythmTransforms.swing(notes, amount, grid_ppq)
    end

  elseif transform_id == 'humanize' then
    undo_name = 'Humanize'
    transform_fn = function(notes)
      return RhythmTransforms.humanize(notes, {
        timing_var = state.humanize_timing,
        velocity_var = state.humanize_velocity,
        length_var = state.humanize_length,
      })
    end

  elseif transform_id == 'legato' then
    undo_name = 'Legato'
    transform_fn = function(notes)
      return RhythmTransforms.legato(notes, state.legato_gap)
    end

  elseif transform_id == 'staccato' then
    undo_name = 'Staccato'
    transform_fn = function(notes)
      return RhythmTransforms.staccato(notes, state.staccato_percent)
    end

  elseif transform_id == 'velocity' then
    undo_name = 'Scale Velocity'
    local factor = state.velocity_factor / 100
    transform_fn = function(notes)
      return RhythmTransforms.velocity_scale(notes, factor, state.velocity_center)
    end

  elseif transform_id == 'shift' then
    undo_name = 'Time Shift'
    local grid_ppq = GRID_OPTIONS[state.shift_grid_idx].ppq
    local offset = state.shift_amount * grid_ppq
    transform_fn = function(notes)
      return RhythmTransforms.time_shift(notes, offset)
    end
  end

  if transform_fn then
    return MidiWriter.apply_transform(transform_fn, selected_only, undo_name)
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
  local tab_color = opts.tab_color or 0xFF6B6BFF

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
    aug_factor_idx = state.aug_factor_idx,
    aug_affect_positions = state.aug_affect_positions,
    aug_affect_durations = state.aug_affect_durations,
    aug_affect_velocities = state.aug_affect_velocities,
    quant_grid_idx = state.quant_grid_idx,
    quant_strength = state.quant_strength,
    quant_ends = state.quant_ends,
    swing_amount = state.swing_amount,
    swing_grid_idx = state.swing_grid_idx,
    humanize_timing = state.humanize_timing,
    humanize_velocity = state.humanize_velocity,
    humanize_length = state.humanize_length,
    legato_gap = state.legato_gap,
    staccato_percent = state.staccato_percent,
    velocity_factor = state.velocity_factor,
    velocity_center = state.velocity_center,
    shift_grid_idx = state.shift_grid_idx,
    shift_amount = state.shift_amount,
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
