-- @noindex
-- MIDIHelix/ui/views/euclidean_view.lua
-- Euclidean generator UI view (Ex Machina style)

local M = {}

-- Dependencies
local Euclidean = require('scripts.MIDIHelix.domain.euclidean')
local MidiWriter = require('scripts.MIDIHelix.app.midi_writer')
local Defaults = require('scripts.MIDIHelix.config.defaults')
local VerticalSlider = require('scripts.MIDIHelix.ui.widgets.vertical_slider')

-- Will be set on init
local Ark = nil
local ImGui = nil

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local NOTES = { 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B' }
local OCTAVES = { 0, 1, 2, 3, 4, 5, 6, 7 }
local GRID_OPTIONS = { '1/4', '1/8', '1/16', '1/32' }
local GRID_VALUES = { 1.0, 0.5, 0.25, 0.125 }

-- Layout constants (relative to content area)
local LAYOUT = {
  SLIDERS = { X = 160, Y = 30, W = 30, H = 150, SPACING = 40 },
  LEFT_PANEL = { X = 25 },
  RIGHT_PANEL = { X = 550, Y = 30 },
  OPTIONS = { X = 700, Y = 60, SPACING = 30 },
  PATTERN_VIS = { X = 420, Y = 50, SIZE = 120 },
  BTN_PRIMARY = { X = 25, Y = 175, W = 110, H = 25 },
}

-- ============================================================================
-- STATE
-- ============================================================================

local state = {
  initialized = false,

  -- Pattern params
  pulses = Defaults.EUCLIDEAN.PULSES,
  steps = Defaults.EUCLIDEAN.STEPS,
  rotation = Defaults.EUCLIDEAN.ROTATION,

  -- MIDI output
  note = Defaults.EUCLIDEAN.NOTE,
  velocity = Defaults.EUCLIDEAN.VELOCITY,
  grid_division = Defaults.EUCLIDEAN.GRID_DIVISION,
  note_length = Defaults.EUCLIDEAN.NOTE_LENGTH,

  -- Options
  generate_on_change = true,
  accent_enabled = false,
  randomize_notes = false,

  -- Computed
  pattern = {},
  message = '',
}

-- ============================================================================
-- PATTERN VISUALIZATION (Ring)
-- ============================================================================

local function draw_pattern_ring(ctx, dl, cx, cy, radius, pattern, steps, tab_color)
  local Colors = Ark.Colors
  local pi2 = math.pi * 2
  local step_angle = pi2 / steps

  -- Draw step markers
  for i = 1, steps do
    local angle = (i - 1) * step_angle - math.pi / 2  -- Start from top
    local x = cx + math.cos(angle) * radius
    local y = cy + math.sin(angle) * radius

    local is_hit = pattern[i] == 1

    if is_hit then
      ImGui.DrawList_AddCircleFilled(dl, x, y, 6, tab_color, 12)
      ImGui.DrawList_AddCircle(dl, x, y, 6, Colors.AdjustBrightness(tab_color, 0.7), 12, 1)
    else
      ImGui.DrawList_AddCircle(dl, x, y, 4, 0x606060FF, 12, 1)
    end
  end

  -- Draw connecting lines between hits
  local prev_hit_angle = nil
  local first_hit_angle = nil

  for i = 1, steps do
    if pattern[i] == 1 then
      local angle = (i - 1) * step_angle - math.pi / 2

      if first_hit_angle == nil then
        first_hit_angle = angle
      end

      if prev_hit_angle then
        local x1 = cx + math.cos(prev_hit_angle) * (radius - 10)
        local y1 = cy + math.sin(prev_hit_angle) * (radius - 10)
        local x2 = cx + math.cos(angle) * (radius - 10)
        local y2 = cy + math.sin(angle) * (radius - 10)
        ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, 0x40404080, 1)
      end

      prev_hit_angle = angle
    end
  end

  -- Connect last to first
  if prev_hit_angle and first_hit_angle and prev_hit_angle ~= first_hit_angle then
    local x1 = cx + math.cos(prev_hit_angle) * (radius - 10)
    local y1 = cy + math.sin(prev_hit_angle) * (radius - 10)
    local x2 = cx + math.cos(first_hit_angle) * (radius - 10)
    local y2 = cy + math.sin(first_hit_angle) * (radius - 10)
    ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, 0x40404080, 1)
  end

  -- Center descriptor text
  local desc = string.format('E(%d,%d,%d)', state.pulses, state.steps, state.rotation)
  local text_w = ImGui.CalcTextSize(ctx, desc)
  ImGui.DrawList_AddText(dl, cx - text_w / 2, cy + radius + 10, 0xA0A0A0FF, desc)
end

-- ============================================================================
-- LEFT PANEL (Key, Octave, Generate button)
-- ============================================================================

