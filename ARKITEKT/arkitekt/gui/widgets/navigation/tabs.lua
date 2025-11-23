-- @noindex
-- arkitekt/gui/widgets/navigation/tabs.lua
-- Simple tab navigation widget with arkitekt styling

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Button = require('arkitekt.gui.widgets.primitives.button')
local Colors = require('arkitekt.core.colors')

local M = {}

-- ============================================================================
-- TAB RENDERING
-- ============================================================================

local function render_tab(ctx, tab_id, label, is_active, width, height, config)
  local button_config = {
    label = label,
    width = width,
    height = height,
    style = is_active and "primary" or "secondary",
    bg_color = is_active and (config.active_color or Colors.hexrgb("#2A5599")) or (config.bg_color or Colors.hexrgb("#252525")),
    text_color = config.text_color or Colors.hexrgb("#FFFFFF"),
    border_thickness = 0,
    rounding = config.rounding or 0,
  }

  return Button.draw_at_cursor(ctx, button_config, "tab_" .. tab_id)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw tabs at cursor position
-- @param ctx ImGui context
-- @param tabs Table of tab definitions: { { id = "tab1", label = "Tab 1", badge = 5 }, ... }
-- @param active_tab Currently active tab id
-- @param user_config Optional configuration table
-- @return clicked_tab_id or nil if no tab was clicked
function M.draw_at_cursor(ctx, tabs, active_tab, user_config)
  if not tabs or #tabs == 0 then return nil end

  local config = user_config or {}
  local tab_height = config.height or 24
  local tab_width = config.tab_width or nil  -- nil = auto-calculate equal widths
  local spacing = config.spacing or 0

  -- Calculate tab width if not specified
  if not tab_width then
    local available_width = config.available_width or ImGui.GetContentRegionAvail(ctx)
    tab_width = math.floor((available_width - (spacing * (#tabs - 1))) / #tabs)
  end

  local clicked_tab = nil

  for i, tab in ipairs(tabs) do
    local is_active = (tab.id == active_tab)

    -- Build label with optional badge
    local label = tab.label
    if tab.badge and tab.badge > 0 then
      label = string.format("%s (%d)", tab.label, tab.badge)
    end

    -- Render tab button
    local clicked = render_tab(ctx, tab.id, label, is_active, tab_width, tab_height, config)

    if clicked then
      clicked_tab = tab.id
    end

    -- Add spacing between tabs
    if i < #tabs then
      ImGui.SameLine(ctx, 0, spacing)
    end
  end

  return clicked_tab
end

--- Draw tabs with full control over position
-- @param ctx ImGui context
-- @param x X position
-- @param y Y position
-- @param tabs Table of tab definitions
-- @param active_tab Currently active tab id
-- @param user_config Optional configuration table
-- @return clicked_tab_id or nil if no tab was clicked
function M.draw(ctx, x, y, tabs, active_tab, user_config)
  ImGui.SetCursorScreenPos(ctx, x, y)
  return M.draw_at_cursor(ctx, tabs, active_tab, user_config)
end

--- Draw vertical tabs (stacked)
-- @param ctx ImGui context
-- @param tabs Table of tab definitions
-- @param active_tab Currently active tab id
-- @param user_config Optional configuration table
-- @return clicked_tab_id or nil if no tab was clicked
function M.draw_vertical(ctx, tabs, active_tab, user_config)
  if not tabs or #tabs == 0 then return nil end

  local config = user_config or {}
  local tab_height = config.height or 24
  local tab_width = config.width or -1  -- -1 = fill available width
  local spacing = config.spacing or 2

  local clicked_tab = nil

  for i, tab in ipairs(tabs) do
    local is_active = (tab.id == active_tab)

    -- Build label with optional badge
    local label = tab.label
    if tab.badge and tab.badge > 0 then
      label = string.format("%s (%d)", tab.label, tab.badge)
    end

    -- Render tab button
    local clicked = render_tab(ctx, tab.id, label, is_active, tab_width, tab_height, config)

    if clicked then
      clicked_tab = tab.id
    end

    -- Add spacing between tabs
    if i < #tabs and spacing > 0 then
      ImGui.Dummy(ctx, 0, spacing)
    end
  end

  return clicked_tab
end

return M
