-- @noindex
-- MIDIHelix/ui/views/generative_view.lua
-- Advanced generative transformations UI
-- Negative harmony, Markov chains, 12-tone, cellular automata, etc.

local M = {}

-- Dependencies
local Scales = require('scripts.MIDIHelix.domain.scales')
local Generative = require('scripts.MIDIHelix.domain.transforms.generative')
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

local TRANSFORMS = {
  { id = 'negative',    label = 'Negative' },
  { id = 'interval',    label = 'Interval×' },
  { id = 'markov',      label = 'Markov' },
  { id = 'serial',      label = '12-Tone' },
  { id = 'cellular',    label = 'Cell Auto' },
  { id = 'contour',     label = 'Contour' },
  { id = 'fibonacci',   label = 'Fibonacci' },
  { id = 'brownian',    label = 'Brownian' },
  { id = 'overtone',    label = 'Overtone' },
  { id = 'permute',     label = 'Permute' },
}

local SERIAL_FORMS = { 'P', 'I', 'R', 'RI' }
local SERIAL_FORM_NAMES = { 'Prime', 'Inversion', 'Retrograde', 'Retro-Inv' }

local CA_RULES = {
  { label = 'Rule 30 (Chaotic)', value = 30 },
  { label = 'Rule 90 (Fractal)', value = 90 },
  { label = 'Rule 110 (Complex)', value = 110 },
  { label = 'Rule 184 (Traffic)', value = 184 },
  { label = 'Rule 45', value = 45 },
  { label = 'Rule 73', value = 73 },
}

local FIB_MODES = { 'Pitch', 'Rhythm', 'Both' }

-- Layout
local LAYOUT = {
  LEFT_PANEL = { X = 25 },
  TRANSFORM_SEL = { X = 160, Y = 20 },
  PARAMS = { X = 160, Y = 75 },
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

  -- Negative harmony params
  neg_root = 1,  -- C
  neg_axis_type = 1,  -- 1 = tonic_dominant, 2 = chromatic

  -- Interval multiply params
  interval_factor = 2.0,
  interval_anchor = 1,  -- 1 = first, 2 = center, 3 = last

  -- Markov params
  markov_chaos = 50,  -- 0-100
  markov_order = 1,

  -- Serial/12-tone params
  serial_form = 1,  -- P
  serial_transposition = 0,

  -- Cellular automata params
  ca_rule_idx = 1,  -- Rule 30
  ca_generations = 16,
  ca_scale_idx = 2,  -- Major
  ca_root = 1,  -- C

  -- Contour params (uses scale from left panel)
  contour_scale_idx = 2,
  contour_root = 1,

  -- Fibonacci params
  fib_mode = 1,  -- Pitch
  fib_scale_idx = 2,
  fib_root = 1,

  -- Brownian params
  brownian_step = 3,
  brownian_gravity = 20,  -- 0-100
  brownian_center = 60,

  -- Overtone params
  overtone_fundamental = 36,  -- C2
  overtone_max_partial = 16,
  overtone_quantize = false,

  -- Common scale (for transforms that need it)
  scale_idx = 2,  -- Major
  scale_root = 1,  -- C

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

  ImGui.SetCursorScreenPos(ctx, lx, base_y + 28)
  if ImGui.RadioButton(ctx, 'Selected', state.selected_only) then
    state.selected_only = true
  end

  ImGui.SetCursorScreenPos(ctx, lx, base_y + 46)
  if ImGui.RadioButton(ctx, 'All Notes', not state.selected_only) then
    state.selected_only = false
  end

  -- Scale selection (used by multiple transforms)
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 75)
  ImGui.Text(ctx, 'Scale')
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 93)
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

  -- Root
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 118)
  ImGui.Text(ctx, 'Root')
  ImGui.SetCursorScreenPos(ctx, lx + 35, base_y + 118)
  ImGui.SetNextItemWidth(ctx, 45)
  if ImGui.BeginCombo(ctx, '##root', NOTES[state.scale_root]) then
    for i, note in ipairs(NOTES) do
      if ImGui.Selectable(ctx, note, i == state.scale_root) then
        state.scale_root = i
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
-- TRANSFORM SELECTION (2 rows of 5)
-- ============================================================================

local function draw_transform_selection(ctx, base_x, base_y, tab_color)
  local tx = base_x + LAYOUT.TRANSFORM_SEL.X
  local ty = base_y + LAYOUT.TRANSFORM_SEL.Y

  ImGui.SetCursorScreenPos(ctx, tx, ty)
  ImGui.Text(ctx, 'Algorithm')

  local btn_x = tx
  for i, transform in ipairs(TRANSFORMS) do
    -- Wrap to second row after 5 buttons
    if i == 6 then
      btn_x = tx
    end

    local row = (i <= 5) and 0 or 1
    ImGui.SetCursorScreenPos(ctx, btn_x, ty + 18 + row * 24)

    local is_selected = (i == state.transform_idx)
    if is_selected then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, tab_color)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x202020FF)
    end

    if ImGui.Button(ctx, transform.label, 65, 20) then
      state.transform_idx = i
    end

    if is_selected then
      ImGui.PopStyleColor(ctx, 2)
    end

    btn_x = btn_x + 70
  end
