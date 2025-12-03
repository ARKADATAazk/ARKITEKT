-- @noindex
-- ItemPicker/ui/components/layout_view/content_panels.lua
-- MIDI/Audio/Mixed panel rendering logic

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local TrackFilterBar = require('ItemPicker.ui.components.filters.track')

local M = {}

-- Lazy load Theme for panel colors
local _Theme
local function get_theme()
  if not _Theme then
    local ok, theme = pcall(require, 'arkitekt.theme')
    if ok then _Theme = theme end
  end
  return _Theme
end

-- Draw a panel background and border
local function draw_panel(dl, x1, y1, x2, y2, rounding, alpha)
  alpha = alpha or 1.0
  rounding = rounding or 6

  local Theme = get_theme()
  local ThemeColors = Theme and Theme.COLORS or {}

  local bg_color = ThemeColors.BG_PANEL or Ark.Colors.Hexrgb('#1A1A1A')
  bg_color = Ark.Colors.WithOpacity(bg_color, alpha * 0.6)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, rounding)

  local border_color = ThemeColors.BORDER_OUTER or Ark.Colors.Hexrgb('#2A2A2A')
  border_color = Ark.Colors.WithOpacity(border_color, alpha * 0.67)
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, rounding, 0, 1)
end

-- Draw a centered panel title
local function draw_panel_title(ctx, draw_list, title_font, title, panel_x, panel_y, panel_width, padding, alpha, font_size, config, scroll_y)
  ImGui.PushFont(ctx, title_font, font_size)
  local title_width = ImGui.CalcTextSize(ctx, title)
  local title_x = panel_x + (panel_width - title_width) / 2
  local title_y = panel_y + padding + config.UI_PANELS.header.title_offset_down

  local final_alpha = alpha
  if config.UI_PANELS.header.fade_on_scroll and scroll_y then
    local threshold = config.UI_PANELS.header.fade_scroll_threshold
    local distance = config.UI_PANELS.header.fade_scroll_distance
    if scroll_y > threshold then
      local fade_progress = math.min(1.0, (scroll_y - threshold) / distance)
      final_alpha = alpha * (1.0 - fade_progress)
    end
  end

  local text_color = config.COLORS.SECTION_HEADER_TEXT or Ark.Colors.Hexrgb('#FFFFFF')
  text_color = Ark.Colors.WithAlpha(text_color, Ark.Colors.Opacity(final_alpha))
  ImGui.DrawList_AddText(draw_list, title_x, title_y, text_color, title)
  ImGui.PopFont(ctx)
end

function M.draw_midi_only(ctx, draw_list, title_font, start_x, start_y, content_width, content_height, header_height, section_fade, panel_right_padding, state, config, coordinator)
  local panel_padding = 4
  local panel_rounding = 6
  local panel_x1 = start_x
  local panel_y1 = start_y
  local panel_x2 = start_x + content_width - panel_right_padding
  local panel_y2 = start_y + header_height + content_height

  draw_panel(draw_list, panel_x1, panel_y1, panel_x2, panel_y2, panel_rounding, section_fade)
  draw_panel_title(ctx, draw_list, title_font, 'MIDI Items', start_x, start_y, content_width - panel_right_padding, panel_padding, section_fade, 14, config, 0)

  local midi_grid_width = content_width - panel_right_padding - panel_padding * 2
  local midi_child_h = content_height - panel_padding
  ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, start_y + header_height)

  coordinator.midi_grid_opts.block_all_input = state.show_track_filter_modal or false

  if ImGui.BeginChild(ctx, 'midi_container', midi_grid_width, midi_child_h, 0, ImGui.WindowFlags_NoScrollbar) then
    coordinator:render_midi_grid(ctx, midi_grid_width, midi_child_h, 0)
    ImGui.EndChild(ctx)
  end
end

function M.draw_audio_only(ctx, draw_list, title_font, start_x, start_y, content_width, content_height, header_height, section_fade, panel_right_padding, state, config, coordinator)
  local panel_padding = 4
  local panel_rounding = 6
  local panel_x1 = start_x
  local panel_y1 = start_y
  local panel_x2 = start_x + content_width - panel_right_padding
  local panel_y2 = start_y + header_height + content_height

  draw_panel(draw_list, panel_x1, panel_y1, panel_x2, panel_y2, panel_rounding, section_fade)
  draw_panel_title(ctx, draw_list, title_font, 'Audio Items', start_x, start_y, content_width - panel_right_padding, panel_padding, section_fade, 15, config, 0)

  local audio_grid_width = content_width - panel_right_padding - panel_padding * 2
  local audio_child_h = content_height - panel_padding
  ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, start_y + header_height)

  coordinator.audio_grid_opts.block_all_input = state.show_track_filter_modal or false

  if ImGui.BeginChild(ctx, 'audio_container', audio_grid_width, audio_child_h, 0, ImGui.WindowFlags_NoScrollbar) then
    coordinator:render_audio_grid(ctx, audio_grid_width, audio_child_h, 0)
    ImGui.EndChild(ctx)
  end
end

