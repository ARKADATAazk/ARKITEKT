-- @noindex
-- ItemPicker/ui/views/layout_view.lua
-- Main layout view with absolute positioning and fade animations

local ImGui = require 'imgui' '0.10'
local SearchWithMode = require('ItemPicker.ui.components.search_with_mode')
local Checkbox = require('arkitekt.gui.widgets.primitives.checkbox')
local Button = require('arkitekt.gui.widgets.primitives.button')
local DraggableSeparator = require('arkitekt.gui.widgets.primitives.separator')
local StatusBar = require('ItemPicker.ui.components.status_bar')
local RegionFilterBar = require('ItemPicker.ui.components.region_filter_bar')
local TrackFilter = require('ItemPicker.ui.components.track_filter')
local TrackFilterBar = require('ItemPicker.ui.components.track_filter_bar')
local Colors = require('arkitekt.core.colors')
local Background = require('arkitekt.gui.widgets.containers.panel.background')

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

-- Draw a panel background and border (no dotted pattern - moved to overlay)
local function draw_panel(dl, x1, y1, x2, y2, rounding, alpha)
  alpha = alpha or 1.0
  rounding = rounding or 6

  -- Panel background (lighter)
  local bg_color = Colors.hexrgb("#1A1A1A")
  bg_color = Colors.with_alpha(bg_color, math.floor(alpha * 0x99))  -- 60% opacity
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, rounding)

  -- Panel border (even lighter)
  local border_color = Colors.hexrgb("#2A2A2A")
  border_color = Colors.with_alpha(border_color, math.floor(alpha * 0xAA))
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, rounding, 0, 1)
end

-- Draw a centered panel title (using DrawList to not block mouse input)
local function draw_panel_title(ctx, draw_list, title_font, title, panel_x, panel_y, panel_width, padding, alpha, font_size, config, scroll_y)
  ImGui.PushFont(ctx, title_font, font_size)
  local title_width = ImGui.CalcTextSize(ctx, title)
  local title_x = panel_x + (panel_width - title_width) / 2
  local title_y = panel_y + padding + config.UI_PANELS.header.title_offset_down

  -- Calculate fade based on scroll position
  local final_alpha = alpha
  if config.UI_PANELS.header.fade_on_scroll and scroll_y then
    local threshold = config.UI_PANELS.header.fade_scroll_threshold
    local distance = config.UI_PANELS.header.fade_scroll_distance
    if scroll_y > threshold then
      local fade_progress = math.min(1.0, (scroll_y - threshold) / distance)
      final_alpha = alpha * (1.0 - fade_progress)
    end
  end

  -- Use DrawList to avoid blocking mouse input for selection rectangle
  local text_color = Colors.hexrgb("#FFFFFF")
  text_color = Colors.with_alpha(text_color, math.floor(final_alpha * 255))
  ImGui.DrawList_AddText(draw_list, title_x, title_y, text_color, title)
  ImGui.PopFont(ctx)
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
      self.state.set_search_filter("")
    end
  end
end

