-- @noindex
-- ThemeAdjuster/ui/views/transport_view.lua
-- Transport bar configuration tab

local ImGui = require 'imgui' '0.10'
local Spinner = require('rearkitekt.gui.widgets.primitives.spinner')
local Checkbox = require('rearkitekt.gui.widgets.primitives.checkbox')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local Background = require('rearkitekt.gui.widgets.containers.panel.background')
local Style = require('rearkitekt.gui.style.defaults')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local PC = Style.PANEL_COLORS  -- Panel colors including pattern defaults

local M = {}
local TransportView = {}
TransportView.__index = TransportView

-- Spinner value lists (from Default 6.0)
local SPINNER_VALUES = {
  trans_rateSize = {'MIN', 60, 90, 120, 150, 180, 210},
  trans_rateMode = {'RATE', 'FRAMES'},
  trans_status_size = {'MIN', 80, 120, 160, 200},
  trans_bpmEdit_size = {'MIN', 60, 80, 100, 120},
  trans_timeEdit_size = {'MIN', 100, 140, 180, 220},
}

function M.new(State, Config, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,

    -- Spinner indices (1-based)
    trans_rateSize_idx = 1,
    trans_rateMode_idx = 1,
    trans_status_size_idx = 1,
    trans_bpmEdit_size_idx = 1,
    trans_timeEdit_size_idx = 1,

    -- Active layout (A/B/C)
    active_layout = 'A',

    -- Toggles (action toggles from Default 6.0)
    show_play_position = true,
    show_playback_status = true,
    show_transport_state = true,
    show_record_status = true,
    show_loop_repeat = true,
    show_auto_crossfade = false,
    show_midi_editor_btn = false,
    show_metronome = true,
    show_tempo_bpm = true,
    show_time_signature = true,
    show_project_length = false,
    show_selection_length = false,
  }, TransportView)

  -- Load initial values from theme
  self:load_from_theme()

  return self
end

function TransportView:load_from_theme()
  -- TODO: Load spinner indices and toggle states from theme parameters
  -- For now, keep defaults
end

function TransportView:get_param_index(param_name)
  -- Get parameter index from theme layout
  -- Returns nil if not found
  local ok, idx = pcall(reaper.ThemeLayout_GetParameter, param_name)
  if ok and type(idx) == "number" then
    return idx
  end
  return nil
end

function TransportView:set_param(param, value, save)
  save = save == nil and true or save
  local ok = pcall(reaper.ThemeLayout_SetParameter, param, value, save)
  if ok and save then
    pcall(reaper.ThemeLayout_RefreshAll)
  end
  return ok
end

