-- @noindex
-- arkitekt/gui/widgets/tree/tree_table.lua
-- Multi-column Tree widget with headers, sorting, and column resizing

local ImGui = require('arkitekt.core.imgui')
local IdStack = require('arkitekt.core.id_stack')
local Config = require('arkitekt.gui.widgets.tree.config')
local State = require('arkitekt.gui.widgets.tree.core.state')
local Virtual = require('arkitekt.gui.widgets.tree.core.virtual')
local Selection = require('arkitekt.gui.widgets.tree.core.selection')
local Keyboard = require('arkitekt.gui.widgets.tree.core.keyboard')
local DragDrop = require('arkitekt.gui.widgets.tree.core.drag_drop')
local Rename = require('arkitekt.gui.widgets.tree.core.rename')
local NodeRenderer = require('arkitekt.gui.widgets.tree.render.node')
local Lines = require('arkitekt.gui.widgets.tree.render.lines')
local Icons = require('arkitekt.gui.widgets.tree.render.icons')

local M = {}

-- ============================================================================
-- COLUMN HEADER RENDERING
-- ============================================================================

local function draw_column_headers(ctx, dl, state, cfg, columns, x, y, w)
  local header_h = cfg.header_height
  local colors = cfg.colors

  -- Header background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + header_h, colors.header_bg)
  ImGui.DrawList_AddLine(dl, x, y + header_h, x + w, y + header_h, colors.header_border, 1)

  local current_x = x
  local mx, my = ImGui.GetMousePos(ctx)
  local header_hovered = mx >= x and mx < x + w and my >= y and my < y + header_h

  for col_idx, col in ipairs(columns) do
    local col_x = current_x
    local col_w = col.width
    local col_right = col_x + col_w

    -- Column separator
    if col_idx > 1 then
      ImGui.DrawList_AddLine(dl, col_x, y, col_x, y + header_h, colors.header_border, 1)
    end

    -- Check hover
    local col_hovered = header_hovered and mx >= col_x and mx < col_right

    -- Hover background
    if col_hovered and col.sortable then
      ImGui.DrawList_AddRectFilled(dl, col_x, y, col_right, y + header_h, 0x33333388)
    end

    -- Title
    local text_x = col_x + 6
    local text_y = y + (header_h - ImGui.CalcTextSize(ctx, 'Tg')) / 2
    ImGui.DrawList_AddText(dl, text_x, text_y, colors.header_text, col.title)

    -- Sort indicator
    if state.sort_column == col.id then
      local arrow_size = 4
      local arrow_x = col_right - arrow_size - 8
      local arrow_y = y + (header_h - arrow_size) / 2

      if state.sort_ascending then
        -- Up arrow
        ImGui.DrawList_AddTriangleFilled(dl,
          arrow_x + arrow_size / 2, arrow_y,
          arrow_x, arrow_y + arrow_size,
          arrow_x + arrow_size, arrow_y + arrow_size,
          colors.header_text)
      else
        -- Down arrow
        ImGui.DrawList_AddTriangleFilled(dl,
          arrow_x, arrow_y,
          arrow_x + arrow_size, arrow_y,
          arrow_x + arrow_size / 2, arrow_y + arrow_size,
          colors.header_text)
      end
    end

    -- Resize handle
    local resize_x = col_right - 4
    local resize_hovered = header_hovered and mx >= resize_x - 4 and mx < resize_x + 4

    if resize_hovered or state.resizing_column == col_idx then
      ImGui.DrawList_AddLine(dl, resize_x, y + 2, resize_x, y + header_h - 2, colors.resize_handle, 2)
      ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
    end

    -- Handle clicks
    if col_hovered and ImGui.IsMouseClicked(ctx, 0) then
      if resize_hovered then
        -- Start resize
        state.resizing_column = col_idx
        state.resize_start_x = mx
        state.resize_start_width = col.width
      elseif col.sortable then
        -- Toggle sort
        if state.sort_column == col.id then
          state.sort_ascending = not state.sort_ascending
        else
          state.sort_column = col.id
          state.sort_ascending = true
        end
      end
    end

    current_x = col_right
  end

  -- Handle column resize drag
  if state.resizing_column then
    if ImGui.IsMouseDown(ctx, 0) then
      local delta = mx - state.resize_start_x
      local col = columns[state.resizing_column]
      col.width = math.max(col.min_width or 50, state.resize_start_width + delta)
    else
      state.resizing_column = nil
    end
  end
end

-- ============================================================================
-- SORTING
-- ============================================================================