local function draw_left_panel(ctx, base_x, base_y, tab_color)
  local Colors = Ark.Colors
  local lx = base_x + LAYOUT.LEFT_PANEL.X

  -- Key dropdown
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 10)
  ImGui.Text(ctx, 'Key')
  ImGui.SetCursorScreenPos(ctx, lx, base_y + 30)
  ImGui.SetNextItemWidth(ctx, 50)

  local key_idx = (state.note % 12) + 1
  if ImGui.BeginCombo(ctx, '##key', NOTES[key_idx]) then
    for i, note in ipairs(NOTES) do
      if ImGui.Selectable(ctx, note, i == key_idx) then
        local octave = math.floor(state.note / 12)
        state.note = (i - 1) + octave * 12
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Octave dropdown
  ImGui.SetCursorScreenPos(ctx, lx + 60, base_y + 10)
  ImGui.Text(ctx, 'Oct')
  ImGui.SetCursorScreenPos(ctx, lx + 60, base_y + 30)
  ImGui.SetNextItemWidth(ctx, 50)

  local oct_idx = math.floor(state.note / 12) + 1
  if ImGui.BeginCombo(ctx, '##oct', tostring(OCTAVES[oct_idx])) then
    for i, oct in ipairs(OCTAVES) do
      if ImGui.Selectable(ctx, tostring(oct), i == oct_idx) then
        local key = state.note % 12
        state.note = key + oct * 12
      end
    end
    ImGui.EndCombo(ctx)
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
    local success, msg = MidiWriter.write_pattern(state.pattern, {
      note = state.note,
      velocity = state.velocity,
      grid_division = state.grid_division,
      note_length = state.note_length,
    })
    state.message = msg
  end

  ImGui.PopStyleColor(ctx, 4)
end

-- ============================================================================
-- RIGHT PANEL (Grid, Length, Velocity)
-- ============================================================================

local function draw_right_panel(ctx, base_x, base_y)
  local panel_x = base_x + LAYOUT.RIGHT_PANEL.X
  local panel_y = base_y + LAYOUT.RIGHT_PANEL.Y

  -- Grid dropdown
  ImGui.SetCursorScreenPos(ctx, panel_x, panel_y)
  ImGui.Text(ctx, 'Grid')
  ImGui.SetCursorScreenPos(ctx, panel_x + 50, panel_y)
  ImGui.SetNextItemWidth(ctx, 80)

  local grid_idx = 3  -- Default 1/16
  for i, v in ipairs(GRID_VALUES) do
    if math.abs(state.grid_division - v) < 0.01 then
      grid_idx = i
      break
    end
  end

  if ImGui.BeginCombo(ctx, '##grid', GRID_OPTIONS[grid_idx]) then
    for i, opt in ipairs(GRID_OPTIONS) do
      if ImGui.Selectable(ctx, opt, i == grid_idx) then
        state.grid_division = GRID_VALUES[i]
        state.note_length = GRID_VALUES[i]
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Length dropdown
  ImGui.SetCursorScreenPos(ctx, panel_x, panel_y + 30)
  ImGui.Text(ctx, 'Length')
  ImGui.SetCursorScreenPos(ctx, panel_x + 50, panel_y + 30)
  ImGui.SetNextItemWidth(ctx, 80)

  local len_idx = 3
  for i, v in ipairs(GRID_VALUES) do
    if math.abs(state.note_length - v) < 0.01 then
      len_idx = i
      break
    end
  end

  if ImGui.BeginCombo(ctx, '##length', GRID_OPTIONS[len_idx]) then
    for i, opt in ipairs(GRID_OPTIONS) do
      if ImGui.Selectable(ctx, opt, i == len_idx) then
        state.note_length = GRID_VALUES[i]
      end
    end
    ImGui.EndCombo(ctx)
  end

  -- Velocity slider
  ImGui.SetCursorScreenPos(ctx, panel_x, panel_y + 65)
  ImGui.Text(ctx, 'Vel')
  ImGui.SetCursorScreenPos(ctx, panel_x + 50, panel_y + 65)
  ImGui.SetNextItemWidth(ctx, 100)
  local changed, new_vel = ImGui.SliderInt(ctx, '##vel', state.velocity, 1, 127)
  if changed then
    state.velocity = new_vel
  end
end

-- ============================================================================
-- OPTIONS PANEL (Checkboxes)
-- ============================================================================

local function draw_options_panel(ctx, base_x, base_y)
  local opt_x = base_x + LAYOUT.OPTIONS.X
  local opt_y = base_y + LAYOUT.OPTIONS.Y

  ImGui.SetCursorScreenPos(ctx, opt_x, opt_y)
  local _, gen = ImGui.Checkbox(ctx, 'Generate', state.generate_on_change)
  state.generate_on_change = gen

  ImGui.SetCursorScreenPos(ctx, opt_x, opt_y + LAYOUT.OPTIONS.SPACING)
  local _, acc = ImGui.Checkbox(ctx, 'Accent', state.accent_enabled)
  state.accent_enabled = acc

  ImGui.SetCursorScreenPos(ctx, opt_x, opt_y + LAYOUT.OPTIONS.SPACING * 2)
  local _, rnd = ImGui.Checkbox(ctx, 'Rnd Notes', state.randomize_notes)
  state.randomize_notes = rnd
