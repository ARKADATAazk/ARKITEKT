-- @noindex
-- MIDIHelix/ui/views/sequencer_view.lua
-- Probability-based sequence generator (Ex Machina style)

local M = {}

-- Dependencies
local Scales = require('scripts.MIDIHelix.domain.scales')
local Sequencer = require('scripts.MIDIHelix.domain.sequencer')
local Randomizer = require('scripts.MIDIHelix.domain.randomizer')
local MidiWriter = require('scripts.MIDIHelix.app.midi_writer')
local Defaults = require('scripts.MIDIHelix.config.defaults')
local VerticalSlider = require('scripts.MIDIHelix.ui.widgets.vertical_slider')

-- Will be set on init
local Ark = nil
local ImGui = nil

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local NOTES = Scales.NOTES
local OCTAVES = { 0, 1, 2, 3, 4, 5, 6, 7 }
local GRID_OPTIONS = { '1/16', '1/8', '1/4' }
local GRID_VALUES = { 0.25, 0.5, 1.0 }

-- Layout constants
local LAYOUT = {
  LEFT_PANEL = { X = 25 },
  LENGTH_SLIDERS = { X = 160, Y = 30, W = 30, H = 130, SPACING = 50 },
  VEL_SLIDERS = { X = 380, Y = 30, W = 30, H = 130, SPACING = 50 },
  OPTIONS = { X = 520, Y = 30, SPACING = 26 },
  SHIFT_BTNS = { X = 700, Y = 160 },
  BTN_PRIMARY = { X = 25, Y = 175, W = 110, H = 25 },
}

-- ============================================================================
-- STATE
-- ============================================================================

local state = {
  initialized = false,

  -- Note selection
  key = Defaults.SEQUENCER.KEY,
  octave = Defaults.SEQUENCER.OCTAVE,
  scale_idx = Defaults.SEQUENCER.SCALE,
  grid_idx = Defaults.SEQUENCER.GRID,

  -- Note length weights (1/16, 1/8, 1/4, Rest)
  length_weights = { table.unpack(Defaults.SEQUENCER.LENGTH_WEIGHTS) },

  -- Velocity
  normal_vel = Defaults.SEQUENCER.NORMAL_VEL,
  accent_vel = Defaults.SEQUENCER.ACCENT_VEL,
  accent_prob = Defaults.SEQUENCER.ACCENT_PROB,
  legato_prob = Defaults.SEQUENCER.LEGATO_PROB,

  -- Options
  generate_on_change = Defaults.SEQUENCER.GENERATE_ON_CHANGE,
  first_note_always = Defaults.SEQUENCER.FIRST_NOTE_ALWAYS,
  accent_enabled = Defaults.SEQUENCER.ACCENT_ENABLED,
  legato_enabled = Defaults.SEQUENCER.LEGATO_ENABLED,
  randomize_notes = Defaults.SEQUENCER.RANDOMIZE_NOTES,

  -- Note weights (for randomize)
  note_weights = {},

  -- Shift amount
  shift = 0,

  -- Status
  message = '',
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function init_note_weights()
  local scale = Scales.get_scale_by_index(state.scale_idx)
  if scale then
    state.note_weights = Randomizer.weights_from_scale(scale, 5)
  else
    for i = 1, 12 do
      state.note_weights[i] = 5
    end
  end
end

-- ============================================================================
-- LEFT PANEL (Key, Octave, Scale, Grid, Generate)
-- ============================================================================

local function draw_left_panel(ctx, base_x, base_y, tab_color)
  local Colors = Ark.Colors
  local lx = base_x + LAYOUT.LEFT_PANEL.X

  -- Key dropdown
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 10)
  ImGui.Text(ctx, 'Key')
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 28)
  ImGui.SetNextItemWidth(ctx, 50)

  if ImGui.BeginCombo(ctx, '##key', NOTES[state.key]) then
    for i, note in ipairs(NOTES) do
      if ImGui.Selectable(ctx, note, i == state.key) then
        state.key = i
        init_note_weights()
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Octave dropdown
  ImGui.SetCursorScreenPos(ctx, lx + 60, base_y + 10)
  ImGui.Text(ctx, 'Oct')
  ImGui.SetCursorScreenPos(ctx, lx + 60, base_y + 28)
  ImGui.SetNextItemWidth(ctx, 40)

  if ImGui.BeginCombo(ctx, '##oct', tostring(state.octave)) then
    for _, oct in ipairs(OCTAVES) do
      if ImGui.Selectable(ctx, tostring(oct), oct == state.octave) then
        state.octave = oct
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Grid radio buttons
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 60)
  ImGui.Text(ctx, 'Grid')

  for i, label in ipairs(GRID_OPTIONS) do
    ImGui.SetCursorScreenPos(ctx, lx, base_y + 75 + (i - 1) * 20)
    if ImGui.RadioButton(ctx, label, state.grid_idx == i) then
      state.grid_idx = i
    end
  end

  -- Generate button
  local btn_x = base_x + LAYOUT.BTN_PRIMARY.X
  local btn_y = base_y + LAYOUT.BTN_PRIMARY.Y
  local btn_w = LAYOUT.BTN_PRIMARY.W
  local btn_h = LAYOUT.BTN_PRIMARY.H

  ImGui.SetCursorScreenPos(ctx, btn_x, btn_y)
  ImGui.PushStyleColor(ctx, ImGui.Col_Button, tab_color)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, Colors.AdjustBrightness(tab_color, 1.15))
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, Colors.AdjustBrightness(tab_color, 0.85))
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x202020FF)

  if ImGui.Button(ctx, 'Generate', btn_w, btn_h) then
    local item_len = Sequencer.get_item_length_ppq()
    if not item_len then
      state.message = 'No active MIDI item'
    else
      local root = (state.octave + 1) * 12 + (state.key - 1)

      local notes = Sequencer.generate_sequence({
        item_length_ppq = item_len,
        grid_qn = GRID_VALUES[state.grid_idx],
        root = root,
        length_weights = state.length_weights,
        accent_enabled = state.accent_enabled,
        normal_vel = state.normal_vel,
        accent_vel = state.accent_vel,
        accent_prob = state.accent_prob,
        legato_enabled = state.legato_enabled,
        legato_prob = state.legato_prob,
        legato_offset = Defaults.SEQUENCER.LEGATO_OFFSET,
        first_note_always = state.first_note_always,
        randomize_notes = state.randomize_notes,
        note_weights = state.note_weights,
        scale_root = root,
      })

      local success, msg = MidiWriter.write_notes(notes, true)
      state.message = msg
    end
  end

  ImGui.PopStyleColor(ctx, 4)
