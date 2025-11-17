-- @noindex
-- rearkitekt/gui/widgets/navigation/tree_view.lua
-- TreeView widget with rearkitekt styling

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('rearkitekt.gui.style.defaults')
local Colors = require('rearkitekt.core.colors')

local M = {}

-- ============================================================================
-- TREE NODE RENDERING
-- ============================================================================

local function render_tree_node(ctx, node, config, state, depth)
  depth = depth or 0
  local node_id = node.id or node.path or node.name

  ImGui.PushID(ctx, node_id)

  -- Determine if node is open
  local is_open = state.open_nodes and state.open_nodes[node_id]
  if is_open == nil then is_open = false end

  -- Check if node is selected
  local is_selected = state.selected_node == node_id

  -- Tree node flags
  local flags = ImGui.TreeNodeFlags_OpenOnArrow |
                ImGui.TreeNodeFlags_OpenOnDoubleClick |
                ImGui.TreeNodeFlags_SpanAvailWidth

  if is_selected then
    flags = flags | ImGui.TreeNodeFlags_Selected
  end

  if not node.children or #node.children == 0 then
    flags = flags | ImGui.TreeNodeFlags_Leaf | ImGui.TreeNodeFlags_NoTreePushOnOpen
  end

  -- Custom styling for selected node
  if is_selected and config.highlight_selected then
    ImGui.PushStyleColor(ctx, ImGui.Col_Header, config.selected_bg_color or Style.COLORS.ACCENT_PRIMARY)
    ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, Colors.adjust_brightness(config.selected_bg_color or Style.COLORS.ACCENT_PRIMARY, 1.2))
  end

  -- Render tree node
  local node_open = ImGui.TreeNodeEx(ctx, node.name, flags)

  -- Pop selection styling
  if is_selected and config.highlight_selected then
    ImGui.PopStyleColor(ctx, 2)
  end

  -- Handle click
  if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left) then
    state.selected_node = node_id
    if config.on_select then
      config.on_select(node)
    end
  end

  -- Handle double-click
  if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, ImGui.MouseButton_Left) then
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

  -- Update open state
  if state.open_nodes then
    state.open_nodes[node_id] = node_open
  end

  -- Render children if node is open
  if node_open and node.children and #node.children > 0 then
    for _, child in ipairs(node.children) do
      render_tree_node(ctx, child, config, state, depth + 1)
    end
    ImGui.TreePop(ctx)
  end

  ImGui.PopID(ctx)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw tree view
-- @param ctx ImGui context
-- @param nodes Table of root nodes: { { id, name, children = {...} }, ... }
-- @param state Table with open_nodes and selected_node
-- @param user_config Optional configuration table
function M.draw(ctx, nodes, state, user_config)
  if not nodes or #nodes == 0 then return end

  local config = user_config or {}

  -- Ensure state tables exist
  if not state.open_nodes then
    state.open_nodes = {}
  end

  -- Apply default config
  config.highlight_selected = config.highlight_selected ~= false -- default true
  config.selected_bg_color = config.selected_bg_color or Style.COLORS.ACCENT_PRIMARY

  -- Render all root nodes
  for _, node in ipairs(nodes) do
    render_tree_node(ctx, node, config, state, 0)
  end
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
