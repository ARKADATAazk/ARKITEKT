-- @noindex
-- Arkitekt/gui/widgets/chip_list/list.lua
-- Chip list container with multiple layout modes

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Chip = require('arkitekt.gui.widgets.data.chip')
local Colors = require('arkitekt.core.colors')
local ResponsiveGrid = require('arkitekt.gui.systems.responsive_grid')
local DragDrop = require('arkitekt.gui.systems.drag_drop')
local MouseUtil = require('arkitekt.gui.systems.mouse_util')

local M = {}

local function _filter_items(items, search_text)
  if search_text == "" then return items end
  local filtered = {}
  for _, item in ipairs(items) do
    if item.label:lower():find(search_text:lower(), 1, true) then
      filtered[#filtered + 1] = item
    end
  end
  return filtered
end

local function _draw_chip(ctx, item, is_selected, opts)
  -- Determine colors based on style
  local item_color = item.color
  local bg_color = opts.bg_color
  local text_color = nil

  -- For ACTION style, item.color is used as bg_color
  if opts.style == Chip.STYLE.ACTION and item_color then
    -- Apply unselected_alpha to entire chip (bg + text) if not selected
    if not is_selected and opts.unselected_alpha then
      bg_color = Colors.with_alpha(item_color, opts.unselected_alpha)
      -- Also apply alpha to text for consistent opacity
      local auto_text = Colors.auto_text_color(item_color)
      text_color = Colors.with_alpha(auto_text, opts.unselected_alpha)
    else
      bg_color = item_color
      -- Auto text color for readability
      text_color = Colors.auto_text_color(item_color)
    end
  elseif item_color and not is_selected and opts.unselected_alpha then
    -- For other styles (DOT), apply alpha to the dot color
    item_color = Colors.with_alpha(item_color, opts.unselected_alpha)
  end

  return Chip.draw(ctx, {
    id = "##chip_" .. (item.id or item.label),
    style = opts.style,
    label = item.label,
    color = item_color,
    height = opts.chip_height,
    is_selected = is_selected,
    bg_color = bg_color,
    text_color = text_color,
    dot_size = opts.dot_size,
    dot_spacing = opts.dot_spacing,
    rounding = opts.rounding,
    padding_h = opts.padding_h,
    explicit_width = opts.explicit_width,
    text_align = opts.text_align,
    border_thickness = opts.border_thickness,
  })
end

function M.draw(ctx, items, opts)
  opts = opts or {}
  local filtered = _filter_items(items, opts.search_text or "")
  if #filtered == 0 then return nil end

  local chip_spacing = opts.chip_spacing or 8
  local line_spacing = opts.line_spacing or 8
  local text_h = ImGui.GetTextLineHeight(ctx)
  local chip_height = opts.chip_height or (text_h + 6)
  local available_width = opts.max_width or ImGui.GetContentRegionAvail(ctx)
  local selected_ids = opts.selected_ids or {}
  local style = opts.style or (opts.use_dot_style and Chip.STYLE.DOT or Chip.STYLE.PILL)
  local justified = opts.justified or false
  
  local clicked_id = nil
  local dragging_id = nil
  local right_clicked_id = nil
  local drag_type = opts.drag_type
  local drag_data_fn = opts.drag_data_fn  -- function(item) -> data table
  local drag_threshold = opts.drag_threshold or MouseUtil.DEFAULTS.DRAG_THRESHOLD

  local draw_opts = {
    style = style,
    chip_height = chip_height,
    bg_color = opts.bg_color,
    dot_size = opts.dot_size,
    dot_spacing = opts.dot_spacing,
    rounding = opts.rounding or 4,
    padding_h = opts.padding_h or (style == Chip.STYLE.DOT and 12 or 14),
    unselected_alpha = opts.unselected_alpha,
  }

  -- Helper to handle drag/click differentiation for a chip
  -- When drag is enabled, we completely handle click detection ourselves
  -- to ensure we wait and see if user wants to drag before triggering click
  local function handle_chip_interaction(item)
    if not drag_type then
      -- No drag enabled, use ImGui's native click detection
      return ImGui.IsItemClicked(ctx, 0)
    end

    local item_id = "chip_drag_" .. (item.id or item.label)

    -- Start tracking on mouse down over this item
    if ImGui.IsItemHovered(ctx) and ImGui.IsMouseClicked(ctx, 0) then
      MouseUtil.start_potential_drag(ctx, item_id, 0)
    end

    -- If we're tracking this item
    if MouseUtil.is_tracking(item_id) then
      -- Check if drag threshold exceeded
      MouseUtil.check_drag_started(ctx, item_id, drag_threshold)

      -- If we're now in drag mode, handle the drag source
      if MouseUtil.is_dragging(item_id) then
        if ImGui.BeginDragDropSource(ctx, ImGui.DragDropFlags_SourceAllowNullID) then
          local payload_data = drag_data_fn and drag_data_fn(item) or { id = item.id, label = item.label }
          local payload_str = type(payload_data) == "table"
            and DragDrop._serialize(payload_data)
            or tostring(payload_data)
          ImGui.SetDragDropPayload(ctx, drag_type, payload_str)
          -- Set global drag type for potential target indicators
          DragDrop.set_active_drag_type(drag_type)
          -- Draw drag preview
          DragDrop.draw_preview_text(ctx, item.label)
          ImGui.EndDragDropSource(ctx)
          dragging_id = item.id
        end

        -- Clear on mouse release
        if ImGui.IsMouseReleased(ctx, 0) then
          MouseUtil.clear(item_id)
          DragDrop.clear_active_drag_type()
        end

        return false  -- Dragging, not a click
      end

      -- Not dragging yet - check if mouse was released (this is a click!)
      if ImGui.IsMouseReleased(ctx, 0) then
        MouseUtil.clear(item_id)
        return true  -- Mouse released without exceeding drag threshold = click
      end

      -- Still tracking, waiting to see if drag or click
      return false
    end

    -- Not tracking this item
    return false
  end
  
  if justified then
    local min_widths = {}
    for i, item in ipairs(filtered) do
      min_widths[i] = Chip.calculate_width(ctx, item.label, draw_opts)
    end

    local layout = ResponsiveGrid.calculate_justified_layout(filtered, {
      available_width = available_width,
      min_widths = min_widths,
      gap = chip_spacing,
      max_stretch_ratio = opts.max_stretch_ratio or 1.5,
    })

    local row_start_x = ImGui.GetCursorPosX(ctx)

    for row_idx, row in ipairs(layout) do
      if row_idx > 1 then ImGui.SetCursorPosX(ctx, row_start_x) end

      for cell_idx, cell in ipairs(row) do
        draw_opts.explicit_width = cell.final_width
        _draw_chip(ctx, cell.item, selected_ids[cell.item.id], draw_opts)
        local is_click = handle_chip_interaction(cell.item)
        if is_click then clicked_id = cell.item.id end
        -- Check for right-click
        if ImGui.IsItemClicked(ctx, 1) then right_clicked_id = cell.item.id end
        if cell_idx < #row then ImGui.SameLine(ctx, 0, chip_spacing) end
      end

      if row_idx < #layout then ImGui.Dummy(ctx, 0, line_spacing) end
    end
  else
    local cursor_start_x = ImGui.GetCursorPosX(ctx)
    local current_x = 0
    local items_in_row = 0

    for _, item in ipairs(filtered) do
      local chip_width = Chip.calculate_width(ctx, item.label, draw_opts)
      local space_needed = chip_width + (items_in_row > 0 and chip_spacing or 0)

      if items_in_row > 0 and (current_x + space_needed) > available_width then
        ImGui.Dummy(ctx, 0, line_spacing)
        ImGui.SetCursorPosX(ctx, cursor_start_x)
        current_x = 0
        items_in_row = 0
      end

      if items_in_row > 0 then
        ImGui.SameLine(ctx, 0, chip_spacing)
        current_x = current_x + chip_spacing
      end

      draw_opts.explicit_width = nil
      _draw_chip(ctx, item, selected_ids[item.id], draw_opts)
      local is_click = handle_chip_interaction(item)
      if is_click then clicked_id = item.id end
      -- Check for right-click
      if ImGui.IsItemClicked(ctx, 1) then right_clicked_id = item.id end

      current_x = current_x + chip_width
      items_in_row = items_in_row + 1
    end
  end

  return clicked_id, dragging_id, right_clicked_id
end

function M.draw_vertical(ctx, items, opts)
  opts = opts or {}
  local filtered = _filter_items(items, opts.search_text or "")
  if #filtered == 0 then return nil end
  
  local item_height = opts.item_height or 28
  local selected_ids = opts.selected_ids or {}
  local style = (opts.use_dot_style ~= false) and Chip.STYLE.DOT or Chip.STYLE.PILL
  
  local clicked_id = nil
  local draw_opts = {
    style = style,
    chip_height = item_height,
    bg_color = opts.bg_color,
    dot_size = opts.dot_size,
    dot_spacing = opts.dot_spacing,
    rounding = opts.rounding or 4,
    padding_h = opts.padding_h or 12,
  }
  
  for _, item in ipairs(filtered) do
    local clicked = _draw_chip(ctx, item, selected_ids[item.id], draw_opts)
    if clicked then clicked_id = item.id end
    ImGui.Dummy(ctx, 0, 4)
  end
  
  return clicked_id
end

function M.draw_columns(ctx, items, opts)
  opts = opts or {}
  local filtered = _filter_items(items, opts.search_text or "")
  if #filtered == 0 then return nil end
  
  local selected_ids = opts.selected_ids or {}
  local style = opts.use_dot_style and Chip.STYLE.DOT or Chip.STYLE.PILL
  local column_width = opts.column_width or 200
  local column_spacing = opts.column_spacing or 20
  local item_spacing = opts.item_spacing or 4
  local text_h = ImGui.GetTextLineHeight(ctx)
  local item_height = opts.item_height or (text_h + 8)
  
  local clicked_id = nil
  local draw_opts = {
    style = style,
    chip_height = item_height,
    bg_color = opts.bg_color,
    dot_size = opts.dot_size or 8,
    dot_spacing = opts.dot_spacing or 10,
    rounding = opts.rounding or 4,
    padding_h = opts.padding_h or 12,
    explicit_width = column_width,
    text_align = "left",
    border_thickness = opts.border_thickness,
  }
  
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local max_height = opts.max_height or avail_h
  local items_per_column = math.floor(max_height / (item_height + item_spacing))
  if items_per_column < 1 then items_per_column = 1 end

  local num_columns = math.ceil(#filtered / items_per_column)

  -- Single column should fill full width (honoring padding)
  local actual_column_width = column_width
  if num_columns == 1 then
    actual_column_width = avail_w
    draw_opts.explicit_width = actual_column_width
  end

  local start_x = ImGui.GetCursorPosX(ctx)
  local start_y = ImGui.GetCursorPosY(ctx)

  -- Center items when sparse (fewer items than fill a column) and NOT single column
  if opts.center_when_sparse and #filtered < items_per_column and num_columns > 1 then
    local total_grid_width = num_columns * (actual_column_width + column_spacing) - column_spacing
    local center_offset = math.floor((avail_w - total_grid_width) / 2)
    if center_offset > 0 then
      start_x = start_x + center_offset
    end
  end

  for col = 0, num_columns - 1 do
    for row = 0, items_per_column - 1 do
      local idx = col * items_per_column + row + 1
      if idx > #filtered then break end

      ImGui.SetCursorPos(ctx,
        start_x + col * (actual_column_width + column_spacing),
        start_y + row * (item_height + item_spacing))

      local clicked = _draw_chip(ctx, filtered[idx], selected_ids[filtered[idx].id], draw_opts)
      if clicked then clicked_id = filtered[idx].id end
    end
  end
  
  local total_height = math.min(#filtered, items_per_column) * (item_height + item_spacing)
  local total_width = num_columns * (actual_column_width + column_spacing) - column_spacing
  ImGui.SetCursorPos(ctx, start_x, start_y + total_height)
  ImGui.Dummy(ctx, total_width, 0)

  return clicked_id
end

function M.draw_grid(ctx, items, opts)
  opts = opts or {}
  local filtered = _filter_items(items, opts.search_text or "")
  if #filtered == 0 then return nil end
  
  local avail_width = opts.width or ImGui.GetContentRegionAvail(ctx)
  local cols = opts.cols or 3
  local gap = opts.gap or 8
  local selected_ids = opts.selected_ids or {}
  local style = opts.use_dot_style and Chip.STYLE.DOT or Chip.STYLE.PILL
  local justified = opts.justified or false
  local text_h = ImGui.GetTextLineHeight(ctx)
  local chip_height = opts.chip_height or (text_h + 6)
  
  local clicked_id = nil
  local draw_opts = {
    style = style,
    chip_height = chip_height,
    bg_color = opts.bg_color,
    dot_size = opts.dot_size or 7,
    dot_spacing = opts.dot_spacing or 7,
    rounding = opts.rounding or 5,
    padding_h = opts.padding_h or 8,
  }
  
  if justified then
    local min_widths = {}
    for i, item in ipairs(filtered) do
      min_widths[i] = Chip.calculate_width(ctx, item.label, draw_opts)
    end
    
    local layout = ResponsiveGrid.calculate_justified_layout(filtered, {
      available_width = avail_width,
      min_widths = min_widths,
      gap = gap,
      max_stretch_ratio = opts.max_stretch_ratio or 1.4,
    })
    
    local row_start_x = ImGui.GetCursorPosX(ctx)
    
    for row_idx, row in ipairs(layout) do
      if row_idx > 1 then ImGui.SetCursorPosX(ctx, row_start_x) end
      
      for cell_idx, cell in ipairs(row) do
        if cell_idx > 1 then ImGui.SameLine(ctx, 0, gap) end
        
        draw_opts.explicit_width = cell.final_width
        local clicked = _draw_chip(ctx, cell.item, selected_ids[cell.item.id], draw_opts)
        if clicked then clicked_id = cell.item.id end
      end
      
      if row_idx < #layout then ImGui.Dummy(ctx, 0, gap) end
    end
  else
    local row_start_x = ImGui.GetCursorPosX(ctx)
    local col_width = (avail_width - (cols - 1) * gap) / cols
    draw_opts.explicit_width = col_width
    
    for i, item in ipairs(filtered) do
      local col = ((i - 1) % cols)
      
      if col > 0 then
        ImGui.SameLine(ctx, 0, gap)
      elseif i > 1 then
        ImGui.Dummy(ctx, 0, gap)
        ImGui.SetCursorPosX(ctx, row_start_x)
      end
      
      local clicked = _draw_chip(ctx, item, selected_ids[item.id], draw_opts)
      if clicked then clicked_id = item.id end
    end
  end
  
  return clicked_id
end

function M.draw_auto(ctx, items, opts)
  opts = opts or {}
  local layout_mode = opts.layout_mode or "flow"
  
  if layout_mode == "columns" then
    return M.draw_columns(ctx, items, opts)
  elseif layout_mode == "grid" then
    return M.draw_grid(ctx, items, opts)
  elseif layout_mode == "vertical" then
    return M.draw_vertical(ctx, items, opts)
  else
    return M.draw(ctx, items, opts)
  end
end

return M