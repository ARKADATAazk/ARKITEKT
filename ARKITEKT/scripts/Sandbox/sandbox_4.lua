-- @noindex
-- ARKITEKT/scripts/Sandbox/sandbox_4.lua
-- Custom TreeView Prototype v3.5 - Advanced Tree Control
-- Multiselection, keyboard nav, search, context menu, clipboard ops
-- Virtual scrolling, custom icons, drag & drop reordering

local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path:match("(.*)[\\/][^\\/]+[\\/]?$") or script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end

local arkitekt_path = root_path .. "ARKITEKT/"
package.path = arkitekt_path .. "?.lua;" .. arkitekt_path .. "?/init.lua;" .. package.path
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

local ImGui = require('imgui')('0.10')
local Shell = require('arkitekt.app.shell')
local Colors = require('arkitekt.core.colors')
local InputText = require('arkitekt.gui.widgets.primitives.inputtext')
local hexrgb = Colors.hexrgb

-- Create namespace for widget modules
local ark = {
  InputText = InputText
}

-- ============================================================================
-- CUSTOM TREEVIEW CONFIG
-- ============================================================================

local TREE_CONFIG = {
  -- Dimensions
  item_height = 17,
  indent_width = 22,
  arrow_size = 5,
  arrow_margin = 6,
  icon_width = 13,
  icon_margin = 4,
  checkbox_size = 12,
  checkbox_margin = 6,

  -- Padding
  padding_left = 4,
  padding_top = 4,
  padding_right = 4,
  padding_bottom = 4,
  item_padding_left = 2,
  item_padding_right = 4,

  -- Visual features
  show_tree_lines = true,
  show_alternating_bg = false,
  show_checkboxes = true,  -- NEW: Global checkbox toggle
  tree_line_thickness = 1,
  tree_line_style = "dotted", -- "solid" or "dotted"
  tree_line_dot_spacing = 2,

  -- Default item flags
  default_item_flags = {
    selectable = true,
    editable = true,
    enabled = true,
    checkable = false,
    draggable = true,
    droppable = true,
  },

  -- Colors
  bg_hover = hexrgb("#2E2E2EFF"),
  bg_selected = hexrgb("#393939FF"),
  bg_selected_hover = hexrgb("#3E3E3EFF"),
  bg_alternate = hexrgb("#1C1C1CFF"),
  bg_disabled = hexrgb("#0F0F0FFF"),
  text_normal = hexrgb("#CCCCCCFF"),
  text_hover = hexrgb("#FFFFFFFF"),
  text_disabled = hexrgb("#666666FF"),
  arrow_color = hexrgb("#B0B0B0FF"),
  icon_color = hexrgb("#888888FF"),
  icon_open_color = hexrgb("#9A9A9AFF"),
  tree_line_color = hexrgb("#505050FF"),
  checkbox_border = hexrgb("#888888FF"),
  checkbox_check = hexrgb("#4A9EFFFF"),
  checkbox_bg = hexrgb("#2A2A2AFF"),
  checkbox_bg_disabled = hexrgb("#1A1A1AFF"),
}

-- ============================================================================
-- MOCK DATA
-- ============================================================================

local mock_tree = {
  {
    id = "root",
    name = "Project Root",
    color = hexrgb("#4A9EFFFF"),
    flags = { checkable = true },
    checked = true,
    children = {
      {
        id = "src",
        name = "src",
        color = hexrgb("#41E0A3FF"),
        flags = { checkable = true },
        checked = true,
        children = {
          { id = "components", name = "components", flags = { checkable = true }, checked = true, children = {
            { id = "button", name = "Button.lua", flags = { checkable = true }, checked = true, children = {} },
            { id = "dropdown", name = "Dropdown.lua", flags = { checkable = true }, checked = false, children = {} },
          }},
          { id = "utils", name = "utils", flags = { checkable = true }, checked = true, children = {
            { id = "colors", name = "colors.lua", flags = { checkable = true }, checked = true, children = {} },
            { id = "config", name = "config.lua", flags = { checkable = true }, checked = true, children = {} },
          }},
          { id = "styles", name = "styles", flags = { checkable = true }, checked = false, children = {} },
        }
      },
      {
        id = "docs",
        name = "Documentation",
        color = hexrgb("#FFA726FF"),
        children = {
          { id = "guides", name = "Guides", children = {
            { id = "getting-started", name = "Getting Started.md", children = {} },
            { id = "advanced", name = "Advanced Topics.md", children = {} },
          }},
          { id = "api", name = "API Reference", children = {} },
        }
      },
      {
        id = "tests",
        name = "tests",
        children = {
          { id = "unit", name = "unit", children = {} },
          { id = "integration", name = "integration", children = {} },
        }
      },
      { id = "config", name = "config", children = {} },
      { id = "scripts", name = "scripts", children = {} },
      { id = "assets", name = "assets", children = {} },
    }
  }
}

-- Find node by ID for renaming
local function find_node_by_id(nodes, id)
  for _, node in ipairs(nodes) do
    if node.id == id then return node end
    if node.children then
      local found = find_node_by_id(node.children, id)
      if found then return found end
    end
  end
  return nil
end

-- Get item flags (merge with defaults)
local function get_item_flags(node)
  if not node.flags then
    return TREE_CONFIG.default_item_flags
  end

  local flags = {}
  for key, default_val in pairs(TREE_CONFIG.default_item_flags) do
    flags[key] = node.flags[key] ~= nil and node.flags[key] or default_val
  end
  return flags
end

-- Check if item is enabled
local function is_item_enabled(node)
  local flags = get_item_flags(node)
  return flags.enabled
end

-- Check if item is checkable
local function is_item_checkable(node)
  local flags = get_item_flags(node)
  return flags.checkable and TREE_CONFIG.show_checkboxes
end

-- Get checkbox state (true, false, or "partial" for tri-state)
local function get_check_state(node)
  return node.checked or false
end

-- Set checkbox state and update parent tri-state
local function set_check_state(nodes, node_id, checked)
  local function update_node(ns)
    for _, n in ipairs(ns) do
      if n.id == node_id then
        n.checked = checked
        -- Update children recursively if enabled
        if n.children and #n.children > 0 then
          for _, child in ipairs(n.children) do
            if is_item_checkable(child) then
              set_check_state(n.children, child.id, checked)
            end
          end
        end
        return true
      elseif n.children then
        if update_node(n.children) then
          -- Update this parent's tri-state
          local all_checked = true
          local any_checked = false
          local has_partial = false

          for _, child in ipairs(n.children) do
            if is_item_checkable(child) then
              local child_state = get_check_state(child)
              if child_state == true then
                any_checked = true
              elseif child_state == "partial" then
                has_partial = true
              else
                all_checked = false
              end
            end
          end

          if has_partial or (any_checked and not all_checked) then
            n.checked = "partial"
          elseif all_checked then
            n.checked = true
          else
            n.checked = false
          end
          return true
        end
      end
    end
    return false
  end

  update_node(nodes)
