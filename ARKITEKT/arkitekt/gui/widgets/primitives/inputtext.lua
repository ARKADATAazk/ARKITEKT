-- @noindex
-- arkitekt/gui/widgets/primitives/fields.lua
-- Standardized text input field widget with Arkitekt styling
-- Uses unified opts-based API
-- Includes search input variant

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('arkitekt.gui.style.defaults')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local hexrgb = Colors.hexrgb

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = "field",

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  width = 200,
  height = 24,

  -- State
  text = "",
  disabled = false,

  -- Content
  hint = nil,
  placeholder = nil,  -- Alias for hint (search compatibility)
  multiline = false,
  flags = nil,  -- ImGui.InputTextFlags_*

  -- Style
  rounding = 4,
  padding_x = 8,
  padding_y = 4,
  fade_speed = 8.0,
  border_thickness = 1,
  preset = nil,  -- "search" or custom preset table

  -- Colors
  bg_color = nil,
  bg_hover_color = nil,
  bg_active_color = nil,
  bg_disabled_color = nil,
  border_color = nil,
  border_hover_color = nil,
  border_active_color = nil,
  border_disabled_color = nil,
  border_inner_color = nil,
  border_outer_color = nil,
  text_color = nil,
  text_disabled_color = nil,

  -- Panel integration
  panel_state = nil,
  corner_rounding = nil,

  -- Callbacks
  on_change = nil,
  tooltip = nil,

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- STATE MANAGEMENT (strong table for stable animation state)
-- ============================================================================

-- Use strong table like combo (prevents GC from clearing animation state during hover)
local field_state = {}

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
-- CONFIG RESOLUTION
-- ============================================================================

local function resolve_config(opts)
  local base = {
    bg_color = hexrgb("#1A1A1A"),
    bg_hover_color = hexrgb("#222222"),
    bg_active_color = hexrgb("#252525"),
    bg_disabled_color = hexrgb("#151515"),
    border_color = hexrgb("#3A3A3A"),
    border_hover_color = hexrgb("#4A4A4A"),
    border_active_color = hexrgb("#4A9EFF"),
    border_disabled_color = hexrgb("#2A2A2A"),
    border_inner_color = hexrgb("#3A3A3A"),
    border_outer_color = hexrgb("#0A0A0A"),
    text_color = hexrgb("#FFFFFF"),
    text_disabled_color = hexrgb("#808080"),
  }

  -- Apply search preset if specified
  if opts.preset == "search" and Style.SEARCH_INPUT then
    base = Style.apply_defaults(base, Style.SEARCH_INPUT)
  elseif type(opts.preset) == "table" then
    base = Style.apply_defaults(base, opts.preset)
  end

  return Style.apply_defaults(base, opts)
end

-- ============================================================================
-- CORNER ROUNDING HELPERS
-- ============================================================================

local function get_corner_flags(corner_rounding)
  if not corner_rounding then
    return 0
  end
  return Style.RENDER.get_corner_flags(corner_rounding)
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_text_field(ctx, dl, x, y, width, height, config, state, id, is_disabled, corner_rounding)
  -- Check hover using GetMousePos (same as combo - avoids ImGui state conflicts)
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = not is_disabled and mx >= x and mx < x + width and my >= y and my < y + height

  -- Animate focus alpha
  local target_alpha = state.focused and 1.0 or (is_hovered and 0.7 or 0.3)
  local alpha_delta = (target_alpha - state.focus_alpha) * (config.fade_speed or 8.0) * ImGui.GetDeltaTime(ctx)
  state.focus_alpha = math.max(0.0, math.min(1.0, state.focus_alpha + alpha_delta))

  -- Get state colors
  local bg_color, border_inner, border_outer, text_color

  if is_disabled then
    bg_color = config.bg_disabled_color
    border_inner = config.border_disabled_color or config.border_inner_color
    border_outer = config.border_outer_color
    text_color = config.text_disabled_color
  elseif state.focused then
    bg_color = config.bg_active_color
    border_inner = config.border_active_color or config.border_inner_color
    border_outer = config.border_outer_color
    text_color = config.text_color
  elseif is_hovered then
    bg_color = config.bg_hover_color
    border_inner = config.border_hover_color or config.border_inner_color
    border_outer = config.border_outer_color
    text_color = config.text_color
  else
    bg_color = config.bg_color
    border_inner = config.border_inner_color or config.border_color
    border_outer = config.border_outer_color
    text_color = config.text_color
  end

  -- Calculate rounding
  local rounding = config.rounding or 4
  if corner_rounding then
    rounding = corner_rounding.rounding or rounding
  end
  local inner_rounding = math.max(0, rounding - 2)
  local corner_flags = get_corner_flags(corner_rounding)

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, bg_color, inner_rounding, corner_flags)

  -- Draw borders (dual border style like buttons)
  if config.border_inner_color or config.border_outer_color then
    ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + width - 1, y + height - 1, border_inner, inner_rounding, corner_flags, 1)
    ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, border_outer, inner_rounding, corner_flags, 1)
  else
    -- Simple single border
    local border_thickness = config.border_thickness or 1
    ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, border_inner, rounding, corner_flags, border_thickness)
  end

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

  -- Handle disabled state
  if is_disabled then
    ImGui.BeginDisabled(ctx)
  end

  -- Get hint text (support both hint and placeholder)
  local hint_text = config.hint or config.placeholder

  if config.multiline then
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
    if hint_text then
      changed, new_text = ImGui.InputTextWithHint(
        ctx,
        input_id,
        hint_text,
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

  if is_disabled then
    ImGui.EndDisabled(ctx)
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

  return changed, is_hovered
end

-- ============================================================================
-- PUBLIC API (Standardized)
-- ============================================================================

--- Draw a text field widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { changed, value, width, height, hovered, active }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)
  local config = resolve_config(opts)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(opts, "field")

  -- Get or create state
  local state = get_or_create_state(unique_id)

  -- Support get_value callback pattern for panel integration
  -- This allows external state management (e.g., app_state.search_query)
  if opts.get_value and type(opts.get_value) == "function" then
    state.text = opts.get_value() or ""
  elseif opts.text and state.text == "" then
    -- Set initial text if provided and state is empty
    state.text = opts.text
  end

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local width = opts.width or 200
  local height = opts.height or 24

  -- Render text field
  local changed, is_hovered = render_text_field(ctx, dl, x, y, width, height, config, state, unique_id, opts.disabled, opts.corner_rounding)

  -- Handle tooltip
  if is_hovered and opts.tooltip then
    ImGui.SetTooltip(ctx, opts.tooltip)
  end

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, width, height, opts.advance)

  -- Return standardized result
  return Base.create_result({
    changed = changed,
    value = state.text,
    width = width,
    height = height,
    hovered = is_hovered,
    active = state.focused,
  })
end

--- Draw a search input (convenience wrapper with search preset)
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result
function M.search(ctx, opts)
  opts = opts or {}
  opts.preset = opts.preset or "search"
  opts.id = opts.id or "search"
  return M.draw(ctx, opts)
end

--- Get text value for a field
--- @param id string Field identifier
--- @return string Current text value
function M.get_text(id)
  if field_state[id] then
    return field_state[id].text or ""
  end
  return ""
end

--- Set text value for a field
--- @param id string Field identifier
--- @param text string New text value
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

--- Clear text for a field
--- @param id string Field identifier
function M.clear(id)
  if field_state[id] then
    field_state[id].text = ""
  end
end

--- Clean up all field instances
function M.cleanup()
  Base.cleanup_registry(field_state)
end

return M
