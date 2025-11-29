-- @noindex
-- arkitekt/gui/widgets/primitives/radio_button.lua
-- Standardized radio button widget with Arkitekt styling
-- Uses unified opts-based API

local ImGui = require('arkitekt.platform.imgui')
local Colors = require('arkitekt.core.colors')
local Theme = require('arkitekt.core.theme')
local Base = require('arkitekt.gui.widgets.base')

local hexrgb = Colors.hexrgb

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = "radio",

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  size = 22,           -- Outer circle diameter
  inner_size = 14,     -- Inner circle diameter
  selected_size = 10,  -- Selected indicator diameter
  spacing = 12,        -- Space between circle and label

  -- State
  selected = false,
  disabled = false,

  -- Content
  label = "",

  -- Colors
  bg_color = nil,
  bg_hover_color = nil,
  bg_active_color = nil,
  inner_color = nil,
  selected_color = nil,
  border_inner_color = nil,
  border_outer_color = nil,
  text_color = nil,
  text_hover_color = nil,

  -- Callbacks
  on_click = nil,
  tooltip = nil,

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- INSTANCE MANAGEMENT (strong tables with access tracking for cleanup)
-- ============================================================================

local instances = Base.create_instance_registry()

local function create_radio_instance(id)
  return { hover_alpha = 0 }
end

local function get_instance(id)
  return Base.get_or_create_instance(instances, id, create_radio_instance)
end

-- ============================================================================
-- PUBLIC API (Standardized)
-- ============================================================================