end

-- ============================================================================
-- TREE STATE - MUST BE DEFINED BEFORE HELPER FUNCTIONS
-- ============================================================================

local tree_state = {
  open = { root = true, src = true, docs = true, components = true, utils = true, guides = true },
  selected = {}, -- Now a table of selected IDs: { [id] = true, ... }
  focused = nil, -- Currently focused item for keyboard nav
  anchor = nil, -- Anchor point for shift-selection
  hovered = nil,
  scroll_y = 0,
  editing = nil,
  edit_buffer = "",
  edit_focus_set = false,
  flat_list = {}, -- Flat list of visible items in order for arrow navigation
  clipboard = {}, -- Clipboard for cut/copy/paste
  clipboard_mode = nil, -- "cut" or "copy"
  context_menu_open = false,
  context_menu_x = 0,
  context_menu_y = 0,
  search_text = "",
  search_active = false,
  tree_bounds = {}, -- Store tree bounds for click detection

  -- Drag & drop state
  drag_active = false,
  drag_node_id = nil,
  drag_start_x = 0,
  drag_start_y = 0,
  drag_threshold = 5, -- pixels to move before drag starts
  drop_target_id = nil,
  drop_position = nil, -- "before", "into", "after"

  -- Virtual scrolling
  use_virtual_scrolling = true,
  total_content_height = 0,

  -- Icon types
  icon_types = {
    folder = "folder",
    file = "file",
    lua = "lua",
    markdown = "markdown",
    config = "config",
  },
}

-- ============================================================================
-- MULTISELECTION HELPERS
-- ============================================================================

local function is_selected(id)
  return tree_state.selected[id] == true
end

local function toggle_selection(id)
  if tree_state.selected[id] then
    tree_state.selected[id] = nil
  else
    tree_state.selected[id] = true
  end
end

local function set_single_selection(id)
  tree_state.selected = { [id] = true }
  tree_state.anchor = id
  tree_state.focused = id
end

local function clear_selection()
  tree_state.selected = {}
  tree_state.anchor = nil
end

local function select_range(from_id, to_id)
  local from_idx, to_idx = nil, nil
  for i, item in ipairs(tree_state.flat_list) do
    if item.id == from_id then from_idx = i end
    if item.id == to_id then to_idx = i end
  end

  if from_idx and to_idx then
    if from_idx > to_idx then from_idx, to_idx = to_idx, from_idx end
    tree_state.selected = {}
    for i = from_idx, to_idx do
      tree_state.selected[tree_state.flat_list[i].id] = true
    end
  end
end

local function select_all_visible()
  tree_state.selected = {}
  for _, item in ipairs(tree_state.flat_list) do
    tree_state.selected[item.id] = true
  end
end

local function invert_selection()
  local new_selection = {}
  for _, item in ipairs(tree_state.flat_list) do
    if not tree_state.selected[item.id] then
      new_selection[item.id] = true
    end
  end
  tree_state.selected = new_selection
end

local function expand_all_recursive(nodes)
  for _, node in ipairs(nodes) do
    tree_state.open[node.id] = true
    if node.children and #node.children > 0 then
      expand_all_recursive(node.children)
    end
  end
end

local function collapse_all_recursive(nodes)
  for _, node in ipairs(nodes) do
    tree_state.open[node.id] = false
    if node.children and #node.children > 0 then
      collapse_all_recursive(node.children)
    end
  end
end

local function delete_nodes_by_ids(nodes, ids_to_delete)
  local i = 1
  while i <= #nodes do
    if ids_to_delete[nodes[i].id] then
      table.remove(nodes, i)
    else
      if nodes[i].children then
        delete_nodes_by_ids(nodes[i].children, ids_to_delete)
      end
      i = i + 1
    end
  end
end

local function duplicate_node(node)
  local new_node = {
    id = node.id .. "_copy_" .. os.time(),
    name = node.name .. " (copy)",
    color = node.color,
    children = {}
  }
  if node.children then
    for _, child in ipairs(node.children) do
      table.insert(new_node.children, duplicate_node(child))
    end
  end
  return new_node
end

local function get_selected_nodes(nodes)
  local selected_nodes = {}
  local function collect(ns)
    for _, node in ipairs(ns) do
      if tree_state.selected[node.id] then
        table.insert(selected_nodes, node)
      end
      if node.children then
        collect(node.children)
      end
    end
  end
  collect(nodes)
  return selected_nodes
end

local function node_matches_search(node, search_text)
  if search_text == "" then return true end
  local lower_search = search_text:lower()
  local lower_name = node.name:lower()
  return lower_name:find(lower_search, 1, true) ~= nil
end

local function has_matching_children(node, search_text)
  if node_matches_search(node, search_text) then return true end
  if node.children then
    for _, child in ipairs(node.children) do
      if has_matching_children(child, search_text) then
        return true
      end
    end
  end
  return false
end

-- Drag & drop helpers
local function is_ancestor(potential_ancestor_id, node_id, nodes)
  local function check(current_id)
    if current_id == node_id then return true end
    local node = find_node_by_id(nodes, current_id)
    if node and node.children then
      for _, child in ipairs(node.children) do
        if check(child.id) then return true end
      end
    end
    return false
  end
  return check(potential_ancestor_id)
end

local function remove_node_from_tree(nodes, node_id)
  for i = #nodes, 1, -1 do
    if nodes[i].id == node_id then
      return table.remove(nodes, i)
    elseif nodes[i].children then
      local removed = remove_node_from_tree(nodes[i].children, node_id)
      if removed then return removed end
    end
  end
  return nil
end

local function insert_node_at(nodes, target_id, node_to_insert, position)
  for i, target_node in ipairs(nodes) do
    if target_node.id == target_id then
      if position == "before" then
        table.insert(nodes, i, node_to_insert)
        return true
      elseif position == "after" then
        table.insert(nodes, i + 1, node_to_insert)
        return true
      elseif position == "into" then
        target_node.children = target_node.children or {}
        table.insert(target_node.children, node_to_insert)
        tree_state.open[target_id] = true -- Auto-expand
        return true
      end
    elseif target_node.children then
      if insert_node_at(target_node.children, target_id, node_to_insert, position) then
        return true
      end
    end
  end
  return false