function LayoutView:render(ctx, title_font, title_font_size, title, screen_w, screen_h, is_overlay_mode)
  self:handle_shortcuts(ctx)

  -- Initialize all_regions if region processing is enabled but all_regions is empty
  if (self.state.settings.enable_region_processing or self.state.settings.show_region_tags) and (not self.state.all_regions or #self.state.all_regions == 0) then
    self.state.all_regions = require('ItemPicker.data.reaper_api').GetAllProjectRegions()
    reaper.ShowConsoleMsg(string.format("[REGION_TAGS] Initialized all_regions: %d regions found\n", #self.state.all_regions))
  end

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

  -- Get window position for coordinate offset (critical for multi-monitor support)
  -- When overlay is on a secondary monitor, we need to offset all coordinates
  local window_x, window_y = ImGui.GetWindowPos(ctx)
  local coord_offset_x = window_x
  local coord_offset_y = window_y

  -- Dotted pattern over entire overlay (no background fill - uses shell overlay scrim)
  -- Using baked texture for performance (single draw call vs 8000+ circles)
  local overlay_pattern_config = {
    enabled = true,
    use_texture = true,  -- Use baked texture for performance
    primary = {
      type = 'dots',
      spacing = 16,
      dot_size = 1.5,
      color = Colors.with_alpha(Colors.hexrgb("#2A2A2A"), math.floor(overlay_alpha * 180)),
      offset_x = 0,
      offset_y = 0,
    }
  }
  Background.draw(ctx, draw_list, coord_offset_x, coord_offset_y,
      coord_offset_x + screen_w, coord_offset_y + screen_h, overlay_pattern_config)

  -- Mouse-based hover detection for responsive UI (slide/push behavior)
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)

  -- Check if mouse is within window bounds (fixes multi-monitor cursor detection issues)
  local mouse_in_window = mouse_x >= coord_offset_x and mouse_x < coord_offset_x + screen_w and
                          mouse_y >= coord_offset_y and mouse_y < coord_offset_y + screen_h

  -- Search fade with different offset (always visible)
  local search_fade = smootherstep(math.max(0, (overlay_alpha - 0.05) / 0.95))
  local search_y_offset = 25 * (1.0 - search_fade)

  -- Base position for search (before settings push it down)
  local search_top_padding = self.config.UI_PANELS.search.top_padding
  local search_base_y = coord_offset_y + 14 + ui_y_offset + search_y_offset + search_top_padding
  local search_height = 28
  local button_height = search_height
  local button_gap = 4  -- Gap between buttons and search

  -- Settings area ABOVE search (slides down with search)
  local settings_area_max_height = self.config.UI_PANELS.settings.max_height

  -- Calculate slide progress first
  if not self.state.settings_slide_progress then
    self.state.settings_slide_progress = 0
  end

  -- Sticky hover behavior: trigger zone above actual search position
  local trigger_zone_padding = self.config.UI_PANELS.settings.trigger_above_search

  -- Calculate current search position for hover detection
  local temp_settings_height = settings_area_max_height * self.state.settings_slide_progress
  local temp_search_y = search_base_y + temp_settings_height

  -- Trigger when mouse is ANYWHERE above the current search position (not just a thin band)
  -- This makes it consistent with filter behavior and works better with fast cursor movement
  -- Only trigger if mouse is within window bounds (fixes multi-monitor cursor detection)
  local is_in_trigger_zone = mouse_in_window and mouse_y < (temp_search_y - trigger_zone_padding)

  -- Detect fast mouse crossing through top of window (helps with fast cursor movement)
  -- If mouse was in window last frame but is now above the window top, trigger the panel
  local crossed_through_top = false
  if self.state.last_mouse_in_window and not mouse_in_window and mouse_y < coord_offset_y then
    -- Mouse was inside, now outside above the top - it crossed through the trigger zone
    crossed_through_top = true
  end
  self.state.last_mouse_in_window = mouse_in_window

  -- Combined trigger: either currently in zone OR crossed through top
  is_in_trigger_zone = is_in_trigger_zone or crossed_through_top

  -- Once triggered, stay visible until mouse goes below the search field (with buffer)
  local is_below_search = mouse_in_window and mouse_y > (temp_search_y + search_height + self.config.UI_PANELS.settings.close_below_search)

  -- Initialize sticky state
  if self.state.settings_sticky_visible == nil then
    self.state.settings_sticky_visible = false
  end

  -- Update sticky state with delay only for mouse leaving window (helps with multi-monitor overshoot)
  local close_delay = 1.5  -- seconds before closing when mouse leaves window
  if is_in_trigger_zone then
    self.state.settings_sticky_visible = true
    self.state.settings_close_timer = nil  -- Cancel any pending close
  elseif is_below_search then
    -- Mouse went below search within window - close immediately
    self.state.settings_sticky_visible = false
    self.state.settings_close_timer = nil
  elseif not mouse_in_window then
    -- Mouse left window (e.g., overshoot to another monitor) - use delay
    if self.state.settings_sticky_visible then
      if not self.state.settings_close_timer then
        self.state.settings_close_timer = reaper.time_precise()
      elseif reaper.time_precise() - self.state.settings_close_timer >= close_delay then
        self.state.settings_sticky_visible = false
        self.state.settings_close_timer = nil
      end
    end
  else
    -- Mouse is in window but between trigger zone and close zone - cancel timer
    self.state.settings_close_timer = nil
  end

  -- Smooth slide for settings area
  local target_slide = self.state.settings_sticky_visible and 1.0 or 0.0
  local slide_speed = self.config.UI_PANELS.settings.slide_speed
  self.state.settings_slide_progress = self.state.settings_slide_progress + (target_slide - self.state.settings_slide_progress) * slide_speed

  -- Calculate settings height and alpha
  local settings_height = settings_area_max_height * self.state.settings_slide_progress
  local settings_alpha = self.state.settings_slide_progress * ui_fade

  -- Settings panel slides down from above (starts off-screen)
  local settings_y = search_base_y - settings_area_max_height + settings_height

  -- Search position (pushed down by settings)
  local search_y = search_base_y + settings_height

  -- Render settings panel ABOVE search (only if visible)
  if settings_height > 1 then
    -- Render checkboxes with slide animation and 14px padding (organized in 2 lines)
    local checkbox_x = coord_offset_x + 14
    local checkbox_y = settings_y
    local checkbox_config = { alpha = settings_alpha }
    local spacing = 20  -- Horizontal spacing between checkboxes

    -- Line 1: Play Item Through Track | Show Muted Tracks | Show Muted Items | Show Disabled Items
    local total_width, clicked = Checkbox.draw(ctx, draw_list, checkbox_x, checkbox_y,
      "Play Item Through Track (will add delay to preview playback)",
      self.state.settings.play_item_through_track, checkbox_config, "play_item_through_track")
    if clicked then
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

    -- Line 2: Show Favorites Only | Show Audio | Show MIDI | Group Items | Tile FX | Show Viz | Enable Regions | Show on Tiles
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

    -- Enable Region Processing checkbox on same line
    prev_width = prev_width + ImGui.CalcTextSize(ctx, "Show Viz in Small Tiles") + 18 + 8 + spacing
    local enable_regions_x = checkbox_x + prev_width
    local enable_regions = self.state.settings.enable_region_processing
    if enable_regions == nil then enable_regions = false end
    _, clicked = Checkbox.draw(ctx, draw_list, enable_regions_x, checkbox_y,
      "Enable Regions",
      enable_regions, checkbox_config, "enable_regions")
    if clicked then
      self.state.set_setting('enable_region_processing', not enable_regions)
      if not enable_regions then
        self.state.all_regions = require('ItemPicker.data.reaper_api').GetAllProjectRegions()
      else
        self.state.all_regions = {}
        self.state.selected_regions = {}
      end
      self.state.needs_recollect = true
    end

    -- Show Region Tags checkbox on same line (only affects display on tiles)
    prev_width = prev_width + ImGui.CalcTextSize(ctx, "Enable Regions") + 18 + 8 + spacing
    local show_region_tags_x = checkbox_x + prev_width
    local show_region_tags = self.state.settings.show_region_tags
    if show_region_tags == nil then show_region_tags = false end
    _, clicked = Checkbox.draw(ctx, draw_list, show_region_tags_x, checkbox_y,
      "Show on Tiles",
      show_region_tags, checkbox_config, "show_region_tags")
    if clicked then
      self.state.set_setting('show_region_tags', not show_region_tags)
    end

    -- Waveform Quality slider on line 3
    checkbox_y = checkbox_y + 24
    local waveform_x = checkbox_x
    local waveform_y = checkbox_y

    ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, settings_alpha)

    local slider_label = "Waveform Quality:"
    local slider_label_width = ImGui.CalcTextSize(ctx, slider_label)
    ImGui.DrawList_AddText(draw_list, waveform_x, waveform_y + 3, Colors.with_alpha(Colors.hexrgb("#FFFFFF"), math.floor(settings_alpha * 180)), slider_label)

    -- Draw slider
    local slider_width = 120
    local track_x = waveform_x + slider_label_width + 8
    local track_y = waveform_y + 7
    local track_h = 6
    local track_rounding = 3

    local track_color = Colors.with_alpha(Colors.hexrgb("#1A1A1A"), math.floor(settings_alpha * 200))
    ImGui.DrawList_AddRectFilled(draw_list, track_x, track_y, track_x + slider_width, track_y + track_h, track_color, track_rounding)

    local quality = self.state.settings.waveform_quality or 1.0
    local fill_width = slider_width * quality
    local fill_color = Colors.with_alpha(Colors.hexrgb("#4A9EFF"), math.floor(settings_alpha * 200))
    if fill_width > 1 then
      ImGui.DrawList_AddRectFilled(draw_list, track_x, track_y, track_x + fill_width, track_y + track_h, fill_color, track_rounding)
    end

    -- Slider thumb
    local thumb_x = track_x + fill_width
    local thumb_y = track_y + track_h / 2
    local thumb_radius = 6
    local is_thumb_hovered = (mouse_x - thumb_x) * (mouse_x - thumb_x) + (mouse_y - thumb_y) * (mouse_y - thumb_y) <= thumb_radius * thumb_radius

    local thumb_color = is_thumb_hovered and Colors.hexrgb("#5AAFFF") or Colors.hexrgb("#4A9EFF")
    thumb_color = Colors.with_alpha(thumb_color, math.floor(settings_alpha * 255))
    ImGui.DrawList_AddCircleFilled(draw_list, thumb_x, thumb_y, thumb_radius, thumb_color)

    -- Slider interaction
    local is_slider_hovered = mouse_x >= track_x and mouse_x < track_x + slider_width and mouse_y >= track_y - 4 and mouse_y < track_y + track_h + 4
    if is_slider_hovered and ImGui.IsMouseDown(ctx, 0) then
      local new_quality = math.max(0.1, math.min(1.0, (mouse_x - track_x) / slider_width))
      self.state.set_setting('waveform_quality', new_quality)
      if self.state.runtime_cache and self.state.runtime_cache.waveforms then
        self.state.runtime_cache.waveforms = {}
      end
    end

    -- Percentage value
    local percent_text = string.format("%d%%", math.floor(quality * 100))
    local percent_x = track_x + slider_width + 8
    ImGui.DrawList_AddText(draw_list, percent_x, waveform_y + 3, Colors.with_alpha(Colors.hexrgb("#AAAAAA"), math.floor(settings_alpha * 180)), percent_text)

    -- Waveform Fill checkbox
    local fill_checkbox_x = percent_x + ImGui.CalcTextSize(ctx, percent_text) + 20
    local waveform_filled = self.state.settings.waveform_filled
    if waveform_filled == nil then waveform_filled = true end

    local _, fill_clicked = Checkbox.draw(ctx, draw_list, fill_checkbox_x, waveform_y,
      "Fill",
      waveform_filled, checkbox_config, "waveform_filled")
    if fill_clicked then
      self.state.set_setting('waveform_filled', not waveform_filled)
      if self.state.runtime_cache and self.state.runtime_cache.waveform_polylines then
        self.state.runtime_cache.waveform_polylines = {}
      end
    end

    -- Zero Line checkbox
    local fill_label_width = ImGui.CalcTextSize(ctx, "Fill")
    local zero_line_checkbox_x = fill_checkbox_x + fill_label_width + 18 + 8
    local waveform_zero_line = self.state.settings.waveform_zero_line or false

    local _, zero_line_clicked = Checkbox.draw(ctx, draw_list, zero_line_checkbox_x, waveform_y,
      "Zero Line",
      waveform_zero_line, checkbox_config, "waveform_zero_line")
    if zero_line_clicked then
      self.state.set_setting('waveform_zero_line', not waveform_zero_line)
    end

    -- Show Duration checkbox
    local zero_line_label_width = ImGui.CalcTextSize(ctx, "Zero Line")
    local show_duration_checkbox_x = zero_line_checkbox_x + zero_line_label_width + 18 + 8
    local show_duration = self.state.settings.show_duration
    if show_duration == nil then show_duration = true end

    local _, show_duration_clicked = Checkbox.draw(ctx, draw_list, show_duration_checkbox_x, waveform_y,
      "Show Duration",
      show_duration, checkbox_config, "show_duration")
    if show_duration_clicked then
      self.state.set_setting('show_duration', not show_duration)
    end

    ImGui.PopStyleVar(ctx)
  end

  -- Calculate sort buttons dimensions first
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, search_fade)
  ImGui.PushFont(ctx, title_font, 14)

  local sort_modes = {
    {id = "none", label = "None"},
    {id = "length", label = "Length"},
    {id = "color", label = "Color"},
    {id = "name", label = "Name"},
    {id = "pool", label = "Pool"},
  }

  local current_sort = self.state.settings.sort_mode or "none"
  local sort_button_widths = {}
  local total_sort_width = 0

  for i, mode in ipairs(sort_modes) do
    local label_width = ImGui.CalcTextSize(ctx, mode.label)
    local button_w = label_width + 16
    sort_button_widths[i] = button_w
    total_sort_width = total_sort_width + button_w
    if i < #sort_modes then
      total_sort_width = total_sort_width + button_gap
    end
  end

  -- Content filter button (replaces Show Audio/MIDI checkboxes)
  local content_button_width = 65
  local content_filter_mode = "MIXED"  -- Default
  if self.state.settings.show_audio and not self.state.settings.show_midi then
    content_filter_mode = "AUDIO"
  elseif self.state.settings.show_midi and not self.state.settings.show_audio then
    content_filter_mode = "MIDI"
  end

  -- Layout toggle button (always visible)
  local layout_button_width = button_height  -- Square button (same as height)

  -- Track filter button (square)
  local track_button_width = button_height

  -- Calculate search width and center it
  local search_width = screen_w * self.config.LAYOUT.SEARCH_WIDTH_RATIO
  local search_x = coord_offset_x + math.floor((screen_w - search_width) / 2)

  -- Position buttons left of search: [Track] [Content] [Layout] [Search]
  local buttons_left_x = search_x
  local current_x = buttons_left_x

  -- Track filter button (leftmost)
  current_x = current_x - track_button_width - button_gap
  local track_filter_x = current_x
  local track_filter_active = self.state.show_track_filter or false

  -- Draw track filter icon (3 horizontal lines representing tracks)
  local draw_track_icon = function(btn_draw_list, icon_x, icon_y)
    local icon_w = 12
    local icon_h = 10
    local line_h = 2
    local line_gap = 2

    for i = 0, 2 do
      local line_y = icon_y + i * (line_h + line_gap)
      local line_w = icon_w - i * 2  -- Progressively shorter lines
      ImGui.DrawList_AddRectFilled(btn_draw_list,
        icon_x, line_y,
        icon_x + line_w, line_y + line_h,
        Colors.hexrgb("#AAAAAA"), 1)
    end
  end

  Button.draw(ctx, draw_list, current_x, search_y, track_button_width, button_height, {
    label = "",
    is_toggled = track_filter_active,
    preset_name = "BUTTON_TOGGLE_WHITE",
    tooltip = "Track Filter",
    ignore_modal = true,
    on_click = function()
      -- Set flag to open track filter modal (main_window will handle it)
      self.state.open_track_filter_modal = true
    end,
  }, "track_filter_button")

  -- Draw track icon on top of button
  local track_icon_x = (current_x + (track_button_width - 12) / 2 + 0.5)//1
  local track_icon_y = (search_y + (button_height - 10) / 2 + 0.5)//1
  draw_track_icon(draw_list, track_icon_x, track_icon_y)

  -- Content filter button
  current_x = current_x - content_button_width - button_gap
  Button.draw(ctx, draw_list, current_x, search_y, content_button_width, button_height, {
    label = content_filter_mode,
    is_toggled = content_filter_mode == "MIXED",  -- Toggled when showing MIXED
    preset_name = "BUTTON_TOGGLE_WHITE",
    tooltip = "Left: Toggle MIDI/AUDIO | Right: Show both",
    ignore_modal = true,  -- Bypass overlay blocking
    on_click = function()
      -- Left click: toggle between MIDI and AUDIO
      if content_filter_mode == "MIDI" then
        self.state.set_setting('show_audio', true)
        self.state.set_setting('show_midi', false)
      else  -- AUDIO or MIXED
        self.state.set_setting('show_audio', false)
        self.state.set_setting('show_midi', true)
      end
    end,
    on_right_click = function()
      -- Right click: set to MIXED (both)
      self.state.set_setting('show_audio', true)
      self.state.set_setting('show_midi', true)
    end,
  }, "content_filter_button")

  -- Layout toggle button (always visible, enables MIXED mode if needed)
  current_x = current_x - layout_button_width - button_gap
  local layout_mode = self.state.settings.layout_mode or "vertical"
  local is_vertical = layout_mode == "vertical"
  local is_mixed_mode = content_filter_mode == "MIXED"

  -- Draw layout icon using rectangles (no text, pure shapes)
  -- We'll draw it directly on the button using a custom render function
  local icon_color = Colors.hexrgb("#AAAAAA")
  local draw_layout_icon = function(btn_draw_list, icon_x, icon_y)
    local icon_size = 14
    local gap = 2
    local top_bar_h = 2  -- Top bar representing search/settings
    local top_padding = 2  -- Padding between top bar and panels

    -- Draw top bar (represents search bar/top panel)
    ImGui.DrawList_AddRectFilled(btn_draw_list, icon_x, icon_y, icon_x + icon_size, icon_y + top_bar_h, icon_color, 0)

    -- Calculate remaining height for panels (reduced by top bar + padding)
    local panels_start_y = icon_y + top_bar_h + top_padding
    local panels_height = icon_size - top_bar_h - top_padding

    if is_vertical then
      -- Vertical mode: 2 rectangles stacked (top and bottom)
      local rect_h = (panels_height - gap) / 2
      -- Draw filled rectangles
      ImGui.DrawList_AddRectFilled(btn_draw_list, icon_x, panels_start_y, icon_x + icon_size, panels_start_y + rect_h, icon_color, 0)
      ImGui.DrawList_AddRectFilled(btn_draw_list, icon_x, panels_start_y + rect_h + gap, icon_x + icon_size, icon_y + icon_size, icon_color, 0)
    else
      -- Horizontal mode: 2 rectangles side by side (left and right)
      local rect_w = (icon_size - gap) / 2
      -- Draw filled rectangles
      ImGui.DrawList_AddRectFilled(btn_draw_list, icon_x, panels_start_y, icon_x + rect_w, icon_y + icon_size, icon_color, 0)
      ImGui.DrawList_AddRectFilled(btn_draw_list, icon_x + rect_w + gap, panels_start_y, icon_x + icon_size, icon_y + icon_size, icon_color, 0)
    end
  end

  -- Draw button first
  Button.draw(ctx, draw_list, current_x, search_y, layout_button_width, button_height, {
    label = "",  -- No text, icon is drawn manually
    is_toggled = is_mixed_mode,  -- Toggled whenever in MIXED mode
    preset_name = "BUTTON_TOGGLE_WHITE",
    tooltip = not is_mixed_mode and "Enable Split View (MIXED mode)" or
              (is_vertical and "Switch to Horizontal Layout" or "Switch to Vertical Layout"),
    ignore_modal = true,  -- Bypass overlay blocking
    on_click = function()
      if not is_mixed_mode then
        -- Enable MIXED mode (both AUDIO and MIDI)
        self.state.set_setting('show_audio', true)
        self.state.set_setting('show_midi', true)
      else
        -- Toggle layout mode
        local new_mode = layout_mode == "vertical" and "horizontal" or "vertical"
        self.state.set_setting('layout_mode', new_mode)
      end
    end,
  }, "layout_toggle_button")

  -- Calculate center position for icon and draw it on top of button
  local icon_x = (current_x + (layout_button_width - 14) / 2 + 0.5)//1
  local icon_y = (search_y + (button_height - 14) / 2 + 0.5)//1
  draw_layout_icon(draw_list, icon_x, icon_y)

  -- Add "Sorting:" label before sort buttons
  local sort_x = search_x + search_width + button_gap
  local sort_label = "Sorting:"
  local sort_label_width = ImGui.CalcTextSize(ctx, sort_label)
  local sort_label_color = Colors.hexrgb("#AAAAAA")
  sort_label_color = Colors.with_alpha(sort_label_color, math.floor(search_fade * 200))
  -- Note: Raw text vertical alignment baseline is search_y + 4 (2px up from buttons for better centering)
  ImGui.DrawList_AddText(draw_list, sort_x, search_y + 4, sort_label_color, sort_label)

  -- Position sort buttons after label
  sort_x = sort_x + sort_label_width + 8
  for i, mode in ipairs(sort_modes) do
    local button_w = sort_button_widths[i]
    local is_active = (current_sort == mode.id)

    Button.draw(ctx, draw_list, sort_x, search_y, button_w, button_height, {
      label = mode.label,
      is_toggled = is_active,
      preset_name = "BUTTON_TOGGLE_WHITE",
      ignore_modal = true,  -- Bypass overlay blocking
      on_click = function()
        if current_sort == mode.id then
          -- Clicking the same sort mode toggles ascending/descending
          local current_reverse = self.state.settings.sort_reverse or false
          self.state.set_setting('sort_reverse', not current_reverse)
        else
          -- Switching to a new sort mode resets to ascending
          self.state.set_setting('sort_mode', mode.id)
          self.state.set_setting('sort_reverse', false)
        end
      end,
    }, "sort_button_" .. mode.id)

    sort_x = sort_x + button_w + button_gap
  end

  ImGui.PopFont(ctx)
  ImGui.PopStyleVar(ctx)

  -- Search input
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, search_fade)
  ImGui.PushFont(ctx, title_font, 14)

  if (not self.state.initialized and self.state.settings.focus_keyboard_on_init) or self.focus_search then
    -- Focus search by setting cursor position
    ImGui.SetCursorScreenPos(ctx, search_x, search_y)
    ImGui.SetKeyboardFocusHere(ctx)
    self.state.initialized = true
    self.focus_search = false
  end

  -- Use custom search widget with mode selector
  SearchWithMode.draw(ctx, self.state.draw_list, search_x, search_y, search_width, search_height, self.state, self.config)

  -- Advance cursor past search widget
  ImGui.SetCursorScreenPos(ctx, search_x, search_y + search_height)

  ImGui.PopFont(ctx)
  ImGui.PopStyleVar(ctx)

  -- Render region filter bar with slide animation (if region processing enabled and regions available)
  local filter_bar_height = 0
  local enable_region_processing = self.state.settings.enable_region_processing or self.state.settings.show_region_tags
  if enable_region_processing and self.state.all_regions and #self.state.all_regions > 0 then
    local filter_bar_base_y = search_y + search_height + self.config.UI_PANELS.filter.spacing_below_search

    -- Calculate actual height needed based on regions (responsive)
    local chip_cfg = self.config.REGION_TAGS.chip
    local padding_x = 14
    local padding_y = 4
    local line_spacing = 4
    local chip_height = chip_cfg.height + 2
    local available_width = screen_w - padding_x * 2

    -- Count lines needed
    local num_lines = 1
    local current_line_width = 0
    for i, region in ipairs(self.state.all_regions) do
      local text_w = ImGui.CalcTextSize(ctx, region.name)
      local chip_w = text_w + chip_cfg.padding_x * 2
      local needed_width = chip_w
      if current_line_width > 0 then
        needed_width = needed_width + chip_cfg.margin_x
      end
      if current_line_width + needed_width > available_width and current_line_width > 0 then
        num_lines = num_lines + 1
        current_line_width = chip_w
      else
        current_line_width = current_line_width + needed_width
      end
    end

    -- Calculate actual max height based on content
    local filter_bar_max_height = padding_y * 2 + num_lines * chip_height + (num_lines - 1) * line_spacing

    -- Calculate current panel start position
    local temp_filter_height = filter_bar_max_height * (self.state.filter_slide_progress or 0)
    local temp_panels_start_y = search_y + search_height + temp_filter_height + 20

    -- Show filter when hovering anywhere above the panels (trigger threshold into panels)
    -- Only trigger if mouse is within window bounds (fixes multi-monitor cursor detection)
    local is_hovering_above_panels = mouse_in_window and mouse_y < (temp_panels_start_y + self.config.UI_PANELS.filter.trigger_into_panels)

    -- Show filters when hovering above panels OR when settings are visible
    local filters_should_show = is_hovering_above_panels or self.state.settings_sticky_visible

    -- Smooth slide for filter bar
    if not self.state.filter_slide_progress then
      self.state.filter_slide_progress = 0
    end
    local target_filter_slide = filters_should_show and 1.0 or 0.0
    local filter_slide_speed = self.config.UI_PANELS.settings.slide_speed  -- Reuse settings slide speed
    self.state.filter_slide_progress = self.state.filter_slide_progress + (target_filter_slide - self.state.filter_slide_progress) * filter_slide_speed

    -- Calculate animated height and alpha
    filter_bar_height = filter_bar_max_height * self.state.filter_slide_progress
    local filter_alpha = self.state.filter_slide_progress * ui_fade

    -- Only render if visible
    if filter_bar_height > 1 then
      local filter_bar_y = filter_bar_base_y

      -- Pass full screen width - filter bar handles multi-line wrapping and centering
      RegionFilterBar.draw(ctx, draw_list, coord_offset_x, filter_bar_y, screen_w, self.state, self.config, filter_alpha)
    end
  end

  -- Section fade
  local section_fade = smootherstep(math.max(0, (overlay_alpha - 0.1) / 0.9))

  -- Calculate panel start position (below search bar and filter bar)
  -- Settings are already accounted for in search_y (pushed it down)
  local panels_start_y = search_y + search_height + filter_bar_height + 20  -- 20px spacing
  local panels_end_y = coord_offset_y + screen_h - 40  -- Leave some bottom margin
  local content_height = panels_end_y - panels_start_y
  local content_width = screen_w - (self.config.LAYOUT.PADDING * 2)

  -- Track filter bar on left side with slide animation
  local track_bar_width = 0
  local track_bar_max_width = 120  -- Max width when expanded
  local track_bar_collapsed_width = 8  -- Visible strip when collapsed
  local has_track_filters = self.state.track_tree and self.state.track_whitelist

  if has_track_filters then
    -- Count whitelisted tracks
    local whitelist_count = 0
    for guid, selected in pairs(self.state.track_whitelist) do
      if selected then whitelist_count = whitelist_count + 1 end
    end

    if whitelist_count > 0 then
      -- Calculate trigger zone on left edge
      local panels_left_edge = coord_offset_x + self.config.LAYOUT.PADDING

      -- Check if mouse is near left edge (within collapsed bar or expanded area)
      local current_bar_width = track_bar_collapsed_width +
        (track_bar_max_width - track_bar_collapsed_width) * (self.state.track_bar_slide_progress or 0)
      local is_hovering_left = mouse_in_window and
                               mouse_x < (panels_left_edge + current_bar_width) and
                               mouse_y >= panels_start_y and mouse_y <= panels_end_y

      -- Smooth slide for track bar
      if not self.state.track_bar_slide_progress then
        self.state.track_bar_slide_progress = 0
      end
      local target_slide = is_hovering_left and 1.0 or 0.0
      local slide_speed = self.config.UI_PANELS.settings.slide_speed
      self.state.track_bar_slide_progress = self.state.track_bar_slide_progress +
        (target_slide - self.state.track_bar_slide_progress) * slide_speed

      -- Calculate animated width (always at least collapsed width)
      track_bar_width = track_bar_collapsed_width +
        (track_bar_max_width - track_bar_collapsed_width) * self.state.track_bar_slide_progress

      -- Draw collapsed indicator strip (always visible)
      local bar_x = panels_left_edge
      local bar_y = panels_start_y
      local bar_height = content_height

      -- Draw indicator strip background
      local strip_alpha = math.floor(0x44 * section_fade)
      local strip_color = Colors.with_alpha(Colors.hexrgb("#3A3A3A"), strip_alpha)
      ImGui.DrawList_AddRectFilled(draw_list, bar_x, bar_y, bar_x + track_bar_collapsed_width, bar_y + bar_height, strip_color, 2)

      -- Only render full bar content if expanded
      if self.state.track_bar_slide_progress > 0.01 then
        local bar_alpha = self.state.track_bar_slide_progress * section_fade

        -- Draw track filter bar
        TrackFilterBar.draw(ctx, draw_list, bar_x, bar_y, bar_height, self.state, bar_alpha)
      end
    end
  end

  -- Adjust content width to account for track bar
  content_width = content_width - track_bar_width

  -- Get view mode
  local view_mode = self.state.get_view_mode()

  -- Calculate section heights based on view mode
  local start_x = coord_offset_x + self.config.LAYOUT.PADDING + track_bar_width
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

    -- Draw MIDI header first, in its own space
    draw_panel_title(ctx, draw_list, title_font, "MIDI Items", start_x, start_y, content_width - panel_right_padding, panel_padding, section_fade, 14, self.config, 0)

    -- MIDI grid child starts below header, in its own space
    local midi_grid_width = content_width - panel_right_padding - panel_padding * 2
    local midi_child_h = content_height - panel_padding
    ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, start_y + header_height)

    if ImGui.BeginChild(ctx, "midi_container", midi_grid_width, midi_child_h, 0,
      ImGui.WindowFlags_NoScrollbar) then
      self.coordinator:render_midi_grid(ctx, midi_grid_width, midi_child_h, 0)
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

    -- Draw Audio header first, in its own space
    draw_panel_title(ctx, draw_list, title_font, "Audio Items", start_x, start_y, content_width - panel_right_padding, panel_padding, section_fade, 15, self.config, 0)

    -- Audio grid child starts below header, in its own space
    local audio_grid_width = content_width - panel_right_padding - panel_padding * 2
    local audio_child_h = content_height - panel_padding
    ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, start_y + header_height)

    if ImGui.BeginChild(ctx, "audio_container", audio_grid_width, audio_child_h, 0,
      ImGui.WindowFlags_NoScrollbar) then
      self.coordinator:render_audio_grid(ctx, audio_grid_width, audio_child_h, 0)
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
      local block_input = self.separator:is_dragging() or (over_sep and ImGui.IsMouseDown(ctx, 0)) or self.state.show_track_filter_modal

      -- MIDI section (left)
      local panel_padding = 4
      local panel_rounding = 6
      local midi_panel_x1 = start_x
      local midi_panel_y1 = start_y
      local midi_panel_x2 = start_x + midi_width
      local midi_panel_y2 = start_y + header_height + content_height

      draw_panel(draw_list, midi_panel_x1, midi_panel_y1, midi_panel_x2, midi_panel_y2, panel_rounding, section_fade)

      -- Draw MIDI header first, in its own space
      draw_panel_title(ctx, draw_list, title_font, "MIDI Items", start_x, start_y, midi_width, panel_padding, section_fade, 14, self.config, 0)

      -- MIDI grid child starts below header, in its own space
      local midi_grid_x = start_x + panel_padding
      local midi_grid_y = start_y + header_height
      local midi_grid_width = midi_width - panel_padding * 2
      local midi_child_h = content_height - panel_padding

      ImGui.SetCursorScreenPos(ctx, midi_grid_x, midi_grid_y)

      if ImGui.BeginChild(ctx, "midi_container", midi_grid_width, midi_child_h, 0,
        ImGui.WindowFlags_NoScrollbar) then
        if self.coordinator.midi_grid then
          self.coordinator.midi_grid.block_all_input = block_input
        end
        self.coordinator:render_midi_grid(ctx, midi_grid_width, midi_child_h, 0)
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

      -- Draw Audio header first, in its own space
      draw_panel_title(ctx, draw_list, title_font, "Audio Items", audio_start_x, start_y, audio_width, panel_padding, section_fade, 15, self.config, 0)

      -- Audio grid child starts below header, in its own space
      local audio_grid_width = audio_width - panel_padding * 2
      local audio_child_h = content_height - panel_padding
      ImGui.SetCursorScreenPos(ctx, audio_start_x + panel_padding, start_y + header_height)

      if ImGui.BeginChild(ctx, "audio_container", audio_grid_width, audio_child_h, 0,
        ImGui.WindowFlags_NoScrollbar) then
        if self.coordinator.audio_grid then
          self.coordinator.audio_grid.block_all_input = block_input
        end
        self.coordinator:render_audio_grid(ctx, audio_grid_width, audio_child_h, 0)
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

    -- Draw MIDI header first, in its own space
    draw_panel_title(ctx, draw_list, title_font, "MIDI Items", start_x, start_y, content_width - panel_right_padding, panel_padding, section_fade, 14, self.config, 0)

    -- MIDI grid child starts below header, in its own space
    local midi_grid_width = content_width - panel_right_padding - panel_padding * 2
    local midi_child_h = midi_height - panel_padding
    ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, start_y + header_height)

    if ImGui.BeginChild(ctx, "midi_container", midi_grid_width, midi_child_h, 0,
      ImGui.WindowFlags_NoScrollbar) then
      -- Block grid input during separator drag
      if self.coordinator.midi_grid then
        self.coordinator.midi_grid.block_all_input = block_input
      end
      self.coordinator:render_midi_grid(ctx, midi_grid_width, midi_child_h, 0)
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

    -- Draw Audio header first, in its own space
    draw_panel_title(ctx, draw_list, title_font, "Audio Items", start_x, audio_start_y, content_width - panel_right_padding, panel_padding, section_fade, 15, self.config, 0)

    -- Audio grid child starts below header, in its own space
    local audio_grid_width = content_width - panel_right_padding - panel_padding * 2
    local audio_child_h = audio_height - panel_padding
    ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, audio_start_y + header_height)

    if ImGui.BeginChild(ctx, "audio_container", audio_grid_width, audio_child_h, 0,
      ImGui.WindowFlags_NoScrollbar) then
      -- Block grid input during separator drag
      if self.coordinator.audio_grid then
        self.coordinator.audio_grid.block_all_input = block_input
      end
      self.coordinator:render_audio_grid(ctx, audio_grid_width, audio_child_h, 0)
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