--- Draw a radio button widget
--- Supports both positional and opts-based parameters:
--- - Positional: Ark.RadioButton(ctx, label, active)
--- - Opts table: Ark.RadioButton(ctx, {label = "...", selected = true, ...})
--- @param ctx userdata ImGui context
--- @param label_or_opts string|table Label string or opts table
--- @param active boolean|nil Active state (positional only)
--- @return table Result { clicked, width, height, hovered, active }
function M.draw(ctx, label_or_opts, active)
  -- Hybrid parameter detection
  local opts
  if type(label_or_opts) == "table" then
    -- Opts table passed directly
    opts = label_or_opts
  elseif type(label_or_opts) == "string" then
    -- Positional params - map to opts
    opts = {
      label = label_or_opts,
      selected = active,
    }
  else
    -- No params or just ctx - empty opts
    opts = {}
  end

  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "radio")

  -- Get instance for animation
  local inst = get_instance(unique_id)

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get sizes
  local outer_radius = (opts.size or 22) / 2
  local inner_radius = (opts.inner_size or 14) / 2
  local selected_radius = (opts.selected_size or 10) / 2

  -- Calculate dimensions
  local label = opts.label or ""
  local text_w, text_h = 0, 0
  if label ~= "" then
    text_w, text_h = Base.measure_text(ctx, label)
  end

  local total_w = outer_radius * 2
  if label ~= "" then
    total_w = total_w + opts.spacing + text_w
  end
  local total_h = math.max(outer_radius * 2, text_h)

  -- Get state
  local disabled = opts.disabled or false
  local selected = opts.selected or false

  -- Check interaction
  local hovered, active = Base.get_interaction_state(ctx, x, y, total_w, total_h, opts)

  -- Update animation (slower fade for smoother effect)
  local dt = ImGui.GetDeltaTime(ctx)
  Base.update_hover_animation(inst, dt, hovered, active, "hover_alpha", 6.0)

  -- Calculate center of circle
  local center_x = x + outer_radius
  local center_y = y + outer_radius

  -- Determine colors
  local bg_color, inner_color, selected_color, text_color, border_inner, border_outer
  local white_overlay = hexrgb("#FFFFFF")

  -- Base colors
  bg_color = opts.bg_color or Theme.COLORS.BG_BASE
  inner_color = Colors.adjust_brightness(opts.inner_color or Theme.COLORS.BG_BASE, 0.85)
  selected_color = opts.selected_color or hexrgb("#7e7e7e")
  text_color = opts.text_color or Theme.COLORS.TEXT_NORMAL
  border_inner = opts.border_inner_color or Theme.COLORS.BORDER_INNER
  border_outer = opts.border_outer_color or Theme.COLORS.BORDER_OUTER

  if disabled then
    bg_color = Colors.with_opacity(Colors.desaturate(bg_color, 0.5), 0.5)
    inner_color = Colors.with_opacity(Colors.desaturate(inner_color, 0.5), 0.5)
    selected_color = Colors.with_opacity(Colors.desaturate(selected_color, 0.5), 0.5)
    text_color = Colors.with_opacity(Colors.desaturate(text_color, 0.5), 0.5)
    border_inner = Colors.with_opacity(Colors.desaturate(border_inner, 0.5), 0.5)
    border_outer = Colors.with_opacity(Colors.desaturate(border_outer, 0.5), 0.5)
  else
    -- Apply hover effects to the visible layer (selected indicator when selected, inner circle when not)
    if active and hovered then
      -- Active and hovered: brighten whichever circle is visible
      if selected then
        selected_color = Colors.lerp(selected_color, white_overlay, 0.5)
      else
        inner_color = Colors.lerp(inner_color, white_overlay, 0.5)
      end
      text_color = opts.text_hover_color or Theme.COLORS.TEXT_HOVER
    elseif active then
      text_color = opts.text_hover_color or Theme.COLORS.TEXT_HOVER
    elseif inst.hover_alpha > 0.01 then
      -- Hover: lighten whichever circle is visible
      if selected then
        selected_color = Colors.lerp(selected_color, white_overlay, inst.hover_alpha * 0.4)
      else
        inner_color = Colors.lerp(inner_color, white_overlay, inst.hover_alpha * 0.15)
      end
      text_color = Colors.lerp(text_color, opts.text_hover_color or Theme.COLORS.TEXT_HOVER, inst.hover_alpha)
    end
  end

  -- Draw outer circle (22x22)
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, outer_radius, bg_color)
  ImGui.DrawList_AddCircle(dl, center_x, center_y, outer_radius - 1, border_inner, 0, 1.0)
  ImGui.DrawList_AddCircle(dl, center_x, center_y, outer_radius, border_outer, 0, 1.0)

  -- Draw inner circle (14x14)
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, inner_radius, inner_color)
  ImGui.DrawList_AddCircle(dl, center_x, center_y, inner_radius, border_outer, 0, 1.0)

  -- Draw selected indicator (10x10)
  if selected then
    ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, selected_radius, selected_color)
  end

  -- Draw label
  if label ~= "" then
    local label_x = x + outer_radius * 2 + opts.spacing
    local label_y = y + (total_h - text_h) * 0.5
    ImGui.DrawList_AddText(dl, label_x, label_y, text_color, label)
  end

  -- Create interaction area
  local clicked, right_clicked = Base.create_interaction_area(ctx, unique_id, x, y, total_w, total_h, opts)

  -- Handle click callback
  if clicked and opts.on_click then
    opts.on_click()
  end

  -- Handle tooltip
  Base.handle_tooltip(ctx, opts)

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, total_w, total_h, opts.advance)

  -- Return standardized result
  return Base.create_result({
    clicked = clicked,
    right_clicked = right_clicked,
    width = total_w,
    height = total_h,
    hovered = hovered,
    active = active,
  })
end

-- ============================================================================
-- DEPRECATED / REMOVED FUNCTIONS
-- ============================================================================

--- @deprecated Use M.draw() instead (uses cursor by default when x/y not provided)
function M.draw_at_cursor(ctx, opts, id)
  opts = opts or {}
  if id then opts.id = id end
  local result = M.draw(ctx, opts)
  return result.selected
end

--- @deprecated Cleanup is automatic via Base, no need to call manually
function M.cleanup()
  -- No-op: cleanup happens automatically via Base.cleanup_registry
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.RadioButton(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
