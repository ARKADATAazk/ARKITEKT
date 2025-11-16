-- @noindex
-- ThemeAdjuster/ui/views/transport_view.lua
-- Transport bar configuration tab

local ImGui = require 'imgui' '0.10'
local Spinner = require('rearkitekt.gui.widgets.primitives.spinner')
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}
local TransportView = {}
TransportView.__index = TransportView

-- Spinner value lists (from Default 6.0)
local SPINNER_VALUES = {
  trans_rateSize = {'MIN', 60, 90, 120, 150, 180, 210},
  trans_rateMode = {'RATE', 'FRAMES'},
}

function M.new(State, Config, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,

    -- Spinner indices (1-based)
    trans_rateSize_idx = 1,
    trans_rateMode_idx = 1,

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

  ImGui.Dummy(ctx, 0, 15)

  -- Layout Settings Section
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "transport_layout_section", avail_w, 120, 1) then
    ImGui.Dummy(ctx, 0, 8)

    ImGui.Indent(ctx, 12)
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "LAYOUT SETTINGS")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 8)

    local label_w = 140
    local spinner_w = math.min(220, avail_w - label_w - 40)

    -- Helper function to draw spinner row
    local function draw_spinner_row(label, id, idx, values)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.Text(ctx, label)
      ImGui.SameLine(ctx, label_w)
      local changed, new_idx = Spinner.draw(ctx, id, idx, values, {w = spinner_w})
      ImGui.Dummy(ctx, 0, 4)
      return changed, new_idx
    end

    -- Spinners
    local changed, new_idx = draw_spinner_row("Rate Display Size", "trans_rateSize", self.trans_rateSize_idx, SPINNER_VALUES.trans_rateSize)
    if changed then self.trans_rateSize_idx = new_idx end

    changed, new_idx = draw_spinner_row("Rate Display Mode", "trans_rateMode", self.trans_rateMode_idx, SPINNER_VALUES.trans_rateMode)
    if changed then self.trans_rateMode_idx = new_idx end

    ImGui.Unindent(ctx, 12)
    ImGui.Dummy(ctx, 0, 8)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 12)

  -- Layout & Size Section
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "transport_layout_buttons", avail_w, 120, 1) then
    ImGui.Dummy(ctx, 0, 8)

    ImGui.Indent(ctx, 12)
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "ACTIVE LAYOUT & SIZE")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 8)

    -- Active Layout
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, "Active Layout")
    ImGui.SameLine(ctx, 140)

    for _, layout in ipairs({'A', 'B', 'C'}) do
      local is_active = (self.active_layout == layout)
      if is_active then
        ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#2D4A37"))
        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, hexrgb("#3A5F48"))
        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, hexrgb("#47724F"))
      end
      if ImGui.Button(ctx, layout, 50, 24) then
        self.active_layout = layout
        -- TODO: Apply layout
      end
      if is_active then
        ImGui.PopStyleColor(ctx, 3)
      end
      ImGui.SameLine(ctx, 0, 6)
    end
    ImGui.NewLine(ctx)

    ImGui.Dummy(ctx, 0, 8)

    -- Apply Size
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, "Apply Size")
    ImGui.SameLine(ctx, 140)

    for _, size in ipairs({'100%', '150%', '200%'}) do
      if ImGui.Button(ctx, size, 70, 24) then
        -- TODO: Apply size
      end
      ImGui.SameLine(ctx, 0, 6)
    end
    ImGui.NewLine(ctx)

    ImGui.Unindent(ctx, 12)
    ImGui.Dummy(ctx, 0, 8)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)

  ImGui.Dummy(ctx, 0, 12)

  -- Element Visibility Section
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, hexrgb("#1A1A1A"))
  if ImGui.BeginChild(ctx, "transport_visibility_section", avail_w, 0, 1) then
    ImGui.Dummy(ctx, 0, 8)

    ImGui.Indent(ctx, 12)
    ImGui.PushFont(ctx, shell_state.fonts.bold, 13)
    ImGui.Text(ctx, "ELEMENT VISIBILITY")
    ImGui.PopFont(ctx)
    ImGui.Dummy(ctx, 0, 4)

    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#999999"))
    ImGui.Text(ctx, "Control which transport elements are visible")
    ImGui.PopStyleColor(ctx)
    ImGui.Dummy(ctx, 0, 8)

    -- Helper function for checkbox rows
    local function draw_checkbox_row(label, checked)
      local result = checked
      if ImGui.Checkbox(ctx, label, checked) then
        result = not checked
      end
      ImGui.Dummy(ctx, 0, 4)
      return result
    end

    -- Two columns layout for checkboxes
    local col_w = (avail_w - 48) / 2

    ImGui.BeginGroup(ctx)

    -- Left column
    self.show_play_position = draw_checkbox_row("Show play position", self.show_play_position)
    self.show_playback_status = draw_checkbox_row("Show playback status", self.show_playback_status)
    self.show_transport_state = draw_checkbox_row("Show transport state", self.show_transport_state)
    self.show_record_status = draw_checkbox_row("Show record status", self.show_record_status)
    self.show_loop_repeat = draw_checkbox_row("Show loop/repeat status", self.show_loop_repeat)
    self.show_auto_crossfade = draw_checkbox_row("Show auto-crossfade", self.show_auto_crossfade)

    ImGui.EndGroup(ctx)

    ImGui.SameLine(ctx, col_w + 24)

    ImGui.BeginGroup(ctx)

    -- Right column
    self.show_midi_editor_btn = draw_checkbox_row("Show MIDI editor button", self.show_midi_editor_btn)
    self.show_metronome = draw_checkbox_row("Show metronome", self.show_metronome)
    self.show_tempo_bpm = draw_checkbox_row("Show tempo (BPM)", self.show_tempo_bpm)
    self.show_time_signature = draw_checkbox_row("Show time signature", self.show_time_signature)
    self.show_project_length = draw_checkbox_row("Show project length", self.show_project_length)
    self.show_selection_length = draw_checkbox_row("Show selection length", self.show_selection_length)

    ImGui.EndGroup(ctx)

    ImGui.Unindent(ctx, 12)
    ImGui.Dummy(ctx, 0, 8)
    ImGui.EndChild(ctx)
  end
  ImGui.PopStyleColor(ctx)
end

return M
