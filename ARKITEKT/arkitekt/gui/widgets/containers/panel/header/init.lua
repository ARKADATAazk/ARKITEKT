-- @noindex
-- Arkitekt/gui/widgets/panel/header/init.lua
-- Header coordinator - supports top and bottom positioning

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Layout = require('arkitekt.gui.widgets.containers.panel.header.layout')
local Style = require('arkitekt.gui.style.defaults')
local C = Style.COLORS          -- Shared primitives
local PC = Style.PANEL_COLORS   -- Panel-specific colors


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

function M.draw(ctx, dl, x, y, w, h, state, config, rounding)
  local header_cfg = config.header
  if not header_cfg or not header_cfg.enabled then
    return 0
  end
  
  local position = header_cfg.position or "top"
  
  -- Determine corner flags based on position
  local corner_flags
  if position == "bottom" then
    corner_flags = ImGui.DrawFlags_RoundCornersBottom
  else
    corner_flags = ImGui.DrawFlags_RoundCornersTop
  end
  
  -- Draw header background
  ImGui.DrawList_AddRectFilled(
    dl, x, y, x + w, y + h,
    header_cfg.bg_color or PC.bg_header,
    rounding,
    corner_flags
  )

  -- Draw border (top or bottom depending on position)
  if position == "bottom" then
    ImGui.DrawList_AddLine(
      dl, x, y, x + w, y,
      header_cfg.border_color or PC.border_header,
      1
    )
  else
    ImGui.DrawList_AddLine(
      dl, x, y + h - 1, x + w, y + h - 1,
      header_cfg.border_color or PC.border_header,
      1
    )
  end
  
  return h
end

-- ============================================================================
-- HEADER ELEMENTS DRAWING
-- ============================================================================

--- Draws header elements (buttons, dropdowns, etc.) using the layout engine.
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
--- @param config table Panel config with header configuration
function M.draw_elements(ctx, dl, x, y, w, h, state, config)
  local header_cfg = config.header
  if not header_cfg or not header_cfg.enabled then
    return
  end
  
  -- Validate and ensure proper panel context
  -- Extract panel ID from state or config
  local panel_id = (state and state.id) or (config and config.id) or "unknown_panel"
  state = ensure_panel_context(state, panel_id)
  
  -- Draw header elements with validated state
  -- The layout engine will pass corner_rounding info to each element
  -- and elements will detect panel context via state._panel_id
  Layout.draw(ctx, dl, x, y, w, h, state, header_cfg)
end

return M
