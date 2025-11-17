-- @noindex
-- rearkitekt/gui/widgets/navigation/tree_view.lua
-- TreeView widget with rearkitekt styling, inline rename, and folder icons

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('rearkitekt.gui.style.defaults')
local Colors = require('rearkitekt.core.colors')
local Fields = require('rearkitekt.gui.widgets.primitives.fields')

local M = {}

-- ============================================================================
-- FOLDER ICON RENDERING
-- ============================================================================

local function draw_folder_icon(ctx, dl, x, y, color)
  -- Folder icon: 13x7 main body with 5x2 tab on top left
  local main_w = 13
  local main_h = 7
  local tab_w = 5
  local tab_h = 2

  local icon_color = color or Colors.hexrgb("#888888")

  -- Draw tab (5x2 rectangle on top left)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + tab_w, y + tab_h, icon_color, 0)

  -- Draw main body (13x7 rectangle)
  ImGui.DrawList_AddRectFilled(dl, x, y + tab_h, x + main_w, y + tab_h + main_h, icon_color, 1)

  return main_w + 4  -- Return width including spacing
end

-- ============================================================================
-- TREE NODE RENDERING
-- ============================================================================

local _node_counter = 0

local function render_tree_node(ctx, node, config, state, depth)
  depth = depth or 0
  _node_counter = _node_counter + 1
  local node_id = node.id or node.path or tostring(_node_counter)

  ImGui.PushID(ctx, node_id)

  -- Determine if node is open
  local is_open = state.open_nodes and state.open_nodes[node_id]
  if is_open == nil then is_open = false end

  -- Check if node is selected
  local is_selected = state.selected_node == node_id

  -- Check if renaming
  local is_renaming = state.renaming_node == node_id

  -- Check if node has color
  local node_color = node.color

  -- If renaming, show input field (same as original working implementation)
  if is_renaming then
    -- Initialize field with current name
    local rename_field_id = "treeview_rename_" .. node_id
    if Fields.get_text(rename_field_id) == "" then
      Fields.set_text(rename_field_id, state.rename_buffer)
    end

    local changed, new_name = Fields.draw_at_cursor(ctx, {
      width = -1,
      height = 20,
      text = state.rename_buffer,
    }, rename_field_id)

    if changed then
      state.rename_buffer = new_name
    end

    -- Commit on Enter or deactivate
    if ImGui.IsItemDeactivatedAfterEdit(ctx) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
      if state.rename_buffer ~= "" and state.rename_buffer ~= node.name then
        if config.on_rename then
          config.on_rename(node, state.rename_buffer)
        end
      end
      state.renaming_node = nil
      state.rename_buffer = ""
    end

    -- Cancel on Escape
    if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      state.renaming_node = nil
      state.rename_buffer = ""
    end
  else
    -- Normal tree node display

    -- Tree node flags (same as original working implementation)
    local flags = ImGui.TreeNodeFlags_SpanAvailWidth

    if is_selected then
      flags = flags | ImGui.TreeNodeFlags_Selected
    end

    if not node.children or #node.children == 0 then
      flags = flags | ImGui.TreeNodeFlags_Leaf
    end

    -- Set open state before rendering
    if is_open then
      ImGui.SetNextItemOpen(ctx, true)
    end

    -- Draw colored background if node has color
    if node_color and config.show_colors then
      local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
      local avail_w = ImGui.GetContentRegionAvail(ctx)
      local line_height = ImGui.GetTextLineHeightWithSpacing(ctx)
      local dl = ImGui.GetWindowDrawList(ctx)

      -- Draw semi-transparent colored background (20% opacity)
      local bg_color = Colors.with_alpha(node_color, 0x33)  -- 20% opacity
      ImGui.DrawList_AddRectFilled(dl, cursor_x, cursor_y, cursor_x + avail_w, cursor_y + line_height, bg_color, 2)
    end

    -- Render tree node with folder icon
    -- We need to draw the icon inline with the label, so use TreeNodeEx with custom rendering
    local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)

    -- Render the tree node structure with empty label
    local node_open = ImGui.TreeNodeEx(ctx, "##" .. node_id, flags)

    -- Now draw the folder icon and name on the same line
    ImGui.SameLine(ctx, 0, 0)

    local dl = ImGui.GetWindowDrawList(ctx)
    local icon_cursor_x, icon_cursor_y = ImGui.GetCursorScreenPos(ctx)
    local text_y_offset = (ImGui.GetTextLineHeight(ctx) - 9) * 0.5  -- Center icon vertically (9 = tab_h + main_h)

    -- Draw folder icon
    local icon_width = draw_folder_icon(ctx, dl, icon_cursor_x, icon_cursor_y + text_y_offset, node_color)

    -- Draw label after icon
    ImGui.SetCursorScreenPos(ctx, icon_cursor_x + icon_width, icon_cursor_y)
    ImGui.Text(ctx, node.name)

    -- Handle clicks
    if ImGui.IsItemClicked(ctx) and not ImGui.IsItemToggledOpen(ctx) then
      -- Single click: select node
      state.selected_node = node_id
      if config.on_select then
        config.on_select(node)
      end
    end

    -- Track open state
    if state.open_nodes then
      state.open_nodes[node_id] = node_open
    end

    -- Handle double-click (rename by default if enabled)
    if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, ImGui.MouseButton_Left) then
      if config.enable_rename then
        state.renaming_node = node_id
        state.rename_buffer = node.name
      end
      if config.on_double_click then
        config.on_double_click(node)
      end
    end

    -- Handle right-click
    if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
      if config.on_right_click then
        config.on_right_click(node)
      end
    end

    -- Render children if node is open
    if node_open then
      if node.children and #node.children > 0 then
        for _, child in ipairs(node.children) do
          render_tree_node(ctx, child, config, state, depth + 1)
        end
      end
      ImGui.TreePop(ctx)
    end
  end

  ImGui.PopID(ctx)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw tree view