local function compare_values(a, b, ascending)
  if a == nil and b == nil then return false end
  if a == nil then return ascending end
  if b == nil then return not ascending end

  local a_str = tostring(a):lower()
  local b_str = tostring(b):lower()

  -- Try numeric comparison
  local a_num = a_str:match('^([%d%.]+)')
  local b_num = b_str:match('^([%d%.]+)')

  if a_num and b_num then
    a_num = tonumber(a_num)
    b_num = tonumber(b_num)
    if a_num and b_num and a_num ~= b_num then
      return ascending and (a_num < b_num) or (a_num > b_num)
    end
  end

  -- String comparison
  if a_str == b_str then return false end
  return ascending and (a_str < b_str) or (a_str > b_str)
end

local function sort_nodes_recursive(nodes, columns, sort_column, ascending)
  if not nodes or #nodes == 0 then return end

  -- Find column
  local col = nil
  for _, c in ipairs(columns) do
    if c.id == sort_column then
      col = c
      break
    end
  end

  if not col or not col.get then return end

  -- Sort this level
  table.sort(nodes, function(a, b)
    return compare_values(col.get(a), col.get(b), ascending)
  end)

  -- Sort children
  for _, node in ipairs(nodes) do
    if node.children and #node.children > 0 then
      sort_nodes_recursive(node.children, columns, sort_column, ascending)
    end
  end
end

-- ============================================================================
-- NODE RENDERING (multi-column)
-- ============================================================================