end

-- ============================================================================
-- DRAWING FUNCTIONS
-- ============================================================================

local function draw_checkbox(dl, x, y, checked, enabled)
  local cfg = TREE_CONFIG
  local size = cfg.checkbox_size

  x = math.floor(x + 0.5)
  y = math.floor(y + 0.5)

  local bg_color = enabled and cfg.checkbox_bg or cfg.checkbox_bg_disabled
  local border_color = enabled and cfg.checkbox_border or cfg.text_disabled
  local check_color = enabled and cfg.checkbox_check or cfg.text_disabled

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + size, y + size, bg_color, 2)

  -- Border
  ImGui.DrawList_AddRect(dl, x, y, x + size, y + size, border_color, 2, 0, 1.5)

  -- Checkmark or partial state
  if checked == true then
    -- Draw checkmark
    local x1, y1 = x + 3, y + 6
    local x2, y2 = x + 5, y + 9
    local x3, y3 = x + 9, y + 3

    ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, check_color, 2)
    ImGui.DrawList_AddLine(dl, x2, y2, x3, y3, check_color, 2)
  elseif checked == "partial" then
    -- Draw dash for partial state (tri-state)
    ImGui.DrawList_AddLine(dl, x + 3, y + size / 2, x + size - 3, y + size / 2, check_color, 2)
  end
end

local function draw_arrow(dl, x, y, is_open, color)
  color = color or TREE_CONFIG.arrow_color
  local size = TREE_CONFIG.arrow_size

  x = math.floor(x + 0.5)
  y = math.floor(y + 0.5)

  if is_open then
    local x1, y1 = x, y
    local x2, y2 = x + size, y
    local x3, y3 = math.floor(x + size / 2 + 0.5), y + size
    ImGui.DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)
  else
    local x1, y1 = x, y
    local x2, y2 = x, y + size
    local x3, y3 = x + size, y + size / 2
    ImGui.DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)
  end
end

local function draw_folder_icon(dl, x, y, is_open, color)
  color = color or (is_open and TREE_CONFIG.icon_open_color or TREE_CONFIG.icon_color)

  local main_w = 13
  local main_h = 7
  local tab_w = 5
  local tab_h = 2

  x = math.floor(x + 0.5)
  y = math.floor(y + 0.5)

  ImGui.DrawList_AddRectFilled(dl, x, y, x + tab_w, y + tab_h, color, 0)
  ImGui.DrawList_AddRectFilled(dl, x, y + tab_h, x + main_w, y + tab_h + main_h, color, 0)
end

local function draw_file_icon(dl, x, y, color)
  color = color or TREE_CONFIG.icon_color
  x = math.floor(x + 0.5)
  y = math.floor(y + 0.5)

  local w = 10
  local h = 12
  local corner = 3

  -- File body
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, color, 0)
  -- Corner fold
  ImGui.DrawList_AddTriangleFilled(dl, x + w - corner, y, x + w, y, x + w, y + corner, hexrgb("#000000AA"))
end

local function draw_lua_icon(dl, x, y, color)
  color = color or hexrgb("#00007FFF") -- Blue for Lua
  x = math.floor(x + 0.5)
  y = math.floor(y + 0.5)

  -- Draw "L" shape
  ImGui.DrawList_AddRectFilled(dl, x, y, x + 3, y + 12, color, 0)
  ImGui.DrawList_AddRectFilled(dl, x, y + 9, x + 10, y + 12, color, 0)
end

local function draw_markdown_icon(dl, x, y, color)
  color = color or hexrgb("#0A7EA3FF") -- Cyan for markdown
  x = math.floor(x + 0.5)
  y = math.floor(y + 0.5)

  -- Draw "M" shape
  local pts = {
    x, y + 10,
    x, y,
    x + 5, y + 5,
    x + 10, y,
    x + 10, y + 10
  }
  ImGui.DrawList_AddPolyline(dl, pts, color, 0, 2)
end

local function draw_config_icon(dl, x, y, color)
  color = color or hexrgb("#888888FF")
  x = math.floor(x + 0.5)
  y = math.floor(y + 0.5)

  -- Draw gear-like shape
  ImGui.DrawList_AddCircleFilled(dl, x + 5, y + 6, 4, color)
  ImGui.DrawList_AddCircleFilled(dl, x + 5, y + 6, 2, hexrgb("#000000AA"))
end

local function get_node_icon_type(node)
  if node.children and #node.children > 0 then
    return "folder"
  end

  local name = node.name:lower()
  if name:match("%.lua$") then return "lua" end
  if name:match("%.md$") then return "markdown" end
  if name:match("config") or name:match("%.json$") or name:match("%.yaml$") then return "config" end

  return "file"
end

local function draw_node_icon(dl, x, y, node, is_open, color)
  local icon_type = get_node_icon_type(node)

  if icon_type == "folder" then
    draw_folder_icon(dl, x, y, is_open, color)
  elseif icon_type == "lua" then
    draw_lua_icon(dl, x, y, color)
  elseif icon_type == "markdown" then
    draw_markdown_icon(dl, x, y, color)
  elseif icon_type == "config" then
    draw_config_icon(dl, x, y, color)
  else
    draw_file_icon(dl, x, y, color)
  end
end

local function draw_dotted_line(dl, x1, y1, x2, y2, color, thickness, dot_spacing)
  -- Round to whole pixels for crisp rendering
  x1 = math.floor(x1 + 0.5)
  y1 = math.floor(y1 + 0.5)
  x2 = math.floor(x2 + 0.5)
  y2 = math.floor(y2 + 0.5)

  local dx = x2 - x1
  local dy = y2 - y1
  local length = math.sqrt(dx * dx + dy * dy)
  local num_dots = math.floor(length / dot_spacing)

  if num_dots == 0 then return end

  for i = 0, num_dots do
    local t = i / num_dots
    local x = math.floor(x1 + dx * t + 0.5)
    local y = math.floor(y1 + dy * t + 0.5)
    ImGui.DrawList_AddCircleFilled(dl, x, y, thickness / 2, color)
  end
end

