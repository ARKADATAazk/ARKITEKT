-- @noindex
-- ItemPicker/ui/views/layout_view.lua
-- Main layout view with search and grids

local ImGui = require 'imgui' '0.10'
local SearchInput = require('rearkitekt.gui.widgets.controls.search_input')

local M = {}
local LayoutView = {}
LayoutView.__index = LayoutView

function M.new(config, state, coordinator)
  local self = setmetatable({
    config = config,
    state = state,
    coordinator = coordinator,
    search_input = nil,
    focus_search = false,
  }, LayoutView)

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

function LayoutView:render_header(ctx, title_font, title)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Title
  ImGui.PushFont(ctx, title_font)
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

  if not self.search_input then
    self.search_input = SearchInput.new({
      placeholder = "Search items...",
      on_change = function(value)
        self.state:set_search_filter(value)
      end,
    })
  end

  local search_value = self.state.settings.search_string or ""
  local search_changed = self.search_input:render(ctx, search_value, self.focus_search)
  if search_changed then
    self.focus_search = false
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

function LayoutView:render(ctx, title_font, title, screen_w, screen_h)
  self:handle_shortcuts(ctx)

  -- Render header
  self:render_header(ctx, title_font, title)

  -- Calculate layout
  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local avail_h = ImGui.GetContentRegionAvail(ctx)

  local midi_h = avail_h * self.config.LAYOUT.MIDI_SECTION_RATIO
  local audio_h = avail_h * self.config.LAYOUT.AUDIO_SECTION_RATIO
  local spacing = self.config.LAYOUT.SECTION_SPACING

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
end

return M
