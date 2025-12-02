-- @noindex
-- Arkitekt/gui/widgets/panel/header/init.lua
-- Header coordinator - supports top and bottom positioning

local ImGui = require('arkitekt.platform.imgui')

local Layout = require('arkitekt.gui.widgets.containers.panel.header.layout')
local Theme = require('arkitekt.core.theme')
local C = Theme.COLORS          -- Shared primitives
local PC = Theme.build_panel_colors()   -- Panel-specific colors


local M = {}

-- ============================================================================
-- STATE VALIDATION
-- ============================================================================

--- Ensures the state object has the required _panel_id field for proper
--- panel context detection in child widgets (buttons, dropdowns, etc.)
--- Without this, widgets will fall back to standalone mode and lose
--- automatic corner rounding behavior.
--- @param state table Panel state object
--- @param panel_id string Panel ID to inject if missing
--- @return table Validated state with _panel_id
local function ensure_panel_context(state, panel_id)
  if not state then
    state = {}
  end
  
  -- Inject _panel_id if not present
  -- This is critical for widgets to detect they're in a panel context
  if not state._panel_id and panel_id then
    state._panel_id = panel_id
  end
  
  -- Also ensure state has an id field for element state management
  if not state.id and panel_id then
    state.id = panel_id
  end
  
  return state
end

-- ============================================================================
-- HEADER BACKGROUND DRAWING
-- ============================================================================

--- Draw toolbar background (horizontal: top or bottom)
--- @param ctx userdata ImGui context
--- @param dl userdata ImGui draw list
--- @param x number X position
--- @param y number Y position
--- @param w number Width
--- @param h number Height
--- @param state table Panel state
--- @param toolbar_cfg table Toolbar configuration (not config.header!)
--- @param rounding number Corner rounding
--- @param position string|nil Position ('top' or 'bottom'), defaults to toolbar_cfg.position or 'top'
--- @return number Height consumed
function M.Draw(ctx, dl, x, y, w, h, state, toolbar_cfg, rounding, position)
  if not toolbar_cfg or not toolbar_cfg.enabled then
    return 0
  end

  -- Use explicit position parameter, fallback to config, default to 'top'
  position = position or toolbar_cfg.position or 'top'

  -- Determine corner flags based on position
  local corner_flags
  if position == 'bottom' then
    corner_flags = ImGui.DrawFlags_RoundCornersBottom
  else
    corner_flags = ImGui.DrawFlags_RoundCornersTop
  end

  -- Draw header background (read dynamically from Theme.COLORS for theme reactivity)
  -- BG_HEADER = 30,30,30 for dark theme (between BG_BASE=36 and BG_PANEL=26)
  local bg_color = toolbar_cfg.bg_color or C.BG_HEADER
  ImGui.DrawList_AddRectFilled(
    dl, x, y, x + w, y + h,
    bg_color,
    rounding,
    corner_flags
  )

  -- Draw border (top or bottom depending on position)
  local border_color = toolbar_cfg.border_color or C.BORDER_OUTER
  if position == 'bottom' then
    ImGui.DrawList_AddLine(
      dl, x, y, x + w, y,
      border_color,
      1
    )
  else
    ImGui.DrawList_AddLine(
      dl, x, y + h - 1, x + w, y + h - 1,
      border_color,
      1
    )
  end

  return h
end

-- ============================================================================
-- HEADER ELEMENTS DRAWING
-- ============================================================================

--- Draws toolbar elements (buttons, dropdowns, etc.) using the layout engine.
--- IMPORTANT: This function MUST receive a state object with _panel_id set,
--- otherwise child widgets will not detect panel context and will fall back
--- to standalone rendering (all corners rounded, no smart corner detection).
--- @param ctx ImGui context
--- @param dl ImGui draw list
--- @param x number X position
--- @param y number Y position
--- @param w number Width
--- @param h number Height
--- @param state table Panel state (MUST have _panel_id field)
--- @param toolbar_cfg table Toolbar configuration (not config.header!)
--- @param position string|nil Position ('top' or 'bottom'), stored in toolbar_cfg for downstream use
function M.draw_elements(ctx, dl, x, y, w, h, state, toolbar_cfg, position)
  if not toolbar_cfg or not toolbar_cfg.enabled then
    return
  end

  -- Store position in toolbar_cfg if provided (for layout/element rendering)
  -- This is the ONE place we mutate, but only for downstream layout - not for logic
  if position then
    toolbar_cfg.position = position
  end

  -- Validate and ensure proper panel context
  -- Extract panel ID from state
  local panel_id = (state and state.id) or 'unknown_panel'
  state = ensure_panel_context(state, panel_id)

  -- Draw toolbar elements with validated state
  -- The layout engine will pass corner_rounding info to each element
  -- and elements will detect panel context via state._panel_id
  Layout.Draw(ctx, dl, x, y, w, h, state, toolbar_cfg)
end

return M
