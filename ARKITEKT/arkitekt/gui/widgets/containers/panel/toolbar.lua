-- @noindex
-- panel/toolbar.lua
-- Unified toolbar system for all four sides (top, bottom, left, right)
-- Replaces the confusing header/footer/sidebar terminology with consistent "toolbar" concept

local ImGui = require('arkitekt.platform.imgui')

-- Delegate to existing specialized renderers
local Header = require('arkitekt.gui.widgets.containers.panel.header')
local Sidebars = require('arkitekt.gui.widgets.containers.panel.sidebars')

local M = {}

-- ============================================================================
-- TOOLBAR ORIENTATION DETECTION
-- ============================================================================

--- Determine if toolbar is horizontal (top/bottom) or vertical (left/right)
--- @param position string Toolbar position ("top", "bottom", "left", "right")
--- @return string "horizontal" or "vertical"
local function get_orientation(position)
  if position == "top" or position == "bottom" then
    return "horizontal"
  else
    return "vertical"
  end
end

-- ============================================================================
-- TOOLBAR BACKGROUND RENDERING
-- ============================================================================

--- Draw toolbar background
--- @param ctx userdata ImGui context
--- @param dl userdata ImGui draw list
--- @param x number X position
--- @param y number Y position
--- @param w number Width
--- @param h number Height
--- @param state table Panel state
--- @param toolbar_cfg table Toolbar configuration
--- @param rounding number Corner rounding
--- @param position string Toolbar position ("top", "bottom", "left", "right")
--- @return number Toolbar size (width or height depending on orientation)
function M.draw_background(ctx, dl, x, y, w, h, state, toolbar_cfg, rounding, position)
  local orientation = get_orientation(position)

  if orientation == "horizontal" then
    return Header.draw(ctx, dl, x, y, w, h, state, toolbar_cfg, rounding, position)
  else
    -- Vertical toolbars (left/right) don't have backgrounds - they're just button stacks
    return 0
  end
end

-- ============================================================================
-- TOOLBAR ELEMENTS RENDERING
-- ============================================================================

--- Draw toolbar elements (buttons, tabs, search, etc.)
--- @param ctx userdata ImGui context
--- @param dl userdata ImGui draw list
--- @param x number X position
--- @param y number Y position
--- @param w number Width (for horizontal) or panel width (for vertical)
--- @param h number Height (for vertical) or toolbar height (for horizontal)
--- @param state table Panel state
--- @param toolbar_cfg table Toolbar configuration
--- @param panel_id string Panel ID
--- @param position string Toolbar position ("top", "bottom", "left", "right")
--- @return number Toolbar size consumed (width for vertical, height for horizontal)
function M.draw_elements(ctx, dl, x, y, w, h, state, toolbar_cfg, panel_id, position)
  local orientation = get_orientation(position)

  if orientation == "horizontal" then
    Header.draw_elements(ctx, dl, x, y, w, h, state, toolbar_cfg, position)
    return h  -- Return height consumed
  else
    -- Delegate to sidebar renderer
    local side = (position == "left") and "left" or "right"

    if not toolbar_cfg then
      return 0
    end

    return Sidebars.draw(ctx, dl, x, y, w, h, toolbar_cfg, panel_id, side)
  end
end

-- ============================================================================
-- UNIFIED TOOLBAR API (Future: Single Config Entry Point)
-- ============================================================================

--- Draw a toolbar at any position with unified API
--- This is the future-facing API that will eventually replace separate
--- header/footer/sidebar config sections
--- @param ctx userdata ImGui context
--- @param dl userdata ImGui draw list
--- @param x number X position
--- @param y number Y position
--- @param w number Width (for horizontal) or available height (for vertical)
--- @param h number Height (for horizontal) or available width (for vertical)
--- @param toolbar_cfg table Toolbar configuration
--- @param state table Panel state
--- @param panel_config table Full panel config
--- @param panel_id string Panel ID
--- @param position string Toolbar position ("top", "bottom", "left", "right")
--- @return number Size consumed (width for vertical, height for horizontal)
function M.draw(ctx, dl, x, y, w, h, toolbar_cfg, state, panel_config, panel_id, position)
  if not toolbar_cfg or not toolbar_cfg.enabled then
    return 0
  end

  local orientation = get_orientation(position)
  local rounding = panel_config.rounding or 0

  -- Draw background (horizontal toolbars only)
  if orientation == "horizontal" then
    M.draw_background(ctx, dl, x, y, w, h, state, toolbar_cfg, rounding, position)
  end

  -- Draw elements
  return M.draw_elements(ctx, dl, x, y, w, h, state, toolbar_cfg, panel_id, position)
end

-- ============================================================================
-- MIGRATION HELPERS
-- ============================================================================

--- Check if toolbar config exists for a given position
--- Handles both old (header/footer/sidebar) and new (toolbar) config formats
--- @param config table Panel config
--- @param position string Position ("top", "bottom", "left", "right")
--- @return boolean True if toolbar is enabled at this position
function M.has_toolbar(config, position)
  -- Check new unified format first
  if config.toolbars and config.toolbars[position] then
    return config.toolbars[position].enabled ~= false
  end

  -- Fall back to legacy format
  if position == "top" then
    return config.header and config.header.enabled and (config.header.position == "top" or not config.header.position)
  elseif position == "bottom" then
    return (config.footer and config.footer.enabled) or
           (config.header and config.header.enabled and config.header.position == "bottom")
  elseif position == "left" then
    return config.left_sidebar and config.left_sidebar.enabled
  elseif position == "right" then
    return config.right_sidebar and config.right_sidebar.enabled
  end

  return false
end

--- Get toolbar config for a given position
--- Handles both old and new config formats
--- @param config table Panel config
--- @param position string Position ("top", "bottom", "left", "right")
--- @return table|nil Toolbar config or nil if disabled
function M.get_toolbar_config(config, position)
  -- Check new unified format first
  if config.toolbars and config.toolbars[position] then
    return config.toolbars[position]
  end

  -- Fall back to legacy format
  if position == "top" then
    if config.header and config.header.enabled and (config.header.position == "top" or not config.header.position) then
      return config.header
    end
  elseif position == "bottom" then
    if config.footer and config.footer.enabled then
      return config.footer
    elseif config.header and config.header.enabled and config.header.position == "bottom" then
      return config.header
    end
  elseif position == "left" then
    -- FIX: Check enabled flag before returning sidebar config
    if config.left_sidebar and config.left_sidebar.enabled then
      return config.left_sidebar
    end
  elseif position == "right" then
    -- FIX: Check enabled flag before returning sidebar config
    if config.right_sidebar and config.right_sidebar.enabled then
      return config.right_sidebar
    end
  end

  return nil
end

return M
