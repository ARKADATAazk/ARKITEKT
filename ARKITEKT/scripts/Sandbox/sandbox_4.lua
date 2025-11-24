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
  item_height = 17,          -- Exact height per entry
  indent_width = 22,         -- Indentation per level
  arrow_size = 5,            -- Arrow width/height
  arrow_margin = 6,          -- Space after arrow
  icon_width = 13,           -- Folder icon width
  icon_margin = 4,           -- Space after icon
  text_padding_left = 2,     -- Padding before text

  -- Colors
  bg_hover = hexrgb("#2E2E2EFF"),
  bg_selected = hexrgb("#393939FF"),
  bg_selected_hover = hexrgb("#3E3E3EFF"),
  text_normal = hexrgb("#CCCCCCFF"),
  text_hover = hexrgb("#FFFFFFFF"),
  arrow_color = hexrgb("#B0B0B0FF"),
  icon_color = hexrgb("#888888FF"),
  icon_open_color = hexrgb("#9A9A9AFF"),
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
          { id = "components", name = "components", children = {} },
          { id = "utils", name = "utils", children = {} },
          { id = "styles", name = "styles", children = {} },
        }
      },
      {
        id = "docs",
        name = "Documentation",
        color = hexrgb("#FFA726FF"),
        children = {
          { id = "guides", name = "Guides", children = {} },
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
    }
  }
}

local tree_state = {
  open = { root = true, src = true, docs = true },
  selected = nil,
  hovered = nil,
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

-- ============================================================================
-- TREE RENDERING
-- ============================================================================

local function render_tree_item(ctx, dl, node, depth, y_pos, visible_x, visible_w)
  local cfg = TREE_CONFIG
  local item_h = cfg.item_height

  -- Calculate positions
  local indent_x = visible_x + depth * cfg.indent_width
  local arrow_x = indent_x
  local arrow_y = y_pos + (item_h - cfg.arrow_size) / 2
  local icon_x = arrow_x + cfg.arrow_size + cfg.arrow_margin
  local icon_y = y_pos + (item_h - 9) / 2  -- 9 = total icon height (tab + body)
  local text_x = icon_x + cfg.icon_width + cfg.icon_margin + cfg.text_padding_left
  local text_y = y_pos + (item_h - ImGui.CalcTextSize(ctx, "Tg")) / 2

  local item_right = visible_x + visible_w

  -- Check hover
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= visible_x and mx < item_right and my >= y_pos and my < y_pos + item_h

  -- Check selection
  local is_selected = tree_state.selected == node.id

  -- Draw background
  if is_selected then
    local bg_color = is_hovered and cfg.bg_selected_hover or cfg.bg_selected
    ImGui.DrawList_AddRectFilled(dl, visible_x, y_pos, item_right, y_pos + item_h, bg_color)
  elseif is_hovered then
    ImGui.DrawList_AddRectFilled(dl, visible_x, y_pos, item_right, y_pos + item_h, cfg.bg_hover)
  end

  -- Draw arrow if has children
  local is_open = tree_state.open[node.id]
  local has_children = node.children and #node.children > 0

  if has_children then
    draw_arrow(dl, arrow_x, arrow_y, is_open, cfg.arrow_color)
  end

  -- Draw folder icon
  local icon_color = node.color or (is_open and cfg.icon_open_color or cfg.icon_color)
  draw_folder_icon(dl, icon_x, icon_y, is_open, icon_color)

  -- Draw text
  local text_color = (is_hovered or is_selected) and cfg.text_hover or cfg.text_normal
  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, node.name)

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

  -- Render children if open
  if is_open and has_children then
    for _, child in ipairs(node.children) do
      next_y = render_tree_item(ctx, dl, child, depth + 1, next_y, visible_x, visible_w)
    end
  end

  return next_y
end

local function draw_custom_tree(ctx, nodes, x, y, w, h)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Draw container background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, hexrgb("#1A1A1AFF"))
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, hexrgb("#000000DD"))

  -- Clip rendering to container
  ImGui.DrawList_PushClipRect(dl, x, y, x + w, y + h, true)

  local current_y = y + 4  -- Top padding

  for _, node in ipairs(nodes) do
    current_y = render_tree_item(ctx, dl, node, 0, current_y, x + 4, w - 8)
  end

  ImGui.DrawList_PopClipRect(dl)
end

-- ============================================================================
-- MAIN SHELL
-- ============================================================================

Shell.run({
  title = "Custom TreeView Prototype",
  version = "v1.0.0",
  version_color = hexrgb("#888888FF"),
  initial_pos = { x = 120, y = 120 },
  initial_size = { w = 500, h = 600 },
  min_size = { w = 400, h = 400 },
  icon_color = hexrgb("#4A9EFFFF"),
  icon_size = 18,

  draw = function(ctx, shell_state)
    ImGui.Text(ctx, "Custom TreeView - Full Control Demo")
    ImGui.Text(ctx, string.format("Item Height: %dpx (configurable)", TREE_CONFIG.item_height))
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "")

    -- Config controls
    ImGui.Text(ctx, "Configuration:")
    ImGui.SetNextItemWidth(ctx, 200)
    local changed, new_height = ImGui.SliderInt(ctx, "Item Height", TREE_CONFIG.item_height, 14, 24)
    if changed then
      TREE_CONFIG.item_height = new_height
    end

    ImGui.SetNextItemWidth(ctx, 200)
    local changed2, new_indent = ImGui.SliderInt(ctx, "Indent Width", TREE_CONFIG.indent_width, 16, 32)
    if changed2 then
      TREE_CONFIG.indent_width = new_indent
    end

    ImGui.Text(ctx, "")
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "")

    -- Tree view
    local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
    local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
    local tree_h = avail_h - 60

    draw_custom_tree(ctx, mock_tree, cursor_x, cursor_y, avail_w, tree_h)

    ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + tree_h + 10)

    -- Status
    ImGui.Separator(ctx)
    ImGui.Text(ctx, string.format("Selected: %s", tree_state.selected or "None"))
    ImGui.Text(ctx, string.format("Hovered: %s", tree_state.hovered or "None"))

    -- Reset hovered state each frame
    tree_state.hovered = nil
  end,
})
