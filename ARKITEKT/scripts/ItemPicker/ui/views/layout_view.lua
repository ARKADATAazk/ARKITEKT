-- @noindex
-- ItemPicker/ui/views/layout_view.lua
-- Main layout view with absolute positioning and fade animations

local ImGui = require 'imgui' '0.10'
local SearchInput = require('rearkitekt.gui.widgets.inputs.search_input')
local Checkbox = require('rearkitekt.gui.widgets.primitives.checkbox')
local DraggableSeparator = require('rearkitekt.gui.widgets.primitives.separator')
local StatusBar = require('ItemPicker.ui.views.status_bar')

-- Debug module - with error handling
local Debug = nil
local debug_ok, debug_module = pcall(require, 'ItemPicker.debug_log')
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

  -- Render checkboxes with fade animation and 14px padding
  -- Note: We pass alpha as config param instead of using PushStyleVar to keep interaction working
  local checkbox_x = 14
  local checkbox_y = 14 + ui_y_offset
  local checkbox_config = { alpha = ui_fade }

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

  checkbox_y = checkbox_y + 24
  _, clicked = Checkbox.draw(ctx, draw_list, checkbox_x, checkbox_y,
    "Show Muted Tracks",
    self.state.settings.show_muted_tracks, checkbox_config, "show_muted_tracks")
  if clicked then
    self.state.set_setting('show_muted_tracks', not self.state.settings.show_muted_tracks)
  end

  checkbox_y = checkbox_y + 24
  _, clicked = Checkbox.draw(ctx, draw_list, checkbox_x, checkbox_y,
    "Show Muted Items",
    self.state.settings.show_muted_items, checkbox_config, "show_muted_items")
  if clicked then
    self.state.set_setting('show_muted_items', not self.state.settings.show_muted_items)
  end

  -- Show Disabled Items on same line (after Show Muted Items)
  local muted_items_width = ImGui.CalcTextSize(ctx, "Show Muted Items") + 18 + 8 + 20  -- checkbox + spacing + margin
  local disabled_x = checkbox_x + muted_items_width
  _, clicked = Checkbox.draw(ctx, draw_list, disabled_x, checkbox_y,
    "Show Disabled Items",
    self.state.settings.show_disabled_items, checkbox_config, "show_disabled_items")
  if clicked then
    self.state.set_setting('show_disabled_items', not self.state.settings.show_disabled_items)
  end

  -- Show Favorites Only checkbox (new line)
  checkbox_y = checkbox_y + 24
  _, clicked = Checkbox.draw(ctx, draw_list, checkbox_x, checkbox_y,
    "Show Favorites Only",
    self.state.settings.show_favorites_only, checkbox_config, "show_favorites_only")
  if clicked then
    self.state.set_setting('show_favorites_only', not self.state.settings.show_favorites_only)
  end

  -- Show Audio checkbox (new line)
  checkbox_y = checkbox_y + 24
  _, clicked = Checkbox.draw(ctx, draw_list, checkbox_x, checkbox_y,
    "Show Audio",
    self.state.settings.show_audio, checkbox_config, "show_audio")
  if clicked then
    self.state.set_setting('show_audio', not self.state.settings.show_audio)
  end

  -- Show MIDI on same line
  local show_audio_width = ImGui.CalcTextSize(ctx, "Show Audio") + 18 + 8 + 20  -- checkbox + spacing + margin
  local show_midi_x = checkbox_x + show_audio_width
  _, clicked = Checkbox.draw(ctx, draw_list, show_midi_x, checkbox_y,
    "Show MIDI",
    self.state.settings.show_midi, checkbox_config, "show_midi")
  if clicked then
    self.state.set_setting('show_midi', not self.state.settings.show_midi)
  end

  -- Split MIDI Items checkbox (new line)
  checkbox_y = checkbox_y + 24
  _, clicked = Checkbox.draw(ctx, draw_list, checkbox_x, checkbox_y,
    "Split MIDI Items by Track",
    self.state.settings.split_midi_by_track, checkbox_config, "split_midi_by_track")
  if clicked then
    self.state.set_setting('split_midi_by_track', not self.state.settings.split_midi_by_track)
    -- Recollect items when this setting changes
    self.state.needs_recollect = true
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
  local content_height = screen_h * self.config.LAYOUT.CONTENT_HEIGHT
  local content_width = screen_w - (self.config.LAYOUT.PADDING * 2)

  -- Get view mode
  local view_mode = self.state.get_view_mode()

  -- Calculate section heights based on view mode
  local start_x = self.config.LAYOUT.PADDING
  local start_y = content_start_y
  local header_height = self.config.LAYOUT.HEADER_HEIGHT

  local max = math.max
  local min = math.min

  if view_mode == "MIDI" then
    -- MIDI only - use full content height
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, section_fade)
    ImGui.SetCursorScreenPos(ctx, start_x, start_y)
    ImGui.PushFont(ctx, title_font, 14)
    ImGui.Text(ctx, "MIDI Tracks")
    ImGui.PopFont(ctx)
    ImGui.PopStyleVar(ctx)

    local midi_height = content_height
    ImGui.SetCursorScreenPos(ctx, start_x, start_y + header_height)

    if ImGui.BeginChild(ctx, "midi_container", content_width, midi_height, 0,
      ImGui.WindowFlags_NoScrollbar) then
      self.coordinator:render_midi_grid(ctx, content_width, midi_height)
      ImGui.EndChild(ctx)
    end

  elseif view_mode == "AUDIO" then
    -- Audio only - use full content height
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, section_fade)
    ImGui.SetCursorScreenPos(ctx, start_x, start_y)
    ImGui.PushFont(ctx, title_font, 15)
    ImGui.Text(ctx, "Audio Sources")
    ImGui.PopFont(ctx)
    ImGui.PopStyleVar(ctx)

    local audio_height = content_height
    ImGui.SetCursorScreenPos(ctx, start_x, start_y + header_height)

    if ImGui.BeginChild(ctx, "audio_container", content_width, audio_height, 0,
      ImGui.WindowFlags_NoScrollbar) then
      self.coordinator:render_audio_grid(ctx, content_width, audio_height)
      ImGui.EndChild(ctx)
    end

  else
    -- MIXED mode - use draggable separator
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

    -- MIDI section
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, section_fade)
    ImGui.SetCursorScreenPos(ctx, start_x, start_y)
    ImGui.PushFont(ctx, title_font, 14)
    ImGui.Text(ctx, "MIDI Tracks")
    ImGui.PopFont(ctx)
    ImGui.PopStyleVar(ctx)

    ImGui.SetCursorScreenPos(ctx, start_x, start_y + header_height)

    if ImGui.BeginChild(ctx, "midi_container", content_width, midi_height, 0,
      ImGui.WindowFlags_NoScrollbar) then
      -- Block grid input during separator drag
      if self.coordinator.midi_grid then
        self.coordinator.midi_grid.block_all_input = block_input
      end
      self.coordinator:render_midi_grid(ctx, content_width, midi_height)
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

    -- Audio section
    local audio_start_y = start_y + header_height + midi_height + separator_gap

    ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, section_fade)
    ImGui.SetCursorScreenPos(ctx, start_x, audio_start_y)
    ImGui.PushFont(ctx, title_font, 15)
    ImGui.Text(ctx, "Audio Sources")
    ImGui.PopFont(ctx)
    ImGui.PopStyleVar(ctx)

    ImGui.SetCursorScreenPos(ctx, start_x, audio_start_y + header_height)

    if ImGui.BeginChild(ctx, "audio_container", content_width, audio_height, 0,
      ImGui.WindowFlags_NoScrollbar) then
      -- Block grid input during separator drag
      if self.coordinator.audio_grid then
        self.coordinator.audio_grid.block_all_input = block_input
      end
      self.coordinator:render_audio_grid(ctx, content_width, audio_height)
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
  end

  -- Only end window if we created one (not in overlay mode)
  if not is_overlay_mode then
    ImGui.End(ctx)
  end
end

return M
