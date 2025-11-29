-- @noindex
-- panel/sidebars.lua
-- Left/right sidebar button rendering
--
-- SCROLLBAR OVERLAP BEHAVIOR:
-- Right sidebar buttons may overlap with the scrollbar when scrolling is enabled.
-- The scrollbar draws on top (later in render pipeline), so scrollbar remains fully interactive.
-- Sidebar buttons remain clickable on the left side of the scrollbar.

local ImGui = require('arkitekt.platform.imgui')
local Button = require('arkitekt.gui.widgets.primitives.button')
local ConfigUtil = require('arkitekt.core.config')
local PanelConfig = require('arkitekt.gui.widgets.containers.panel.defaults')

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

M.DEFAULTS = {
  button_size = 28,
  width = 36,
  rounding = 8,
  valign = "center",  -- top, center, bottom
}

-- ============================================================================
-- LAYOUT CALCULATION
-- ============================================================================

local function calculate_layout(sidebar_cfg, panel_y, panel_height)
  local button_height = sidebar_cfg.button_size or M.DEFAULTS.button_size
  local button_width = (button_height * 0.7) // 1  -- 30% narrower
  local rounding = sidebar_cfg.rounding or M.DEFAULTS.rounding

  local elements = sidebar_cfg.elements or {}
  local count = #elements

  -- Extra height for rounding
  local corner_extension = rounding

  -- Total height with overlap
  local total_height = (count * button_height) - (count - 1) + (corner_extension * 2)

  -- Calculate start Y based on alignment
  local start_y
  local valign = sidebar_cfg.valign or M.DEFAULTS.valign
  if valign == "top" then
    start_y = panel_y
  elseif valign == "bottom" then
    start_y = panel_y + panel_height - total_height
  else -- center
    start_y = panel_y + (panel_height - total_height) / 2
  end

  return {
    button_width = button_width,
    button_height = button_height,
    rounding = rounding,
    corner_extension = corner_extension,
    start_y = start_y,
    elements = elements,
  }
end

-- ============================================================================
-- CORNER ROUNDING CONFIGURATION
-- ============================================================================

local function get_corner_rounding(side, is_first, is_last, rounding)
  if side == "left" then
    return {
      round_top_left = false,
      round_top_right = is_first,
      round_bottom_left = false,
      round_bottom_right = is_last,
      rounding = rounding,
    }
  else -- right
    return {
      round_top_left = is_first,
      round_top_right = false,
      round_bottom_left = is_last,
      round_bottom_right = false,
      rounding = rounding,
    }
  end
end

-- ============================================================================
-- SIDEBAR RENDERING
-- ============================================================================

--- Draw a sidebar (left or right)
--- @param ctx userdata ImGui context
--- @param dl userdata ImGui draw list
--- @param panel_x number Panel X position
--- @param panel_y number Panel Y position
--- @param panel_width number Panel width
--- @param panel_height number Panel height (content area)
--- @param sidebar_cfg table Sidebar configuration
--- @param panel_id string Panel ID
--- @param side string "left" or "right"
--- @return number Sidebar width consumed
function M.draw(ctx, dl, panel_x, panel_y, panel_width, panel_height, sidebar_cfg, panel_id, side)
  if not sidebar_cfg or not sidebar_cfg.enabled then
    return 0
  end

  local layout = calculate_layout(sidebar_cfg, panel_y, panel_height)

  if #layout.elements == 0 then
    return sidebar_cfg.width or M.DEFAULTS.width
  end

  -- Calculate base button X position
  local btn_x
  if side == "left" then
    btn_x = panel_x
  else -- right
    btn_x = panel_x + panel_width - layout.button_width
  end

  -- Draw each button
  for i, element in ipairs(layout.elements) do
    local is_first = (i == 1)
    local is_last = (i == #layout.elements)

    -- Calculate position and height
    local btn_y = layout.start_y + layout.corner_extension + (i - 1) * (layout.button_height - 1)
    local current_height = layout.button_height

    -- Extend first/last buttons for rounding
    if is_first then
      btn_y = btn_y - layout.corner_extension
      current_height = current_height + layout.corner_extension
    end
    if is_last then
      current_height = current_height + layout.corner_extension
    end

    -- Corner rounding config
    local corner_rounding = get_corner_rounding(side, is_first, is_last, layout.rounding)

    -- Merge element config with defaults
    local btn_config = ConfigUtil.merge_safe(element.config or {}, PanelConfig.ELEMENT_STYLE.button)
    btn_config.id = panel_id .. "_sidebar_" .. side .. "_" .. (element.id or i)
    btn_config.draw_list = dl
    btn_config.x = btn_x
    btn_config.y = btn_y
    btn_config.width = layout.button_width
    btn_config.height = current_height
    btn_config.corner_rounding = corner_rounding
    btn_config.panel_state = { _panel_id = panel_id }

    Button.draw(ctx, btn_config)
  end

  return sidebar_cfg.width or M.DEFAULTS.width
end

return M