function M.draw_mixed_horizontal(ctx, draw_list, title_font, start_x, start_y, content_width, content_height, header_height, section_fade, panel_right_padding, state, config, coordinator)
  local sep_config = config.SEPARATOR
  local min_midi_width = 200
  local min_audio_width = 300
  local separator_gap = sep_config.gap
  local min_total_width = min_midi_width + min_audio_width + separator_gap
  local max = math.max
  local min = math.min

  local midi_width, audio_width

  if content_width < min_total_width then
    local ratio = content_width / min_total_width
    midi_width = (min_midi_width * ratio)//1
    audio_width = content_width - midi_width - separator_gap
    if midi_width < 100 then midi_width = 100 end
    if audio_width < 150 then audio_width = 150 end
    audio_width = max(1, content_width - midi_width - separator_gap)
  else
    midi_width = state.settings.separator_position_horizontal or 400
    midi_width = max(min_midi_width, min(midi_width, content_width - min_audio_width - separator_gap))
    audio_width = content_width - midi_width - separator_gap
  end

  midi_width = max(1, midi_width)
  audio_width = max(1, audio_width)

  -- MIDI section (left)
  local panel_padding = 4
  local panel_rounding = 6

  draw_panel(draw_list, start_x, start_y, start_x + midi_width, start_y + header_height + content_height, panel_rounding, section_fade)
  draw_panel_title(ctx, draw_list, title_font, 'MIDI Items', start_x, start_y, midi_width, panel_padding, section_fade, 14, config, 0)

  local midi_grid_width = midi_width - panel_padding * 2
  local midi_child_h = content_height - panel_padding

  ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, start_y + header_height)

  if ImGui.BeginChild(ctx, 'midi_container', midi_grid_width, midi_child_h, 0, ImGui.WindowFlags_NoScrollbar) then
    coordinator:render_midi_grid(ctx, midi_grid_width, midi_child_h, 0)
    ImGui.EndChild(ctx)
  end

  -- Vertical separator
  local separator_x = start_x + midi_width + separator_gap/2
  local Ark = require('arkitekt')
  local sep_result = Ark.Splitter(ctx, {
    id = 'midi_audio_sep_h',
    x = separator_x,
    y = start_y,
    height = header_height + content_height,
    orientation = 'vertical',
    thickness = sep_config.thickness,
  })

  local block_input = sep_result.dragging or state.show_track_filter_modal
  if coordinator.midi_grid_opts then coordinator.midi_grid_opts.block_all_input = block_input end
  if coordinator.audio_grid_opts then coordinator.audio_grid_opts.block_all_input = block_input end

  if sep_result.action == 'reset' then
    state.set_setting('separator_position_horizontal', 400)
  elseif sep_result.action == 'drag' and content_width >= min_total_width then
    local new_midi_width = sep_result.position - start_x - separator_gap/2
    new_midi_width = max(min_midi_width, min(new_midi_width, content_width - min_audio_width - separator_gap))
    state.set_setting('separator_position_horizontal', new_midi_width)
  end

  -- Audio section (right)
  local audio_start_x = start_x + midi_width + separator_gap

  draw_panel(draw_list, audio_start_x, start_y, audio_start_x + audio_width, start_y + header_height + content_height, panel_rounding, section_fade)
  draw_panel_title(ctx, draw_list, title_font, 'Audio Items', audio_start_x, start_y, audio_width, panel_padding, section_fade, 15, config, 0)

  local audio_grid_width = audio_width - panel_padding * 2
  local audio_child_h = content_height - panel_padding
  ImGui.SetCursorScreenPos(ctx, audio_start_x + panel_padding, start_y + header_height)

  if ImGui.BeginChild(ctx, 'audio_container', audio_grid_width, audio_child_h, 0, ImGui.WindowFlags_NoScrollbar) then
    coordinator:render_audio_grid(ctx, audio_grid_width, audio_child_h, 0)
    ImGui.EndChild(ctx)
  end
end