local function render_node_row(ctx, dl, node, opts, state, cfg, columns, result, x, y, w, depth, parent_lines, is_last_child, row_index, parent_id, visible_top, visible_bottom)
  local item_h = cfg.item_height
  local colors = cfg.colors

  -- Add to flat list
  Virtual.add_to_flat_list(state, node, parent_id, y, item_h)

  -- Virtual scrolling check
  local is_visible = not cfg.virtual_scroll or Virtual.is_visible(y, item_h, visible_top, visible_bottom)

  local has_children = node.children and #node.children > 0
  local is_open = State.is_open(state, node.id)
  local is_selected = State.is_selected(state, node.id)
  local is_focused = state.focused == node.id
  local is_editing = state.editing == node.id

  if is_visible then
    ImGui.PushID(ctx, node.id)

    -- Check hover
    local mx, my = ImGui.GetMousePos(ctx)
    local is_hovered = mx >= x and mx < x + w and my >= y and my < y + item_h

    if is_hovered then
      state.hovered = node.id
      result.hovered_id = node.id
    end

    -- Backgrounds
    NodeRenderer.draw_background(dl, cfg, x, y, w, item_h, is_selected, is_hovered, is_focused, row_index, false)

    -- Drag overlay
    if state.drag_active then
      for _, drag_id in ipairs(state.drag_node_ids) do
        if drag_id == node.id then
          NodeRenderer.draw_drag_overlay(dl, cfg, x, y, w, item_h)
          break
        end
      end
    end

    -- Drop indicator
    if state.drag_active and state.drop_target_id == node.id and state.drop_position then
      NodeRenderer.draw_drop_indicator(dl, cfg, x, y, w, item_h, state.drop_position)
    end

    -- Render each column
    local current_col_x = x
    local text_y = y + (item_h - ImGui.CalcTextSize(ctx, 'Tg')) / 2
    local text_color = (is_hovered or is_selected) and colors.text_hover or colors.text_normal

    for col_idx, col in ipairs(columns) do
      local col_x = current_col_x
      local col_w = col.width
      local col_right = col_x + col_w

      -- Column separator
      if col_idx > 1 then
        ImGui.DrawList_AddLine(dl, col_x, y, col_x, y + item_h, 0x303030AA, 1)
      end

      -- First column: tree structure
      if col.tree then
        local indent_x = col_x + cfg.padding_left + depth * cfg.indent_width
        local arrow_x = indent_x
        local arrow_y = y + (item_h - cfg.arrow_size) / 2
        local icon_x = arrow_x + cfg.arrow_size + cfg.arrow_margin
        local icon_y = y + (item_h - 9) / 2
        local content_x = icon_x + cfg.icon_width + cfg.icon_margin + cfg.item_padding_left

        -- Tree lines
        Lines.draw(dl, cfg, indent_x, y, depth, item_h, has_children, is_last_child, parent_lines)

        -- Arrow
        if has_children then
          Icons.arrow(dl, arrow_x, arrow_y, is_open, colors.arrow, cfg.arrow_size)
        end

        -- Icon
        local icon_color = node.color or (is_open and colors.icon_open or colors.icon)
        Icons.draw(dl, icon_x, icon_y, node, is_open, icon_color)

        -- Text or rename input
        if is_editing then
          local input_width = col_right - content_x - 6
          Rename.draw_input(ctx, state, content_x, y + 1, input_width, item_h - 2, opts, result)
        else
          local value = col.get and col.get(node) or node.name
          local available_w = col_right - content_x - 6
          NodeRenderer.draw_text(ctx, dl, value or '', content_x, text_y, available_w, text_color)
        end
      else
        -- Other columns: just data
        local value = col.get and col.get(node)
        if value then
          local content_x = col_x + 6
          local available_w = col_right - content_x - 6
          NodeRenderer.draw_text(ctx, dl, tostring(value), content_x, text_y, available_w, text_color)
        end
      end

      current_col_x = col_right
    end

    -- Interaction (entire row)
    if not is_editing then
      ImGui.SetCursorScreenPos(ctx, x, y)
      ImGui.InvisibleButton(ctx, '##row', w, item_h)

      -- Drag start
      if ImGui.IsItemActive(ctx) and ImGui.IsMouseDragging(ctx, 0, 0) and not state.drag_active then
        if opts.draggable ~= false then
          DragDrop.start_drag(state, node.id, mx, my)
        end
      end

      -- Click: check if on arrow first
      if ImGui.IsItemClicked(ctx, 0) then
        local first_col = columns[1]
        if first_col and first_col.tree then
          local indent_x = x + cfg.padding_left + depth * cfg.indent_width
          if has_children and mx >= indent_x and mx < indent_x + cfg.arrow_size + cfg.arrow_margin then
            State.toggle_open(state, node.id)
            result.expand_changed = true
          else
            Selection.handle_click(ctx, state, node.id, opts, result)
          end
        else
          Selection.handle_click(ctx, state, node.id, opts, result)
        end
      end

      -- Right-click
      if ImGui.IsItemClicked(ctx, 1) then
        if not State.is_selected(state, node.id) then
          State.set_single_selection(state, node.id)
        end
        result.right_clicked_id = node.id
        if opts.on_right_click then
          opts.on_right_click(node.id, State.get_selected_ids(state))
        end
      end

      -- Double-click
      if is_hovered and ImGui.IsMouseDoubleClicked(ctx, 0) then
        result.double_clicked_id = node.id
        if opts.on_double_click then
          opts.on_double_click(node.id)
        end
        Rename.handle_double_click(ctx, state, node, opts, is_hovered)
      end

      -- F2
      if State.is_selected(state, node.id) then
        Rename.handle_f2(ctx, state, node, opts)
      end

      -- Drop target
      if state.drag_active and is_hovered then
        DragDrop.update_drop_target(state, node.id, has_children, y, item_h, my)
      end
    end

    ImGui.PopID(ctx)
  end

  local next_y = y + item_h
  local next_row = row_index + 1

  -- Children
  if is_open and has_children then
    local child_parent_lines = {}
    for i = 1, depth do
      child_parent_lines[i] = parent_lines[i]
    end
    child_parent_lines[depth + 1] = not is_last_child

    for i, child in ipairs(node.children) do
      local is_last = (i == #node.children)
      next_y, next_row = render_node_row(ctx, dl, child, opts, state, cfg, columns, result, x, next_y, w, depth + 1, child_parent_lines, is_last, next_row, node.id, visible_top, visible_bottom)
    end
  end

  return next_y, next_row
end

-- ============================================================================
-- MAIN DRAW FUNCTION
-- ============================================================================

--- Draw a TreeTable widget
--- @param ctx userdata ImGui context
--- @param opts table Options { id, nodes, columns, on_select, ... }
--- @return table Result object
function M.Draw(ctx, opts)
  opts = opts or {}

  -- Validate columns
  local columns = opts.columns
  if not columns or #columns == 0 then
    error('Ark.TreeTable requires columns option', 2)
  end

  -- Resolve ID
  local id = opts.id or IdStack.resolve(ctx, 'tree_table')

  -- Get state and config
  local state = State.get(id)
  local cfg = Config.resolve(opts)

  -- Periodic cleanup
  State.cleanup()

  -- Initialize result
  local result = {
    selection_changed = false,
    clicked_id = nil,
    double_clicked_id = nil,
    right_clicked_id = nil,
    expand_changed = false,
    renamed = false,
    renamed_id = nil,
    renamed_value = nil,
    dropped = false,
    drop_source_ids = nil,
    drop_target_id = nil,
    drop_position = nil,
    drop_is_copy = nil,
    deleted = false,
    deleted_ids = nil,
    hovered_id = nil,
    sort_changed = false,
    sort_column = state.sort_column,
    sort_ascending = state.sort_ascending,
  }

  local nodes = opts.nodes or {}
  if #nodes == 0 then
    return result
  end

  -- Apply sorting if needed
  if state.sort_column then
    sort_nodes_recursive(nodes, columns, state.sort_column, state.sort_ascending)
  end

  -- Get draw area
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = opts.width or ImGui.GetContentRegionAvail(ctx)
  local h = opts.height or 200

  local dl = ImGui.GetWindowDrawList(ctx)

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, cfg.colors.bg)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, cfg.colors.border)

  -- Column headers
  draw_column_headers(ctx, dl, state, cfg, columns, x, y, w)

  -- Tree area below headers
  local tree_y = y + cfg.header_height
  local tree_h = h - cfg.header_height

  -- Store bounds (tree area only)
  state.tree_bounds = { x = x, y = tree_y, w = w, h = tree_h }

  -- Handle wheel
  Virtual.handle_wheel(ctx, state, cfg, state.tree_bounds)

  -- Clear flat list
  Virtual.clear_flat_list(state)
  state.hovered = nil

  -- Clip rect
  ImGui.DrawList_PushClipRect(dl, x, tree_y, x + w, tree_y + tree_h, true)

  -- Visible region
  local visible_top, visible_bottom = Virtual.get_visible_region(state.tree_bounds, cfg)

  -- Render nodes
  local start_y = tree_y + cfg.padding_top - state.scroll_y
  local current_y = start_y
  local row_index = 0

  for i, node in ipairs(nodes) do
    local is_last = (i == #nodes)
    current_y, row_index = render_node_row(ctx, dl, node, opts, state, cfg, columns, result, x, current_y, w, 0, {}, is_last, row_index, nil, visible_top, visible_bottom)
  end

  Virtual.update_content_height(state, cfg, start_y, current_y)

  ImGui.DrawList_PopClipRect(dl)

  -- Init focus
  Virtual.init_focus(state)

  -- Keyboard
  if ImGui.IsWindowFocused(ctx) and not state.editing then
    Selection.handle_keyboard(ctx, state, nodes, result)
    Keyboard.handle_arrows(ctx, state, cfg, state.tree_bounds, result)
    Keyboard.handle_expand_shortcuts(ctx, state, nodes, result)
    Keyboard.handle_type_search(ctx, state, cfg, state.tree_bounds, result)
    Keyboard.handle_delete(ctx, state, opts, result)
  end

  -- Drag completion
  if state.drag_active then
    DragDrop.complete_drag(ctx, state, opts, result)
    DragDrop.handle_auto_scroll(ctx, state, cfg, state.tree_bounds)
    DragDrop.clear_drop_target(state)
  end

  -- Drag preview
  if state.drag_active and state.drag_node_id then
    local function find_node(ns, target_id)
      for _, n in ipairs(ns) do
        if n.id == target_id then return n end
        if n.children then
          local found = find_node(n.children, target_id)
          if found then return found end
        end
      end
    end

    local drag_node = find_node(nodes, state.drag_node_id)
    if drag_node then
      DragDrop.draw_preview(ctx, dl, drag_node, #state.drag_node_ids, state.drag_is_copy)
    end
  end

  -- Empty click
  Selection.handle_empty_click(ctx, state, result)

  -- Advance cursor
  ImGui.SetCursorScreenPos(ctx, x, y + h)
  ImGui.Dummy(ctx, w, 0)

  -- Result state
  result.selected_ids = State.get_selected_ids(state)
  result.focused_id = state.focused

  return result
end

-- Re-export utility functions from Tree
M.expand_to_node = require('arkitekt.gui.widgets.tree.tree').expand_to_node
M.select_node = require('arkitekt.gui.widgets.tree.tree').select_node
M.clear_selection = require('arkitekt.gui.widgets.tree.tree').clear_selection
M.get_selected = require('arkitekt.gui.widgets.tree.tree').get_selected
M.expand_all = require('arkitekt.gui.widgets.tree.tree').expand_all
M.collapse_all = require('arkitekt.gui.widgets.tree.tree').collapse_all
M.start_rename = require('arkitekt.gui.widgets.tree.tree').start_rename

return M
