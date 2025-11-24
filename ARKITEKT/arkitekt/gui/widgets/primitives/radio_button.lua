-- @noindex
-- arkitekt/gui/widgets/primitives/radio_button.lua
-- Standardized radio button widget with Arkitekt styling
-- Uses unified opts-based API

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Style = require('arkitekt.gui.style.defaults')
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
-- INSTANCE MANAGEMENT
-- ============================================================================

local instances = Base.create_instance_registry()

local function get_instance(id)
  if not instances[id] then
    instances[id] = { hover_alpha = 0 }
  end
  return instances[id]
end

-- ============================================================================
-- PUBLIC API (Standardized)
-- ============================================================================

--- Draw a radio button widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { clicked, width, height, hovered, active }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(opts, "radio")

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

  -- Update animation
  local dt = ImGui.GetDeltaTime(ctx)
  Base.update_hover_animation(inst, dt, hovered, active, Base.ANIMATION_SPEED)

  -- Calculate center of circle
  local center_x = x + outer_radius
  local center_y = y + outer_radius

  -- Determine colors
  local bg_color, inner_color, text_color, border_inner, border_outer

  if disabled then
    bg_color = Colors.with_alpha(Colors.desaturate(opts.bg_color or Style.COLORS.BG_BASE, 0.5), 0x80)
    inner_color = Colors.with_alpha(Colors.desaturate(opts.inner_color or Style.COLORS.BG_BASE, 0.5), 0x80)
    text_color = Colors.with_alpha(Colors.desaturate(opts.text_color or Style.COLORS.TEXT_NORMAL, 0.5), 0x80)
    border_inner = Colors.with_alpha(Colors.desaturate(opts.border_inner_color or Style.COLORS.BORDER_INNER, 0.5), 0x80)
    border_outer = Colors.with_alpha(Colors.desaturate(opts.border_outer_color or Style.COLORS.BORDER_OUTER, 0.5), 0x80)
  elseif active then
    bg_color = opts.bg_active_color or Style.COLORS.BG_ACTIVE
    inner_color = Colors.adjust_brightness(opts.inner_color or Style.COLORS.BG_BASE, 0.85)
    text_color = opts.text_hover_color or Style.COLORS.TEXT_HOVER
    border_inner = opts.border_inner_color or Style.COLORS.BORDER_INNER
    border_outer = opts.border_outer_color or Style.COLORS.BORDER_OUTER
  elseif inst.hover_alpha > 0.01 then
    local hover_bg = opts.bg_hover_color or Style.COLORS.BG_HOVER
    bg_color = Style.RENDER.lerp_color(opts.bg_color or Style.COLORS.BG_BASE, hover_bg, inst.hover_alpha)
    inner_color = Colors.adjust_brightness(opts.inner_color or Style.COLORS.BG_BASE, 0.85)
    text_color = Style.RENDER.lerp_color(
      opts.text_color or Style.COLORS.TEXT_NORMAL,
      opts.text_hover_color or Style.COLORS.TEXT_HOVER,
      inst.hover_alpha
    )
    border_inner = opts.border_inner_color or Style.COLORS.BORDER_INNER
    border_outer = opts.border_outer_color or Style.COLORS.BORDER_OUTER
  else
    bg_color = opts.bg_color or Style.COLORS.BG_BASE
    inner_color = Colors.adjust_brightness(opts.inner_color or Style.COLORS.BG_BASE, 0.85)
    text_color = opts.text_color or Style.COLORS.TEXT_NORMAL
    border_inner = opts.border_inner_color or Style.COLORS.BORDER_INNER
    border_outer = opts.border_outer_color or Style.COLORS.BORDER_OUTER
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
    local selected_color = opts.selected_color or hexrgb("#7e7e7e")
    if disabled then
      selected_color = Colors.with_alpha(Colors.desaturate(selected_color, 0.5), 0x80)
    end
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

--- Clean up all radio button instances
function M.cleanup()
  Base.cleanup_registry(instances)
end

return M
