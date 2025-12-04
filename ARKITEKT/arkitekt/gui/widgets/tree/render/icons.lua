-- @noindex
-- arkitekt/gui/widgets/tree/render/icons.lua
-- Icon rendering for Tree widgets

local ImGui = require('arkitekt.core.imgui')

local M = {}

-- ============================================================================
-- ARROW (expand/collapse indicator)
-- ============================================================================

--- Draw expand/collapse arrow
--- @param dl userdata DrawList
--- @param x number X position
--- @param y number Y position
--- @param is_open boolean Whether node is expanded
--- @param color number Arrow color (RRGGBBAA)
--- @param size number Arrow size in pixels
function M.arrow(dl, x, y, is_open, color, size)
  size = size or 5
  color = color or 0xB0B0B0FF

  x = (x + 0.5) // 1
  y = (y + 0.5) // 1

  if is_open then
    -- Down arrow (pointing down)
    local x1, y1 = x, y
    local x2, y2 = x + size, y
    local x3, y3 = (x + size / 2 + 0.5) // 1, y + size
    ImGui.DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)
  else
    -- Right arrow (pointing right)
    local x1, y1 = x, y
    local x2, y2 = x, y + size
    local x3, y3 = x + size, y + size / 2
    ImGui.DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)
  end
end

-- ============================================================================
-- FOLDER ICON
-- ============================================================================

--- Draw folder icon
--- @param dl userdata DrawList
--- @param x number X position
--- @param y number Y position
--- @param color number Icon color (RRGGBBAA)
--- @param is_open boolean|nil Whether folder is open (affects color)
--- @return number Width of icon including margin
function M.folder(dl, x, y, color, is_open)
  local main_w = 13
  local main_h = 7
  local tab_w = 5
  local tab_h = 2

  x = (x + 0.5) // 1
  y = (y + 0.5) // 1

  color = color or (is_open and 0x9A9A9AFF or 0x888888FF)

  -- Tab
  ImGui.DrawList_AddRectFilled(dl, x, y, x + tab_w, y + tab_h, color, 0)
  -- Body
  ImGui.DrawList_AddRectFilled(dl, x, y + tab_h, x + main_w, y + tab_h + main_h, color, 0)

  return main_w + 4
end

--- Draw virtual folder icon (outline style)
--- @param dl userdata DrawList
--- @param x number X position
--- @param y number Y position
--- @param color number Icon color (RRGGBBAA)
--- @return number Width of icon including margin
function M.folder_virtual(dl, x, y, color)
  local main_w = 13
  local main_h = 7
  local tab_w = 5
  local tab_h = 2

  x = (x + 0.5) // 1
  y = (y + 0.5) // 1

  color = color or 0x888888FF

  -- Tab (outline)
  ImGui.DrawList_AddRect(dl, x, y, x + tab_w, y + tab_h, color, 0, 0, 2)
  -- Body (outline)
  ImGui.DrawList_AddRect(dl, x, y + tab_h, x + main_w, y + tab_h + main_h, color, 0, 0, 2)

  -- V symbol inside
  local v_x = x + 4
  local v_y = y + tab_h + 2
  local v_size = 4
  ImGui.DrawList_AddLine(dl, v_x, v_y, v_x + v_size / 2, v_y + v_size, color, 1.5)
  ImGui.DrawList_AddLine(dl, v_x + v_size / 2, v_y + v_size, v_x + v_size, v_y, color, 1.5)

  return main_w + 4
end

-- ============================================================================
-- FILE ICON
-- ============================================================================

--- Draw file icon
--- @param dl userdata DrawList
--- @param x number X position
--- @param y number Y position
--- @param color number Icon color (RRGGBBAA)
--- @return number Width of icon including margin
function M.file(dl, x, y, color)
  local w = 10
  local h = 12
  local corner = 3

  x = (x + 0.5) // 1
  y = (y + 0.5) // 1

  color = color or 0x888888FF

  -- File body
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, color, 0)
  -- Corner fold
  ImGui.DrawList_AddTriangleFilled(dl, x + w - corner, y, x + w, y, x + w, y + corner, 0x000000AA)

  return w + 4