function TransportView:draw(ctx, shell_state)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Title
  ImGui.PushFont(ctx, shell_state.fonts.bold, 16)
  ImGui.Text(ctx, "Transport Bar")
  ImGui.PopFont(ctx)

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
  ImGui.Text(ctx, "Configure transport bar appearance and visibility")
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 8)

  -- Single scrollable content area
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "transport_content", avail_w, 0, 1) then
    -- Draw background pattern (using panel defaults)
    local child_x, child_y = ImGui.GetWindowPos(ctx)
    local child_w, child_h = ImGui.GetWindowSize(ctx)
    local dl = ImGui.GetWindowDrawList(ctx)
    local pattern_cfg = {
      enabled = true,
      primary = {type = 'grid', spacing = 50, color = PC.pattern_primary, line_thickness = 1.5},
      secondary = {enabled = true, type = 'grid', spacing = 5, color = PC.pattern_secondary, line_thickness = 0.5},
    }
    Background.draw(dl, child_x, child_y, child_x + child_w, child_y + child_h, pattern_cfg)

    ImGui.Dummy(ctx, 0, 4)

    ImGui.Indent(ctx, 8)

    -- Layout & Size Section
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "ACTIVE LAYOUT & SIZE")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 4)

    -- Active Layout
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, "Active Layout")
    ImGui.SameLine(ctx, 120)

    for _, layout in ipairs({'A', 'B', 'C'}) do
      local is_active = (self.active_layout == layout)
      if Button.draw_at_cursor(ctx, {
        label = layout,
        width = 50,
        height = 24,
        is_toggled = is_active,
        preset_name = "BUTTON_TOGGLE_WHITE",
        on_click = function()
          self.active_layout = layout
          -- TODO: Apply layout
        end
      }, "trans_layout_" .. layout) then
      end
      ImGui.SameLine(ctx, 0, 6)
    end
    ImGui.NewLine(ctx)

    ImGui.Dummy(ctx, 0, 4)

    -- Apply Size
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, "Apply Size")
    ImGui.SameLine(ctx, 120)

    for _, size in ipairs({'100%', '150%', '200%'}) do
      if Button.draw_at_cursor(ctx, {
        label = size,
        width = 70,
        height = 24,
        on_click = function()
          -- TODO: Apply size
        end
      }, "trans_size_" .. size) then
      end
      ImGui.SameLine(ctx, 0, 6)
    end
    ImGui.NewLine(ctx)

    ImGui.Dummy(ctx, 0, 16)

    -- Sizing Controls Section
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "SIZING CONTROLS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 4)

    -- Column layout for spinners
    local col_w = (avail_w - 32) / 2
    local label_w = 100  -- Fixed label width for consistency

    local spinner_w = col_w - label_w - 16  -- Remaining for spinner

    -- Helper function to draw properly aligned spinner row
    local function draw_spinner_row(label, id, idx, values)
      -- Label (right-aligned in label column)
      local label_text_w = ImGui.CalcTextSize(ctx, label)
      ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + label_w - label_text_w)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#AAAAAA"))
      ImGui.Text(ctx, label)
      ImGui.PopStyleColor(ctx)

      -- Spinner (fixed position, fixed width)
      ImGui.SameLine(ctx, 0, 8)
      local changed, new_idx = Spinner.draw(ctx, id, idx, values, {w = spinner_w, h = 24})


      ImGui.Dummy(ctx, 0, 2)
      return changed, new_idx
    end

    ImGui.BeginGroup(ctx)
    -- Left column
    local changed, new_idx = draw_spinner_row("Rate Size", "trans_rateSize", self.trans_rateSize_idx, SPINNER_VALUES.trans_rateSize)
    if changed then self.trans_rateSize_idx = new_idx end

    changed, new_idx = draw_spinner_row("Rate Mode", "trans_rateMode", self.trans_rateMode_idx, SPINNER_VALUES.trans_rateMode)
    if changed then self.trans_rateMode_idx = new_idx end

    changed, new_idx = draw_spinner_row("Status Size", "trans_status_size", self.trans_status_size_idx, SPINNER_VALUES.trans_status_size)
    if changed then self.trans_status_size_idx = new_idx end

    ImGui.EndGroup(ctx)

    ImGui.SameLine(ctx, col_w + 8)

    ImGui.BeginGroup(ctx)
    -- Right column
    changed, new_idx = draw_spinner_row("BPM Editor", "trans_bpmEdit_size", self.trans_bpmEdit_size_idx, SPINNER_VALUES.trans_bpmEdit_size)
    if changed then self.trans_bpmEdit_size_idx = new_idx end

    changed, new_idx = draw_spinner_row("Time Editor", "trans_timeEdit_size", self.trans_timeEdit_size_idx, SPINNER_VALUES.trans_timeEdit_size)
    if changed then self.trans_timeEdit_size_idx = new_idx end

    ImGui.EndGroup(ctx)

    ImGui.Dummy(ctx, 0, 16)

    -- Element Visibility Section
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "ELEMENT VISIBILITY")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 4)

    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
    ImGui.Text(ctx, "Control which transport elements are visible")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 2)

    -- Helper function for checkbox rows
    local function draw_checkbox_row(label, checked, id)
      local result = checked
      if Checkbox.draw_at_cursor(ctx, label, checked, nil, id) then
        result = not checked
      end
      ImGui.NewLine(ctx)
      ImGui.Dummy(ctx, 0, 3)
      return result
    end

    -- Two columns layout for checkboxes
    local col_w = (avail_w - 32) / 2

    ImGui.BeginGroup(ctx)

    -- Left column
    self.show_play_position = draw_checkbox_row("Show play position", self.show_play_position, "trans_play_position")
    self.show_playback_status = draw_checkbox_row("Show playback status", self.show_playback_status, "trans_playback_status")
    self.show_transport_state = draw_checkbox_row("Show transport state", self.show_transport_state, "trans_transport_state")
    self.show_record_status = draw_checkbox_row("Show record status", self.show_record_status, "trans_record_status")
    self.show_loop_repeat = draw_checkbox_row("Show loop/repeat status", self.show_loop_repeat, "trans_loop_repeat")
    self.show_auto_crossfade = draw_checkbox_row("Show auto-crossfade", self.show_auto_crossfade, "trans_auto_crossfade")

    ImGui.EndGroup(ctx)

    ImGui.SameLine(ctx, col_w + 8)

    ImGui.BeginGroup(ctx)

    -- Right column
    self.show_midi_editor_btn = draw_checkbox_row("Show MIDI editor button", self.show_midi_editor_btn, "trans_midi_editor")
    self.show_metronome = draw_checkbox_row("Show metronome", self.show_metronome, "trans_metronome")
    self.show_tempo_bpm = draw_checkbox_row("Show tempo (BPM)", self.show_tempo_bpm, "trans_tempo_bpm")
    self.show_time_signature = draw_checkbox_row("Show time signature", self.show_time_signature, "trans_time_signature")
    self.show_project_length = draw_checkbox_row("Show project length", self.show_project_length, "trans_project_length")
    self.show_selection_length = draw_checkbox_row("Show selection length", self.show_selection_length, "trans_selection_length")

    ImGui.EndGroup(ctx)

    ImGui.Unindent(ctx, 8)
    ImGui.Dummy(ctx, 0, 2)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)
end

return M