end

-- ============================================================================
-- TRANSFORM PARAMETERS
-- ============================================================================

local function draw_negative_params(ctx, px, py)
  -- Axis root
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Axis Root')
  ImGui.SetCursorScreenPos(ctx, px + 70, py)
  ImGui.SetNextItemWidth(ctx, 50)
  if ImGui.BeginCombo(ctx, '##neg_root', NOTES[state.neg_root]) then
    for i, note in ipairs(NOTES) do
      if ImGui.Selectable(ctx, note, i == state.neg_root) then
        state.neg_root = i
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Axis type
  ImGui.SetCursorScreenPos(ctx, px + 140, py)
  if ImGui.RadioButton(ctx, 'Tonic-Dom', state.neg_axis_type == 1) then
    state.neg_axis_type = 1
  end
  ImGui.SetCursorScreenPos(ctx, px + 240, py)
  if ImGui.RadioButton(ctx, 'Chromatic', state.neg_axis_type == 2) then
    state.neg_axis_type = 2
  end

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, 'Ernst Levy negative harmony - mirrors melody around tonic/dominant axis')
end

local function draw_interval_params(ctx, px, py)
  -- Factor
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Factor')
  ImGui.SetCursorScreenPos(ctx, px + 50, py)
  ImGui.SetNextItemWidth(ctx, 120)
  local _, fac = ImGui.SliderDouble(ctx, '##int_fac', state.interval_factor, -3.0, 3.0, '%.2fx')
  state.interval_factor = fac

  -- Anchor
  ImGui.SetCursorScreenPos(ctx, px + 200, py)
  ImGui.Text(ctx, 'Anchor')
  local anchors = { 'First', 'Center', 'Last' }
  ImGui.SetCursorScreenPos(ctx, px + 260, py)
  ImGui.SetNextItemWidth(ctx, 70)
  if ImGui.BeginCombo(ctx, '##anchor', anchors[state.interval_anchor]) then
    for i, a in ipairs(anchors) do
      if ImGui.Selectable(ctx, a, i == state.interval_anchor) then
        state.interval_anchor = i
      end
    end
    ImGui.EndCombo(ctx)
  end

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, 'Multiply intervals - 2x=expand, 0.5x=contract, -1x=invert')
end

local function draw_markov_params(ctx, px, py)
  -- Chaos amount
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Chaos')
  ImGui.SetCursorScreenPos(ctx, px + 50, py)
  ImGui.SetNextItemWidth(ctx, 120)
  local _, chaos = ImGui.SliderInt(ctx, '##markov_chaos', state.markov_chaos, 0, 100, '%d%%')
  state.markov_chaos = chaos

  -- Order
  ImGui.SetCursorScreenPos(ctx, px + 200, py)
  ImGui.Text(ctx, 'Order')
  ImGui.SetCursorScreenPos(ctx, px + 250, py)
  ImGui.SetNextItemWidth(ctx, 50)
  local _, ord = ImGui.SliderInt(ctx, '##markov_ord', state.markov_order, 1, 3)
  state.markov_order = ord

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, 'Analyzes note transitions, generates probabilistic melody')
end

local function draw_serial_params(ctx, px, py)
  -- Form
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Form')
  ImGui.SetCursorScreenPos(ctx, px + 45, py)
  ImGui.SetNextItemWidth(ctx, 100)
  if ImGui.BeginCombo(ctx, '##serial_form', SERIAL_FORM_NAMES[state.serial_form]) then
    for i, name in ipairs(SERIAL_FORM_NAMES) do
      if ImGui.Selectable(ctx, name, i == state.serial_form) then
        state.serial_form = i
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Transposition
  ImGui.SetCursorScreenPos(ctx, px + 170, py)
  ImGui.Text(ctx, 'T')
  ImGui.SetCursorScreenPos(ctx, px + 190, py)
  ImGui.SetNextItemWidth(ctx, 100)
  local _, trans = ImGui.SliderInt(ctx, '##serial_t', state.serial_transposition, 0, 11)
  state.serial_transposition = trans

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, '12-tone serial technique - P/I/R/RI transformations')
end

