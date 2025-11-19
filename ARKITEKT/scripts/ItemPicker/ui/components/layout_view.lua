-- @noindex
-- ItemPicker/ui/views/layout_view.lua
-- Main layout view with absolute positioning and fade animations

local ImGui = require 'imgui' '0.10'
local SearchInput = require('rearkitekt.gui.widgets.inputs.search_input')
local Checkbox = require('rearkitekt.gui.widgets.primitives.checkbox')
local DraggableSeparator = require('rearkitekt.gui.widgets.primitives.separator')
local StatusBar = require('ItemPicker.ui.components.status_bar')
local Colors = require('rearkitekt.core.colors')
local Background = require('rearkitekt.gui.widgets.containers.panel.background')

-- Debug module - with error handling
local Debug = nil
local debug_ok, debug_module = pcall(require, 'ItemPicker.utils.logger')
if debug_ok then
  Debug = debug_module
  reaper.ShowConsoleMsg("=== ITEMPICKER DEBUG MODULE LOADED ===\n")
else
  reaper.ShowConsoleMsg("=== DEBUG MODULE FAILED: " .. tostring(debug_module) .. " ===\n")
end

local M = {}
local LayoutView = {}
LayoutView.__index = LayoutView

function M.new(config, state, coordinator)
  local self = setmetatable({
    config = config,
    state = state,
    coordinator = coordinator,
    status_bar = nil,
    separator = nil,
    focus_search = false,
  }, LayoutView)

  self.status_bar = StatusBar.new(config, state)
  self.separator = DraggableSeparator.new()

  return self
end

-- Smooth easing function (same as original)
local function smootherstep(t)
  t = math.max(0.0, math.min(1.0, t))
  return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Draw a panel background and border with dotted pattern
local function draw_panel(dl, x1, y1, x2, y2, rounding, alpha)
  alpha = alpha or 1.0
  rounding = rounding or 6

  -- Panel background (semi-transparent, lighter)
  local bg_color = Colors.hexrgb("#0F0F0F")
  bg_color = Colors.with_alpha(bg_color, math.floor(alpha * 0x99))  -- 60% opacity (lighter)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, rounding)

  -- Dotted background pattern (more visible)
  local pattern_config = {
    enabled = true,
    primary = {
      type = 'dots',
      spacing = 16,
      dot_size = 1.5,
      color = Colors.with_alpha(Colors.hexrgb("#2A2A2A"), math.floor(alpha * 180)),  -- More visible
      offset_x = 0,
      offset_y = 0,
    }
  }

  -- Push clip rect for rounded corners
  ImGui.DrawList_PushClipRect(dl, x1, y1, x2, y2, true)
  Background.draw(dl, x1, y1, x2, y2, pattern_config)
  ImGui.DrawList_PopClipRect(dl)

  -- Panel border
  local border_color = Colors.hexrgb("#1A1A1A")
  border_color = Colors.with_alpha(border_color, math.floor(alpha * 0xAA))
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, rounding, 0, 1)
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

