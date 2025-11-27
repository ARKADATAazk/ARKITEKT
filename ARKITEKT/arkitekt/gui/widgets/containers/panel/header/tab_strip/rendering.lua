-- @noindex
-- arkitekt/gui/widgets/containers/panel/header/tab_strip/rendering.lua
-- Tab rendering logic: drawing tabs, buttons, track background

local ImGuiLoader = require('arkitekt.gui.imgui_loader')
local ImGui = ImGuiLoader.get()
local Theme = require('arkitekt.core.theme')
local InteractionBlocking = require('arkitekt.gui.interaction.blocking')
local Colors = require('arkitekt.core.colors')
local ContextMenu = require('arkitekt.gui.widgets.overlays.context_menu')
local Chip = require('arkitekt.gui.widgets.data.chip')
local ColorPickerMenu = require('arkitekt.gui.widgets.menus.color_picker_menu')

local hexrgb = Colors.hexrgb

local M = {}

-- Animation module reference (set via set_animation_module)
local Animation = nil

function M.set_animation_module(anim_module)
  Animation = anim_module
end

-- Dynamic color lookup function for theme reactivity
-- Called each frame to get fresh colors from Theme.COLORS
function M.get_tab_colors()
  local C = Theme.COLORS
  return {
    bg_color = C.BG_BASE,
    bg_hover_color = C.BG_HOVER,
    bg_active_color = C.BG_ACTIVE,
    border_outer_color = C.BORDER_OUTER,
    border_inner_color = C.BORDER_INNER,
    border_hover_color = C.BORDER_HOVER,
    border_active_color = C.BORDER_FOCUS,
    text_color = C.TEXT_DIMMED,
    text_hover_color = C.TEXT_HOVER,
    text_active_color = C.TEXT_ACTIVE,
  }
end

function M.get_corner_flags(corner_rounding)
  if not corner_rounding then
    return 0
  end

  local flags = 0
  if corner_rounding.round_top_left then
    flags = flags | ImGui.DrawFlags_RoundCornersTopLeft
  end
  if corner_rounding.round_top_right then
    flags = flags | ImGui.DrawFlags_RoundCornersTopRight
  end

  return flags
end

function M.calculate_tab_width(ctx, label, config, has_chip)
  local text_w = ImGui.CalcTextSize(ctx, label)
  local chip_width = has_chip and 20 or 0
  local min_width = config.min_width or 50
  local max_width = config.max_width or 180
  local padding_x = config.padding_x or 5

  local ideal_width = text_w + padding_x * 2 + chip_width
  return math.min(max_width, math.max(min_width, ideal_width))
end