local function draw_tree_lines(dl, x, y, depth, item_h, has_children, is_last_child, parent_lines)
  if not TREE_CONFIG.show_tree_lines or depth == 0 then return end

  local cfg = TREE_CONFIG
  local line_color = cfg.tree_line_color
  local is_dotted = cfg.tree_line_style == "dotted"

  -- Better line positioning - align with arrow center
  local base_x = x - cfg.indent_width / 2
  local mid_y = y + item_h / 2

  if depth > 0 then
    -- Horizontal line to item
    local h_start_x = base_x
    local h_end_x = x + cfg.arrow_size / 2

    if is_dotted then
      draw_dotted_line(dl, h_start_x, mid_y, h_end_x, mid_y, line_color, cfg.tree_line_thickness, cfg.tree_line_dot_spacing)
    else
      ImGui.DrawList_AddLine(dl, h_start_x, mid_y, h_end_x, mid_y, line_color, cfg.tree_line_thickness)
    end

    -- Vertical line
    if not is_last_child then
      local v_start_y = y
      local v_end_y = y + item_h
      if is_dotted then
        draw_dotted_line(dl, base_x, v_start_y, base_x, v_end_y, line_color, cfg.tree_line_thickness, cfg.tree_line_dot_spacing)
      else
        ImGui.DrawList_AddLine(dl, base_x, v_start_y, base_x, v_end_y, line_color, cfg.tree_line_thickness)
      end
    else
      -- Only to mid point if last child
      if is_dotted then
        draw_dotted_line(dl, base_x, y, base_x, mid_y, line_color, cfg.tree_line_thickness, cfg.tree_line_dot_spacing)
      else
        ImGui.DrawList_AddLine(dl, base_x, y, base_x, mid_y, line_color, cfg.tree_line_thickness)
      end
    end
  end

  -- Parent level vertical lines
  for i = 1, depth - 1 do
    if parent_lines[i] then
      local parent_x = base_x - (depth - i) * cfg.indent_width
      if is_dotted then
        draw_dotted_line(dl, parent_x, y, parent_x, y + item_h, line_color, cfg.tree_line_thickness, cfg.tree_line_dot_spacing)
      else
        ImGui.DrawList_AddLine(dl, parent_x, y, parent_x, y + item_h, line_color, cfg.tree_line_thickness)
      end
    end
  end
end

-- ============================================================================
-- TREE RENDERING
-- ============================================================================