function LayoutView:render(ctx, title_font, title_font_size, title, screen_w, screen_h, is_overlay_mode)
  self:handle_shortcuts(ctx)

  -- In overlay mode, skip window creation (overlay manager already created the window)
  local imgui_visible = true
  if not is_overlay_mode then
    -- Set window position and size BEFORE Begin (critical!)
    ImGui.SetNextWindowPos(ctx, 0, 0)
    ImGui.SetNextWindowSize(ctx, screen_w, screen_h)

    -- Debug output
    if not self.window_size_logged then
      reaper.ShowConsoleMsg(string.format("=== WINDOW SIZE: %dx%d ===\n", screen_w, screen_h))
      self.window_size_logged = true
    end

    -- Create fullscreen window wrapper (matching old MainWindow)
    local window_flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoTitleBar |
                         ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoMove |
                         ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse

    local imgui_open
    imgui_visible, imgui_open = ImGui.Begin(ctx, title, true, window_flags)

    if not imgui_visible then
      ImGui.End(ctx)
      return
    end
  end

  local overlay_alpha = self.state.overlay_alpha or 1.0

  -- UI fade with offset (matching original)
  local ui_fade = smootherstep(math.max(0, (overlay_alpha - 0.15) / 0.85))
  local ui_y_offset = 15 * (1.0 - ui_fade)

  -- Get current window draw list (not cached)
  local draw_list = ImGui.GetWindowDrawList(ctx)

  -- Render checkboxes with fade animation and 14px padding (organized in 2 lines)
  -- Note: We pass alpha as config param instead of using PushStyleVar to keep interaction working
  local checkbox_x = 14
  local checkbox_y = 14 + ui_y_offset
  local checkbox_config = { alpha = ui_fade }
  local spacing = 20  -- Horizontal spacing between checkboxes

  -- Line 1: Play Item Through Track | Show Muted Tracks | Show Muted Items | Show Disabled Items
  local total_width, clicked = Checkbox.draw(ctx, draw_list, checkbox_x, checkbox_y,
    "Play Item Through Track (will add delay to preview playback)",
    self.state.settings.play_item_through_track, checkbox_config, "play_item_through_track")

  -- Log file debug (if available)
  if Debug then
    Debug.log_checkbox("play_item_through_track", clicked, self.state.settings.play_item_through_track, total_width)
  end

  -- Console debug only on interaction
  if clicked then
    reaper.ShowConsoleMsg("[CHECKBOX] CLICKED play_item_through_track! (toggling)\n")
    if Debug then Debug.log("CHECKBOX", "play_item_through_track TOGGLED") end
    self.state.set_setting('play_item_through_track', not self.state.settings.play_item_through_track)
  end

  -- Show Muted Tracks on same line
  local prev_width = ImGui.CalcTextSize(ctx, "Play Item Through Track (will add delay to preview playback)") + 18 + 8 + spacing
  local muted_tracks_x = checkbox_x + prev_width
  _, clicked = Checkbox.draw(ctx, draw_list, muted_tracks_x, checkbox_y,
    "Show Muted Tracks",
    self.state.settings.show_muted_tracks, checkbox_config, "show_muted_tracks")
  if clicked then
    self.state.set_setting('show_muted_tracks', not self.state.settings.show_muted_tracks)
  end

  -- Show Muted Items on same line
  prev_width = prev_width + ImGui.CalcTextSize(ctx, "Show Muted Tracks") + 18 + 8 + spacing
  local muted_items_x = checkbox_x + prev_width
  _, clicked = Checkbox.draw(ctx, draw_list, muted_items_x, checkbox_y,
    "Show Muted Items",
    self.state.settings.show_muted_items, checkbox_config, "show_muted_items")
  if clicked then
    self.state.set_setting('show_muted_items', not self.state.settings.show_muted_items)
  end

  -- Show Disabled Items on same line
  prev_width = prev_width + ImGui.CalcTextSize(ctx, "Show Muted Items") + 18 + 8 + spacing
  local disabled_x = checkbox_x + prev_width
  _, clicked = Checkbox.draw(ctx, draw_list, disabled_x, checkbox_y,
    "Show Disabled Items",
    self.state.settings.show_disabled_items, checkbox_config, "show_disabled_items")
  if clicked then
    self.state.set_setting('show_disabled_items', not self.state.settings.show_disabled_items)
  end

  -- Line 2: Show Favorites Only | Show Audio | Show MIDI | Sort Mode
  checkbox_y = checkbox_y + 24
  _, clicked = Checkbox.draw(ctx, draw_list, checkbox_x, checkbox_y,
    "Show Favorites Only",
    self.state.settings.show_favorites_only, checkbox_config, "show_favorites_only")
  if clicked then
    self.state.set_setting('show_favorites_only', not self.state.settings.show_favorites_only)
  end

  -- Show Audio on same line
  prev_width = ImGui.CalcTextSize(ctx, "Show Favorites Only") + 18 + 8 + spacing
  local show_audio_x = checkbox_x + prev_width
  _, clicked = Checkbox.draw(ctx, draw_list, show_audio_x, checkbox_y,
    "Show Audio",
    self.state.settings.show_audio, checkbox_config, "show_audio")
  if clicked then
    self.state.set_setting('show_audio', not self.state.settings.show_audio)
  end

  -- Show MIDI on same line
  prev_width = prev_width + ImGui.CalcTextSize(ctx, "Show Audio") + 18 + 8 + spacing
  local show_midi_x = checkbox_x + prev_width
  _, clicked = Checkbox.draw(ctx, draw_list, show_midi_x, checkbox_y,
    "Show MIDI",
    self.state.settings.show_midi, checkbox_config, "show_midi")
  if clicked then
    self.state.set_setting('show_midi', not self.state.settings.show_midi)
  end

  -- Group Items of Same Name checkbox on same line
  prev_width = prev_width + ImGui.CalcTextSize(ctx, "Show MIDI") + 18 + 8 + spacing
  local group_items_x = checkbox_x + prev_width
  _, clicked = Checkbox.draw(ctx, draw_list, group_items_x, checkbox_y,
    "Group Items of Same Name",
    self.state.settings.group_items_by_name, checkbox_config, "group_items_by_name")
  if clicked then
    self.state.set_setting('group_items_by_name', not self.state.settings.group_items_by_name)
    reaper.ShowConsoleMsg(string.format("[GROUPING] Checkbox clicked! New value: %s\n", tostring(self.state.settings.group_items_by_name)))
    -- Trigger instant reorganization (no REAPER API calls)
    self.state.needs_reorganize = true
  end

  -- Enable TileFX checkbox on same line
  prev_width = prev_width + ImGui.CalcTextSize(ctx, "Group Items of Same Name") + 18 + 8 + spacing
  local enable_fx_x = checkbox_x + prev_width
  local enable_fx = self.state.settings.enable_tile_fx
  if enable_fx == nil then enable_fx = true end
  _, clicked = Checkbox.draw(ctx, draw_list, enable_fx_x, checkbox_y,
    "Tile FX",
    enable_fx, checkbox_config, "enable_fx")
  if clicked then
    self.state.set_setting('enable_tile_fx', not enable_fx)
  end

  -- Show Visualization in Small Tiles checkbox on same line
  prev_width = prev_width + ImGui.CalcTextSize(ctx, "Tile FX") + 18 + 8 + spacing
  local show_viz_small_x = checkbox_x + prev_width
  local show_viz_small = self.state.settings.show_visualization_in_small_tiles
  if show_viz_small == nil then show_viz_small = true end
  _, clicked = Checkbox.draw(ctx, draw_list, show_viz_small_x, checkbox_y,
    "Show Viz in Small Tiles",
    show_viz_small, checkbox_config, "show_viz_small")
  if clicked then
    self.state.set_setting('show_visualization_in_small_tiles', not show_viz_small)
  end

  -- Sort mode buttons (on same line after checkboxes)
  prev_width = prev_width + ImGui.CalcTextSize(ctx, "Show Viz in Small Tiles") + 18 + 8 + 40  -- Extra spacing
  local sort_button_x = checkbox_x + prev_width

  -- Draw sort mode label and buttons
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, ui_fade)
  local sort_label = "Sort:"
  local sort_label_width = ImGui.CalcTextSize(ctx, sort_label)
  ImGui.DrawList_AddText(draw_list, sort_button_x, checkbox_y + 3, Colors.with_alpha(Colors.hexrgb("#FFFFFF"), math.floor(ui_fade * 180)), sort_label)

  -- Sort buttons
  local button_x = sort_button_x + sort_label_width + 8
  local button_y = checkbox_y
  local button_h = 20
  local button_gap = 4

  local sort_modes = {
    {id = "none", label = "None"},
    {id = "color", label = "Color"},
    {id = "name", label = "Name"},
    {id = "pool", label = "Pool"},
  }

  local current_sort = self.state.settings.sort_mode or "none"
  for i, mode in ipairs(sort_modes) do
    local label = mode.label
    local label_width = ImGui.CalcTextSize(ctx, label)
    local button_w = label_width + 16

    local is_active = (current_sort == mode.id)
    local mx, my = ImGui.GetMousePos(ctx)
    local is_hovered = mx >= button_x and mx < button_x + button_w and my >= button_y and my < button_y + button_h

    -- Button background
    local bg_color = is_active and Colors.hexrgb("#2A2A2A") or Colors.hexrgb("#1A1A1A")
    if is_hovered and not is_active then
      bg_color = Colors.hexrgb("#222222")
    end
    bg_color = Colors.with_alpha(bg_color, math.floor(ui_fade * 200))
    ImGui.DrawList_AddRectFilled(draw_list, button_x, button_y, button_x + button_w, button_y + button_h, bg_color, 3)

    -- Button border
    local border_color = is_active and Colors.hexrgb("#3A3A3A") or Colors.hexrgb("#2A2A2A")
    border_color = Colors.with_alpha(border_color, math.floor(ui_fade * 255))
    ImGui.DrawList_AddRect(draw_list, button_x, button_y, button_x + button_w, button_y + button_h, border_color, 3, 0, 1)

    -- Button text
    local text_color = is_active and Colors.hexrgb("#FFFFFF") or Colors.hexrgb("#AAAAAA")
    text_color = Colors.with_alpha(text_color, math.floor(ui_fade * 255))
    ImGui.DrawList_AddText(draw_list, button_x + 8, button_y + 2, text_color, label)

    -- Click detection
    if is_hovered and ImGui.IsMouseClicked(ctx, 0) then
      self.state.set_setting('sort_mode', mode.id)
    end

    button_x = button_x + button_w + button_gap
  end

  -- Waveform Quality slider (after sort buttons)
  local slider_x = button_x + 20
  local slider_y = checkbox_y
  local slider_width = 120
  local slider_label = "Waveform Quality:"
  local slider_label_width = ImGui.CalcTextSize(ctx, slider_label)

  ImGui.DrawList_AddText(draw_list, slider_x, slider_y + 3, Colors.with_alpha(Colors.hexrgb("#FFFFFF"), math.floor(ui_fade * 180)), slider_label)

  -- Draw slider track
  local track_x = slider_x + slider_label_width + 8
  local track_y = slider_y + 7
  local track_h = 6
  local track_rounding = 3

  local track_color = Colors.with_alpha(Colors.hexrgb("#1A1A1A"), math.floor(ui_fade * 200))
  ImGui.DrawList_AddRectFilled(draw_list, track_x, track_y, track_x + slider_width, track_y + track_h, track_color, track_rounding)

  -- Draw slider fill
  local quality = self.state.settings.waveform_quality or 1.0
  local fill_width = slider_width * quality
  local fill_color = Colors.with_alpha(Colors.hexrgb("#4A9EFF"), math.floor(ui_fade * 200))
  if fill_width > 1 then
    ImGui.DrawList_AddRectFilled(draw_list, track_x, track_y, track_x + fill_width, track_y + track_h, fill_color, track_rounding)
  end

  -- Draw slider thumb
  local thumb_x = track_x + fill_width
  local thumb_y = track_y + track_h / 2
  local thumb_radius = 6
  local mx, my = ImGui.GetMousePos(ctx)
  local is_thumb_hovered = (mx - thumb_x) * (mx - thumb_x) + (my - thumb_y) * (my - thumb_y) <= thumb_radius * thumb_radius

  local thumb_color = is_thumb_hovered and Colors.hexrgb("#5AAFFF") or Colors.hexrgb("#4A9EFF")
  thumb_color = Colors.with_alpha(thumb_color, math.floor(ui_fade * 255))
  ImGui.DrawList_AddCircleFilled(draw_list, thumb_x, thumb_y, thumb_radius, thumb_color)

  -- Slider interaction
  local is_slider_hovered = mx >= track_x and mx < track_x + slider_width and my >= track_y - 4 and my < track_y + track_h + 4
  if is_slider_hovered and ImGui.IsMouseDown(ctx, 0) then
    local new_quality = math.max(0.1, math.min(1.0, (mx - track_x) / slider_width))
    self.state.set_setting('waveform_quality', new_quality)
    -- Clear waveform cache to force rebuild with new quality
    if self.state.runtime_cache and self.state.runtime_cache.waveforms then
      self.state.runtime_cache.waveforms = {}
    end
  end

  -- Draw percentage value
  local percent_text = string.format("%d%%", math.floor(quality * 100))
  local percent_x = track_x + slider_width + 8
  ImGui.DrawList_AddText(draw_list, percent_x, slider_y + 3, Colors.with_alpha(Colors.hexrgb("#AAAAAA"), math.floor(ui_fade * 180)), percent_text)

  -- Waveform fill checkbox (next to quality slider)
  local fill_checkbox_x = percent_x + ImGui.CalcTextSize(ctx, percent_text) + 20
  local fill_checkbox_y = checkbox_y

  local waveform_filled = self.state.settings.waveform_filled
  if waveform_filled == nil then waveform_filled = true end

  local _, fill_clicked = Checkbox.draw(ctx, draw_list, fill_checkbox_x, fill_checkbox_y,
    "Fill",
    waveform_filled, checkbox_config, "waveform_filled")
  if fill_clicked then
    self.state.set_setting('waveform_filled', not waveform_filled)
    -- Clear polyline cache to force rebuild with new style
    if self.state.runtime_cache and self.state.runtime_cache.waveform_polylines then
      self.state.runtime_cache.waveform_polylines = {}
    end
  end

  -- Zero line checkbox (next to Fill checkbox)
  local fill_label_width = ImGui.CalcTextSize(ctx, "Fill")
  local zero_line_checkbox_x = fill_checkbox_x + fill_label_width + 18 + 8
  local zero_line_checkbox_y = checkbox_y

  local waveform_zero_line = self.state.settings.waveform_zero_line or false

  local _, zero_line_clicked = Checkbox.draw(ctx, draw_list, zero_line_checkbox_x, zero_line_checkbox_y,
    "Zero Line",
    waveform_zero_line, checkbox_config, "waveform_zero_line")
  if zero_line_clicked then
    self.state.set_setting('waveform_zero_line', not waveform_zero_line)
  end

  -- Layout mode toggle button (only show when both MIDI and Audio are visible)
  if self.state.settings.show_audio and self.state.settings.show_midi then
    local zero_line_label_width = ImGui.CalcTextSize(ctx, "Zero Line")
    local layout_button_x = zero_line_checkbox_x + zero_line_label_width + 18 + 8 + 10
    local layout_button_y = checkbox_y
    local layout_button_h = 20

    local layout_mode = self.state.settings.layout_mode or "vertical"
    local button_label = layout_mode == "vertical" and "⬍⬍" or "⬌⬌"  -- Vertical or Horizontal arrows
    local label_width = ImGui.CalcTextSize(ctx, button_label)
    local button_w = label_width + 16

    local mx, my = ImGui.GetMousePos(ctx)
    local is_hovered = mx >= layout_button_x and mx < layout_button_x + button_w and my >= layout_button_y and my < layout_button_y + layout_button_h

    -- Button background
    local bg_color = is_hovered and Colors.hexrgb("#2A2A2A") or Colors.hexrgb("#1A1A1A")
    bg_color = Colors.with_alpha(bg_color, math.floor(ui_fade * 200))
    ImGui.DrawList_AddRectFilled(draw_list, layout_button_x, layout_button_y, layout_button_x + button_w, layout_button_y + layout_button_h, bg_color, 3)

    -- Button border
    local border_color = Colors.hexrgb("#3A3A3A")
    border_color = Colors.with_alpha(border_color, math.floor(ui_fade * 255))
    ImGui.DrawList_AddRect(draw_list, layout_button_x, layout_button_y, layout_button_x + button_w, layout_button_y + layout_button_h, border_color, 3, 0, 1)

    -- Button text
    local text_color = Colors.hexrgb("#FFFFFF")
    text_color = Colors.with_alpha(text_color, math.floor(ui_fade * 255))
    ImGui.DrawList_AddText(draw_list, layout_button_x + 8, layout_button_y + 2, text_color, button_label)

    -- Click detection
    if is_hovered and ImGui.IsMouseClicked(ctx, 0) then
      local new_mode = layout_mode == "vertical" and "horizontal" or "vertical"
      self.state.set_setting('layout_mode', new_mode)
    end
  end

  ImGui.PopStyleVar(ctx)

  -- Track final checkbox Y position for search bar positioning
  local checkboxes_end_y = checkbox_y + 24 + 10  -- Add some spacing after checkboxes

  -- Search fade with different offset
  local search_fade = smootherstep(math.max(0, (overlay_alpha - 0.05) / 0.95))
  local search_y_offset = 25 * (1.0 - search_fade)

  -- Search input centered using rearkitekt widget (rounded to whole pixels)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, search_fade)
  ImGui.PushFont(ctx, title_font, 14)

  local search_x = math.floor(screen_w / 2 - (screen_w * self.config.LAYOUT.SEARCH_WIDTH_RATIO) / 2 + 0.5)
  local search_y = math.floor(checkboxes_end_y + search_y_offset + 0.5)
  local search_width = screen_w * self.config.LAYOUT.SEARCH_WIDTH_RATIO
  local search_height = 28  -- Increased by 4 pixels

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

  -- Calculate panel start position (below search bar)
  local panels_start_y = search_y + search_height + 20  -- 20px spacing below search
  local panels_end_y = screen_h - 40  -- Leave some bottom margin
  local content_height = panels_end_y - panels_start_y
  local content_width = screen_w - (self.config.LAYOUT.PADDING * 2)

  -- Get view mode
  local view_mode = self.state.get_view_mode()

  -- Calculate section heights based on view mode
  local start_x = self.config.LAYOUT.PADDING
  local start_y = panels_start_y
  local header_height = self.config.LAYOUT.HEADER_HEIGHT

  -- Panel right padding
  local panel_right_padding = 12

  local max = math.max
  local min = math.min

  if view_mode == "MIDI" then
    -- MIDI only - use full content height with panel
    local panel_padding = 4
    local panel_rounding = 6
    local panel_x1 = start_x
    local panel_y1 = start_y
    local panel_x2 = start_x + content_width - panel_right_padding
    local panel_y2 = start_y + header_height + content_height

    -- Draw panel background
    draw_panel(draw_list, panel_x1, panel_y1, panel_x2, panel_y2, panel_rounding, section_fade)

    -- MIDI header
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, section_fade)
    ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, start_y + panel_padding)
    ImGui.PushFont(ctx, title_font, 14)
    ImGui.Text(ctx, "MIDI Tracks")
    ImGui.PopFont(ctx)
    ImGui.PopStyleVar(ctx)

    -- MIDI grid
    local midi_content_y = start_y + header_height
    local midi_content_h = content_height - panel_padding
    local midi_grid_width = content_width - panel_right_padding - panel_padding * 2
    ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, midi_content_y)

    if ImGui.BeginChild(ctx, "midi_container", midi_grid_width, midi_content_h, 0,
      ImGui.WindowFlags_NoScrollbar) then
      self.coordinator:render_midi_grid(ctx, midi_grid_width, midi_content_h)
      ImGui.EndChild(ctx)
    end

  elseif view_mode == "AUDIO" then
    -- Audio only - use full content height with panel
    local panel_padding = 4
    local panel_rounding = 6
    local panel_x1 = start_x
    local panel_y1 = start_y
    local panel_x2 = start_x + content_width - panel_right_padding
    local panel_y2 = start_y + header_height + content_height

    -- Draw panel background
    draw_panel(draw_list, panel_x1, panel_y1, panel_x2, panel_y2, panel_rounding, section_fade)

    -- Audio header
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, section_fade)
    ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, start_y + panel_padding)
    ImGui.PushFont(ctx, title_font, 15)
    ImGui.Text(ctx, "Audio Sources")
    ImGui.PopFont(ctx)
    ImGui.PopStyleVar(ctx)

    -- Audio grid
    local audio_content_y = start_y + header_height
    local audio_content_h = content_height - panel_padding
    local audio_grid_width = content_width - panel_right_padding - panel_padding * 2
    ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, audio_content_y)

    if ImGui.BeginChild(ctx, "audio_container", audio_grid_width, audio_content_h, 0,
      ImGui.WindowFlags_NoScrollbar) then
      self.coordinator:render_audio_grid(ctx, audio_grid_width, audio_content_h)
      ImGui.EndChild(ctx)
    end

  else
    -- MIXED mode - check layout mode
    local layout_mode = self.state.settings.layout_mode or "vertical"

    if layout_mode == "horizontal" then
      -- HORIZONTAL LAYOUT: MIDI left, Audio right with vertical separator
      local sep_config = self.config.SEPARATOR
      local min_midi_width = 200  -- Minimum MIDI section width
      local min_audio_width = 300  -- Minimum Audio section width
      local separator_gap = sep_config.gap
      local min_total_width = min_midi_width + min_audio_width + separator_gap

      local midi_width, audio_width

      if content_width < min_total_width then
        -- Not enough space - scale proportionally
        local ratio = content_width / min_total_width
        midi_width = (min_midi_width * ratio)//1
        audio_width = content_width - midi_width - separator_gap

        if midi_width < 100 then midi_width = 100 end
        if audio_width < 150 then audio_width = 150 end

        audio_width = max(1, content_width - midi_width - separator_gap)
      else
        -- Use saved horizontal separator position
        midi_width = self.state.settings.separator_position_horizontal or 400
        midi_width = max(min_midi_width, min(midi_width, content_width - min_audio_width - separator_gap))
        audio_width = content_width - midi_width - separator_gap
      end

      midi_width = max(1, midi_width)
      audio_width = max(1, audio_width)

      -- Check if separator is being interacted with
      local sep_thickness = sep_config.thickness
      local sep_x = start_x + midi_width + separator_gap/2
      local mx, my = ImGui.GetMousePos(ctx)
      local over_sep = (my >= start_y and my < start_y + header_height + content_height and
                        mx >= sep_x - sep_thickness/2 and mx < sep_x + sep_thickness/2)
      local block_input = self.separator:is_dragging() or (over_sep and ImGui.IsMouseDown(ctx, 0))

      -- MIDI section (left)
      local panel_padding = 4
      local panel_rounding = 6
      local midi_panel_x1 = start_x
      local midi_panel_y1 = start_y
      local midi_panel_x2 = start_x + midi_width
      local midi_panel_y2 = start_y + header_height + content_height

      draw_panel(draw_list, midi_panel_x1, midi_panel_y1, midi_panel_x2, midi_panel_y2, panel_rounding, section_fade)

      ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, section_fade)
      ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, start_y + panel_padding)
      ImGui.PushFont(ctx, title_font, 14)
      ImGui.Text(ctx, "MIDI Tracks")
      ImGui.PopFont(ctx)
      ImGui.PopStyleVar(ctx)

      local midi_content_y = start_y + header_height
      local midi_content_h = content_height - panel_padding
      local midi_grid_width = midi_width - panel_padding * 2
      ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, midi_content_y)

      if ImGui.BeginChild(ctx, "midi_container", midi_grid_width, midi_content_h, 0,
        ImGui.WindowFlags_NoScrollbar) then
        if self.coordinator.midi_grid then
          self.coordinator.midi_grid.block_all_input = block_input
        end
        self.coordinator:render_midi_grid(ctx, midi_grid_width, midi_content_h)
        ImGui.EndChild(ctx)
      end

      -- Vertical separator
      local separator_x = sep_x
      local action, value = self.separator:draw_vertical(ctx, separator_x, start_y, content_height, content_width, sep_config)

      if action == "reset" then
        self.state.set_setting('separator_position_horizontal', 400)
      elseif action == "drag" and content_width >= min_total_width then
        local new_midi_width = value - start_x - separator_gap/2
        new_midi_width = max(min_midi_width, min(new_midi_width, content_width - min_audio_width - separator_gap))
        self.state.set_setting('separator_position_horizontal', new_midi_width)
      end

      -- Audio section (right)
      local audio_start_x = start_x + midi_width + separator_gap
      local audio_panel_x1 = audio_start_x
      local audio_panel_y1 = start_y
      local audio_panel_x2 = audio_start_x + audio_width
      local audio_panel_y2 = start_y + header_height + content_height

      draw_panel(draw_list, audio_panel_x1, audio_panel_y1, audio_panel_x2, audio_panel_y2, panel_rounding, section_fade)

      ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, section_fade)
      ImGui.SetCursorScreenPos(ctx, audio_start_x + panel_padding, start_y + panel_padding)
      ImGui.PushFont(ctx, title_font, 15)
      ImGui.Text(ctx, "Audio Sources")
      ImGui.PopFont(ctx)
      ImGui.PopStyleVar(ctx)

      local audio_content_y = start_y + header_height
      local audio_content_h = content_height - panel_padding
      local audio_grid_width = audio_width - panel_padding * 2
      ImGui.SetCursorScreenPos(ctx, audio_start_x + panel_padding, audio_content_y)

      if ImGui.BeginChild(ctx, "audio_container", audio_grid_width, audio_content_h, 0,
        ImGui.WindowFlags_NoScrollbar) then
        if self.coordinator.audio_grid then
          self.coordinator.audio_grid.block_all_input = block_input
        end
        self.coordinator:render_audio_grid(ctx, audio_grid_width, audio_content_h)
        ImGui.EndChild(ctx)
      end

    else
      -- VERTICAL LAYOUT: MIDI top, Audio bottom with horizontal separator (existing code)
      local sep_config = self.config.SEPARATOR
      local min_midi_height = sep_config.min_midi_height
      local min_audio_height = sep_config.min_audio_height
      local separator_gap = sep_config.gap
      local min_total_height = min_midi_height + min_audio_height + separator_gap

    local midi_height, audio_height

    if content_height < min_total_height then
      -- Not enough space - scale proportionally
      local ratio = content_height / min_total_height
      midi_height = (min_midi_height * ratio)//1
      audio_height = content_height - midi_height - separator_gap

      if midi_height < 50 then midi_height = 50 end
      if audio_height < 50 then audio_height = 50 end

      audio_height = max(1, content_height - midi_height - separator_gap)
    else
      -- Use saved separator position
      midi_height = self.state.get_separator_position()
      midi_height = max(min_midi_height, min(midi_height, content_height - min_audio_height - separator_gap))
      audio_height = content_height - midi_height - separator_gap
    end

    midi_height = max(1, midi_height)
    audio_height = max(1, audio_height)

    -- Check if separator is being interacted with
    local sep_thickness = sep_config.thickness
    local sep_y = start_y + header_height + midi_height + separator_gap/2
    local mx, my = ImGui.GetMousePos(ctx)
    local over_sep = (mx >= start_x and mx < start_x + content_width and
                      my >= sep_y - sep_thickness/2 and my < sep_y + sep_thickness/2)
    local block_input = self.separator:is_dragging() or (over_sep and ImGui.IsMouseDown(ctx, 0))

    -- MIDI section with panel
    local panel_padding = 4
    local panel_rounding = 6
    local midi_panel_x1 = start_x
    local midi_panel_y1 = start_y
    local midi_panel_x2 = start_x + content_width - panel_right_padding
    local midi_panel_y2 = start_y + header_height + midi_height

    -- Draw MIDI panel background
    draw_panel(draw_list, midi_panel_x1, midi_panel_y1, midi_panel_x2, midi_panel_y2, panel_rounding, section_fade)

    -- MIDI header
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, section_fade)
    ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, start_y + panel_padding)
    ImGui.PushFont(ctx, title_font, 14)
    ImGui.Text(ctx, "MIDI Tracks")
    ImGui.PopFont(ctx)
    ImGui.PopStyleVar(ctx)

    -- MIDI grid container
    local midi_content_y = start_y + header_height
    local midi_content_h = midi_height - panel_padding
    local midi_grid_width = content_width - panel_right_padding - panel_padding * 2
    ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, midi_content_y)

    if ImGui.BeginChild(ctx, "midi_container", midi_grid_width, midi_content_h, 0,
      ImGui.WindowFlags_NoScrollbar) then
      -- Block grid input during separator drag
      if self.coordinator.midi_grid then
        self.coordinator.midi_grid.block_all_input = block_input
      end
      self.coordinator:render_midi_grid(ctx, midi_grid_width, midi_content_h)
      ImGui.EndChild(ctx)
    end

    -- Draggable separator
    local separator_y = sep_y
    local action, value = self.separator:draw_horizontal(ctx, start_x, separator_y, content_width, content_height, sep_config)

    if action == "reset" then
      self.state.set_separator_position(sep_config.default_midi_height)
    elseif action == "drag" and content_height >= min_total_height then
      local new_midi_height = value - start_y - header_height - separator_gap/2
      new_midi_height = max(min_midi_height, min(new_midi_height, content_height - min_audio_height - separator_gap))
      self.state.set_separator_position(new_midi_height)
    end

    -- Audio section with panel
    local audio_start_y = start_y + header_height + midi_height + separator_gap
    local audio_panel_x1 = start_x
    local audio_panel_y1 = audio_start_y
    local audio_panel_x2 = start_x + content_width - panel_right_padding
    local audio_panel_y2 = audio_start_y + header_height + audio_height

    -- Draw Audio panel background
    draw_panel(draw_list, audio_panel_x1, audio_panel_y1, audio_panel_x2, audio_panel_y2, panel_rounding, section_fade)

    -- Audio header
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, section_fade)
    ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, audio_start_y + panel_padding)
    ImGui.PushFont(ctx, title_font, 15)
    ImGui.Text(ctx, "Audio Sources")
    ImGui.PopFont(ctx)
    ImGui.PopStyleVar(ctx)

    -- Audio grid container
    local audio_content_y = audio_start_y + header_height
    local audio_content_h = audio_height - panel_padding
    local audio_grid_width = content_width - panel_right_padding - panel_padding * 2
    ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, audio_content_y)

    if ImGui.BeginChild(ctx, "audio_container", audio_grid_width, audio_content_h, 0,
      ImGui.WindowFlags_NoScrollbar) then
      -- Block grid input during separator drag
      if self.coordinator.audio_grid then
        self.coordinator.audio_grid.block_all_input = block_input
      end
      self.coordinator:render_audio_grid(ctx, audio_grid_width, audio_content_h)
      ImGui.EndChild(ctx)
    end

      -- Unblock input after separator interaction
      if not self.separator:is_dragging() and not (over_sep and ImGui.IsMouseDown(ctx, 0)) then
        if self.coordinator.midi_grid then
          self.coordinator.midi_grid.block_all_input = false
        end
        if self.coordinator.audio_grid then
          self.coordinator.audio_grid.block_all_input = false
        end
      end
    end  -- end of vertical layout
  end  -- end of MIXED mode (view_mode else)

  -- Only end window if we created one (not in overlay mode)
  if not is_overlay_mode then
    ImGui.End(ctx)
  end
end

return M