function M.calculate_responsive_tab_widths(ctx, tabs, config, available_width, should_extend)
  local min_width = config.min_width or 50
  local max_width = config.max_width or 180
  local padding_x = config.padding_x or 5
  local spacing = config.spacing or 0

  if #tabs == 0 then return {} end

  -- Calculate natural/ideal widths for all tabs
  local natural_widths = {}
  local min_text_widths = {}
  local total_natural = 0
  local total_spacing = 0

  for i, tab in ipairs(tabs) do
    local has_chip = tab.chip_color ~= nil
    local text_w = ImGui.CalcTextSize(ctx, tab.label or "Tab")

    -- Calculate width based on actual rendering
    local left_margin = math.max(0, padding_x - 3)
    local right_margin = 6
    local actual_chip_space = has_chip and 12 or 0
    local actual_text_width = (text_w + left_margin + right_margin + actual_chip_space + 0.5) // 1

    min_text_widths[i] = math.max(20, actual_text_width)

    local natural = min_text_widths[i]
    natural = math.min(max_width, natural)
    natural = (natural + 0.5) // 1

    natural_widths[i] = natural
    total_natural = total_natural + natural

    if i < #tabs then
      local effective_spacing = (spacing == 0 and -1 or spacing)
      total_spacing = total_spacing + effective_spacing
    end
  end

  local total_with_spacing = total_natural + total_spacing

  -- STAGE 1: Always expand tabs with clipped text
  if total_with_spacing < available_width then
    local extra_space = available_width - total_with_spacing

    local clipped_tabs = {}
    local total_deficit = 0
    for i, tab in ipairs(tabs) do
      if min_text_widths[i] > natural_widths[i] then
        local deficit = math.min(min_text_widths[i] - natural_widths[i], extra_space)
        clipped_tabs[i] = deficit
        total_deficit = total_deficit + deficit
      end
    end

    if total_deficit > 0 and next(clipped_tabs) then
      local space_to_distribute = math.min(extra_space, total_deficit)

      for i, deficit in pairs(clipped_tabs) do
        local proportion = deficit / total_deficit
        local extra = (space_to_distribute * proportion + 0.5) // 1
        natural_widths[i] = natural_widths[i] + extra
      end

      total_with_spacing = 0
      for i = 1, #tabs do
        total_with_spacing = total_with_spacing + natural_widths[i]
        if i < #tabs then
          local effective_spacing = (spacing == 0 and -1 or spacing)
          total_with_spacing = total_with_spacing + effective_spacing
        end
      end
    end
  end

  -- STAGE 2: If should_extend, distribute remaining space evenly
  if should_extend and total_with_spacing < available_width then
    local extra_space = available_width - total_with_spacing
    local base_per_tab = (extra_space / #tabs) // 1
    local remainder = extra_space - (base_per_tab * #tabs)

    for i = 1, #tabs do
      natural_widths[i] = natural_widths[i] + base_per_tab
      if i <= remainder then
        natural_widths[i] = natural_widths[i] + 1
      end
    end
  end

  return natural_widths, min_text_widths
end

function M.calculate_visible_tabs(ctx, tabs, config, available_width)
  local visible_indices = {}
  local current_width = 0
  local spacing = config.spacing or 0

  for i, tab in ipairs(tabs) do
    local has_chip = tab.chip_color ~= nil
    local tab_width = M.calculate_tab_width(ctx, tab.label or "Tab", config, has_chip)
    local effective_spacing = (i > 1) and spacing or 0
    if i > 1 and i <= #tabs and spacing == 0 then
      effective_spacing = -1
    end
    local needed = tab_width + effective_spacing

    if current_width + needed <= available_width then
      visible_indices[#visible_indices + 1] = i
      current_width = current_width + needed
    else
      break
    end
  end

  local overflow_count = #tabs - #visible_indices

  return visible_indices, overflow_count, current_width
end

function M.draw_plus_button(ctx, dl, x, y, width, height, config, unique_id, corner_rounding)
  local btn_cfg = config.plus_button or {}

  -- Apply dynamic colors from theme
  for k, v in pairs(M.get_tab_colors()) do
    if btn_cfg[k] == nil then btn_cfg[k] = v end
  end

  local is_hovered = InteractionBlocking.is_mouse_hovering_rect_unblocked(ctx, x, y, x + width, y + height)
  local is_active = ImGui.IsMouseDown(ctx, 0) and is_hovered

  local bg_color = btn_cfg.bg_color
  local border_inner = btn_cfg.border_inner_color
  local icon_color = btn_cfg.text_color

  if is_active then
    bg_color = btn_cfg.bg_active_color
    border_inner = btn_cfg.border_active_color or btn_cfg.border_hover_color
    icon_color = btn_cfg.text_active_color or btn_cfg.text_hover_color
  elseif is_hovered then
    bg_color = btn_cfg.bg_hover_color
    border_inner = btn_cfg.border_hover_color
    icon_color = btn_cfg.text_hover_color
  end

  local rounding = corner_rounding and corner_rounding.rounding or 4
  local inner_rounding = math.max(0, rounding - 2)
  local corner_flags = M.get_corner_flags(corner_rounding)

  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, bg_color, inner_rounding, corner_flags)
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + width - 1, y + height - 1, border_inner, inner_rounding, corner_flags, 1)
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, btn_cfg.border_outer_color or config.border_outer_color, inner_rounding, corner_flags, 1)

  local center_x = x + width * 0.5
  local center_y = y + height * 0.5
  local cross_size = 7
  local cross_thickness = 1

  ImGui.DrawList_AddRectFilled(dl,
    center_x - cross_size * 0.5, center_y - cross_thickness * 0.5,
    center_x + cross_size * 0.5, center_y + cross_thickness * 0.5,
    icon_color)

  ImGui.DrawList_AddRectFilled(dl,
    center_x - cross_thickness * 0.5, center_y - cross_size * 0.5,
    center_x + cross_thickness * 0.5, center_y + cross_size * 0.5,
    icon_color)

  ImGui.SetCursorScreenPos(ctx, x, y)
  local clicked = ImGui.InvisibleButton(ctx, "##plus_" .. unique_id, width, height)

  return clicked, width