local function draw_cellular_params(ctx, px, py)
  -- Rule
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Rule')
  ImGui.SetCursorScreenPos(ctx, px + 40, py)
  ImGui.SetNextItemWidth(ctx, 130)
  if ImGui.BeginCombo(ctx, '##ca_rule', CA_RULES[state.ca_rule_idx].label) then
    for i, rule in ipairs(CA_RULES) do
      if ImGui.Selectable(ctx, rule.label, i == state.ca_rule_idx) then
        state.ca_rule_idx = i
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Generations
  ImGui.SetCursorScreenPos(ctx, px + 200, py)
  ImGui.Text(ctx, 'Gen')
  ImGui.SetCursorScreenPos(ctx, px + 240, py)
  ImGui.SetNextItemWidth(ctx, 60)
  local _, gen = ImGui.SliderInt(ctx, '##ca_gen', state.ca_generations, 4, 64)
  state.ca_generations = gen

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, 'Cellular automata - emergent patterns from simple rules')
end

local function draw_contour_params(ctx, px, py)
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.TextColored(ctx, 0x808080FF, 'Maps melodic contour (shape) to scale degrees')

  ImGui.SetCursorScreenPos(ctx, px, py + 20)
  ImGui.TextColored(ctx, 0x606060FF, 'Uses Scale/Root from left panel')
end

local function draw_fibonacci_params(ctx, px, py)
  -- Mode
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Mode')
  ImGui.SetCursorScreenPos(ctx, px + 45, py)
  ImGui.SetNextItemWidth(ctx, 80)
  if ImGui.BeginCombo(ctx, '##fib_mode', FIB_MODES[state.fib_mode]) then
    for i, mode in ipairs(FIB_MODES) do
      if ImGui.Selectable(ctx, mode, i == state.fib_mode) then
        state.fib_mode = i
      end
    end
    ImGui.EndCombo(ctx)
  end

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, 'Fibonacci sequence for pitch intervals or rhythm durations')
end

local function draw_brownian_params(ctx, px, py)
  -- Step size
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Step')
  ImGui.SetCursorScreenPos(ctx, px + 40, py)
  ImGui.SetNextItemWidth(ctx, 60)
  local _, step = ImGui.SliderInt(ctx, '##br_step', state.brownian_step, 1, 12)
  state.brownian_step = step

  -- Gravity
  ImGui.SetCursorScreenPos(ctx, px + 120, py)
  ImGui.Text(ctx, 'Gravity')
  ImGui.SetCursorScreenPos(ctx, px + 175, py)
  ImGui.SetNextItemWidth(ctx, 60)
  local _, grav = ImGui.SliderInt(ctx, '##br_grav', state.brownian_gravity, 0, 100, '%d%%')
  state.brownian_gravity = grav

  -- Center
  ImGui.SetCursorScreenPos(ctx, px + 260, py)
  ImGui.Text(ctx, 'Center')
  ImGui.SetCursorScreenPos(ctx, px + 310, py)
  ImGui.SetNextItemWidth(ctx, 50)
  local _, cen = ImGui.SliderInt(ctx, '##br_cen', state.brownian_center, 36, 96)
  state.brownian_center = cen

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, 'Random walk with optional pull toward center pitch')
end

local function draw_overtone_params(ctx, px, py)
  -- Fundamental
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.Text(ctx, 'Fundamental')
  ImGui.SetCursorScreenPos(ctx, px + 85, py)
  ImGui.SetNextItemWidth(ctx, 60)
  local _, fund = ImGui.SliderInt(ctx, '##ot_fund', state.overtone_fundamental, 24, 60)
  state.overtone_fundamental = fund

  -- Max partial
  ImGui.SetCursorScreenPos(ctx, px + 170, py)
  ImGui.Text(ctx, 'Partials')
  ImGui.SetCursorScreenPos(ctx, px + 230, py)
  ImGui.SetNextItemWidth(ctx, 50)
  local _, part = ImGui.SliderInt(ctx, '##ot_part', state.overtone_max_partial, 4, 32)
  state.overtone_max_partial = part

  -- Quantize mode
  ImGui.SetCursorScreenPos(ctx, px + 310, py)
  local _, quant = ImGui.Checkbox(ctx, 'Snap', state.overtone_quantize)
  state.overtone_quantize = quant

  ImGui.SetCursorScreenPos(ctx, px, py + 25)
  ImGui.TextColored(ctx, 0x808080FF, 'Map notes to harmonic overtone series')
end

local function draw_permute_params(ctx, px, py)
  ImGui.SetCursorScreenPos(ctx, px, py)
  ImGui.TextColored(ctx, 0x808080FF, 'Randomly permute (shuffle) pitch order while keeping rhythm')

  ImGui.SetCursorScreenPos(ctx, px, py + 20)
  ImGui.TextColored(ctx, 0x606060FF, 'Each click generates a new random permutation')
end