end

-- ============================================================================
-- SLIDERS
-- ============================================================================

local function draw_sliders(ctx, base_x, base_y, tab_color)
  local slider_x = base_x + LAYOUT.SLIDERS.X
  local slider_y = base_y + LAYOUT.SLIDERS.Y
  local pattern_changed = false

  -- Pulses slider
  local pulses_result = VerticalSlider.Draw(ctx, {
    id = 'pulses',
    x = slider_x,
    y = slider_y,
    width = LAYOUT.SLIDERS.W,
    height = LAYOUT.SLIDERS.H,
    value = state.pulses,
    min = 0,
    max = 32,
    default = Defaults.EUCLIDEAN.PULSES,
    label = 'Puls',
    fill_color = tab_color,
    advance = 'none',
  })
  if pulses_result.changed then
    state.pulses = pulses_result.value
    if state.pulses > state.steps then
      state.pulses = state.steps
    end
    pattern_changed = true
  end

  -- Steps slider
  local steps_result = VerticalSlider.Draw(ctx, {
    id = 'steps',
    x = slider_x + LAYOUT.SLIDERS.SPACING,
    y = slider_y,
    width = LAYOUT.SLIDERS.W,
    height = LAYOUT.SLIDERS.H,
    value = state.steps,
    min = 1,
    max = 32,
    default = Defaults.EUCLIDEAN.STEPS,
    label = 'Steps',
    fill_color = tab_color,
    advance = 'none',
  })
  if steps_result.changed then
    state.steps = steps_result.value
    if state.pulses > state.steps then
      state.pulses = state.steps
    end
    pattern_changed = true
  end

  -- Rotation slider
  local rotation_result = VerticalSlider.Draw(ctx, {
    id = 'rotation',
    x = slider_x + LAYOUT.SLIDERS.SPACING * 2,
    y = slider_y,
    width = LAYOUT.SLIDERS.W,
    height = LAYOUT.SLIDERS.H,
    value = state.rotation,
    min = 0,
    max = state.steps - 1,
    default = Defaults.EUCLIDEAN.ROTATION,
    label = 'Rotat',
    fill_color = tab_color,
    advance = 'none',
  })
  if rotation_result.changed then
    state.rotation = rotation_result.value
    pattern_changed = true
  end

  return pattern_changed
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Initialize the Euclidean view
--- @param ark_instance table Ark instance
function M.init(ark_instance)
  if state.initialized then return end
  Ark = ark_instance
  ImGui = Ark.ImGui
  state.pattern = Euclidean.generate(state.pulses, state.steps, state.rotation)
  state.initialized = true
end

--- Draw the Euclidean view
--- @param ctx userdata ImGui context
--- @param opts table { x, y, w, h, tab_color }
function M.Draw(ctx, opts)
  if not state.initialized then return end

  opts = opts or {}
  local base_x = opts.x or 0
  local base_y = opts.y or 0
  local win_w = opts.w or 900
  local win_h = opts.h or 200
  local tab_color = opts.tab_color or 0xFF8C00FF

  local dl = ImGui.GetWindowDrawList(ctx)

  -- Draw sliders and check for pattern changes
  local pattern_changed = draw_sliders(ctx, base_x, base_y, tab_color)

  if pattern_changed then
    state.pattern = Euclidean.generate(state.pulses, state.steps, state.rotation)
  end

  -- Draw pattern ring visualization
  local ring_cx = base_x + LAYOUT.PATTERN_VIS.X
  local ring_cy = base_y + LAYOUT.PATTERN_VIS.Y + LAYOUT.PATTERN_VIS.SIZE / 2
  local ring_radius = LAYOUT.PATTERN_VIS.SIZE / 2
  draw_pattern_ring(ctx, dl, ring_cx, ring_cy, ring_radius, state.pattern, state.steps, tab_color)

  -- Draw panels
  draw_left_panel(ctx, base_x, base_y, tab_color)
  draw_right_panel(ctx, base_x, base_y)
  draw_options_panel(ctx, base_x, base_y)

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
    pulses = state.pulses,
    steps = state.steps,
    rotation = state.rotation,
    note = state.note,
    velocity = state.velocity,
    grid_division = state.grid_division,
    note_length = state.note_length,
    generate_on_change = state.generate_on_change,
    accent_enabled = state.accent_enabled,
    randomize_notes = state.randomize_notes,
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
  state.pattern = Euclidean.generate(state.pulses, state.steps, state.rotation)
end

return M
