-- @noindex
-- ItemPicker/ui/views/layout_view.lua
-- Main layout view with search and grids

local ImGui = require 'imgui' '0.10'
local StatusBar = require('ItemPicker.ui.views.status_bar')
local HeightStabilizer = require('rearkitekt.gui.systems.height_stabilizer')

local M = {}
local LayoutView = {}
LayoutView.__index = LayoutView

function M.new(config, state, coordinator)
  local self = setmetatable({
    config = config,
    state = state,
    coordinator = coordinator,
    status_bar = nil,
    focus_search = false,

    -- Height stabilizers to prevent jitter
    midi_height_stabilizer = nil,
    audio_height_stabilizer = nil,
  }, LayoutView)

  self.status_bar = StatusBar.new(config, state)

  -- Create height stabilizers
  self.midi_height_stabilizer = HeightStabilizer.new({
    stable_frames_required = 2,
    height_hysteresis = 12,
  })

  self.audio_height_stabilizer = HeightStabilizer.new({
    stable_frames_required = 2,
    height_hysteresis = 12,
  })

  return self
end

function LayoutView:handle_shortcuts(ctx)
  -- Ctrl+F to focus search
  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)

  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_F) then
    self.focus_search = true
    return
  end

  -- ESC to clear search
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    if self.state.settings.search_string and self.state.settings.search_string ~= "" then
      self.state:set_search_filter("")
    end
  end
end

function LayoutView:render_header(ctx, title_font, title_font_size, title)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Title
  ImGui.PushFont(ctx, title_font, title_font_size)
  local title_w = ImGui.CalcTextSize(ctx, title)
  ImGui.SetCursorPosX(ctx, (avail_w - title_w) / 2)
  ImGui.Text(ctx, title)
  ImGui.PopFont(ctx)

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Search and filters
  local search_w = math.max(200, avail_w * 0.3)

  -- Search field
  ImGui.SetNextItemWidth(ctx, search_w)

  local search_value = self.state.settings.search_string or ""

  if self.focus_search then
    ImGui.SetKeyboardFocusHere(ctx)
    self.focus_search = false
  end

  local changed, new_value = ImGui.InputTextWithHint(ctx, "##search", "Search items...", search_value)
  if changed then
    self.state:set_search_filter(new_value)
  end

  ImGui.SameLine(ctx)

  -- Checkboxes
  ImGui.SetCursorPosX(ctx, search_w + 20)

  local changed, show_muted_tracks = ImGui.Checkbox(ctx, "Show Muted Tracks", self.state.settings.show_muted_tracks)
  if changed then
    self.state:set_setting('show_muted_tracks', show_muted_tracks)
  end

  ImGui.SameLine(ctx)

  changed, show_muted_items = ImGui.Checkbox(ctx, "Show Muted Items", self.state.settings.show_muted_items)
  if changed then
    self.state:set_setting('show_muted_items', show_muted_items)
  end

  ImGui.SameLine(ctx)

  changed, show_disabled = ImGui.Checkbox(ctx, "Show Disabled", self.state.settings.show_disabled_items)
  if changed then
    self.state:set_setting('show_disabled_items', show_disabled)
  end

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
end

function LayoutView:render(ctx, title_font, title_font_size, title, screen_w, screen_h)
  self:handle_shortcuts(ctx)

  -- Render header
  self:render_header(ctx, title_font, title_font_size, title)

  -- Calculate layout (reserve space for status bar)
  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local avail_h = ImGui.GetContentRegionAvail(ctx) - 40  -- Reserve for status bar

  local raw_midi_h = avail_h * self.config.LAYOUT.MIDI_SECTION_RATIO
  local raw_audio_h = avail_h * self.config.LAYOUT.AUDIO_SECTION_RATIO
  local spacing = self.config.LAYOUT.SECTION_SPACING

  -- Stabilize heights to prevent jitter
  local midi_h = self.midi_height_stabilizer:update(raw_midi_h)
  local audio_h = self.audio_height_stabilizer:update(raw_audio_h)

  -- MIDI section
  if midi_h > 50 then
    ImGui.Text(ctx, "MIDI Items")
    ImGui.Spacing(ctx)

    self.coordinator:render_midi_grid(ctx, avail_w, midi_h - 40)

    ImGui.Spacing(ctx)
    ImGui.Dummy(ctx, 1, spacing)
  end

  -- Audio section
  if audio_h > 50 then
    ImGui.Text(ctx, "Audio Items")
    ImGui.Spacing(ctx)

    self.coordinator:render_audio_grid(ctx, avail_w, audio_h - 40)
  end

  -- Status bar at bottom
  self.status_bar:render(ctx)
end

return M