end

-- ============================================================================
-- NOTE LENGTH SLIDERS (1/16, 1/8, 1/4, Rest)
-- ============================================================================

local function draw_length_sliders(ctx, base_x, base_y, tab_color)
  local slider_x = base_x + LAYOUT.LENGTH_SLIDERS.X
  local slider_y = base_y + LAYOUT.LENGTH_SLIDERS.Y

  local labels = { '1/16', '1/8', '1/4', 'Rest' }

  for i = 1, 4 do
    local x = slider_x + (i - 1) * LAYOUT.LENGTH_SLIDERS.SPACING

    local result = VerticalSlider.Draw(ctx, {
      id = 'len_' .. i,
      x = x,
      y = slider_y,
      width = LAYOUT.LENGTH_SLIDERS.W,
      height = LAYOUT.LENGTH_SLIDERS.H,
      value = state.length_weights[i] or 0,
      min = 0,
      max = 10,
      default = Defaults.SEQUENCER.LENGTH_WEIGHTS[i],
      label = labels[i],
      fill_color = tab_color,
      advance = 'none',
    })

    if result.changed then
      state.length_weights[i] = result.value
    end
  end
end

-- ============================================================================
-- VELOCITY/LEGATO SLIDERS
-- ============================================================================

local function draw_velocity_sliders(ctx, base_x, base_y, tab_color)
  local slider_x = base_x + LAYOUT.VEL_SLIDERS.X
  local slider_y = base_y + LAYOUT.VEL_SLIDERS.Y

  -- Velocity slider (normal)
  local vel_result = VerticalSlider.Draw(ctx, {
    id = 'vel_norm',
    x = slider_x,
    y = slider_y,
    width = LAYOUT.VEL_SLIDERS.W,
    height = LAYOUT.VEL_SLIDERS.H,
    value = state.normal_vel,
    min = 1,
    max = 127,
    default = Defaults.SEQUENCER.NORMAL_VEL,
    label = 'Vel',
    fill_color = tab_color,
    advance = 'none',
  })
  if vel_result.changed then
    state.normal_vel = vel_result.value
  end

  -- Legato probability slider
  local leg_result = VerticalSlider.Draw(ctx, {
    id = 'leg_prob',
    x = slider_x + LAYOUT.VEL_SLIDERS.SPACING,
    y = slider_y,
    width = LAYOUT.VEL_SLIDERS.W,
    height = LAYOUT.VEL_SLIDERS.H,
    value = state.legato_prob,
    min = 0,
    max = 10,
    default = Defaults.SEQUENCER.LEGATO_PROB,
    label = 'Leg',
    fill_color = state.legato_enabled and tab_color or 0x606060FF,
    advance = 'none',
  })
  if leg_result.changed then
    state.legato_prob = leg_result.value
  end
