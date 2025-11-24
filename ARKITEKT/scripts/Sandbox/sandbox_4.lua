-- @noindex
-- ARKITEKT/scripts/Sandbox/sandbox_4.lua
-- Custom TreeView Prototype - Full control over rendering

local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path:match("(.*)[\\/][^\\/]+[\\/]?$") or script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end

local arkitekt_path = root_path .. "ARKITEKT/"
package.path = arkitekt_path .. "?.lua;" .. arkitekt_path .. "?/init.lua;" .. package.path
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

local ImGui = require('imgui')('0.10')
local Shell = require('arkitekt.app.runtime.shell')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

-- ============================================================================
-- CUSTOM TREEVIEW CONFIG
-- ============================================================================

local TREE_CONFIG = {
  -- Dimensions
  item_height = 17,          -- Exact height per entry
  indent_width = 22,         -- Indentation per level
  arrow_size = 5,            -- Arrow width/height
  arrow_margin = 6,          -- Space after arrow
  icon_width = 13,           -- Folder icon width
  icon_margin = 4,           -- Space after icon

  -- Padding
  padding_left = 4,          -- Left padding before first level
  padding_top = 4,           -- Top padding in container
  padding_right = 4,         -- Right padding
  padding_bottom = 4,        -- Bottom padding
  item_padding_left = 2,     -- Extra padding before text
  item_padding_right = 4,    -- Padding after text

  -- Visual features
  show_tree_lines = true,    -- Show connecting lines
  show_alternating_bg = false, -- Alternating row backgrounds
  tree_line_thickness = 1,   -- Line thickness

  -- Colors
  bg_hover = hexrgb("#2E2E2EFF"),
  bg_selected = hexrgb("#393939FF"),
  bg_selected_hover = hexrgb("#3E3E3EFF"),
  bg_alternate = hexrgb("#1C1C1CFF"),
  text_normal = hexrgb("#CCCCCCFF"),
  text_hover = hexrgb("#FFFFFFFF"),
  arrow_color = hexrgb("#B0B0B0FF"),
  icon_color = hexrgb("#888888FF"),
  icon_open_color = hexrgb("#9A9A9AFF"),
  tree_line_color = hexrgb("#404040FF"),
}

-- ============================================================================
-- MOCK DATA
-- ============================================================================

