-- @noindex
-- ItemPicker/ui/views/layout_view.lua
-- Main layout view with absolute positioning and fade animations

local ImGui = require 'imgui' '0.10'
local SearchInput = require('rearkitekt.gui.widgets.controls.search_input')
local Checkbox = require('rearkitekt.gui.widgets.controls.checkbox')
local StatusBar = require('ItemPicker.ui.views.status_bar')

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
  }, LayoutView)

  self.status_bar = StatusBar.new(config, state)

  return self
end

-- Smooth easing function (same as original)
local function smootherstep(t)
  t = math.max(0.0, math.min(1.0, t))
  return t * t * t * (t * (t * 6 - 15) + 10)
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

function LayoutView:render(ctx, title_font, title_font_size, title, screen_w, screen_h)
  self:handle_shortcuts(ctx)

  -- Create fullscreen window wrapper (matching old MainWindow)
  local window_flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoTitleBar |
                       ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoMove |
                       ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse

  local imgui_visible, imgui_open = ImGui.Begin(ctx, title, true, window_flags)

  if not imgui_visible then
    ImGui.End(ctx)
    return
  end

  local overlay_alpha = self.state.overlay_alpha or 1.0

  -- UI fade with offset (matching original)
  local ui_fade = smootherstep(math.max(0, (overlay_alpha - 0.15) / 0.85))
  local ui_y_offset = 15 * (1.0 - ui_fade)

  -- Render checkboxes with fade animation and 14px padding
  -- Note: We pass alpha as config param instead of using PushStyleVar to keep interaction working
  local checkbox_x = 14
  local checkbox_y = 14 + ui_y_offset
  local checkbox_config = { alpha = ui_fade }

  ImGui.SetCursorScreenPos(ctx, checkbox_x, checkbox_y)
  local _, clicked = Checkbox.draw(ctx, self.state.draw_list, checkbox_x, checkbox_y,
    "Play Item Through Track (will add delay to preview playback)",
    self.state.settings.play_item_through_track, checkbox_config, "play_item_through_track")
  if clicked then
    self.state:set_setting('play_item_through_track', not self.state.settings.play_item_through_track)
  end

  checkbox_y = checkbox_y + 24
  ImGui.SetCursorScreenPos(ctx, checkbox_x, checkbox_y)
  _, clicked = Checkbox.draw(ctx, self.state.draw_list, checkbox_x, checkbox_y,
    "Show Muted Tracks",
    self.state.settings.show_muted_tracks, checkbox_config, "show_muted_tracks")
  if clicked then
    self.state:set_setting('show_muted_tracks', not self.state.settings.show_muted_tracks)
  end

  checkbox_y = checkbox_y + 24
  ImGui.SetCursorScreenPos(ctx, checkbox_x, checkbox_y)
  _, clicked = Checkbox.draw(ctx, self.state.draw_list, checkbox_x, checkbox_y,
    "Show Muted Items",
    self.state.settings.show_muted_items, checkbox_config, "show_muted_items")
  if clicked then
    self.state:set_setting('show_muted_items', not self.state.settings.show_muted_items)
  end

  -- Show Disabled Items on same line (after Show Muted Items)
  local muted_items_width = ImGui.CalcTextSize(ctx, "Show Muted Items") + 18 + 8 + 20  -- checkbox + spacing + margin
  local disabled_x = checkbox_x + muted_items_width
  _, clicked = Checkbox.draw(ctx, self.state.draw_list, disabled_x, checkbox_y,
    "Show Disabled Items",
    self.state.settings.show_disabled_items, checkbox_config, "show_disabled_items")
  if clicked then
    self.state:set_setting('show_disabled_items', not self.state.settings.show_disabled_items)
  end

  -- Search fade with different offset
  local search_fade = smootherstep(math.max(0, (overlay_alpha - 0.05) / 0.95))
  local search_y_offset = 25 * (1.0 - search_fade)

  -- Search input centered using rearkitekt widget (rounded to whole pixels)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, search_fade)
  ImGui.PushFont(ctx, title_font, 14)
  local content_start_y = screen_h * self.config.LAYOUT.CONTENT_START_Y

  local search_x = math.floor(screen_w / 2 - (screen_w * self.config.LAYOUT.SEARCH_WIDTH_RATIO) / 2 + 0.5)
  local search_y = math.floor(content_start_y + search_y_offset + 0.5)
  local search_width = screen_w * self.config.LAYOUT.SEARCH_WIDTH_RATIO
  local search_height = 24

  if (not self.state.initialized and self.state.settings.focus_keyboard_on_init) or self.focus_search then
    -- Focus search by setting cursor position
    ImGui.SetCursorScreenPos(ctx, search_x, search_y)
    ImGui.SetKeyboardFocusHere(ctx)
    self.state.initialized = true
    self.focus_search = false
  end

  -- Use rearkitekt search widget
  local current_search = self.state.settings.search_string or ""
  SearchInput.draw(ctx, self.state.draw_list, search_x, search_y, search_width, search_height, {
    id = "item_picker_search",
    placeholder = "Search items...",
    value = current_search,
  }, "item_picker_search")

  -- Get updated search text
  local new_search = SearchInput.get_text("item_picker_search")
  if new_search ~= current_search then
    self.state:set_search_filter(new_search)
  end

  -- Advance cursor past search widget
  ImGui.SetCursorScreenPos(ctx, search_x, search_y + search_height)

  ImGui.PopFont(ctx)
  ImGui.PopStyleVar(ctx)

  -- Section fade
  local section_fade = smootherstep(math.max(0, (overlay_alpha - 0.1) / 0.9))
  local content_height = screen_h * self.config.LAYOUT.CONTENT_HEIGHT

  -- MIDI section
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, section_fade)
  ImGui.SetCursorScreenPos(ctx, self.config.LAYOUT.PADDING, content_start_y)
  ImGui.PushFont(ctx, title_font, 14)
  ImGui.Text(ctx, "MIDI Tracks")
  ImGui.PopFont(ctx)
  ImGui.PopStyleVar(ctx)

  local midi_height = content_height * self.config.LAYOUT.MIDI_SECTION_RATIO
  ImGui.SetCursorScreenPos(ctx, self.config.LAYOUT.PADDING, content_start_y + self.config.LAYOUT.HEADER_HEIGHT)

  if ImGui.BeginChild(ctx, "midi_container", screen_w - (self.config.LAYOUT.PADDING * 2), midi_height, 0,
    ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse) then
    self.coordinator:render_midi_grid(ctx, screen_w - (self.config.LAYOUT.PADDING * 2), midi_height)
    ImGui.EndChild(ctx)
  end

  -- Audio section
  local audio_start_y = content_start_y + (content_height * self.config.LAYOUT.MIDI_SECTION_RATIO) + self.config.LAYOUT.SECTION_SPACING

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, section_fade)
  ImGui.SetCursorScreenPos(ctx, self.config.LAYOUT.PADDING, audio_start_y)
  ImGui.PushFont(ctx, title_font, 15)
  ImGui.Text(ctx, "Audio Sources")
  ImGui.PopFont(ctx)
  ImGui.PopStyleVar(ctx)

  local audio_height = content_height * self.config.LAYOUT.AUDIO_SECTION_RATIO
  ImGui.SetCursorScreenPos(ctx, self.config.LAYOUT.PADDING, audio_start_y + self.config.LAYOUT.HEADER_HEIGHT)

  if ImGui.BeginChild(ctx, "audio_container", screen_w - (self.config.LAYOUT.PADDING * 2), audio_height, 0,
    ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse) then
    self.coordinator:render_audio_grid(ctx, screen_w - (self.config.LAYOUT.PADDING * 2), audio_height)
    ImGui.EndChild(ctx)
  end

  ImGui.End(ctx)
end

return M