end

function M.draw_overflow_button(ctx, dl, x, y, width, height, config, hidden_count, unique_id, corner_rounding)
  local btn_cfg = config.overflow_button or {}

  -- Apply dynamic colors from theme
  for k, v in pairs(M.get_tab_colors()) do
    if btn_cfg[k] == nil then btn_cfg[k] = v end
  end

  local display_text = (hidden_count > 0) and tostring(hidden_count) or "⋮"

  local is_hovered = InteractionBlocking.is_mouse_hovering_rect_unblocked(ctx, x, y, x + width, y + height)
  local is_active = ImGui.IsMouseDown(ctx, 0) and is_hovered

  local bg_color = btn_cfg.bg_color
  local border_inner = btn_cfg.border_inner_color
  local text_color = btn_cfg.text_color

  if is_active then
    bg_color = btn_cfg.bg_active_color
    border_inner = btn_cfg.border_active_color or btn_cfg.border_hover_color
    text_color = btn_cfg.text_active_color or btn_cfg.text_hover_color
  elseif is_hovered then
    bg_color = btn_cfg.bg_hover_color
    border_inner = btn_cfg.border_hover_color
    text_color = btn_cfg.text_hover_color
  end

  local rounding = corner_rounding and corner_rounding.rounding or 4
  local inner_rounding = math.max(0, rounding - 2)
  local corner_flags = M.get_corner_flags(corner_rounding)

  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, bg_color, inner_rounding, corner_flags)
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + width - 1, y + height - 1, border_inner, inner_rounding, corner_flags, 1)
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, btn_cfg.border_outer_color or config.border_outer_color, inner_rounding, corner_flags, 1)

  local text_w = ImGui.CalcTextSize(ctx, display_text)
  local text_x = x + (width - text_w) * 0.5
  local text_y = y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5
  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, display_text)

  ImGui.SetCursorScreenPos(ctx, x, y)
  local clicked = ImGui.InvisibleButton(ctx, "##overflow_" .. unique_id, width, height)

  return clicked
end

function M.draw_track(ctx, dl, x, y, width, height, config, corner_rounding)
  local track_cfg = config.track
  if not track_cfg or not track_cfg.enabled then return end

  local track_x = x - track_cfg.extend_left
  local track_y = y - track_cfg.extend_top
  local track_width = width + track_cfg.extend_left + track_cfg.extend_right
  local track_height = height + track_cfg.extend_top + track_cfg.extend_bottom

  local rounding = corner_rounding and corner_rounding.rounding or (track_cfg.rounding or 6)
  local corner_flags = M.get_corner_flags(corner_rounding)

  ImGui.DrawList_AddRectFilled(
    dl,
    track_x, track_y,
    track_x + track_width, track_y + track_height,
    track_cfg.bg_color or Theme.COLORS.BG_PANEL,
    rounding,
    corner_flags
  )

  if track_cfg.border_thickness and track_cfg.border_thickness > 0 then
    ImGui.DrawList_AddRect(
      dl,
      track_x, track_y,
      track_x + track_width, track_y + track_height,
      track_cfg.border_color or Theme.COLORS.BORDER_OUTER,
      rounding,
      corner_flags,
      track_cfg.border_thickness
    )
  end