local function render_tree_item(ctx, dl, node, depth, y_pos, visible_x, visible_w, parent_lines, is_last_child, row_index, parent_id, visible_top, visible_bottom)
  local cfg = TREE_CONFIG
  local item_h = cfg.item_height

  -- Skip if doesn't match search
  local search_active = tree_state.search_text ~= ""
  if search_active and not has_matching_children(node, tree_state.search_text) then
    return y_pos, row_index
  end

  local matches_search = node_matches_search(node, tree_state.search_text)

  -- Add to flat list for keyboard navigation
  table.insert(tree_state.flat_list, {
    id = node.id,
    node = node,
    parent_id = parent_id,
    y_pos = y_pos,
    height = item_h,
  })

  -- Virtual scrolling: check if item is visible
  local is_visible = not tree_state.use_virtual_scrolling or
                    (y_pos + item_h >= visible_top and y_pos <= visible_bottom)

  local indent_x = visible_x + cfg.padding_left + depth * cfg.indent_width
  local arrow_x = indent_x
  local arrow_y = y_pos + (item_h - cfg.arrow_size) / 2
  local icon_x = arrow_x + cfg.arrow_size + cfg.arrow_margin
  local icon_y = y_pos + (item_h - 9) / 2
  local text_x = icon_x + cfg.icon_width + cfg.icon_margin + cfg.item_padding_left
  local text_y = y_pos + (item_h - ImGui.CalcTextSize(ctx, "Tg")) / 2

  local item_right = visible_x + visible_w - cfg.padding_right

  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = is_visible and mx >= visible_x and mx < visible_x + visible_w and my >= y_pos and my < y_pos + item_h
  local item_selected = is_selected(node.id)
  local is_focused = tree_state.focused == node.id
  local is_editing = tree_state.editing == node.id

  -- Only draw if visible (virtual scrolling optimization)
  if is_visible then
  -- Backgrounds
  if cfg.show_alternating_bg and row_index % 2 == 0 then
    ImGui.DrawList_AddRectFilled(dl, visible_x, y_pos, visible_x + visible_w, y_pos + item_h, cfg.bg_alternate)
  end

  -- Search highlight
  if search_active and matches_search then
    ImGui.DrawList_AddRectFilled(dl, visible_x, y_pos, visible_x + visible_w, y_pos + item_h, hexrgb("#4A4A1AFF"))
  end

  if item_selected then
    local bg_color = is_hovered and cfg.bg_selected_hover or cfg.bg_selected
    ImGui.DrawList_AddRectFilled(dl, visible_x, y_pos, visible_x + visible_w, y_pos + item_h, bg_color)
  elseif is_hovered then
    ImGui.DrawList_AddRectFilled(dl, visible_x, y_pos, visible_x + visible_w, y_pos + item_h, cfg.bg_hover)
  end

  -- Focused indicator (subtle border)
  if is_focused and not tree_state.editing then
    ImGui.DrawList_AddRect(dl, visible_x + 1, y_pos, visible_x + visible_w - 1, y_pos + item_h, hexrgb("#6A9EFFAA"), 0, 0, 1)
  end

  -- Drag & drop visual feedback
  if tree_state.drag_active and tree_state.drop_target_id == node.id then
    local drop_color = hexrgb("#4A9EFFFF")
    if tree_state.drop_position == "before" then
      ImGui.DrawList_AddLine(dl, visible_x, y_pos, visible_x + visible_w, y_pos, drop_color, 2)
    elseif tree_state.drop_position == "after" then
      ImGui.DrawList_AddLine(dl, visible_x, y_pos + item_h, visible_x + visible_w, y_pos + item_h, drop_color, 2)
    elseif tree_state.drop_position == "into" then
      ImGui.DrawList_AddRect(dl, visible_x + 2, y_pos + 1, visible_x + visible_w - 2, y_pos + item_h - 1, drop_color, 0, 0, 2)
    end
  end

  -- Tree lines
  local has_children = node.children and #node.children > 0
  draw_tree_lines(dl, indent_x, y_pos, depth, item_h, has_children, is_last_child, parent_lines)

  -- Arrow
  local is_open = tree_state.open[node.id]
  if has_children then
    draw_arrow(dl, arrow_x, arrow_y, is_open, cfg.arrow_color)
  end

  -- Icon (custom based on type)
  local icon_color = node.color or (is_open and cfg.icon_open_color or cfg.icon_color)
  draw_node_icon(dl, icon_x, icon_y, node, is_open, icon_color)

  -- Text or edit field
  if is_editing then
    -- Inline editing
    ark.InputText.set_text("tree_edit_" .. node.id, tree_state.edit_buffer)

    local available_w = item_right - text_x
    local result = ark.InputText.draw(ctx, {
      id = "tree_edit_" .. node.id,
      x = text_x,
      y = y_pos + 1,
      width = available_w,
      height = item_h - 2,
    })

    tree_state.edit_buffer = ark.InputText.get_text("tree_edit_" .. node.id) or tree_state.edit_buffer

    if not tree_state.edit_focus_set then
      ImGui.SetKeyboardFocusHere(ctx, -1)
      tree_state.edit_focus_set = true
    end

    -- Handle enter/escape
    if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter) then
      if tree_state.edit_buffer ~= "" then
        node.name = tree_state.edit_buffer
      end
      tree_state.editing = nil
      tree_state.edit_focus_set = false
    elseif ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      tree_state.editing = nil
      tree_state.edit_focus_set = false
    end
  else
    -- Normal text display
    local text_color = (is_hovered or item_selected) and cfg.text_hover or cfg.text_normal
    local text_w = ImGui.CalcTextSize(ctx, node.name)
    local available_w = item_right - text_x

    if text_w > available_w then
      local truncated = node.name
      while text_w > available_w - 10 and #truncated > 3 do
        truncated = truncated:sub(1, -2)
        text_w = ImGui.CalcTextSize(ctx, truncated .. "...")
      end
      ImGui.DrawList_AddText(dl, text_x, text_y, text_color, truncated .. "...")
    else
      ImGui.DrawList_AddText(dl, text_x, text_y, text_color, node.name)
    end

    -- Invisible button for interaction
    ImGui.SetCursorScreenPos(ctx, visible_x, y_pos)
    ImGui.InvisibleButton(ctx, "##tree_item_" .. node.id, visible_w, item_h)

    -- Mouse down for drag start
    if ImGui.IsItemActive(ctx) and ImGui.IsMouseDragging(ctx, 0, 0) and not tree_state.drag_active then
      tree_state.drag_active = true
      tree_state.drag_node_id = node.id
      tree_state.drag_start_x = mx
      tree_state.drag_start_y = my
    end

    -- Left click
    if ImGui.IsItemClicked(ctx, 0) then
      if has_children and mx >= arrow_x and mx < arrow_x + cfg.arrow_size + cfg.arrow_margin then
        -- Toggle open/close
        tree_state.open[node.id] = not tree_state.open[node.id]
      else
        -- Selection handling
        local ctrl_held = ImGui.GetKeyMods(ctx) & ImGui.Mod_Ctrl ~= 0
        local shift_held = ImGui.GetKeyMods(ctx) & ImGui.Mod_Shift ~= 0

        if ctrl_held then
          -- CTRL+click: Toggle individual selection
          toggle_selection(node.id)
          tree_state.anchor = node.id
          tree_state.focused = node.id
        elseif shift_held and tree_state.anchor then
          -- SHIFT+click: Range selection from anchor
          select_range(tree_state.anchor, node.id)
          tree_state.focused = node.id
        else
          -- Normal click: Single selection
          set_single_selection(node.id)
        end
      end
    end

    -- Detect drop target during drag
    if tree_state.drag_active and tree_state.drag_node_id ~= node.id then
      if is_hovered then
        local relative_y = my - y_pos
        if relative_y < item_h * 0.25 then
          tree_state.drop_target_id = node.id
          tree_state.drop_position = "before"
        elseif relative_y > item_h * 0.75 then
          tree_state.drop_target_id = node.id
          tree_state.drop_position = "after"
        elseif has_children then
          tree_state.drop_target_id = node.id
          tree_state.drop_position = "into"
        end
      end
    end

    -- Right click for context menu
    if ImGui.IsItemClicked(ctx, 1) then
      if not item_selected then
        set_single_selection(node.id)
      end
      tree_state.context_menu_open = true
      tree_state.context_menu_x = mx
      tree_state.context_menu_y = my
    end

    -- Double-click or F2 to edit
    if item_selected then
      if (ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0)) or
         ImGui.IsKeyPressed(ctx, ImGui.Key_F2) then
        tree_state.editing = node.id
        tree_state.edit_buffer = node.name
        tree_state.edit_focus_set = false
      end
    end
  end

  if is_hovered then
    tree_state.hovered = node.id
  end
  end -- Close if is_visible

  local next_y = y_pos + item_h
  local next_row = row_index + 1

  -- Debug: Track why children aren't rendering for root
  if node.id == "root" and depth == 0 then
    tree_state.debug_root_open = is_open
    tree_state.debug_root_has_children = has_children
    tree_state.debug_root_child_count = has_children and #node.children or 0

    -- More detailed debugging
    tree_state.debug_node_id = node.id
    tree_state.debug_node_name = node.name
    tree_state.debug_children_nil = (node.children == nil)
    tree_state.debug_children_count = node.children and #node.children or "NIL"
    tree_state.debug_open_table_root = tree_state.open["root"]
    tree_state.debug_open_table_size = 0
    for k, v in pairs(tree_state.open) do
      tree_state.debug_open_table_size = tree_state.debug_open_table_size + 1
    end
  end

  if is_open and has_children then
    local child_parent_lines = {}
    for i = 1, depth do
      child_parent_lines[i] = parent_lines[i]
    end
    child_parent_lines[depth + 1] = not is_last_child

    for i, child in ipairs(node.children) do
      local is_last = (i == #node.children)
      next_y, next_row = render_tree_item(ctx, dl, child, depth + 1, next_y, visible_x, visible_w, child_parent_lines, is_last, next_row, node.id, visible_top, visible_bottom)
    end
  end

  return next_y, next_row
end

local function draw_custom_tree(ctx, nodes, x, y, w, h)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cfg = TREE_CONFIG

  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, hexrgb("#1A1A1AFF"))
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, hexrgb("#000000DD"))

  -- Mouse wheel scrolling
  if ImGui.IsWindowHovered(ctx) then
    local wheel = ImGui.GetMouseWheel(ctx)
    if wheel ~= 0 then
      tree_state.scroll_y = tree_state.scroll_y - wheel * cfg.item_height * 3
      tree_state.scroll_y = math.max(0, tree_state.scroll_y)
    end
  end

  -- Clear flat list and rebuild this frame
  local old_flat_list = tree_state.flat_list
  tree_state.flat_list = {}

  ImGui.DrawList_PushClipRect(dl, x, y, x + w, y + h, true)

  local current_y = y + cfg.padding_top - tree_state.scroll_y
  local row_index = 0

  -- Calculate visible range for virtual scrolling
  local visible_top = y
  local visible_bottom = y + h

  for i, node in ipairs(nodes) do
    local is_last = (i == #nodes)
    local next_y, next_row = render_tree_item(ctx, dl, node, 0, current_y, x, w, {}, is_last, row_index, nil, visible_top, visible_bottom)
    current_y = next_y
    row_index = next_row
  end

  -- Store total content height for scrollbar
  tree_state.total_content_height = current_y - (y + cfg.padding_top - tree_state.scroll_y)

  ImGui.DrawList_PopClipRect(dl)

  -- Initialize focus if nothing is focused and we have items
  if not tree_state.focused and #tree_state.flat_list > 0 then
    tree_state.focused = tree_state.flat_list[1].id
  end

  -- Store tree bounds for click-to-deselect
  tree_state.tree_bounds = { x = x, y = y, w = w, h = h }

  -- Keyboard shortcuts (after flat_list is built)
  if ImGui.IsWindowFocused(ctx) and not tree_state.editing then
    local ctrl_held = ImGui.GetKeyMods(ctx) & ImGui.Mod_Ctrl ~= 0
    local shift_held = ImGui.GetKeyMods(ctx) & ImGui.Mod_Shift ~= 0

    -- ESC: Clear selection
    if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      clear_selection()
    end

    -- CTRL+A: Select all visible
    if ctrl_held and ImGui.IsKeyPressed(ctx, ImGui.Key_A) then
      select_all_visible()
    end

    -- CTRL+I: Invert selection
    if ctrl_held and ImGui.IsKeyPressed(ctx, ImGui.Key_I) then
      invert_selection()
    end

    -- CTRL+8 (*): Expand all
    if ctrl_held and ImGui.IsKeyPressed(ctx, ImGui.Key_8) then
      expand_all_recursive(nodes)
    end

    -- CTRL+9 ((: Collapse all
    if ctrl_held and ImGui.IsKeyPressed(ctx, ImGui.Key_9) then
      collapse_all_recursive(nodes)
    end

    -- Arrow key navigation
    if tree_state.focused and #tree_state.flat_list > 0 then
      local focused_idx = nil
      for i, item in ipairs(tree_state.flat_list) do
        if item.id == tree_state.focused then
          focused_idx = i
          break
        end
      end

      if focused_idx then
        local new_idx = nil

        -- Home: Jump to first item
        if ImGui.IsKeyPressed(ctx, ImGui.Key_Home) then
          new_idx = 1
        -- End: Jump to last item
        elseif ImGui.IsKeyPressed(ctx, ImGui.Key_End) then
          new_idx = #tree_state.flat_list
        -- Page Up: Jump up by ~10 items
        elseif ImGui.IsKeyPressed(ctx, ImGui.Key_PageUp) then
          new_idx = math.max(1, focused_idx - 10)
        -- Page Down: Jump down by ~10 items
        elseif ImGui.IsKeyPressed(ctx, ImGui.Key_PageDown) then
          new_idx = math.min(#tree_state.flat_list, focused_idx + 10)
        -- Up arrow
        elseif ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow) then
          new_idx = math.max(1, focused_idx - 1)
        -- Down arrow
        elseif ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow) then
          new_idx = math.min(#tree_state.flat_list, focused_idx + 1)
        -- Left arrow: collapse node or go to parent
        elseif ImGui.IsKeyPressed(ctx, ImGui.Key_LeftArrow) then
          local focused_node = tree_state.flat_list[focused_idx]
          if tree_state.open[focused_node.id] then
            tree_state.open[focused_node.id] = false
          elseif focused_node.parent_id then
            -- Find parent in flat list
            for i, item in ipairs(tree_state.flat_list) do
              if item.id == focused_node.parent_id then
                new_idx = i
                break
              end
            end
          end
        -- Right arrow: expand node or go to first child
        elseif ImGui.IsKeyPressed(ctx, ImGui.Key_RightArrow) then
          local focused_node = tree_state.flat_list[focused_idx]
          local has_children = focused_node.node.children and #focused_node.node.children > 0
          if has_children then
            if not tree_state.open[focused_node.id] then
              tree_state.open[focused_node.id] = true
            elseif focused_idx < #tree_state.flat_list then
              new_idx = focused_idx + 1
            end
          end
        end

        if new_idx and new_idx ~= focused_idx then
          local new_id = tree_state.flat_list[new_idx].id
          if shift_held and tree_state.anchor then
            -- SHIFT+arrow: Range selection
            select_range(tree_state.anchor, new_id)
            tree_state.focused = new_id
          else
            -- Normal arrow: Move selection
            set_single_selection(new_id)
          end

          -- Auto-scroll to keep focused item visible
          local item_info = tree_state.flat_list[new_idx]
          local item_screen_y = item_info.y_pos
          local visible_top = y + cfg.padding_top
          local visible_bottom = y + h - cfg.padding_bottom

          if item_screen_y < visible_top then
            tree_state.scroll_y = tree_state.scroll_y - (visible_top - item_screen_y)
          elseif item_screen_y + item_info.height > visible_bottom then
            tree_state.scroll_y = tree_state.scroll_y + (item_screen_y + item_info.height - visible_bottom)
          end
          tree_state.scroll_y = math.max(0, tree_state.scroll_y)
        end
      end
    end

    -- Delete key: Remove selected items
    if ImGui.IsKeyPressed(ctx, ImGui.Key_Delete) then
      if next(tree_state.selected) then
        delete_nodes_by_ids(nodes, tree_state.selected)
        clear_selection()
      end
    end

    -- CTRL+D: Duplicate selected items
    if ctrl_held and ImGui.IsKeyPressed(ctx, ImGui.Key_D) then
      local selected_nodes = get_selected_nodes(nodes)
      for _, node in ipairs(selected_nodes) do
        local parent_list = nodes -- Would need proper parent tracking for real implementation
        local duplicated = duplicate_node(node)
        table.insert(parent_list, duplicated)
      end
    end

    -- CTRL+X: Cut
    if ctrl_held and ImGui.IsKeyPressed(ctx, ImGui.Key_X) then
      tree_state.clipboard = get_selected_nodes(nodes)
      tree_state.clipboard_mode = "cut"
    end

    -- CTRL+C: Copy
    if ctrl_held and ImGui.IsKeyPressed(ctx, ImGui.Key_C) then
      tree_state.clipboard = get_selected_nodes(nodes)
      tree_state.clipboard_mode = "copy"
    end

    -- CTRL+V: Paste
    if ctrl_held and ImGui.IsKeyPressed(ctx, ImGui.Key_V) then
      if #tree_state.clipboard > 0 then
        for _, node in ipairs(tree_state.clipboard) do
          if tree_state.clipboard_mode == "copy" then
            table.insert(nodes, duplicate_node(node))
          else
            -- For cut, would need to remove from original location
            table.insert(nodes, node)
          end
        end
        if tree_state.clipboard_mode == "cut" then
          tree_state.clipboard = {}
          tree_state.clipboard_mode = nil
        end
      end
    end
  end

  -- Handle drag & drop completion
  if tree_state.drag_active then
    if ImGui.IsMouseReleased(ctx, 0) then
      -- Perform drop
      if tree_state.drop_target_id and tree_state.drop_position then
        local drag_id = tree_state.drag_node_id
        local target_id = tree_state.drop_target_id

        -- Prevent dropping into self or descendants
        if drag_id ~= target_id and not is_ancestor(drag_id, target_id, nodes) then
          local node_to_move = remove_node_from_tree(nodes, drag_id)
          if node_to_move then
            insert_node_at(nodes, target_id, node_to_move, tree_state.drop_position)
          end
        end
      end

      -- Reset drag state
      tree_state.drag_active = false
      tree_state.drag_node_id = nil
      tree_state.drop_target_id = nil
      tree_state.drop_position = nil
    else
      -- Clear drop target if not hovering
      if not tree_state.hovered then
        tree_state.drop_target_id = nil
        tree_state.drop_position = nil
      end
    end
  end

  -- Click on empty space to deselect
  local mx, my = ImGui.GetMousePos(ctx)
  if ImGui.IsMouseClicked(ctx, 0) then
    local in_tree = mx >= x and mx < x + w and my >= y and my < y + h
    if in_tree and not tree_state.hovered then
      clear_selection()
    end
  end
end

-- ============================================================================
-- CONTEXT MENU
-- ============================================================================

local function draw_context_menu(ctx, nodes)
  if not tree_state.context_menu_open then return end

  ImGui.SetNextWindowPos(ctx, tree_state.context_menu_x, tree_state.context_menu_y)
  if ImGui.BeginPopup(ctx, "##tree_context_menu") then
    local selected_count = 0
    for _ in pairs(tree_state.selected) do
      selected_count = selected_count + 1
    end

    ImGui.Text(ctx, string.format("%d item(s) selected", selected_count))
    ImGui.Separator(ctx)

    if ImGui.MenuItem(ctx, "Rename (F2)") then
      if tree_state.focused then
        tree_state.editing = tree_state.focused
        local node = find_node_by_id(nodes, tree_state.focused)
        if node then
          tree_state.edit_buffer = node.name
          tree_state.edit_focus_set = false
        end
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    if ImGui.MenuItem(ctx, "Duplicate (Ctrl+D)") then
      local selected_nodes = get_selected_nodes(nodes)
      for _, node in ipairs(selected_nodes) do
        table.insert(nodes, duplicate_node(node))
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    if ImGui.MenuItem(ctx, "Delete (Del)") then
      delete_nodes_by_ids(nodes, tree_state.selected)
      clear_selection()
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.Separator(ctx)

    if ImGui.MenuItem(ctx, "Cut (Ctrl+X)") then
      tree_state.clipboard = get_selected_nodes(nodes)
      tree_state.clipboard_mode = "cut"
      ImGui.CloseCurrentPopup(ctx)
    end

    if ImGui.MenuItem(ctx, "Copy (Ctrl+C)") then
      tree_state.clipboard = get_selected_nodes(nodes)
      tree_state.clipboard_mode = "copy"
      ImGui.CloseCurrentPopup(ctx)
    end

    if ImGui.MenuItem(ctx, "Paste (Ctrl+V)", nil, false, #tree_state.clipboard > 0) then
      for _, node in ipairs(tree_state.clipboard) do
        if tree_state.clipboard_mode == "copy" then
          table.insert(nodes, duplicate_node(node))
        else
          table.insert(nodes, node)
        end
      end
      if tree_state.clipboard_mode == "cut" then
        tree_state.clipboard = {}
        tree_state.clipboard_mode = nil
      end
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.Separator(ctx)

    if ImGui.MenuItem(ctx, "Select All (Ctrl+A)") then
      select_all_visible()
      ImGui.CloseCurrentPopup(ctx)
    end

    if ImGui.MenuItem(ctx, "Invert Selection (Ctrl+I)") then
      invert_selection()
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  else
    tree_state.context_menu_open = false
  end
end

-- ============================================================================
-- UI HELPERS
-- ============================================================================

local function config_section(ctx, title)
  ImGui.Text(ctx, "")
  ImGui.Text(ctx, title)
  ImGui.Separator(ctx)
end

local function slider_int(ctx, label, value, min, max, width)
  ImGui.SetNextItemWidth(ctx, width or 180)
  local changed, new_value = ImGui.SliderInt(ctx, label, value, min, max)
  return changed and new_value or value
end

local function checkbox(ctx, label, value)
  local changed, new_value = ImGui.Checkbox(ctx, label, value)
  if changed then
    return new_value
  end
  return value
end

-- ============================================================================
-- MAIN SHELL
-- ============================================================================

Shell.run({
  title = "Custom TreeView Prototype",
  version = "v3.5.0",
  version_color = hexrgb("#888888FF"),
  initial_pos = { x = 120, y = 120 },
  initial_size = { w = 700, h = 700 },
  min_size = { w = 600, h = 500 },
  icon_color = hexrgb("#4A9EFFFF"),
  icon_size = 18,

  draw = function(ctx, shell_state)
    ImGui.Text(ctx, "Custom TreeView v3.5 - Advanced Tree Control")
    ImGui.Text(ctx, "Features: Virtual Scrolling • Custom Icons • Drag & Drop Reordering")
    ImGui.Text(ctx, "Selection: Click • CTRL+Click • SHIFT+Click • CTRL+A • CTRL+I")
    ImGui.Text(ctx, "Navigation: Arrows • Home/End • PgUp/PgDown • Search • F2/Del/Menu")
    ImGui.Separator(ctx)

    local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
    local left_width = 280

    ImGui.BeginChild(ctx, "config_panel", left_width, 0)

    config_section(ctx, "Dimensions")
    TREE_CONFIG.item_height = slider_int(ctx, "Item Height", TREE_CONFIG.item_height, 14, 28, 200)
    TREE_CONFIG.indent_width = slider_int(ctx, "Indent Width", TREE_CONFIG.indent_width, 16, 36, 200)
    TREE_CONFIG.arrow_size = slider_int(ctx, "Arrow Size", TREE_CONFIG.arrow_size, 3, 8, 200)
    TREE_CONFIG.icon_width = slider_int(ctx, "Icon Width", TREE_CONFIG.icon_width, 10, 20, 200)

    config_section(ctx, "Padding")
    TREE_CONFIG.padding_left = slider_int(ctx, "Padding Left", TREE_CONFIG.padding_left, 0, 16, 200)
    TREE_CONFIG.padding_top = slider_int(ctx, "Padding Top", TREE_CONFIG.padding_top, 0, 16, 200)
    TREE_CONFIG.item_padding_left = slider_int(ctx, "Item Pad L", TREE_CONFIG.item_padding_left, 0, 8, 200)

    config_section(ctx, "Tree Lines")
    TREE_CONFIG.show_tree_lines = checkbox(ctx, "Show Lines", TREE_CONFIG.show_tree_lines)
    if TREE_CONFIG.show_tree_lines then
      ImGui.Indent(ctx, 20)
      TREE_CONFIG.tree_line_thickness = slider_int(ctx, "Thickness", TREE_CONFIG.tree_line_thickness, 1, 3, 160)

      ImGui.Text(ctx, "Style:")
      ImGui.SameLine(ctx)
      if ImGui.RadioButton(ctx, "Solid##style", TREE_CONFIG.tree_line_style == "solid") then
        TREE_CONFIG.tree_line_style = "solid"
      end
      ImGui.SameLine(ctx)
      if ImGui.RadioButton(ctx, "Dotted##style", TREE_CONFIG.tree_line_style == "dotted") then
        TREE_CONFIG.tree_line_style = "dotted"
      end

      if TREE_CONFIG.tree_line_style == "dotted" then
        TREE_CONFIG.tree_line_dot_spacing = slider_int(ctx, "Dot Spacing", TREE_CONFIG.tree_line_dot_spacing, 1, 5, 160)
      end
      ImGui.Unindent(ctx, 20)
    end
    TREE_CONFIG.show_alternating_bg = checkbox(ctx, "Alternating Rows", TREE_CONFIG.show_alternating_bg)

    config_section(ctx, "Actions")
    if ImGui.Button(ctx, "Expand All", 120, 24) then
      for _, node in ipairs(mock_tree) do
        local function expand_all(n)
          tree_state.open[n.id] = true
          if n.children then
            for _, child in ipairs(n.children) do
              expand_all(child)
            end
          end
        end
        expand_all(node)
      end
    end

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Collapse All", 120, 24) then
      tree_state.open = { root = true }
    end

    ImGui.EndChild(ctx)

    ImGui.SameLine(ctx)

    -- Right side: Tree view
    ImGui.BeginChild(ctx, "tree_container", 0, 0)

    local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

    -- Search bar at top
    ImGui.SetNextItemWidth(ctx, avail_w - 100)
    local search_changed, new_search = ImGui.InputText(ctx, "##search", tree_state.search_text)
    if search_changed then
      tree_state.search_text = new_search
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Clear", 90, 0) then
      tree_state.search_text = ""
    end

    local tree_x, tree_y = ImGui.GetCursorScreenPos(ctx)
    local tree_h = avail_h - 130  -- Leave room for search + debug info

    draw_custom_tree(ctx, mock_tree, tree_x, tree_y, avail_w, tree_h)

    -- Context menu
    if tree_state.context_menu_open then
      ImGui.OpenPopup(ctx, "##tree_context_menu")
    end
    draw_context_menu(ctx, mock_tree)

    ImGui.SetCursorScreenPos(ctx, tree_x, tree_y + tree_h + 4)

    ImGui.Separator(ctx)

    -- Count selected items
    local selected_count = 0
    local selected_ids = {}
    for id, _ in pairs(tree_state.selected) do
      selected_count = selected_count + 1
      table.insert(selected_ids, id)
    end

    local selected_text = "None"
    if selected_count == 1 then
      selected_text = selected_ids[1]
    elseif selected_count > 1 then
      selected_text = string.format("%d items", selected_count)
    end

    -- Debug info
    ImGui.Text(ctx, string.format("Selected: %s  |  Focused: %s  |  Editing: %s  |  Hovered: %s",
      selected_text,
      tree_state.focused or "None",
      tree_state.editing or "None",
      tree_state.hovered or "None"))

    -- Debug: Show tree structure info
    ImGui.Text(ctx, string.format("Tree nodes: %d  |  Flat list: %d  |  Scroll: %.1f",
      #mock_tree,
      #tree_state.flat_list,
      tree_state.scroll_y))

    ImGui.Text(ctx, string.format("Root: %s (children: %d)  |  src open: %s",
      mock_tree[1] and mock_tree[1].name or "nil",
      mock_tree[1] and mock_tree[1].children and #mock_tree[1].children or 0,
      tree_state.open["src"] and "yes" or "no"))

    -- More detailed debug
    if #tree_state.flat_list <= 1 then
      ImGui.TextColored(ctx, 0xFF0000FF, "WARNING: Only root in flat_list! Children not rendering!")
      ImGui.Text(ctx, string.format("Debug: is_open=%s | has_children=%s | child_count=%s",
        tree_state.debug_root_open and "TRUE" or "FALSE",
        tree_state.debug_root_has_children and "TRUE" or "FALSE",
        tostring(tree_state.debug_root_child_count or 0)))

      ImGui.Text(ctx, string.format("Node: id=%s name=%s",
        tree_state.debug_node_id or "NIL",
        tree_state.debug_node_name or "NIL"))

      ImGui.Text(ctx, string.format("Children: nil=%s count=%s | open_table[root]=%s table_size=%d",
        tree_state.debug_children_nil and "YES" or "NO",
        tostring(tree_state.debug_children_count or "?"),
        tostring(tree_state.debug_open_table_root),
        tree_state.debug_open_table_size or 0))
    end

    tree_state.hovered = nil

    ImGui.EndChild(ctx)  -- End tree_container
  end,
})
