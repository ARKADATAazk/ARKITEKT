-- @noindex
-- ItemPicker/ui/components/layout_view.lua
-- Main layout view with absolute positioning and fade animations
-- Refactored: Now uses separate modules for settings, search toolbar, and content panels

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local StatusBar = require('ItemPicker.ui.components.status')
local RegionFilterBar = require('ItemPicker.ui.components.filters.region')
local Background = require('arkitekt.gui.draw.patterns')

-- Sub-modules
local SettingsPanel = require('ItemPicker.ui.components.layout_view.settings_panel')
local SearchToolbar = require('ItemPicker.ui.components.layout_view.search_toolbar')
local ContentPanels = require('ItemPicker.ui.components.layout_view.content_panels')

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

-- Smooth easing function
local function smootherstep(t)
  t = math.max(0.0, math.min(1.0, t))
  return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Lazy load Theme for pattern colors
local _Theme
local function get_theme()
  if not _Theme then
    local ok, theme = pcall(require, 'arkitekt.theme')
    if ok then _Theme = theme end
  end
  return _Theme
end

function LayoutView:handle_shortcuts(ctx)
  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)

  -- Ctrl+` to toggle debug console
  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_GraveAccent) then
    local ok, ConsoleWindow = pcall(require, 'arkitekt.debug.console_window')
    if ok and ConsoleWindow and ConsoleWindow.launch then
      ConsoleWindow.launch()
    end
    return
  end

  -- Ctrl+F to focus search
  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_F) then
    self.focus_search = true
    return
  end

  -- ESC to clear search
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    if self.state.settings.search_string and self.state.settings.search_string ~= '' then
      self.state.set_search_filter('')
    end
  end
end

function LayoutView:render(ctx, title_font, title_font_size, title, screen_w, screen_h, is_overlay_mode)
  self:handle_shortcuts(ctx)

  -- Initialize all_regions if region processing is enabled
  if (self.state.settings.enable_region_processing or self.state.settings.show_region_tags) and
     (not self.state.all_regions or #self.state.all_regions == 0) then
    self.state.all_regions = require('ItemPicker.data.reaper_api').GetAllProjectRegions()
  end

  -- In overlay mode, skip window creation
  local imgui_visible = true
  if not is_overlay_mode then
    ImGui.SetNextWindowPos(ctx, 0, 0)
    ImGui.SetNextWindowSize(ctx, screen_w, screen_h)

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
  local ui_fade = smootherstep(math.max(0, (overlay_alpha - 0.15) / 0.85))
  local ui_y_offset = 15 * (1.0 - ui_fade)

  local draw_list = ImGui.GetWindowDrawList(ctx)
  local window_x, window_y = ImGui.GetWindowPos(ctx)
  local coord_offset_x = window_x
  local coord_offset_y = window_y

  -- Draw dotted pattern
  local Theme = get_theme()
  local ThemeColors = Theme and Theme.COLORS or {}
  local pattern_color = ThemeColors.PATTERN_PRIMARY or Ark.Colors.Hexrgb('#2A2A2A')

  local overlay_pattern_config = {
    enabled = true,
    use_texture = true,
    primary = {
      type = 'dots',
      spacing = 16,
      dot_size = 1.5,
      color = Ark.Colors.WithAlpha(pattern_color, math.floor(overlay_alpha * 180)),
      offset_x = 0,
      offset_y = 0,
    }
  }
  Background.Draw(ctx, draw_list, coord_offset_x, coord_offset_y,
      coord_offset_x + screen_w, coord_offset_y + screen_h, overlay_pattern_config)

  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local mouse_in_window = mouse_x >= coord_offset_x and mouse_x < coord_offset_x + screen_w and
                          mouse_y >= coord_offset_y and mouse_y < coord_offset_y + screen_h

  local search_fade = smootherstep(math.max(0, (overlay_alpha - 0.05) / 0.95))
  local search_y_offset = 25 * (1.0 - search_fade)

  local search_top_padding = self.config.UI_PANELS.search.top_padding
  local search_base_y = coord_offset_y + 14 + ui_y_offset + search_y_offset + search_top_padding
  local search_height = 28

  local settings_area_max_height = self.config.UI_PANELS.settings.max_height
  local settings_offset = 11  -- Move panel up 11px

  -- Settings panel (using SlidingZone)
  local settings_result = Ark.SlidingZone(ctx, {
    id = 'settings_panel',
    edge = 'top',
    bounds = {
      x = coord_offset_x,
      y = search_base_y - settings_offset,  -- Position 11px higher
      w = screen_w,
      h = settings_area_max_height,
    },
    size = settings_area_max_height,
    collapsed_ratio = 0.0,  -- Fully hidden when collapsed

    -- Trigger zone extends upward to window edge only when collapsed
    trigger_extension = {
      up = (search_base_y - settings_offset) - coord_offset_y,  -- To window top
      down = 0,  -- No extension below when collapsed
      left = 0,
      right = 0,
    },

    -- When expanded, extend trigger zone down to cover RegionFilter + search area
    trigger_extension_expanded = {
      up = (search_base_y - settings_offset) - coord_offset_y,  -- To window top
      down = search_height + 100,  -- Extend far down to cover region filter area
      left = 0,
      right = 0,
    },

    -- Custom retract: close when hovering below search bar
    retract_when = function(ctx, mx, my, state)
      local current_visibility = state.visibility_track:get()
      local current_settings_height = settings_area_max_height * current_visibility
      local current_search_y = search_base_y + current_settings_height
      local close_threshold = current_search_y + search_height +
                             self.config.UI_PANELS.settings.close_below_search
      return mouse_in_window and my > close_threshold
    end,

    retract_delay = 1.5,  -- 1.5s delay before retracting
    window_bounds = {
      x = coord_offset_x,
      y = coord_offset_y,
      w = screen_w,
      h = screen_h,
    },

    draw_list = draw_list,

    draw = function(zone_ctx, dl, bounds, visibility)
      local settings_height = bounds.h
      local settings_alpha = visibility * ui_fade
      local settings_y = bounds.y
      SettingsPanel.Draw(zone_ctx, dl, coord_offset_x, settings_y, settings_height, settings_alpha, self.state, self.config)
    end,
  })

  -- Calculate search_y based on settings visibility
  local settings_height = settings_area_max_height * settings_result.visibility
  local search_y = search_base_y + settings_height

  -- Draw search toolbar
  self.state.focus_search = self.focus_search
  SearchToolbar.Draw(ctx, coord_offset_x, search_y, screen_w, search_height, search_fade, title_font, self.state, self.config)
  self.focus_search = false

  -- Region filter bar
  local filter_bar_height = 0
  local enable_region_processing = self.state.settings.enable_region_processing or self.state.settings.show_region_tags
  if enable_region_processing and self.state.all_regions and #self.state.all_regions > 0 then
    local filter_bar_base_y = search_y + search_height + self.config.UI_PANELS.filter.spacing_below_search

    -- Calculate filter bar height based on number of lines
    local chip_cfg = self.config.REGION_TAGS.chip
    local padding_x = 14
    local padding_y = 4
    local line_spacing = 4
    local chip_height = chip_cfg.height + 2
    local available_width = screen_w - padding_x * 2

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

    local filter_bar_max_height = padding_y * 2 + num_lines * chip_height + (num_lines - 1) * line_spacing

    -- Region filter using SlidingZone (extends upward to cover SettingsPanel area)
    local filter_result = Ark.SlidingZone(ctx, {
      id = 'region_filter_bar',
      edge = 'top',
      bounds = {
        x = coord_offset_x,
        y = filter_bar_base_y,
        w = screen_w,
        h = filter_bar_max_height,
      },
      size = filter_bar_max_height,
      collapsed_ratio = 0.0,

      -- Extend upward to cover entire SettingsPanel area + search bar
      trigger_extension = {
        up = filter_bar_base_y - coord_offset_y,  -- All the way to top of window
        down = self.config.UI_PANELS.filter.trigger_into_panels,
        left = 0,
        right = 0,
      },

      retract_delay = 0.2,  -- Base delay
      directional_delay = true,
      retract_delay_toward = 1.5,  -- When exiting upward (toward panel edge)
      retract_delay_away = 0.1,    -- When exiting downward (away from panel)
      window_bounds = {
        x = coord_offset_x,
        y = coord_offset_y,
        w = screen_w,
        h = screen_h,
      },


      draw_list = draw_list,

      draw = function(zone_ctx, dl, bounds, visibility)
        local filter_alpha = visibility * ui_fade
        if filter_alpha > 0.01 then
          RegionFilterBar.Draw(zone_ctx, dl, coord_offset_x, filter_bar_base_y, screen_w, self.state, self.config, filter_alpha)
        end
      end,
    })

    filter_bar_height = filter_bar_max_height * filter_result.visibility
  end

  local section_fade = smootherstep(math.max(0, (overlay_alpha - 0.1) / 0.9))
  local panels_start_y = search_y + search_height + filter_bar_height + 20
  local panels_end_y = coord_offset_y + screen_h - 40
  local content_height = panels_end_y - panels_start_y
  local content_width = screen_w - (self.config.LAYOUT.PADDING * 2)

  -- Track filter bar
  local track_bar_width = ContentPanels.draw_track_filter_bar(ctx, draw_list, coord_offset_x, panels_start_y, content_height, section_fade, self.state, self.config)
  content_width = content_width - track_bar_width

  local view_mode = self.state.get_view_mode()
  local start_x = coord_offset_x + self.config.LAYOUT.PADDING + track_bar_width
  local start_y = panels_start_y
  local header_height = self.config.LAYOUT.HEADER_HEIGHT
  local panel_right_padding = 12

  if view_mode == 'MIDI' then
    ContentPanels.draw_midi_only(ctx, draw_list, title_font, start_x, start_y, content_width, content_height, header_height, section_fade, panel_right_padding, self.state, self.config, self.coordinator)
  elseif view_mode == 'AUDIO' then
    ContentPanels.draw_audio_only(ctx, draw_list, title_font, start_x, start_y, content_width, content_height, header_height, section_fade, panel_right_padding, self.state, self.config, self.coordinator)
  else
    local layout_mode = self.state.settings.layout_mode or 'vertical'
    if layout_mode == 'horizontal' then
      ContentPanels.draw_mixed_horizontal(ctx, draw_list, title_font, start_x, start_y, content_width, content_height, header_height, section_fade, panel_right_padding, self.state, self.config, self.coordinator)
    else
      ContentPanels.draw_mixed_vertical(ctx, draw_list, title_font, start_x, start_y, content_width, content_height, header_height, section_fade, panel_right_padding, self.state, self.config, self.coordinator)
    end
  end

  if not is_overlay_mode then
    ImGui.End(ctx)
  end
end

return M