end

-- ============================================================================
-- SPECIALIZED FILE ICONS
-- ============================================================================

--- Draw Lua file icon
--- @param dl userdata DrawList
--- @param x number X position
--- @param y number Y position
--- @param color number Icon color (RRGGBBAA)
--- @return number Width of icon including margin
function M.lua(dl, x, y, color)
  color = color or 0x00007FFF  -- Blue for Lua

  x = (x + 0.5) // 1
  y = (y + 0.5) // 1

  -- Draw 'L' shape
  ImGui.DrawList_AddRectFilled(dl, x, y, x + 3, y + 12, color, 0)
  ImGui.DrawList_AddRectFilled(dl, x, y + 9, x + 10, y + 12, color, 0)

  return 10 + 4
end

--- Draw Markdown file icon
--- @param dl userdata DrawList
--- @param x number X position
--- @param y number Y position
--- @param color number Icon color (RRGGBBAA)
--- @return number Width of icon including margin
function M.markdown(dl, x, y, color)
  color = color or 0x0A7EA3FF  -- Cyan for markdown

  x = (x + 0.5) // 1
  y = (y + 0.5) // 1

  -- Draw 'M' shape using lines
  local thickness = 2
  ImGui.DrawList_AddLine(dl, x, y + 10, x, y, color, thickness)
  ImGui.DrawList_AddLine(dl, x, y, x + 5, y + 5, color, thickness)
  ImGui.DrawList_AddLine(dl, x + 5, y + 5, x + 10, y, color, thickness)
  ImGui.DrawList_AddLine(dl, x + 10, y, x + 10, y + 10, color, thickness)

  return 10 + 4
end

--- Draw config/settings file icon
--- @param dl userdata DrawList
--- @param x number X position
--- @param y number Y position
--- @param color number Icon color (RRGGBBAA)
--- @return number Width of icon including margin
function M.config(dl, x, y, color)
  color = color or 0x888888FF

  x = (x + 0.5) // 1
  y = (y + 0.5) // 1

  -- Draw gear-like shape
  ImGui.DrawList_AddCircleFilled(dl, x + 5, y + 6, 4, color)
  ImGui.DrawList_AddCircleFilled(dl, x + 5, y + 6, 2, 0x000000AA)

  return 10 + 4
end

-- ============================================================================
-- ICON TYPE DETECTION
-- ============================================================================

--- Get icon type from node
--- @param node table Node data
--- @return string Icon type: 'folder', 'folder_virtual', 'file', 'lua', 'markdown', 'config'
function M.get_type(node)
  -- Check for explicit type
  if node.icon_type then
    return node.icon_type
  end

  -- Check for folder
  if node.children and #node.children > 0 then
    return node.is_virtual and 'folder_virtual' or 'folder'
  end

  -- Detect from filename
  local name = (node.name or ''):lower()
  if name:match('%.lua$') then return 'lua' end
  if name:match('%.md$') then return 'markdown' end
  if name:match('config') or name:match('%.json$') or name:match('%.yaml$') or name:match('%.toml$') then
    return 'config'
  end

  return 'file'
end

--- Draw icon based on node type
--- @param dl userdata DrawList
--- @param x number X position
--- @param y number Y position
--- @param node table Node data
--- @param is_open boolean Whether node is expanded
--- @param color number|nil Override color
--- @return number Width of icon including margin
function M.draw(dl, x, y, node, is_open, color)
  local icon_type = M.get_type(node)
  color = color or node.color

  if icon_type == 'folder' then
    return M.folder(dl, x, y, color, is_open)
  elseif icon_type == 'folder_virtual' then
    return M.folder_virtual(dl, x, y, color)
  elseif icon_type == 'lua' then
    return M.lua(dl, x, y, color)
  elseif icon_type == 'markdown' then
    return M.markdown(dl, x, y, color)
  elseif icon_type == 'config' then
    return M.config(dl, x, y, color)
  else
    return M.file(dl, x, y, color)
  end
end

return M
