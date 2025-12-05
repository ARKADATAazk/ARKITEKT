-- @noindex
-- MIDIHelix/ui/views/randomizer_view.lua
-- Scale-weighted note randomizer (Ex Machina style)

local M = {}

-- Dependencies
local Scales = require('scripts.MIDIHelix.domain.scales')
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

-- Layout constants (relative to content area)
local LAYOUT = {
  LEFT_PANEL = { X = 25 },
  SLIDERS = { X = 160, Y = 30, W = 24, H = 130, SPACING = 32 },
  OPTIONS = { X = 580, Y = 30, SPACING = 28 },
  OCT_SLIDER = { X = 720, Y = 30, W = 30, H = 130 },
  BTN_PRIMARY = { X = 25, Y = 175, W = 110, H = 25 },
  BTN_SECONDARY = { X = 25, Y = 140, W = 110, H = 25 },
}

-- ============================================================================
-- STATE
-- ============================================================================

local state = {
  initialized = false,

  -- Note selection
  key = Defaults.RANDOMIZER.KEY,           -- 1-12 (C through B)
  octave = Defaults.RANDOMIZER.OCTAVE,     -- 0-7
  scale_idx = Defaults.RANDOMIZER.SCALE,   -- Index into Scales.SCALES

  -- Note weights (0-10 for each chromatic note C through B)
  weights = {},

  -- Options
  all_notes = Defaults.RANDOMIZER.ALL_NOTES,
  first_is_root = Defaults.RANDOMIZER.FIRST_IS_ROOT,
  octave_double = Defaults.RANDOMIZER.OCTAVE_DOUBLE,
  octave_prob = Defaults.RANDOMIZER.OCTAVE_PROB,

  -- Status
  message = '',
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function init_weights_from_scale()
  local scale = Scales.get_scale_by_index(state.scale_idx)
  if scale then
    state.weights = Randomizer.weights_from_scale(scale, Defaults.RANDOMIZER.DEFAULT_WEIGHT)
  else
    -- Default to all equal weights
    for i = 1, 12 do
      state.weights[i] = Defaults.RANDOMIZER.DEFAULT_WEIGHT
    end
  end
end

-- ============================================================================
-- LEFT PANEL (Key, Octave, Scale, Buttons)
-- ============================================================================

local function draw_left_panel(ctx, base_x, base_y, tab_color)
  local Colors = Ark.Colors
  local lx = base_x + LAYOUT.LEFT_PANEL.X

  -- Key dropdown
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 10)
  ImGui.Text(ctx, 'Key')
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 30)
  ImGui.SetNextItemWidth(ctx, 50)

  if ImGui.BeginCombo(ctx, '##key', NOTES[state.key]) then
    for i, note in ipairs(NOTES) do
      if ImGui.Selectable(ctx, note, i == state.key) then
        state.key = i
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Octave dropdown
  ImGui.SetCursorScreenPos(ctx, lx + 60, base_y + 10)
  ImGui.Text(ctx, 'Oct')
  ImGui.SetCursorScreenPos(ctx, lx + 60, base_y + 30)
  ImGui.SetNextItemWidth(ctx, 40)

  if ImGui.BeginCombo(ctx, '##oct', tostring(state.octave)) then
    for _, oct in ipairs(OCTAVES) do
      if ImGui.Selectable(ctx, tostring(oct), oct == state.octave) then
        state.octave = oct
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Scale dropdown
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 65)
  ImGui.Text(ctx, 'Scale')
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 85)
  ImGui.SetNextItemWidth(ctx, 110)

  local scale_names = Scales.get_scale_names()
  local current_scale = scale_names[state.scale_idx] or 'Chromatic'

  if ImGui.BeginCombo(ctx, '##scale', current_scale) then
    for i, name in ipairs(scale_names) do
      if ImGui.Selectable(ctx, name, i == state.scale_idx) then
        state.scale_idx = i
        init_weights_from_scale()
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Shuffle button
  local btn2_x = base_x + LAYOUT.BTN_SECONDARY.X
  local btn2_y = base_y + LAYOUT.BTN_SECONDARY.Y
  local btn2_w = LAYOUT.BTN_SECONDARY.W
  local btn2_h = LAYOUT.BTN_SECONDARY.H

  ImGui.SetCursorScreenPos(ctx, btn2_x, btn2_y)
  ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x505050FF)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0x606060FF)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0x404040FF)

  if ImGui.Button(ctx, 'Shuffle', btn2_w, btn2_h) then
    local success, msg = MidiWriter.randomize_notes(function(notes)
      return Randomizer.shuffle_notes(notes, not state.all_notes)
    end, not state.all_notes)
    state.message = msg
  end

  ImGui.PopStyleColor(ctx, 3)

  -- Randomize button
  local btn_x = base_x + LAYOUT.BTN_PRIMARY.X
  local btn_y = base_y + LAYOUT.BTN_PRIMARY.Y
  local btn_w = LAYOUT.BTN_PRIMARY.W
  local btn_h = LAYOUT.BTN_PRIMARY.H

  ImGui.SetCursorScreenPos(ctx, btn_x, btn_y)
  ImGui.PushStyleColor(ctx, ImGui.Col_Button, tab_color)
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, Colors.AdjustBrightness(tab_color, 1.15))
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, Colors.AdjustBrightness(tab_color, 0.85))
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x202020FF)

  if ImGui.Button(ctx, 'Randomize', btn_w, btn_h) then
    local root = (state.octave + 1) * 12 + (state.key - 1)

    local success, msg = MidiWriter.randomize_notes(function(notes)
      return Randomizer.randomize_notes(notes, state.weights, root, {
        first_is_root = state.first_is_root,
        octave_double = state.octave_double,
        octave_prob = state.octave_prob,
        selected_only = not state.all_notes,
      })
    end, not state.all_notes)
    state.message = msg
  end

  ImGui.PopStyleColor(ctx, 4)
