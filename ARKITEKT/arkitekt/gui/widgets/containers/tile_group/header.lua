-- @noindex
-- arkitekt/gui/widgets/containers/tile_group/header.lua
-- Renders collapsible group headers for tile groups

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Defaults = require('arkitekt.gui.widgets.containers.tile_group.defaults')
local hexrgb = Colors.hexrgb

local M = {}

--- Renders a group header with collapse/expand functionality
--- @param ctx ImGui context
--- @param rect table {x1, y1, x2, y2} - Header bounding box
--- @param group table - Group data {name, color, collapsed, count}
--- @param state table - {hover} - Interaction state
--- @param config table - Optional styling overrides
--- @return boolean - True if clicked (toggle collapse state)
function M.render(ctx, rect, group, state, config)
  config = config or {}

  -- Merge config with defaults (use inverted ternary to handle false values correctly)
  local cfg = {}
  for k, v in pairs(Defaults.HEADER) do
    cfg[k] = config[k] == nil and v or config[k]
  end

  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Determine background color based on state
  local bg_color = cfg.bg_color
  if group.collapsed then
    bg_color = cfg.bg_color_collapsed
  end
  if state.hover then
    bg_color = cfg.bg_color_hover
  end

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, cfg.rounding)

  -- Draw border
  ImGui.DrawList_AddRect(dl, x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5, cfg.border_color, cfg.rounding, 0, cfg.border_thickness)

  -- Calculate positions with better vertical centering
  local content_height = cfg.icon_size  -- Use icon size as baseline for vertical alignment
  local cursor_x = x1 + cfg.padding_x
  local cursor_y = y1 + ((y2 - y1) / 2) - (content_height / 2)  -- Center vertically

  -- Draw color badge (if group has a color)
  if group.color then
    local badge_x = cursor_x
    local badge_y = cursor_y + (content_height / 2) - (cfg.color_badge_size / 2)
    local badge_size = cfg.color_badge_size

    -- Parse color if it's a hex string
    local badge_color = type(group.color) == "string" and hexrgb(group.color) or group.color
    ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x + badge_size, badge_y + badge_size, badge_color, 1)

    cursor_x = cursor_x + cfg.color_badge_size + cfg.color_badge_spacing
  end

  -- Draw collapse/expand icon (bigger and centered)
  local icon = group.collapsed and Defaults.ICONS.collapsed or Defaults.ICONS.expanded
  local icon_color = state.hover and cfg.collapse_icon_color_hover or cfg.collapse_icon_color

  -- DrawList_AddText doesn't use font stack, so no PushFont needed
  ImGui.DrawList_AddText(dl, cursor_x, cursor_y, icon_color, icon)

  cursor_x = cursor_x + cfg.icon_size + cfg.icon_spacing

  -- Draw group name (with better vertical alignment)
  -- Calculate text height for vertical centering
  local text_size_x, text_size_y = ImGui.CalcTextSize(ctx, group.name or "Unnamed Group")
  local text_y = cursor_y + (content_height / 2) - (text_size_y / 2)

  ImGui.DrawList_AddText(dl, cursor_x, text_y, cfg.text_color, group.name or "Unnamed Group")

  -- Draw item count (if available)
  if group.count and group.count > 0 then
    local count_text = string.format("(%d)", group.count)
    local count_w, count_h = ImGui.CalcTextSize(ctx, count_text)
    local count_x = x2 - cfg.padding_x - count_w
    local count_y = cursor_y + (content_height / 2) - (count_h / 2)
    ImGui.DrawList_AddText(dl, count_x, count_y, cfg.text_color_secondary, count_text)
  end

  -- Check for click
  local mx, my = ImGui.GetMousePos(ctx)
  local is_clicked = false
  if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
    if ImGui.IsMouseClicked(ctx, 0) then
      is_clicked = true
    end
  end

  return is_clicked
end

--- Calculate the height needed for a group header
--- @param config table - Optional styling overrides
--- @return number - Header height in pixels
function M.get_height(config)
  config = config or {}
  return config.height or Defaults.HEADER.height
end

return M
