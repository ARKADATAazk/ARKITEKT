-- @noindex
-- ItemPicker/ui/components/layout_view/settings_panel.lua
-- Settings panel with checkboxes and waveform quality slider
-- Uses cursor flow for checkbox layout

local ImGui = require('arkitekt.platform.imgui')
local Ark = require('arkitekt')

local M = {}

-- Checkbox with cursor flow
local function checkbox(ctx, id, label, is_checked, alpha, on_click)
  local result = Ark.Checkbox(ctx, {
    id = id,
    label = label,
    is_checked = is_checked,
    alpha = alpha,
    advance = 'none',
  })
  if result.clicked and on_click then
    on_click()
  end
  return result
end

function M.draw(ctx, draw_list, base_x, base_y, settings_height, settings_alpha, state, config)
  if settings_height <= 1 then return end

  local spacing = 20

  -- ============================================================================
  -- LINE 1: Play Item Through Track | Show Muted Tracks | Show Muted Items | Show Disabled Items
  -- ============================================================================
  ImGui.SetCursorScreenPos(ctx, base_x + 14, base_y)

  checkbox(ctx, 'play_item_through_track',
    'Play Item Through Track (will add delay to preview playback)',
    state.settings.play_item_through_track, settings_alpha,
    function() state.set_setting('play_item_through_track', not state.settings.play_item_through_track) end
  )
  ImGui.SameLine(ctx, 0, spacing)

  checkbox(ctx, 'show_muted_tracks',
    'Show Muted Tracks',
    state.settings.show_muted_tracks, settings_alpha,
    function() state.set_setting('show_muted_tracks', not state.settings.show_muted_tracks) end
  )
  ImGui.SameLine(ctx, 0, spacing)

  checkbox(ctx, 'show_muted_items',
    'Show Muted Items',
    state.settings.show_muted_items, settings_alpha,
    function() state.set_setting('show_muted_items', not state.settings.show_muted_items) end
  )
  ImGui.SameLine(ctx, 0, spacing)

  checkbox(ctx, 'show_disabled_items',
    'Show Disabled Items',
    state.settings.show_disabled_items, settings_alpha,
    function() state.set_setting('show_disabled_items', not state.settings.show_disabled_items) end
  )

  -- ============================================================================
  -- LINE 2: Show Favorites Only | Show Audio | Show MIDI | Group Items | Tile FX | Show Viz | Enable Regions | Show on Tiles
  -- ============================================================================
  ImGui.SetCursorScreenPos(ctx, base_x + 14, base_y + 24)

  checkbox(ctx, 'show_favorites_only',
    'Show Favorites Only',
    state.settings.show_favorites_only, settings_alpha,
    function() state.set_setting('show_favorites_only', not state.settings.show_favorites_only) end
  )
  ImGui.SameLine(ctx, 0, spacing)

  checkbox(ctx, 'show_audio',
    'Show Audio',
    state.settings.show_audio, settings_alpha,
    function() state.set_setting('show_audio', not state.settings.show_audio) end
  )
  ImGui.SameLine(ctx, 0, spacing)

  checkbox(ctx, 'show_midi',
    'Show MIDI',
    state.settings.show_midi, settings_alpha,
    function() state.set_setting('show_midi', not state.settings.show_midi) end
  )
  ImGui.SameLine(ctx, 0, spacing)

  checkbox(ctx, 'group_items_by_name',
    'Group Items of Same Name',
    state.settings.group_items_by_name, settings_alpha,
    function()
      state.set_setting('group_items_by_name', not state.settings.group_items_by_name)
      state.needs_reorganize = true
    end
  )
  ImGui.SameLine(ctx, 0, spacing)

  local enable_fx = state.settings.enable_tile_fx
  if enable_fx == nil then enable_fx = true end
  checkbox(ctx, 'enable_fx',
    'Tile FX',
    enable_fx, settings_alpha,
    function() state.set_setting('enable_tile_fx', not enable_fx) end
  )
  ImGui.SameLine(ctx, 0, spacing)

  local show_viz_small = state.settings.show_visualization_in_small_tiles
  if show_viz_small == nil then show_viz_small = true end
  checkbox(ctx, 'show_viz_small',
    'Show Viz in Small Tiles',
    show_viz_small, settings_alpha,
    function() state.set_setting('show_visualization_in_small_tiles', not show_viz_small) end
  )
  ImGui.SameLine(ctx, 0, spacing)

  local enable_regions = state.settings.enable_region_processing
  if enable_regions == nil then enable_regions = false end
  checkbox(ctx, 'enable_regions',
    'Enable Regions',
    enable_regions, settings_alpha,
    function()
      state.set_setting('enable_region_processing', not enable_regions)
      if not enable_regions then
        state.all_regions = require('ItemPicker.data.reaper_api').GetAllProjectRegions()
      else
        state.all_regions = {}
        state.selected_regions = {}
      end
      state.needs_recollect = true
    end
  )
  ImGui.SameLine(ctx, 0, spacing)

  local show_region_tags = state.settings.show_region_tags
  if show_region_tags == nil then show_region_tags = false end
  checkbox(ctx, 'show_region_tags',
    'Show on Tiles',
    show_region_tags, settings_alpha,
    function() state.set_setting('show_region_tags', not show_region_tags) end
  )

  -- ============================================================================
  -- LINE 3: Waveform Quality slider and related checkboxes
  -- ============================================================================
  local waveform_x = base_x + 14
  local waveform_y = base_y + 48

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, settings_alpha)

  -- Slider label
  local slider_label = 'Waveform Quality:'
  local slider_label_width = ImGui.CalcTextSize(ctx, slider_label)
  ImGui.DrawList_AddText(draw_list, waveform_x, waveform_y + 3,
    Ark.Colors.with_alpha(Ark.Colors.hexrgb('#FFFFFF'), (settings_alpha * 180) // 1), slider_label)

  -- Slider track
  local slider_width = 120
  local track_x = waveform_x + slider_label_width + 8
  local track_y = waveform_y + 7
  local track_h = 6
  local track_rounding = 3

  local track_color = Ark.Colors.with_alpha(Ark.Colors.hexrgb('#1A1A1A'), (settings_alpha * 200) // 1)
  ImGui.DrawList_AddRectFilled(draw_list, track_x, track_y, track_x + slider_width, track_y + track_h, track_color, track_rounding)

  local quality = state.settings.waveform_quality or 1.0
  local fill_width = slider_width * quality
  local fill_color = Ark.Colors.with_alpha(Ark.Colors.hexrgb('#4A9EFF'), (settings_alpha * 200) // 1)
  if fill_width > 1 then
    ImGui.DrawList_AddRectFilled(draw_list, track_x, track_y, track_x + fill_width, track_y + track_h, fill_color, track_rounding)
  end

  -- Slider thumb
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local thumb_x = track_x + fill_width
  local thumb_y = track_y + track_h / 2
  local thumb_radius = 6
  local is_thumb_hovered = (mouse_x - thumb_x) * (mouse_x - thumb_x) + (mouse_y - thumb_y) * (mouse_y - thumb_y) <= thumb_radius * thumb_radius

  local thumb_color = is_thumb_hovered and Ark.Colors.hexrgb('#5AAFFF') or Ark.Colors.hexrgb('#4A9EFF')
  thumb_color = Ark.Colors.with_alpha(thumb_color, Ark.Colors.opacity(settings_alpha))
  ImGui.DrawList_AddCircleFilled(draw_list, thumb_x, thumb_y, thumb_radius, thumb_color)

  -- Slider interaction
  local is_slider_hovered = mouse_x >= track_x and mouse_x < track_x + slider_width and mouse_y >= track_y - 4 and mouse_y < track_y + track_h + 4
  if is_slider_hovered and ImGui.IsMouseDown(ctx, 0) then
    local new_quality = math.max(0.1, math.min(1.0, (mouse_x - track_x) / slider_width))
    state.set_setting('waveform_quality', new_quality)
    if state.runtime_cache and state.runtime_cache.waveforms then
      state.runtime_cache.waveforms = {}
    end
  end

  -- Percentage value
  local percent_text = string.format('%d%%', (quality * 100) // 1)
  local percent_x = track_x + slider_width + 8
  ImGui.DrawList_AddText(draw_list, percent_x, waveform_y + 3,
    Ark.Colors.with_alpha(Ark.Colors.hexrgb('#AAAAAA'), (settings_alpha * 180) // 1), percent_text)

  ImGui.PopStyleVar(ctx)

  -- Checkboxes after slider (use cursor flow)
  local checkboxes_x = percent_x + ImGui.CalcTextSize(ctx, percent_text) + 20
  ImGui.SetCursorScreenPos(ctx, checkboxes_x, waveform_y)

  local waveform_filled = state.settings.waveform_filled
  if waveform_filled == nil then waveform_filled = true end
  checkbox(ctx, 'waveform_filled',
    'Fill',
    waveform_filled, settings_alpha,
    function()
      state.set_setting('waveform_filled', not waveform_filled)
      if state.runtime_cache and state.runtime_cache.waveform_polylines then
        state.runtime_cache.waveform_polylines = {}
      end
    end
  )
  ImGui.SameLine(ctx, 0, spacing)

  local waveform_zero_line = state.settings.waveform_zero_line or false
  checkbox(ctx, 'waveform_zero_line',
    'Zero Line',
    waveform_zero_line, settings_alpha,
    function() state.set_setting('waveform_zero_line', not waveform_zero_line) end
  )
  ImGui.SameLine(ctx, 0, spacing)

  local show_duration = state.settings.show_duration
  if show_duration == nil then show_duration = true end
  checkbox(ctx, 'show_duration',
    'Show Duration',
    show_duration, settings_alpha,
    function() state.set_setting('show_duration', not show_duration) end
  )
  ImGui.SameLine(ctx, 0, spacing)

  local auto_preview = state.settings.auto_preview_on_hover or false
  checkbox(ctx, 'auto_preview_on_hover',
    'Auto-Preview on Hover',
    auto_preview, settings_alpha,
    function() state.set_setting('auto_preview_on_hover', not auto_preview) end
  )
end

return M