end

-- ============================================================================
-- OPTIONS PANEL
-- ============================================================================

local function draw_options_panel(ctx, base_x, base_y)
  local opt_x = base_x + LAYOUT.OPTIONS.X
  local opt_y = base_y + LAYOUT.OPTIONS.Y

  -- Generate on change
  ImGui.SetCursorScreenPos(ctx, opt_x, opt_y)
  local _, gen = ImGui.Checkbox(ctx, 'Generate', state.generate_on_change)
  state.generate_on_change = gen

  -- First note always
  ImGui.SetCursorScreenPos(ctx, opt_x, opt_y + LAYOUT.OPTIONS.SPACING)
  local _, first = ImGui.Checkbox(ctx, '1st Note', state.first_note_always)
  state.first_note_always = first

  -- Accent enabled
  ImGui.SetCursorScreenPos(ctx, opt_x, opt_y + LAYOUT.OPTIONS.SPACING * 2)
  local _, acc = ImGui.Checkbox(ctx, 'Accent', state.accent_enabled)
  state.accent_enabled = acc

  -- Legato enabled
  ImGui.SetCursorScreenPos(ctx, opt_x, opt_y + LAYOUT.OPTIONS.SPACING * 3)
  local _, leg = ImGui.Checkbox(ctx, 'Legato', state.legato_enabled)
  state.legato_enabled = leg

  -- Randomize notes
  ImGui.SetCursorScreenPos(ctx, opt_x, opt_y + LAYOUT.OPTIONS.SPACING * 4)
  local _, rnd = ImGui.Checkbox(ctx, 'Rnd Notes', state.randomize_notes)
  state.randomize_notes = rnd
end

-- ============================================================================
-- SHIFT CONTROLS
-- ============================================================================

local function draw_shift_controls(ctx, base_x, base_y, tab_color)
  local sx = base_x + LAYOUT.SHIFT_BTNS.X
  local sy = base_y + LAYOUT.SHIFT_BTNS.Y

  ImGui.SetCursorScreenPos(ctx, sx, sy)
  if ImGui.Button(ctx, '<<', 30, 22) then
    state.shift = state.shift - 1
  end

  ImGui.SetCursorScreenPos(ctx, sx + 35, sy)
  ImGui.SetNextItemWidth(ctx, 40)
  local _, new_shift = ImGui.InputInt(ctx, '##shift', state.shift, 0, 0)
  state.shift = new_shift

  ImGui.SetCursorScreenPos(ctx, sx + 80, sy)
  if ImGui.Button(ctx, '>>', 30, 22) then
    state.shift = state.shift + 1
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Initialize the Sequencer view
--- @param ark_instance table Ark instance
function M.init(ark_instance)
  if state.initialized then return end
  Ark = ark_instance
  ImGui = Ark.ImGui

  init_note_weights()

  state.initialized = true
end

--- Draw the Sequencer view
--- @param ctx userdata ImGui context
--- @param opts table { x, y, w, h, tab_color }
function M.Draw(ctx, opts)
  if not state.initialized then return end

  opts = opts or {}
  local base_x = opts.x or 0
  local base_y = opts.y or 0
  local win_w = opts.w or 900
  local win_h = opts.h or 200
  local tab_color = opts.tab_color or 0xFFD700FF

  -- Draw components
  draw_left_panel(ctx, base_x, base_y, tab_color)
  draw_length_sliders(ctx, base_x, base_y, tab_color)
  draw_velocity_sliders(ctx, base_x, base_y, tab_color)
  draw_options_panel(ctx, base_x, base_y)
  draw_shift_controls(ctx, base_x, base_y, tab_color)

  -- Status message
  if state.message ~= '' then
    ImGui.SetCursorScreenPos(ctx, base_x + 160, base_y + win_h - 30)
    ImGui.TextColored(ctx, 0x80FF80FF, state.message)
  end
end

--- Get current state (for persistence)
function M.get_state()
  return {
    key = state.key,
    octave = state.octave,
    scale_idx = state.scale_idx,
    grid_idx = state.grid_idx,
    length_weights = state.length_weights,
    normal_vel = state.normal_vel,
    accent_vel = state.accent_vel,
    accent_prob = state.accent_prob,
    legato_prob = state.legato_prob,
    generate_on_change = state.generate_on_change,
    first_note_always = state.first_note_always,
    accent_enabled = state.accent_enabled,
    legato_enabled = state.legato_enabled,
    randomize_notes = state.randomize_notes,
    shift = state.shift,
  }
end

--- Set state (for persistence)
function M.set_state(new_state)
  if not new_state then return end
  for k, v in pairs(new_state) do
    if state[k] ~= nil then
      state[k] = v
    end
  end
end

return M