-- @param ctx ImGui context
-- @param nodes Table of root nodes: { { id, name, children = {...}, color = 0xRRGGBBAA }, ... }
-- @param state Table with open_nodes, selected_node, renaming_node, rename_buffer
-- @param user_config Optional configuration table
function M.draw(ctx, nodes, state, user_config)
  if not nodes or #nodes == 0 then return end

  local config = user_config or {}

  -- Ensure state tables exist
  if not state.open_nodes then
    state.open_nodes = {}
  end

  -- Apply default config
  config.enable_rename = config.enable_rename ~= false  -- default true
  config.show_colors = config.show_colors ~= false      -- default true

  -- Reset counter for consistent IDs
  _node_counter = 0

  -- Render all root nodes
  for _, node in ipairs(nodes) do
    render_tree_node(ctx, node, config, state, 0)
  end
end

--- Start renaming a node
-- @param state State table
-- @param node_id Node ID to rename
-- @param current_name Current node name
function M.start_rename(state, node_id, current_name)
  state.renaming_node = node_id
  state.rename_buffer = current_name or ""
end

--- Cancel current rename operation
-- @param state State table
function M.cancel_rename(state)
  state.renaming_node = nil
  state.rename_buffer = ""
end

--- Find node by ID in tree
-- @param nodes Root nodes
-- @param node_id Node ID to find
-- @return node or nil
function M.find_node(nodes, node_id)
  local function search(nodes_list)
    for _, node in ipairs(nodes_list) do
      local id = node.id or node.path or node.name
      if id == node_id then
        return node
      end
      if node.children then
        local found = search(node.children)
        if found then return found end
      end
    end
    return nil
  end
  return search(nodes)
end

--- Expand all nodes in path to target node
-- @param nodes Root nodes
-- @param node_id Target node ID
-- @param state State table
function M.expand_to_node(nodes, node_id, state)
  if not state.open_nodes then
    state.open_nodes = {}
  end

  local function find_path(nodes_list, target_id, path)
    path = path or {}
    for _, node in ipairs(nodes_list) do
      local id = node.id or node.path or node.name
      if id == target_id then
        -- Found it - expand all in path
        for _, parent_id in ipairs(path) do
          state.open_nodes[parent_id] = true
        end
        return true
      end
      if node.children then
        table.insert(path, id)
        if find_path(node.children, target_id, path) then
          return true
        end
        table.remove(path)
      end
    end
    return false
  end

  find_path(nodes, node_id)
end

--- Collapse all nodes
-- @param state State table
function M.collapse_all(state)
  if state.open_nodes then
    state.open_nodes = {}
  end
end

--- Expand all nodes
-- @param nodes Root nodes
-- @param state State table
function M.expand_all(nodes, state)
  if not state.open_nodes then
    state.open_nodes = {}
  end

  local function expand_recursive(nodes_list)
    for _, node in ipairs(nodes_list) do
      local id = node.id or node.path or node.name
      state.open_nodes[id] = true
      if node.children then
        expand_recursive(node.children)
      end
    end
  end

  expand_recursive(nodes)
end

return M