local function draw_params(ctx, base_x, base_y)
  local px = base_x + LAYOUT.PARAMS.X
  local py = base_y + LAYOUT.PARAMS.Y

  local transform = TRANSFORMS[state.transform_idx]

  if transform.id == 'negative' then
    draw_negative_params(ctx, px, py)
  elseif transform.id == 'interval' then
    draw_interval_params(ctx, px, py)
  elseif transform.id == 'markov' then
    draw_markov_params(ctx, px, py)
  elseif transform.id == 'serial' then
    draw_serial_params(ctx, px, py)
  elseif transform.id == 'cellular' then
    draw_cellular_params(ctx, px, py)
  elseif transform.id == 'contour' then
    draw_contour_params(ctx, px, py)
  elseif transform.id == 'fibonacci' then
    draw_fibonacci_params(ctx, px, py)
  elseif transform.id == 'brownian' then
    draw_brownian_params(ctx, px, py)
  elseif transform.id == 'overtone' then
    draw_overtone_params(ctx, px, py)
  elseif transform.id == 'permute' then
    draw_permute_params(ctx, px, py)
  end
end

-- ============================================================================
-- APPLY TRANSFORM
-- ============================================================================

apply_transform = function(transform_id)
  local scale = Scales.get_scale_by_index(state.scale_idx)
  local root = state.scale_root - 1  -- 0-11

  local transform_fn
  local undo_name

  if transform_id == 'negative' then
    undo_name = 'Negative Harmony'
    local neg_root = state.neg_root - 1
    local axis_type = state.neg_axis_type == 1 and 'tonic_dominant' or 'chromatic'
    transform_fn = function(notes)
      return Generative.negative_harmony(notes, neg_root, axis_type)
    end

  elseif transform_id == 'interval' then
    undo_name = 'Interval Multiply'
    local anchors = { 'first', 'center', 'last' }
    transform_fn = function(notes)
      return Generative.interval_multiply(notes, state.interval_factor, anchors[state.interval_anchor])
    end

  elseif transform_id == 'markov' then
    undo_name = 'Markov Transform'
    transform_fn = function(notes)
      return Generative.markov_transform(notes, state.markov_chaos / 100)
    end

  elseif transform_id == 'serial' then
    undo_name = '12-Tone Transform'
    local forms = { 'P', 'I', 'R', 'RI' }
    transform_fn = function(notes)
      return Generative.apply_tone_row(notes, nil, forms[state.serial_form], state.serial_transposition)
    end

  elseif transform_id == 'cellular' then
    undo_name = 'Cellular Automata'
    local rule = CA_RULES[state.ca_rule_idx].value
    transform_fn = function(notes)
      return Generative.cellular_automata(notes, rule, state.ca_generations, scale, root)
    end

  elseif transform_id == 'contour' then
    undo_name = 'Contour Map'
    transform_fn = function(notes)
      return Generative.contour_map(notes, notes, nil, scale, root)
    end

  elseif transform_id == 'fibonacci' then
    undo_name = 'Fibonacci Transform'
    local modes = { 'pitch', 'rhythm', 'both' }
    transform_fn = function(notes)
      return Generative.fibonacci_transform(notes, modes[state.fib_mode], scale, root)
    end

  elseif transform_id == 'brownian' then
    undo_name = 'Brownian Motion'
    transform_fn = function(notes)
      return Generative.brownian_motion(notes, state.brownian_step, state.brownian_gravity / 100, state.brownian_center)
    end

  elseif transform_id == 'overtone' then
    if state.overtone_quantize then
      undo_name = 'Overtone Quantize'
      transform_fn = function(notes)
        return Generative.overtone_quantize(notes, state.overtone_fundamental, state.overtone_max_partial)
      end
    else
      undo_name = 'Overtone Map'
      transform_fn = function(notes)
        return Generative.overtone_map(notes, state.overtone_fundamental, state.overtone_max_partial)
      end
    end

  elseif transform_id == 'permute' then
    undo_name = 'Permute Pitches'
    transform_fn = function(notes)
      return Generative.permute_pitches(notes, 'random')
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
  local tab_color = opts.tab_color or 0x9370DBFF  -- Medium purple

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
    neg_root = state.neg_root,
    neg_axis_type = state.neg_axis_type,
    interval_factor = state.interval_factor,
    interval_anchor = state.interval_anchor,
    markov_chaos = state.markov_chaos,
    markov_order = state.markov_order,
    serial_form = state.serial_form,
    serial_transposition = state.serial_transposition,
    ca_rule_idx = state.ca_rule_idx,
    ca_generations = state.ca_generations,
    fib_mode = state.fib_mode,
    brownian_step = state.brownian_step,
    brownian_gravity = state.brownian_gravity,
    brownian_center = state.brownian_center,
    overtone_fundamental = state.overtone_fundamental,
    overtone_max_partial = state.overtone_max_partial,
    overtone_quantize = state.overtone_quantize,
    scale_idx = state.scale_idx,
    scale_root = state.scale_root,
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
