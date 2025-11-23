-- @noindex
-- Arkitekt/gui/widgets/controls/search_input.lua
-- Standalone search input component with Arkitekt styling
-- Can be used anywhere, with optional panel integration

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('arkitekt.gui.style.defaults')
local Tooltip = require('arkitekt.gui.widgets.overlays.tooltip')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb


local M = {}

-- Animation state storage (internal to component)
local animation_state = {}

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
    context.unique_id = string.format("%s_%s", state_or_id._panel_id, config.id or "search")
    context.corner_rounding = config.corner_rounding
  else
    -- Standalone context
    context.unique_id = type(state_or_id) == "string" and state_or_id or (config.id or "search")
    context.corner_rounding = nil
  end
  
  return context
end

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local function get_or_create_state(state_or_id, context)
  local state
  
  if context.is_panel_context then
    -- Panel context: use panel's state object
    state = state_or_id
  else
    -- Standalone context: use internal state storage
    if not animation_state[context.unique_id] then
      animation_state[context.unique_id] = {}
    end
    state = animation_state[context.unique_id]
  end
  
  -- Initialize state fields if needed
  state.search_text = state.search_text or ""
  state.search_focused = state.search_focused or false
  state.search_alpha = state.search_alpha or 0.3
  
  return state
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_search_input(ctx, dl, x, y, width, height, config, state, context)
  local is_hovered = ImGui.IsMouseHoveringRect(ctx, x, y, x + width, y + height)
  
  -- Animate placeholder alpha
  local target_alpha = (state.search_focused or is_hovered or #state.search_text > 0) and 1.0 or 0.3
  local alpha_delta = (target_alpha - state.search_alpha) * config.fade_speed * ImGui.GetDeltaTime(ctx)
  state.search_alpha = math.max(0.3, math.min(1.0, state.search_alpha + alpha_delta))
  
  -- Get state colors with smooth transitions
  local bg_color = config.bg_color
  local border_inner = config.border_inner_color
  local text_color = config.text_color
  
  if state.search_focused then
    bg_color = config.bg_active_color or bg_color
    border_inner = config.border_active_color or border_inner
  elseif is_hovered then
    bg_color = config.bg_hover_color or bg_color
    border_inner = config.border_hover_color or border_inner
  end
  
  -- Apply alpha to text (for placeholder fade)
  local alpha_byte = math.floor(state.search_alpha * 255)
  text_color = (text_color & 0xFFFFFF00) | alpha_byte
  
  -- Calculate rounding
  local rounding = config.rounding or 0
  if context.corner_rounding then
    rounding = context.corner_rounding.rounding or rounding
  end
  local inner_rounding = math.max(0, rounding - 2)
  local corner_flags = Style.RENDER.get_corner_flags(context.corner_rounding)
  
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
  
  -- Draw input field
  ImGui.SetCursorScreenPos(ctx, x + config.padding_x, y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5 - 2)
  ImGui.PushItemWidth(ctx, width - config.padding_x * 2)
  
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
  
  local changed, new_text = ImGui.InputTextWithHint(
    ctx,
    "##" .. context.unique_id,
    config.placeholder,
    state.search_text,
    ImGui.InputTextFlags_None
  )
  
  if changed then
    state.search_text = new_text
    if config.on_change then
      config.on_change(new_text)
    end
  end
  
  state.search_focused = ImGui.IsItemActive(ctx)
  
  ImGui.PopStyleColor(ctx, 5)
  ImGui.PopItemWidth(ctx)
  
  return is_hovered, changed
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function M.draw(ctx, dl, x, y, width, height, user_config, state_or_id)
  -- Apply style defaults
  local config = Style.apply_defaults(Style.SEARCH_INPUT, user_config)
  
  -- Resolve context (panel vs standalone)
  local context = resolve_context(config, state_or_id)
  
  -- Get or create state
  local state = get_or_create_state(state_or_id, context)
  
  -- Render search input
  local is_hovered, changed = render_search_input(ctx, dl, x, y, width, height, config, state, context)
  
  -- Handle tooltip
  if is_hovered and config.tooltip then
    Tooltip.show_delayed(ctx, config.tooltip, {
      delay = config.tooltip_delay or Style.TOOLTIP.delay
    })
  else
    if not is_hovered then
      Tooltip.reset()
    end
  end
  
  return width, changed
end

function M.measure(ctx, user_config)
  local config = Style.apply_defaults(Style.SEARCH_INPUT, user_config)
  return config.width or 200
end

-- ============================================================================
-- CONVENIENCE FUNCTION (Cursor-based)
-- ============================================================================

function M.draw_at_cursor(ctx, user_config, id)
  id = id or (user_config and user_config.id) or "search"
  
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  
  local width = M.measure(ctx, user_config)
  local height = user_config and user_config.height or 24
  
  local used_width, changed = M.draw(ctx, dl, cursor_x, cursor_y, width, height, user_config, id)
  
  -- Advance cursor
  ImGui.SetCursorScreenPos(ctx, cursor_x + used_width, cursor_y)
  
  return changed
end

-- ============================================================================
-- STATE ACCESSORS (for standalone use)
-- ============================================================================

function M.get_text(id)
  if animation_state[id] then
    return animation_state[id].search_text or ""
  end
  return ""
end

function M.set_text(id, text)
  if not animation_state[id] then
    animation_state[id] = {}
  end
  animation_state[id].search_text = text or ""
end

function M.clear(id)
  if animation_state[id] then
    animation_state[id].search_text = ""
  end
end

return M
