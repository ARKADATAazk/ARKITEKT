-- @noindex
-- arkitekt/gui/widgets/tree/tree.lua
-- Single-column Tree widget with custom canvas rendering

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
local Icons = require('arkitekt.gui.widgets.tree.render.icons')

local M = {}

-- ============================================================================
-- RECURSIVE NODE RENDERING
-- ============================================================================

local function render_node_recursive(ctx, dl, node, opts, state, cfg, result, x, y, w, depth, parent_lines, is_last_child, row_index, parent_id, visible_top, visible_bottom)
  local item_h = cfg.item_height

  -- Skip if doesn't match search filter
  if result._search_text and result._search_text ~= '' then
    local matches = node.name:lower():find(result._search_text:lower(), 1, true)
    local has_matching_child = false

    if node.children then
      for _, child in ipairs(node.children) do
        if child.name:lower():find(result._search_text:lower(), 1, true) then
          has_matching_child = true
          break
        end
      end
    end

    if not matches and not has_matching_child then
      return y, row_index
    end
  end

  -- Add to flat list
  Virtual.add_to_flat_list(state, node, parent_id, y, item_h)

  -- Virtual scrolling: only render if visible
  local is_visible = not cfg.virtual_scroll or Virtual.is_visible(y, item_h, visible_top, visible_bottom)

  local has_children = node.children and #node.children > 0
  local is_open = State.is_open(state, node.id)
  local is_editing = state.editing == node.id

  if is_visible then
    ImGui.PushID(ctx, node.id)

    -- Calculate layout
    local layout = NodeRenderer.calculate_layout(cfg, x, y, w, depth)

    -- Check hover
    local mx, my = ImGui.GetMousePos(ctx)
    local is_hovered = mx >= x and mx < x + w and my >= y and my < y + item_h

    -- Render node content
    if not is_editing then
      local is_truncated = NodeRenderer.render(ctx, dl, node, state, cfg, layout, x, y, w, depth, is_last_child, parent_lines, row_index, result)

      -- Tooltip for truncated text
      if is_truncated and is_hovered then
        ImGui.SetTooltip(ctx, node.name)
      end

      -- Invisible button for interaction
      ImGui.SetCursorScreenPos(ctx, x, y)
      ImGui.InvisibleButton(ctx, '##item', w, item_h)

      -- Handle drag start
      if ImGui.IsItemActive(ctx) and ImGui.IsMouseDragging(ctx, 0, 0) and not state.drag_active then
        if opts.draggable ~= false then
          DragDrop.start_drag(state, node.id, mx, my)
        end
      end

      -- Handle click
      if ImGui.IsItemClicked(ctx, 0) then
        -- Check if clicking arrow
        if has_children and mx >= layout.arrow_x and mx < layout.arrow_x + cfg.arrow_size + cfg.arrow_margin then
          State.toggle_open(state, node.id)
          result.expand_changed = true
        else
          Selection.handle_click(ctx, state, node.id, opts, result)
        end
      end

      -- Handle right-click
      if ImGui.IsItemClicked(ctx, 1) then
        if not State.is_selected(state, node.id) then
          State.set_single_selection(state, node.id)
        end
        result.right_clicked_id = node.id
        if opts.on_right_click then
          opts.on_right_click(node.id, State.get_selected_ids(state))
        end
      end

      -- Handle double-click
      if is_hovered and ImGui.IsMouseDoubleClicked(ctx, 0) then
        result.double_clicked_id = node.id
        if opts.on_double_click then
          opts.on_double_click(node.id)
        end
        Rename.handle_double_click(ctx, state, node, opts, is_hovered)
      end

      -- Handle F2
      if State.is_selected(state, node.id) then
        Rename.handle_f2(ctx, state, node, opts)
      end

      -- Update drop target during drag
      if state.drag_active and is_hovered then
        DragDrop.update_drop_target(state, node.id, has_children, y, item_h, my)
      end
    else
      -- Render rename input
      local text_x = layout.text_x
      local input_width = layout.item_right - text_x
      Rename.draw_input(ctx, state, text_x, y + 1, input_width, item_h - 2, opts, result)
    end

    ImGui.PopID(ctx)
  end

  local next_y = y + item_h
  local next_row = row_index + 1

  -- Render children if open
  if is_open and has_children then
    -- Build parent lines for children
    local child_parent_lines = {}
    for i = 1, depth do
      child_parent_lines[i] = parent_lines[i]
    end
    child_parent_lines[depth + 1] = not is_last_child

    for i, child in ipairs(node.children) do
      local is_last = (i == #node.children)
      next_y, next_row = render_node_recursive(ctx, dl, child, opts, state, cfg, result, x, next_y, w, depth + 1, child_parent_lines, is_last, next_row, node.id, visible_top, visible_bottom)
    end
  end

  return next_y, next_row
end

-- ============================================================================
-- MAIN DRAW FUNCTION
-- ============================================================================

--- Draw a Tree widget
--- @param ctx userdata ImGui context
--- @param opts table Options { id, nodes, on_select, ... }
--- @return table Result object
function M.Draw(ctx, opts)
  opts = opts or {}

  -- Resolve ID
  local id = opts.id or IdStack.resolve(ctx, 'tree')

  -- Get state and config
  local state = State.get(id)
  local cfg = Config.resolve(opts)

  -- Periodic cleanup
  State.cleanup()

  -- Initialize result
  local result = {
    -- Selection
    selection_changed = false,
    clicked_id = nil,
    double_clicked_id = nil,
    right_clicked_id = nil,

    -- Expansion
    expand_changed = false,

    -- Rename
    renamed = false,
    renamed_id = nil,
    renamed_value = nil,

    -- Drag & drop
    dropped = false,
    drop_source_ids = nil,
    drop_target_id = nil,
    drop_position = nil,
    drop_is_copy = nil,

    -- Delete
    deleted = false,
    deleted_ids = nil,

    -- Hover
    hovered_id = nil,

    -- Internal
    _search_text = opts.search_text or '',
  }

  local nodes = opts.nodes or {}
  if #nodes == 0 then
    return result
  end

  -- Get draw area
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = opts.width or ImGui.GetContentRegionAvail(ctx)
  local h = opts.height or 200

  -- Store bounds
  state.tree_bounds = { x = x, y = y, w = w, h = h }

  -- Get draw list
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, cfg.colors.bg)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, cfg.colors.border)

  -- Handle mouse wheel
  Virtual.handle_wheel(ctx, state, cfg, state.tree_bounds)

  -- Clear and rebuild flat list
  Virtual.clear_flat_list(state)
  state.hovered = nil

  -- Clip rect for tree content
  ImGui.DrawList_PushClipRect(dl, x, y, x + w, y + h, true)

  -- Calculate visible region
  local visible_top, visible_bottom = Virtual.get_visible_region(state.tree_bounds, cfg)

  -- Render all nodes
  local start_y = y + cfg.padding_top - state.scroll_y
  local current_y = start_y
  local row_index = 0

  for i, node in ipairs(nodes) do
    local is_last = (i == #nodes)
    current_y, row_index = render_node_recursive(ctx, dl, node, opts, state, cfg, result, x, current_y, w, 0, {}, is_last, row_index, nil, visible_top, visible_bottom)
  end

  -- Update content height
  Virtual.update_content_height(state, cfg, start_y, current_y)

  ImGui.DrawList_PopClipRect(dl)

  -- Initialize focus
  Virtual.init_focus(state)

  -- Handle keyboard (only when window focused and not editing)
  if ImGui.IsWindowFocused(ctx) and not state.editing then
    Selection.handle_keyboard(ctx, state, nodes, result)
    Keyboard.handle_arrows(ctx, state, cfg, state.tree_bounds, result)
    Keyboard.handle_expand_shortcuts(ctx, state, nodes, result)
    Keyboard.handle_type_search(ctx, state, cfg, state.tree_bounds, result)
    Keyboard.handle_delete(ctx, state, opts, result)
  end

  -- Handle drag completion
  if state.drag_active then
    DragDrop.complete_drag(ctx, state, opts, result)
    DragDrop.handle_auto_scroll(ctx, state, cfg, state.tree_bounds)
    DragDrop.clear_drop_target(state)
  end

  -- Draw drag preview
  if state.drag_active and state.drag_node_id then
    -- Find primary drag node
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

  -- Handle empty click
  Selection.handle_empty_click(ctx, state, result)

  -- Advance cursor
  ImGui.SetCursorScreenPos(ctx, x, y + h)
  ImGui.Dummy(ctx, w, 0)

  -- Populate result with current state
  result.selected_ids = State.get_selected_ids(state)
  result.focused_id = state.focused

  return result
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Expand path to a node
--- @param tree_id string Tree widget ID
--- @param nodes table Root nodes
--- @param target_id string Target node ID
function M.expand_to_node(tree_id, nodes, target_id)
  local state = State.get(tree_id)

  local function find_path(ns, target, path)
    for _, node in ipairs(ns) do
      if node.id == target then
        for _, parent_id in ipairs(path) do
          state.open[parent_id] = true
        end
        return true
      end
      if node.children then
        path[#path + 1] = node.id
        if find_path(node.children, target, path) then
          return true
        end
        table.remove(path)
      end
    end
    return false
  end

  find_path(nodes, target_id, {})
end

--- Select a node programmatically
--- @param tree_id string Tree widget ID
--- @param node_id string Node ID
--- @param append boolean|nil Add to selection vs replace
function M.select_node(tree_id, node_id, append)
  local state = State.get(tree_id)
  if not append then
    state.selected = {}
  end
  state.selected[node_id] = true
  state.focused = node_id
end

--- Clear selection
--- @param tree_id string Tree widget ID
function M.clear_selection(tree_id)
  local state = State.get(tree_id)
  State.clear_selection(state)
end

--- Get selected IDs
--- @param tree_id string Tree widget ID
--- @return table Array of selected node IDs
function M.get_selected(tree_id)
  local state = State.get(tree_id)
  return State.get_selected_ids(state)
end

--- Expand all nodes
--- @param tree_id string Tree widget ID
--- @param nodes table Root nodes
function M.expand_all(tree_id, nodes)
  local state = State.get(tree_id)
  State.expand_all(state, nodes)
end

--- Collapse all nodes
--- @param tree_id string Tree widget ID
function M.collapse_all(tree_id)
  local state = State.get(tree_id)
  State.collapse_all(state)
end

--- Start rename on a node
--- @param tree_id string Tree widget ID
--- @param node_id string Node ID
--- @param name string Current name
function M.start_rename(tree_id, node_id, name)
  local state = State.get(tree_id)
  Rename.start(state, node_id, name)
end

return M
