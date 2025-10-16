-- @noindex
-- ReArkitekt/gui/widgets/controls/button.lua
-- Standalone button component with ReArkitekt styling
-- Can be used anywhere, with optional panel integration

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('rearkitekt.gui.widgets.controls.style_defaults')

local M = {}

-- ============================================================================
-- CONTEXT DETECTION
-- ============================================================================

local function resolve_context(config, state_or_id)
  local context = {
    unique_id = nil,
    corner_rounding = nil,
    is_panel_context = false,
  }
  
  -- Check if we're in a panel context
  if type(state_or_id) == "table" and state_or_id._panel_id then
    context.is_panel_context = true
    context.unique_id = string.format("%s_%s", state_or_id._panel_id, config.id or "button")
    context.corner_rounding = config.corner_rounding
  else
    -- Standalone context
    context.unique_id = type(state_or_id) == "string" and state_or_id or (config.id or "button")
    context.corner_rounding = nil
  end
  
  return context
end

-- ============================================================================
-- CORNER ROUNDING
-- ============================================================================

local function get_corner_flags(corner_rounding)
  if not corner_rounding then
    return 0
  end
  
  local flags = 0
  if corner_rounding.round_top_left then
    flags = flags | ImGui.DrawFlags_RoundCornersTopLeft
  end
  if corner_rounding.round_top_right then
    flags = flags | ImGui.DrawFlags_RoundCornersTopRight
  end
  if corner_rounding.round_bottom_left then
    flags = flags | ImGui.DrawFlags_RoundCornersBottomLeft
  end
  if corner_rounding.round_bottom_right then
    flags = flags | ImGui.DrawFlags_RoundCornersBottomRight
  end
  
  return flags == 0 and ImGui.DrawFlags_RoundCornersAll or flags
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_button(ctx, dl, x, y, width, height, config, context)
  local is_hovered = ImGui.IsMouseHoveringRect(ctx, x, y, x + width, y + height)
  local is_active = ImGui.IsMouseDown(ctx, 0) and is_hovered
  
  -- Get state colors
  local bg_color = Style.get_state_color(config, is_hovered, is_active, "bg_color")
  local border_inner = Style.get_state_color(config, is_hovered, is_active, "border_inner_color")
  local text_color = Style.get_state_color(config, is_hovered, is_active, "text_color")
  
  -- Calculate rounding
  local rounding = config.rounding or 0
  if context.corner_rounding then
    rounding = context.corner_rounding.rounding or rounding
  end
  local inner_rounding = math.max(0, rounding - 2)
  local corner_flags = get_corner_flags(context.corner_rounding)
  
  -- Draw background
  ImGui.DrawList_AddRectFilled(
    dl, x, y, x + width, y + height,
    bg_color, inner_rounding, corner_flags
  )
  
  -- Draw inner border
  ImGui.DrawList_AddRect(
    dl, x + 1, y + 1, x + width - 1, y + height - 1,
    border_inner, inner_rounding, corner_flags, 1
  )
  
  -- Draw outer border
  ImGui.DrawList_AddRect(
    dl, x, y, x + width, y + height,
    config.border_outer_color, inner_rounding, corner_flags, 1
  )
  
  -- Draw content (text or custom)
  local label = config.label or ""
  local icon = config.icon or ""
  local display_text = icon .. (icon ~= "" and label ~= "" and " " or "") .. label
  
  if config.custom_draw then
    config.custom_draw(ctx, dl, x, y, width, height, is_hovered, is_active, text_color)
  elseif display_text ~= "" then
    local text_w = ImGui.CalcTextSize(ctx, display_text)
    local text_x = x + (width - text_w) * 0.5
    local text_y = y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5
    ImGui.DrawList_AddText(dl, text_x, text_y, text_color, display_text)
  end
  
  return is_hovered, is_active
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function M.draw(ctx, dl, x, y, width, height, user_config, state_or_id)
  -- Apply style defaults
  local config = Style.apply_defaults(Style.BUTTON, user_config)
  
  -- Resolve context (panel vs standalone)
  local context = resolve_context(config, state_or_id)
  
  -- Render button
  local is_hovered, is_active = render_button(ctx, dl, x, y, width, height, config, context)
  
  -- Create invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. context.unique_id, width, height)
  
  local clicked = ImGui.IsItemClicked(ctx, 0)
  
  -- Handle click callback
  if clicked and config.on_click then
    config.on_click()
  end
  
  -- Handle tooltip
  if is_hovered and config.tooltip then
    ImGui.SetTooltip(ctx, config.tooltip)
  end
  
  return width, clicked
end

function M.measure(ctx, user_config)
  local config = Style.apply_defaults(Style.BUTTON, user_config)
  
  -- Fixed width?
  if config.width then
    return config.width
  end
  
  -- Calculate from text
  local label = config.label or ""
  local icon = config.icon or ""
  local display_text = icon .. (icon ~= "" and label ~= "" and " " or "") .. label
  
  local text_w = ImGui.CalcTextSize(ctx, display_text)
  local padding = config.padding_x or 10
  
  return text_w + padding * 2
end

-- ============================================================================
-- CONVENIENCE FUNCTION (Cursor-based)
-- ============================================================================

function M.draw_at_cursor(ctx, user_config, id)
  id = id or (user_config and user_config.id) or "button"
  
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  
  local width = M.measure(ctx, user_config)
  local height = user_config and user_config.height or 24
  
  local used_width, clicked = M.draw(ctx, dl, cursor_x, cursor_y, width, height, user_config, id)
  
  -- Advance cursor
  ImGui.SetCursorScreenPos(ctx, cursor_x + used_width, cursor_y)
  
  return clicked
end

return M