end

-- ============================================================================
-- NOTE WEIGHT SLIDERS (12 sliders for C through B)
-- ============================================================================

local function draw_note_sliders(ctx, base_x, base_y, tab_color)
  local slider_x = base_x + LAYOUT.SLIDERS.X
  local slider_y = base_y + LAYOUT.SLIDERS.Y

  -- Get current scale mask to highlight in-scale notes
  local scale = Scales.get_scale_by_index(state.scale_idx)
  local scale_mask = scale and Scales.get_scale_mask(scale) or {}

  for i = 1, 12 do
    local x = slider_x + (i - 1) * LAYOUT.SLIDERS.SPACING

    -- Determine slider color based on scale membership
    local in_scale = scale_mask[i]
    local slider_color = in_scale and tab_color or 0x606060FF

    -- Get note label relative to current key
    local note_idx = ((i - 1 + state.key - 1) % 12) + 1
    local label = NOTES[note_idx]
    if #label > 2 then label = label:sub(1, 2) end

    local result = VerticalSlider.Draw(ctx, {
      id = 'note_' .. i,
      x = x,
      y = slider_y,
      width = LAYOUT.SLIDERS.W,
      height = LAYOUT.SLIDERS.H,
      value = state.weights[i] or 0,
      min = 0,
      max = 10,
      default = in_scale and Defaults.RANDOMIZER.DEFAULT_WEIGHT or 0,
      label = label,
      fill_color = slider_color,
      advance = 'none',
    })

    if result.changed then
      state.weights[i] = result.value
    end
  end
end

-- ============================================================================
-- OPTIONS PANEL (Checkboxes)
-- ============================================================================

local function draw_options_panel(ctx, base_x, base_y, tab_color)
  local opt_x = base_x + LAYOUT.OPTIONS.X
  local opt_y = base_y + LAYOUT.OPTIONS.Y

  -- All/Selected toggle
  ImGui.SetCursorScreenPos(ctx, opt_x, opt_y)
  local _, all = ImGui.Checkbox(ctx, 'All Notes', state.all_notes)
  state.all_notes = all

  -- First note = root
  ImGui.SetCursorScreenPos(ctx, opt_x, opt_y + LAYOUT.OPTIONS.SPACING)
  local _, first = ImGui.Checkbox(ctx, '1st=Root', state.first_is_root)
  state.first_is_root = first

  -- Octave doubler
  ImGui.SetCursorScreenPos(ctx, opt_x, opt_y + LAYOUT.OPTIONS.SPACING * 2)
  local _, oct2 = ImGui.Checkbox(ctx, 'Oct x2', state.octave_double)
  state.octave_double = oct2

  -- Octave probability slider (only if octave double enabled)
  if state.octave_double then
    local oct_x = base_x + LAYOUT.OCT_SLIDER.X
    local oct_y = base_y + LAYOUT.OCT_SLIDER.Y

    local result = VerticalSlider.Draw(ctx, {
      id = 'oct_prob',
      x = oct_x,
      y = oct_y,
      width = LAYOUT.OCT_SLIDER.W,
      height = LAYOUT.OCT_SLIDER.H,
      value = state.octave_prob,
      min = 0,
      max = 10,
      default = Defaults.RANDOMIZER.OCTAVE_PROB,
      label = 'Oct',
      fill_color = tab_color,
      advance = 'none',
    })

    if result.changed then
      state.octave_prob = result.value
    end
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Initialize the Randomizer view
--- @param ark_instance table Ark instance
function M.init(ark_instance)
  if state.initialized then return end
  Ark = ark_instance
  ImGui = Ark.ImGui

  -- Initialize weights from default scale
  init_weights_from_scale()

  state.initialized = true
end

--- Draw the Randomizer view
--- @param ctx userdata ImGui context
--- @param opts table { x, y, w, h, tab_color }
function M.Draw(ctx, opts)
  if not state.initialized then return end

  opts = opts or {}
  local base_x = opts.x or 0
  local base_y = opts.y or 0
  local win_w = opts.w or 900
  local win_h = opts.h or 200
  local tab_color = opts.tab_color or 0x50C878FF

  -- Draw components
  draw_left_panel(ctx, base_x, base_y, tab_color)
  draw_note_sliders(ctx, base_x, base_y, tab_color)
  draw_options_panel(ctx, base_x, base_y, tab_color)

  -- Status message
  if state.message ~= '' then
    ImGui.SetCursorScreenPos(ctx, base_x + 160, base_y + win_h - 30)
    ImGui.TextColored(ctx, 0x80FF80FF, state.message)
  end
end

--- Get current state (for persistence)
--- @return table Current view state
function M.get_state()
  return {
    key = state.key,
    octave = state.octave,
    scale_idx = state.scale_idx,
    weights = state.weights,
    all_notes = state.all_notes,
    first_is_root = state.first_is_root,
    octave_double = state.octave_double,
    octave_prob = state.octave_prob,
  }
end

--- Set state (for persistence)
--- @param new_state table State to restore
function M.set_state(new_state)
  if not new_state then return end
  for k, v in pairs(new_state) do
    if state[k] ~= nil then
      state[k] = v
    end
  end
end

return M
