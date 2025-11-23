-- @noindex
-- arkitekt/gui/widgets/primitives/fields.lua
-- Generic text input field widget with arkitekt styling

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('arkitekt.gui.style.defaults')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- Animation state storage (internal to component)
local field_state = {}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local function get_or_create_state(id)
  if not field_state[id] then
    field_state[id] = {
      text = "",
      focused = false,
      focus_alpha = 0.0,
    }
  end
  return field_state[id]
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_text_field(ctx, dl, x, y, width, height, config, state, id)
  local is_hovered = ImGui.IsMouseHoveringRect(ctx, x, y, x + width, y + height)

  -- Animate focus alpha
  local target_alpha = state.focused and 1.0 or (is_hovered and 0.7 or 0.3)
  local alpha_delta = (target_alpha - state.focus_alpha) * (config.fade_speed or 8.0) * ImGui.GetDeltaTime(ctx)
  state.focus_alpha = math.max(0.0, math.min(1.0, state.focus_alpha + alpha_delta))

  -- Get state colors
  local bg_color = config.bg_color or hexrgb("#1A1A1A")
  local border_color = config.border_color or hexrgb("#3A3A3A")
  local text_color = config.text_color or hexrgb("#FFFFFF")

  if state.focused then
    bg_color = config.bg_active_color or Colors.adjust_brightness(bg_color, 1.2)
    border_color = config.border_active_color or hexrgb("#4A9EFF")
  elseif is_hovered then
    bg_color = config.bg_hover_color or Colors.adjust_brightness(bg_color, 1.1)
    border_color = config.border_hover_color or Colors.adjust_brightness(border_color, 1.3)
  end

  -- Rounding
  local rounding = config.rounding or 4

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, bg_color, rounding)

  -- Draw border
  local border_thickness = config.border_thickness or 1
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, border_color, rounding, 0, border_thickness)

  -- Draw input field
  local padding_x = config.padding_x or 8
  local padding_y = config.padding_y or 4

  ImGui.SetCursorScreenPos(ctx, x + padding_x, y + padding_y)
  ImGui.PushItemWidth(ctx, width - padding_x * 2)

  -- Make input background transparent
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, hexrgb("#00000000"))
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)

  local changed, new_text
  local input_id = "##" .. id

  if config.multiline then
    -- Multiline text input
    local input_height = height - padding_y * 2
    changed, new_text = ImGui.InputTextMultiline(
      ctx,
      input_id,
      state.text,
      width - padding_x * 2,
      input_height,
      config.flags or ImGui.InputTextFlags_None
    )
  else
    -- Single line text input
    if config.hint then
      changed, new_text = ImGui.InputTextWithHint(
        ctx,
        input_id,
        config.hint,
        state.text,
        config.flags or ImGui.InputTextFlags_None
      )
    else
      changed, new_text = ImGui.InputText(
        ctx,
        input_id,
        state.text,
        config.flags or ImGui.InputTextFlags_None
      )
    end
  end

  if changed then
    state.text = new_text
    if config.on_change then
      config.on_change(new_text)
    end
  end

  state.focused = ImGui.IsItemActive(ctx)

  ImGui.PopStyleColor(ctx, 5)
  ImGui.PopItemWidth(ctx)

  return changed
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function M.draw(ctx, dl, x, y, width, height, user_config, id)
  id = id or (user_config and user_config.id) or "field"

  -- Get or create state
  local state = get_or_create_state(id)

  -- Set initial text if provided and state is empty
  if user_config and user_config.text and state.text == "" then
    state.text = user_config.text
  end

  -- Render text field
  local changed = render_text_field(ctx, dl, x, y, width, height, user_config or {}, state, id)

  return changed, state.text
end

function M.draw_at_cursor(ctx, user_config, id)
  id = id or (user_config and user_config.id) or "field"

  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  local width = (user_config and user_config.width) or 200
  local height = (user_config and user_config.height) or 24

  local changed, text = M.draw(ctx, dl, cursor_x, cursor_y, width, height, user_config, id)

  -- Advance cursor
  ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + height)

  return changed, text
end

-- ============================================================================
-- STATE ACCESSORS
-- ============================================================================

function M.get_text(id)
  if field_state[id] then
    return field_state[id].text or ""
  end
  return ""
end

function M.set_text(id, text)
  if not field_state[id] then
    field_state[id] = {
      text = "",
      focused = false,
      focus_alpha = 0.0,
    }
  end
  field_state[id].text = text or ""
end

function M.clear(id)
  if field_state[id] then
    field_state[id].text = ""
  end
end

return M