local mock_tree = {
  {
    id = "root",
    name = "Project Root",
    color = hexrgb("#4A9EFFFF"),
    children = {
      {
        id = "src",
        name = "src",
        color = hexrgb("#41E0A3FF"),
        children = {
          { id = "components", name = "components", children = {
            { id = "button", name = "Button.lua", children = {} },
            { id = "dropdown", name = "Dropdown.lua", children = {} },
          }},
          { id = "utils", name = "utils", children = {
            { id = "colors", name = "colors.lua", children = {} },
            { id = "config", name = "config.lua", children = {} },
          }},
          { id = "styles", name = "styles", children = {} },
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

local tree_state = {
  open = { root = true, src = true, docs = true, components = true, utils = true, guides = true },
  selected = nil,
  hovered = nil,
  scroll_y = 0,
}

-- ============================================================================
-- DRAWING FUNCTIONS
-- ============================================================================

local function draw_arrow(dl, x, y, is_open, color)
  color = color or TREE_CONFIG.arrow_color
  local size = TREE_CONFIG.arrow_size

  x = math.floor(x + 0.5)
  y = math.floor(y + 0.5)

  if is_open then
    -- Down-pointing triangle
    local x1, y1 = x, y
    local x2, y2 = x + size, y
    local x3, y3 = math.floor(x + size / 2 + 0.5), y + size
    ImGui.DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)
  else
    -- Right-pointing triangle
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

  -- Draw tab
  ImGui.DrawList_AddRectFilled(dl, x, y, x + tab_w, y + tab_h, color, 0)
  -- Draw main body
  ImGui.DrawList_AddRectFilled(dl, x, y + tab_h, x + main_w, y + tab_h + main_h, color, 0)
end

local function draw_tree_lines(dl, x, y, depth, item_h, has_children, is_last_child, parent_lines)
  if not TREE_CONFIG.show_tree_lines or depth == 0 then return end

  local cfg = TREE_CONFIG
  local line_color = cfg.tree_line_color
  local line_x = x + cfg.indent_width / 2
  local mid_y = y + item_h / 2

  -- Draw vertical line from parent (if not root level)
  if depth > 0 then
    -- Draw horizontal line to item
    local h_line_start = line_x - cfg.indent_width / 2
    local h_line_end = line_x + cfg.arrow_size + cfg.arrow_margin - 2
    ImGui.DrawList_AddLine(dl, h_line_start, mid_y, h_line_end, mid_y, line_color, cfg.tree_line_thickness)

    -- Draw vertical line through this level (unless last child)
    if not is_last_child then
      ImGui.DrawList_AddLine(dl, h_line_start, y, h_line_start, y + item_h, line_color, cfg.tree_line_thickness)
    else
      -- Only draw to mid point if last child
      ImGui.DrawList_AddLine(dl, h_line_start, y, h_line_start, mid_y, line_color, cfg.tree_line_thickness)
    end
  end

  -- Draw vertical lines for all parent levels
  for i = 1, depth - 1 do
    if parent_lines[i] then  -- Only if parent has more siblings
      local parent_line_x = x - (depth - i) * cfg.indent_width + cfg.indent_width / 2
      ImGui.DrawList_AddLine(dl, parent_line_x, y, parent_line_x, y + item_h, line_color, cfg.tree_line_thickness)
    end
  end
end

-- ============================================================================
-- TREE RENDERING
-- ============================================================================

local function render_tree_item(ctx, dl, node, depth, y_pos, visible_x, visible_w, parent_lines, is_last_child, row_index)
  local cfg = TREE_CONFIG
  local item_h = cfg.item_height

  -- Calculate positions
  local indent_x = visible_x + cfg.padding_left + depth * cfg.indent_width
  local arrow_x = indent_x
  local arrow_y = y_pos + (item_h - cfg.arrow_size) / 2
  local icon_x = arrow_x + cfg.arrow_size + cfg.arrow_margin
  local icon_y = y_pos + (item_h - 9) / 2  -- 9 = total icon height (tab + body)
  local text_x = icon_x + cfg.icon_width + cfg.icon_margin + cfg.item_padding_left
  local text_y = y_pos + (item_h - ImGui.CalcTextSize(ctx, "Tg")) / 2

  local item_right = visible_x + visible_w - cfg.padding_right

  -- Check hover
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= visible_x and mx < visible_x + visible_w and my >= y_pos and my < y_pos + item_h

  -- Check selection
  local is_selected = tree_state.selected == node.id

  -- Draw alternating background
  if cfg.show_alternating_bg and row_index % 2 == 0 then
    ImGui.DrawList_AddRectFilled(dl, visible_x, y_pos, visible_x + visible_w, y_pos + item_h, cfg.bg_alternate)
  end

  -- Draw background
  if is_selected then
    local bg_color = is_hovered and cfg.bg_selected_hover or cfg.bg_selected
    ImGui.DrawList_AddRectFilled(dl, visible_x, y_pos, visible_x + visible_w, y_pos + item_h, bg_color)
  elseif is_hovered then
    ImGui.DrawList_AddRectFilled(dl, visible_x, y_pos, visible_x + visible_w, y_pos + item_h, cfg.bg_hover)
  end

  -- Draw tree lines
  local has_children = node.children and #node.children > 0
  draw_tree_lines(dl, indent_x, y_pos, depth, item_h, has_children, is_last_child, parent_lines)

  -- Draw arrow if has children
  local is_open = tree_state.open[node.id]

  if has_children then
    draw_arrow(dl, arrow_x, arrow_y, is_open, cfg.arrow_color)
  end

  -- Draw folder icon
  local icon_color = node.color or (is_open and cfg.icon_open_color or cfg.icon_color)
  draw_folder_icon(dl, icon_x, icon_y, is_open, icon_color)

  -- Draw text
  local text_color = (is_hovered or is_selected) and cfg.text_hover or cfg.text_normal
  local text_w = ImGui.CalcTextSize(ctx, node.name)
  local available_w = item_right - text_x

  -- Truncate if needed
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

  -- Handle clicks
  ImGui.SetCursorScreenPos(ctx, visible_x, y_pos)
  ImGui.InvisibleButton(ctx, "##tree_item_" .. node.id, visible_w, item_h)

  if ImGui.IsItemClicked(ctx, 0) then
    -- Check if clicked on arrow area
    if has_children and mx >= arrow_x and mx < arrow_x + cfg.arrow_size + cfg.arrow_margin then
      -- Toggle expand/collapse
      tree_state.open[node.id] = not tree_state.open[node.id]
    else
      -- Select item
      tree_state.selected = node.id
    end
  end

  -- Update hovered state
  if is_hovered then
    tree_state.hovered = node.id
  end

  local next_y = y_pos + item_h
  local next_row = row_index + 1

  -- Render children if open
  if is_open and has_children then
    -- Update parent lines for children
    local child_parent_lines = {}
    for i = 1, depth do
      child_parent_lines[i] = parent_lines[i]
    end
    child_parent_lines[depth + 1] = not is_last_child  -- This level continues if not last child

    for i, child in ipairs(node.children) do
      local is_last = (i == #node.children)
      next_y, next_row = render_tree_item(ctx, dl, child, depth + 1, next_y, visible_x, visible_w, child_parent_lines, is_last, next_row)
    end
  end

  return next_y, next_row
end

local function draw_custom_tree(ctx, nodes, x, y, w, h)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cfg = TREE_CONFIG

  -- Draw container background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, hexrgb("#1A1A1AFF"))
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, hexrgb("#000000DD"))

  -- Handle mouse wheel for scrolling
  if ImGui.IsWindowHovered(ctx) then
    local wheel = ImGui.GetMouseWheel(ctx)
    if wheel ~= 0 then
      tree_state.scroll_y = tree_state.scroll_y - wheel * cfg.item_height * 3
      tree_state.scroll_y = math.max(0, tree_state.scroll_y)
    end
  end

  -- Clip rendering to container
  ImGui.DrawList_PushClipRect(dl, x, y, x + w, y + h, true)

  local current_y = y + cfg.padding_top - tree_state.scroll_y
  local row_index = 0

  for i, node in ipairs(nodes) do
    local is_last = (i == #nodes)
    local next_y, next_row = render_tree_item(ctx, dl, node, 0, current_y, x, w, {}, is_last, row_index)
    current_y = next_y
    row_index = next_row
  end

  ImGui.DrawList_PopClipRect(dl)
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
  return changed and new_value or value
end

-- ============================================================================
-- MAIN SHELL
-- ============================================================================

Shell.run({
  title = "Custom TreeView Prototype",
  version = "v2.0.0",
  version_color = hexrgb("#888888FF"),
  initial_pos = { x = 120, y = 120 },
  initial_size = { w = 700, h = 700 },
  min_size = { w = 600, h = 500 },
  icon_color = hexrgb("#4A9EFFFF"),
  icon_size = 18,

  draw = function(ctx, shell_state)
    ImGui.Text(ctx, "Custom TreeView - Full Control Demo")
    ImGui.Text(ctx, "Complete pixel-perfect control with all features")
    ImGui.Separator(ctx)

    -- Left column: Config
    local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
    local left_width = 280

    ImGui.BeginChild(ctx, "config_panel", left_width, 0, ImGui.ChildFlags_Border)

    config_section(ctx, "Dimensions")
    TREE_CONFIG.item_height = slider_int(ctx, "Item Height", TREE_CONFIG.item_height, 14, 28, 200)
    TREE_CONFIG.indent_width = slider_int(ctx, "Indent Width", TREE_CONFIG.indent_width, 16, 36, 200)
    TREE_CONFIG.arrow_size = slider_int(ctx, "Arrow Size", TREE_CONFIG.arrow_size, 3, 8, 200)
    TREE_CONFIG.icon_width = slider_int(ctx, "Icon Width", TREE_CONFIG.icon_width, 10, 20, 200)

    config_section(ctx, "Padding")
    TREE_CONFIG.padding_left = slider_int(ctx, "Padding Left", TREE_CONFIG.padding_left, 0, 16, 200)
    TREE_CONFIG.padding_top = slider_int(ctx, "Padding Top", TREE_CONFIG.padding_top, 0, 16, 200)
    TREE_CONFIG.item_padding_left = slider_int(ctx, "Item Pad L", TREE_CONFIG.item_padding_left, 0, 8, 200)
    TREE_CONFIG.item_padding_right = slider_int(ctx, "Item Pad R", TREE_CONFIG.item_padding_right, 0, 12, 200)

    config_section(ctx, "Visual Features")
    TREE_CONFIG.show_tree_lines = checkbox(ctx, "Show Tree Lines", TREE_CONFIG.show_tree_lines)
    if TREE_CONFIG.show_tree_lines then
      ImGui.Indent(ctx, 20)
      TREE_CONFIG.tree_line_thickness = slider_int(ctx, "Line Thick", TREE_CONFIG.tree_line_thickness, 1, 3, 160)
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

    -- Right column: Tree view
    ImGui.SameLine(ctx)

    local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
    local tree_x, tree_y = ImGui.GetCursorScreenPos(ctx)
    local tree_h = avail_h - 60

    draw_custom_tree(ctx, mock_tree, tree_x, tree_y, avail_w, tree_h)

    ImGui.SetCursorScreenPos(ctx, tree_x, tree_y + tree_h + 4)

    -- Status
    ImGui.Separator(ctx)
    ImGui.Text(ctx, string.format("Selected: %s  |  Hovered: %s  |  Scroll: %d",
      tree_state.selected or "None",
      tree_state.hovered or "None",
      math.floor(tree_state.scroll_y)))

    -- Reset hovered state each frame
    tree_state.hovered = nil
  end,
})