function M.draw_mixed_vertical(ctx, draw_list, title_font, start_x, start_y, content_width, content_height, header_height, section_fade, panel_right_padding, state, config, coordinator)
  local sep_config = config.SEPARATOR
  local min_midi_height = sep_config.min_midi_height
  local min_audio_height = sep_config.min_audio_height
  local separator_gap = sep_config.gap
  local min_total_height = min_midi_height + min_audio_height + separator_gap
  local max = math.max
  local min = math.min

  local midi_height, audio_height

  if content_height < min_total_height then
    local ratio = content_height / min_total_height
    midi_height = (min_midi_height * ratio)//1
    audio_height = content_height - midi_height - separator_gap
    if midi_height < 50 then midi_height = 50 end
    if audio_height < 50 then audio_height = 50 end
    audio_height = max(1, content_height - midi_height - separator_gap)
  else
    midi_height = state.get_separator_position()
    midi_height = max(min_midi_height, min(midi_height, content_height - min_audio_height - separator_gap))
    audio_height = content_height - midi_height - separator_gap
  end

  midi_height = max(1, midi_height)
  audio_height = max(1, audio_height)

  -- MIDI section with panel
  local panel_padding = 4
  local panel_rounding = 6

  draw_panel(draw_list, start_x, start_y, start_x + content_width - panel_right_padding, start_y + header_height + midi_height, panel_rounding, section_fade)
  draw_panel_title(ctx, draw_list, title_font, 'MIDI Items', start_x, start_y, content_width - panel_right_padding, panel_padding, section_fade, 14, config, 0)

  local midi_grid_width = content_width - panel_right_padding - panel_padding * 2
  local midi_child_h = midi_height - panel_padding
  ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, start_y + header_height)

  if ImGui.BeginChild(ctx, 'midi_container', midi_grid_width, midi_child_h, 0, ImGui.WindowFlags_NoScrollbar) then
    coordinator:render_midi_grid(ctx, midi_grid_width, midi_child_h, 0)
    ImGui.EndChild(ctx)
  end

  -- Draggable separator
  local separator_y = start_y + header_height + midi_height + separator_gap/2
  local Ark = require('arkitekt')
  local sep_result = Ark.Splitter(ctx, {
    id = 'midi_audio_sep_v',
    x = start_x,
    y = separator_y,
    width = content_width,
    orientation = 'horizontal',
    thickness = sep_config.thickness,
  })

  local block_input = sep_result.dragging or state.show_track_filter_modal
  if coordinator.midi_grid_opts then coordinator.midi_grid_opts.block_all_input = block_input end
  if coordinator.audio_grid_opts then coordinator.audio_grid_opts.block_all_input = block_input end

  if sep_result.action == 'reset' then
    state.set_separator_position(sep_config.default_midi_height)
  elseif sep_result.action == 'drag' and content_height >= min_total_height then
    local new_midi_height = sep_result.position - start_y - header_height - separator_gap/2
    new_midi_height = max(min_midi_height, min(new_midi_height, content_height - min_audio_height - separator_gap))
    state.set_separator_position(new_midi_height)
  end

  -- Audio section with panel
  local audio_start_y = start_y + header_height + midi_height + separator_gap

  draw_panel(draw_list, start_x, audio_start_y, start_x + content_width - panel_right_padding, audio_start_y + header_height + audio_height, panel_rounding, section_fade)
  draw_panel_title(ctx, draw_list, title_font, 'Audio Items', start_x, audio_start_y, content_width - panel_right_padding, panel_padding, section_fade, 15, config, 0)

  local audio_grid_width = content_width - panel_right_padding - panel_padding * 2
  local audio_child_h = audio_height - panel_padding
  ImGui.SetCursorScreenPos(ctx, start_x + panel_padding, audio_start_y + header_height)

  if ImGui.BeginChild(ctx, 'audio_container', audio_grid_width, audio_child_h, 0, ImGui.WindowFlags_NoScrollbar) then
    coordinator:render_audio_grid(ctx, audio_grid_width, audio_child_h, 0)
    ImGui.EndChild(ctx)
  end
end

function M.draw_track_filter_bar(ctx, draw_list, coord_offset_x, panels_start_y, content_height, section_fade, state, config)
  local track_bar_width = 0
  local track_bar_max_width = 120
  local track_bar_collapsed_width = 8
  local has_track_filters = state.track_tree and state.track_whitelist

  if has_track_filters then
    local whitelist_count = 0
    for guid, selected in pairs(state.track_whitelist) do
      if selected then whitelist_count = whitelist_count + 1 end
    end

    if whitelist_count > 0 then
      local panels_left_edge = coord_offset_x + config.LAYOUT.PADDING

      local track_zone_result = Ark.SlidingZone(ctx, {
        id = 'track_filter_bar',
        edge = 'left',
        bounds = {
          x = panels_left_edge,
          y = panels_start_y,
          w = track_bar_max_width,
          h = content_height,
        },
        size = track_bar_max_width,
        collapsed_ratio = 0.0,  -- Fully hidden when collapsed
        -- trigger_extension uses default (8px)
        retract_delay = 0.2,
        directional_delay = true,
        retract_delay_toward = 1.0,
        retract_delay_away = 0.1,
        hover_padding = 0,
        draw_list = draw_list,
        debug_mouse_tracking = true,

        draw = function(zone_ctx, dl, bounds, visibility)
          local bar_x = bounds.x
          local bar_y = bounds.y
          local bar_height = bounds.h
          local current_width = bounds.w

          local strip_alpha = (0x44 * section_fade) // 1
          local strip_color = Ark.Colors.WithAlpha(Ark.Colors.Hexrgb('#3A3A3A'), strip_alpha)
          ImGui.DrawList_AddRectFilled(dl, bar_x, bar_y, bar_x + track_bar_collapsed_width, bar_y + bar_height, strip_color, 2)

          if visibility > 0.1 then
            local bar_alpha = visibility * section_fade
            TrackFilterBar.Draw(zone_ctx, dl, bar_x, bar_y, bar_height, state, bar_alpha)
          end
        end,
      })

      track_bar_width = track_zone_result.bounds.w
    end
  end

  return track_bar_width
end

return M
