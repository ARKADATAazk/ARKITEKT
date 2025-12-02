-- @noindex
-- Arkitekt/gui/widgets/panel/header/tab_strip.lua
-- Clean, modular tab strip with improved animation control
-- Refactored: Now uses separate modules for animations and rendering

local ImGui = require('arkitekt.platform.imgui')

-- Load sub-modules
local Rendering = require('arkitekt.gui.widgets.containers.panel.header.tab_strip.rendering')
local Animation = require('arkitekt.gui.widgets.containers.panel.header.tab_strip.animations')

-- Wire up cross-module dependencies
Rendering.set_animation_module(Animation)
Animation.set_width_calculators(Rendering.calculate_responsive_tab_widths, Rendering.calculate_tab_width)

local M = {}

function M.Draw(ctx, dl, x, y, available_width, height, config, state)
  config = config or {}
  state = state or {}

  local element_id = state.id or 'tabstrip'
  local unique_id = string.format('%s_%s', tostring(state._panel_id or 'unknown'), element_id)

  local tabs = state.tabs or {}
  local active_tab_id = state.active_tab_id
  local animator = state.tab_animator
  local corner_rounding = config.corner_rounding

  if animator and animator.update then
    animator:update()
  end

  local plus_cfg = config.plus_button or {}
  local plus_width = plus_cfg.width or 23
  local spacing = config.spacing or 0

  local tabs_start_x = x + plus_width
  if spacing > 0 then
    tabs_start_x = tabs_start_x + spacing
  else
    tabs_start_x = tabs_start_x - 1
  end

  -- Calculate available space for tabs
  local tabs_max_width = available_width - plus_width
  if spacing > 0 then
    tabs_max_width = tabs_max_width - spacing
  else
    tabs_max_width = tabs_max_width + 1
  end

  -- Calculate natural tab widths
  local natural_widths, min_text_widths = Rendering.calculate_responsive_tab_widths(ctx, tabs, config, tabs_max_width, false)

  -- Calculate total natural width of tabs
  local total_tabs_natural = 0
  for i = 1, #tabs do
    total_tabs_natural = total_tabs_natural + natural_widths[i]
    if i < #tabs then
      total_tabs_natural = total_tabs_natural + (spacing == 0 and -1 or spacing)
    end
  end

  -- Determine overflow button width
  local overflow_cfg = config.overflow_button or { min_width = 21, padding_x = 8 }
  local overflow_width = overflow_cfg.min_width or 21

  -- Calculate usage ratio for overflow positioning
  local usage_ratio = (total_tabs_natural + overflow_width + (spacing == 0 and -1 or spacing)) / tabs_max_width
  local overflow_at_edge = (usage_ratio >= 0.75)

  local tabs_available_width
  if overflow_at_edge then
    tabs_available_width = tabs_max_width - overflow_width + 1
  else
    tabs_available_width = tabs_max_width
  end

  -- Calculate final widths
  local final_tab_widths
  if overflow_at_edge then
    final_tab_widths, min_text_widths = Rendering.calculate_responsive_tab_widths(ctx, tabs, config, tabs_available_width, true)
  else
    final_tab_widths, min_text_widths = Rendering.calculate_responsive_tab_widths(ctx, tabs, config, tabs_available_width, false)
  end

  -- Calculate visible tabs
  local visible_indices, overflow_count, tabs_width
  if final_tab_widths then
    visible_indices = {}
    local current_width = 0
    local spacing_val = config.spacing or 0
    local total_buffer = 10

    for i, tab in ipairs(tabs) do
      local tab_width = final_tab_widths[i]
      local effective_spacing = (i > 1) and spacing_val or 0
      if i > 1 and i <= #tabs and spacing_val == 0 then
        effective_spacing = -1
      end
      local needed = tab_width + effective_spacing

      if i == 1 and #tabs == 1 then
        visible_indices[#visible_indices + 1] = i
        local max_single_tab_width = tabs_available_width
        final_tab_widths[i] = math.min(tab_width, max_single_tab_width)
        current_width = final_tab_widths[i]
      elseif current_width + needed <= tabs_available_width + total_buffer then
        visible_indices[#visible_indices + 1] = i
        current_width = current_width + needed
      else
        break
      end
    end

    overflow_count = #tabs - #visible_indices
    tabs_width = current_width

    -- Re-extend visible tabs to fill space when at edge
    if overflow_at_edge then
      if overflow_count > 0 and #visible_indices > 0 then
        local visible_tabs = {}
        for _, idx in ipairs(visible_indices) do
          visible_tabs[#visible_tabs + 1] = tabs[idx]
        end

        local visible_widths, _ = Rendering.calculate_responsive_tab_widths(ctx, visible_tabs, config, tabs_available_width, true)

        local verify_total = 0
        for i = 1, #visible_widths do
          verify_total = verify_total + visible_widths[i]
          if i < #visible_widths then
            verify_total = verify_total + (spacing_val == 0 and -1 or spacing_val)
          end
        end

        local diff = tabs_available_width - verify_total
        if diff ~= 0 and #visible_widths > 0 then
          visible_widths[#visible_widths] = visible_widths[#visible_widths] + diff
        end

        local remapped_widths = {}
        for i, idx in ipairs(visible_indices) do
          remapped_widths[idx] = visible_widths[i]
        end
        final_tab_widths = remapped_widths
        tabs_width = tabs_available_width
      elseif overflow_count == 0 and #visible_indices > 0 then
        local verify_total = 0
        for i, idx in ipairs(visible_indices) do
          verify_total = verify_total + final_tab_widths[idx]
          if i < #visible_indices then
            verify_total = verify_total + (spacing_val == 0 and -1 or spacing_val)
          end
        end

        local diff = tabs_available_width - verify_total
        if diff ~= 0 and #visible_indices > 0 then
          local last_idx = visible_indices[#visible_indices]
          final_tab_widths[last_idx] = final_tab_widths[last_idx] + diff
        end
        tabs_width = tabs_available_width
      end
    end
  else
    visible_indices, overflow_count, tabs_width = Rendering.calculate_visible_tabs(ctx, tabs, config, tabs_available_width)
  end

  -- Store cached widths
  state._cached_tab_widths = final_tab_widths
  state._cached_should_extend = overflow_at_edge

  Animation.init_tab_positions(state, tabs, tabs_start_x, ctx, config, tabs_available_width, overflow_at_edge)

  -- Recalculate overflow button width based on content
  if overflow_count > 0 then
    local count_text = tostring(overflow_count)
    local text_w = ImGui.CalcTextSize(ctx, count_text)
    overflow_width = math.max(overflow_cfg.min_width or 21, text_w + (overflow_cfg.padding_x or 8) * 2)
  end

  -- Calculate total width
  local tabs_total_width
  if overflow_at_edge then
    tabs_total_width = tabs_max_width
  else
    tabs_total_width = tabs_width + overflow_width
    if spacing > 0 then
      tabs_total_width = tabs_total_width + spacing
    else
      tabs_total_width = tabs_total_width - 1
    end
  end

  -- Draw track background
  if config.track and config.track.enabled then
    local track_start_x = x
    if not config.track.include_plus_button then
      track_start_x = tabs_start_x
    end

    Rendering.draw_track(ctx, dl, track_start_x, y,
               tabs_start_x - track_start_x + tabs_total_width,
               height, config, corner_rounding)
  end

  -- Draw plus button
  local plus_corner = corner_rounding and {
    round_top_left = corner_rounding.round_top_left,
    round_top_right = false,
    rounding = corner_rounding.rounding,
  } or nil

  local plus_clicked, _ = Rendering.draw_plus_button(ctx, dl, x, y, plus_width, height, config, unique_id, plus_corner)

  if plus_clicked and config.on_tab_create then
    config.on_tab_create()
  end

  -- Calculate responsive widths for drawing
  local responsive_widths
  if overflow_at_edge and final_tab_widths then
    responsive_widths = {}
    for i = 1, #tabs do
      responsive_widths[i] = final_tab_widths[i] or Rendering.calculate_tab_width(ctx, tabs[i].label or 'Tab', config, tabs[i].chip_color ~= nil)
    end
  else
    local widths, _ = Rendering.calculate_responsive_tab_widths(ctx, tabs, config, tabs_available_width, overflow_at_edge)
    responsive_widths = widths
  end

  -- Calculate overflow button position
  local overflow_x
  if overflow_at_edge then
    overflow_x = x + available_width - overflow_width
  else
    overflow_x = tabs_start_x + tabs_width
    if spacing > 0 then
      overflow_x = overflow_x + spacing
    else
      overflow_x = overflow_x - 1
    end
  end

  -- Handle tab dragging
  Animation.handle_drag_reorder(ctx, state, tabs, config, tabs_start_x, tabs_available_width, overflow_at_edge, overflow_x)
  Animation.finalize_drag(ctx, state, config, tabs, tabs_start_x, overflow_x, responsive_widths)
  Animation.update_tab_positions(ctx, state, config, tabs, tabs_start_x, tabs_available_width, overflow_at_edge)

  local clicked_tab_id = nil
  local id_to_delete = nil

  -- Apply clipping
  ImGui.DrawList_PushClipRect(dl, x, y, x + available_width, y + height, true)

  -- Draw visible tabs
  for i, tab_data in ipairs(tabs) do
    local is_visible = false
    local is_last_visible = false
    for idx, vis_idx in ipairs(visible_indices) do
      if vis_idx == i then
        is_visible = true
        is_last_visible = (idx == #visible_indices)
        break
      end
    end

    if is_visible then
      local pos = state.tab_positions[tab_data.id]
      if pos then
        local tab_w = responsive_widths[i] or Rendering.calculate_tab_width(ctx, tab_data.label or 'Tab', config, tab_data.chip_color ~= nil)
        local tab_x = (pos.current_x + 0.5) // 1

        if state.dragging_tab and state.dragging_tab.id == tab_data.id then
          if state.dragging_tab.clamped_x then
            tab_x = (state.dragging_tab.clamped_x + 0.5) // 1
          else
            local mx = ImGui.GetMousePos(ctx)
            local unclamped_x = mx - state.dragging_tab.offset_x
            local min_x = tabs_start_x
            local max_x = overflow_x - tab_w
            tab_x = math.floor(math.max(min_x, math.min(max_x, unclamped_x)) + 0.5)
          end
        end

        -- Calculate render width for border overlap
        local render_width = tab_w
        local next_visible_idx = nil
        for j = i + 1, #tabs do
          for _, vis_idx in ipairs(visible_indices) do
            if vis_idx == j then
              next_visible_idx = j
              break
            end
          end
          if next_visible_idx then break end
        end

        if next_visible_idx then
          local next_pos = state.tab_positions[tabs[next_visible_idx].id]
          if next_pos then
            local next_x = (next_pos.current_x + 0.5) // 1
            if state.dragging_tab and state.dragging_tab.id == tabs[next_visible_idx].id then
              if state.dragging_tab.clamped_x then
                next_x = (state.dragging_tab.clamped_x + 0.5) // 1
              end
            end
            local distance_to_next = next_x - tab_x
            render_width = math.max(tab_w, distance_to_next + 1)
          end
        elseif is_last_visible then
          local target_x = overflow_x
          local distance_to_target = target_x - tab_x
          render_width = distance_to_target + 1
        end

        render_width = math.max(1, render_width)
        render_width = (render_width + 0.5) // 1

        local is_active = (tab_data.id == active_tab_id)
        local clicked, delete_requested = Rendering.draw_tab(
          ctx, dl, tab_data, is_active,
          i, tab_x, y, render_width, height,
          state, config, unique_id, animator, nil
        )

        if clicked and not (state.dragging_tab or ImGui.IsMouseDragging(ctx, 0)) then
          clicked_tab_id = tab_data.id
        end

        if delete_requested then
          id_to_delete = tab_data.id
        end
      end
    end
  end

  -- Draw overflow button
  local overflow_corner = corner_rounding and {
    round_top_left = false,
    round_top_right = corner_rounding.round_top_right,
    rounding = corner_rounding.rounding,
  } or nil

  local overflow_clicked = Rendering.draw_overflow_button(
    ctx, dl, overflow_x, y, overflow_width, height,
    config, overflow_count, unique_id, overflow_corner
  )

  if overflow_clicked and config.on_overflow_clicked then
    config.on_overflow_clicked()
  end

  -- Draw clip edge borders
  local panel_right = x + available_width
  if tabs_start_x + tabs_width > panel_right or (overflow_at_edge and overflow_x + overflow_width > panel_right) then
    local border_color = 0x000000FF
    ImGui.DrawList_AddLine(dl, panel_right, y, panel_right, y + height, border_color, 1)
  end

  ImGui.DrawList_PopClipRect(dl)

  -- Handle tab click
  if clicked_tab_id and config.on_tab_change then
    config.on_tab_change(clicked_tab_id)
  end

  -- Handle tab deletion
  if id_to_delete and #tabs > 1 then
    for i, tab in ipairs(tabs) do
      if tab.id == id_to_delete then
        Animation.enable_animation_for_affected_tabs(state, tabs, i + 1)
        break
      end
    end

    if animator then
      animator:destroy(id_to_delete)
      state.pending_delete_id = id_to_delete

      if id_to_delete == active_tab_id and config.on_tab_change then
        for i, tab in ipairs(tabs) do
          if tab.id ~= id_to_delete then
            config.on_tab_change(tab.id)
            break
          end
        end
      end
    else
      if id_to_delete == active_tab_id and config.on_tab_change then
        for i, tab in ipairs(tabs) do
          if tab.id ~= id_to_delete then
            config.on_tab_change(tab.id)
            break
          end
        end
      end

      if config.on_tab_delete then
        config.on_tab_delete(id_to_delete)
      end
    end
  end

  if state.pending_delete_id and animator then
    if not animator:is_destroying(state.pending_delete_id) then
      if config.on_tab_delete then
        config.on_tab_delete(state.pending_delete_id)
      end
      state.pending_delete_id = nil
    end
  end

  return plus_width + (spacing > 0 and spacing or -1) + tabs_total_width
end

function M.Measure(ctx, config, state)
  state = state or {}
  config = config or {}

  local plus_width = (config.plus_button and config.plus_button.width) or 23
  local spacing = config.spacing or 0

  local tabs = state.tabs or {}

  if #tabs == 0 then
    return plus_width
  end

  local total = plus_width
  if spacing > 0 then
    total = total + spacing
  else
    total = total - 1
  end

  for i, tab in ipairs(tabs) do
    local has_chip = tab.chip_color ~= nil
    local tab_w = Rendering.calculate_tab_width(ctx, tab.label or 'Tab', config, has_chip)
    total = total + tab_w

    local effective_spacing = spacing
    if i < #tabs and spacing == 0 then
      effective_spacing = -1
    end

    if i < #tabs then
      total = total + effective_spacing
    end
  end

  return total
end

return M