end

function M.draw_tab(ctx, dl, tab_data, is_active, tab_index, x, y, width, height, state, config, unique_id, animator, corner_rounding)
  -- Apply dynamic colors from theme
  for k, v in pairs(M.get_tab_colors()) do
    if config[k] == nil then config[k] = v end
  end

  local label = tab_data.label or "Tab"
  local id = tab_data.id
  local chip_color = tab_data.chip_color
  local has_chip = chip_color ~= nil

  local is_spawning = animator and animator:is_spawning(id)
  local is_destroying = animator and animator:is_destroying(id)

  local render_x, render_y, render_w, render_h = x, y, width, height
  local alpha_factor = 1.0

  if is_spawning and animator.get_spawn_factor then
    local spawn_factor = animator:get_spawn_factor(id)
    local target_w = width * spawn_factor
    local offset_x = (width - target_w) * 0.5
    render_x = x + offset_x
    render_w = target_w
    alpha_factor = spawn_factor
  elseif is_destroying and animator.get_destroy_factor then
    local destroy_factor = animator:get_destroy_factor(id)
    local scale = 1.0 - destroy_factor
    local new_w = width * scale
    local new_h = height * scale
    local offset_x = (width - new_w) * 0.5
    local offset_y = (height - new_h) * 0.5
    render_x = x + offset_x
    render_y = y + offset_y
    render_w = new_w
    render_h = new_h
    alpha_factor = 1.0 - destroy_factor
  end

  local is_hovered = InteractionBlocking.is_mouse_hovering_rect_unblocked(ctx, render_x, render_y, render_x + render_w, render_y + render_h)
  local is_pressed = ImGui.IsMouseDown(ctx, 0) and is_hovered and not state.dragging_tab

  local apply_alpha = function(color, factor)
    local a = color & 0xFF
    local new_a = (a * factor) // 1
    return (color & 0xFFFFFF00) | new_a
  end

  local bg_color = config.bg_color
  local border_inner = config.border_inner_color
  local text_color = config.text_color

  if is_active then
    bg_color = config.bg_active_color
    border_inner = config.border_active_color
    text_color = config.text_active_color
  elseif is_pressed then
    bg_color = config.bg_active_color
    border_inner = config.border_hover_color
    text_color = config.text_hover_color
  elseif is_hovered then
    bg_color = config.bg_hover_color
    border_inner = config.border_hover_color
    text_color = config.text_hover_color
  end

  bg_color = apply_alpha(bg_color, alpha_factor)
  local border_outer = apply_alpha(config.border_outer_color, alpha_factor)
  border_inner = apply_alpha(border_inner, alpha_factor)
  text_color = apply_alpha(text_color, alpha_factor)

  local rounding = corner_rounding and corner_rounding.rounding or 0
  local inner_rounding = math.max(0, rounding - 2)
  local corner_flags = M.get_corner_flags(corner_rounding)

  ImGui.DrawList_AddRectFilled(dl, render_x, render_y, render_x + render_w, render_y + render_h,
                                bg_color, inner_rounding, corner_flags)

  ImGui.DrawList_AddRect(dl, render_x + 1, render_y + 1, render_x + render_w - 1, render_y + render_h - 1,
                         border_inner, inner_rounding, corner_flags, 1)

  ImGui.DrawList_AddRect(dl, render_x, render_y, render_x + render_w, render_y + render_h,
                         border_outer, inner_rounding, corner_flags, 1)

  -- Check if currently editing this tab
  local is_being_edited = Animation and Animation.is_editing_inline(state) and state.editing_state.id == id

  -- Render label and chip OR inline editor
  if is_being_edited then
    local edit_result, edit_action = Animation.handle_inline_edit_input(ctx, dl, state, id, render_x, render_y, render_w, render_h, chip_color)

    if edit_action == true then
      Animation.stop_inline_edit(state, true, config)
    elseif edit_action == false then
      Animation.stop_inline_edit(state, false, config)
    end
  else
    -- Render normal label and chip
    local content_x = render_x + (config.padding_x or 5)

    if has_chip then
      local chip_x = content_x + 2
      local chip_y = render_y + render_h * 0.5

      Chip.draw(ctx, {
        style = Chip.STYLE.INDICATOR,
        color = chip_color,
        draw_list = dl,
        x = chip_x,
        y = chip_y,
        radius = config.chip_radius or 4,
        is_selected = is_active,
        is_hovered = is_hovered,
        show_glow = is_active or is_hovered,
        glow_layers = 2,
        alpha_factor = alpha_factor,
      })

      content_x = content_x + 12
    end

    local text_w, text_h = ImGui.CalcTextSize(ctx, label)
    local text_x = content_x - 3
    local text_y = render_y + (render_h - text_h) * 0.5

    local text_max_w = render_x + render_w - text_x - 2
    if text_w > text_max_w then
      ImGui.DrawList_PushClipRect(dl, text_x, render_y,
                                  render_x + render_w - 2, render_y + render_h, true)
      ImGui.DrawList_AddText(dl, text_x, text_y, text_color, label)
      ImGui.DrawList_PopClipRect(dl)
    else
      ImGui.DrawList_AddText(dl, text_x, text_y, text_color, label)
    end
  end

  ImGui.SetCursorScreenPos(ctx, render_x, render_y)
  ImGui.InvisibleButton(ctx, "##tab_" .. id .. "_" .. unique_id, render_w, render_h)

  local clicked = ImGui.IsItemClicked(ctx, 0)
  local double_clicked = ImGui.IsItemClicked(ctx, 0) and ImGui.IsMouseDoubleClicked(ctx, 0)
  local right_clicked = ImGui.IsItemClicked(ctx, 1)

  -- Double-click to start inline editing
  if double_clicked and Animation and not Animation.is_editing_inline(state) then
    Animation.start_inline_edit(state, id, label)
    clicked = false
  end

  -- Check for Alt+click to delete
  local alt_held = ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) or ImGui.IsKeyDown(ctx, ImGui.Key_RightAlt)

  local DRAG_THRESHOLD = Animation and Animation.DRAG_THRESHOLD or 3.0

  if ImGui.IsItemActive(ctx) and not state.dragging_tab and not is_being_edited then
    local drag_delta_x, drag_delta_y = ImGui.GetMouseDragDelta(ctx, 0)
    local drag_distance = math.sqrt(drag_delta_x * drag_delta_x + drag_delta_y * drag_delta_y)

    if drag_distance > DRAG_THRESHOLD and ImGui.IsMouseDragging(ctx, 0) then
      local mx = ImGui.GetMousePos(ctx)
      state.dragging_tab = {
        id = id,
        index = tab_index,
        offset_x = mx - render_x,
        original_index = tab_index,
      }
    end
  end

  local delete_requested = false

  -- Alt+click to delete
  if clicked and alt_held then
    delete_requested = true
    clicked = false
  end

  if right_clicked then
    ImGui.OpenPopup(ctx, "##tab_context_" .. id .. "_" .. unique_id)
  end

  if ContextMenu.begin(ctx, "##tab_context_" .. id .. "_" .. unique_id, config.context_menu) then
    if ContextMenu.item(ctx, "Duplicate Playlist", config.context_menu) then
      if config.on_tab_duplicate then
        config.on_tab_duplicate(id)
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.Separator(ctx)

    if ContextMenu.item(ctx, "Delete Playlist", config.context_menu) then
      delete_requested = true
    end

    ColorPickerMenu.render(ctx, {
      current_color = chip_color,
      icon_font = config.icon_font,
      icon_font_size = config.icon_font_size or 12,
      on_select = function(color_int, color_hex, color_name)
        if config.on_tab_color_change then
          config.on_tab_color_change(id, color_int or false)
        end
      end,
    })

    ContextMenu.end_menu(ctx)
  end

  return clicked, delete_requested
end

return M
