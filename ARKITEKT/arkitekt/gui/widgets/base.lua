-- @noindex
-- arkitekt/gui/widgets/base.lua
-- Base widget utilities for standardized widget API
-- Provides shared functionality: instance management, state handling, opts parsing

local ImGui = require('arkitekt.core.imgui')
local Colors = require('arkitekt.core.colors')
local Anim = require('arkitekt.core.animation')
local CoreMath = require('arkitekt.core.math')

local M = {}

-- ============================================================================
-- CONSTANTS (deprecated - use arkitekt.core.animation instead)
-- ============================================================================

--- Default animation speed for hover/focus transitions
M.ANIMATION_SPEED = Anim.HOVER_SPEED

--- Fast animation speed for quick feedback
M.ANIMATION_SPEED_FAST = 16.0

--- Slow animation speed for smooth transitions
M.ANIMATION_SPEED_SLOW = Anim.FADE_SPEED

-- ============================================================================
-- MATH UTILITIES (re-exported from core/math)
-- ============================================================================

M.clamp = CoreMath.clamp
M.lerp = CoreMath.lerp
M.remap = CoreMath.remap

--- Snap a value to the nearest pixel (reduces aliasing)
--- @param v number Value to snap
--- @return number Snapped value
function M.snap_pixel(v)
  return math.floor(v + 0.5)
end

-- ============================================================================
-- TEXT UTILITIES
-- ============================================================================

--- Truncate text to fit within a maximum width
--- @param ctx userdata ImGui context
--- @param text string Text to truncate
--- @param max_width number Maximum width in pixels
--- @param suffix string|nil Suffix to add when truncated (default "...")
--- @return string Truncated text
function M.truncate_text(ctx, text, max_width, suffix)
  suffix = suffix or "..."
  local text_w = ImGui.CalcTextSize(ctx, text)

  if text_w <= max_width then
    return text
  end

  local suffix_w = ImGui.CalcTextSize(ctx, suffix)
  local available_w = max_width - suffix_w

  if available_w <= 0 then
    return suffix
  end

  -- Binary search for the right length
  local lo, hi = 1, #text
  while lo < hi do
    local mid = math.ceil((lo + hi) / 2)
    local substr = text:sub(1, mid)
    local w = ImGui.CalcTextSize(ctx, substr)
    if w <= available_w then
      lo = mid
    else
      hi = mid - 1
    end
  end

  return text:sub(1, lo) .. suffix
end

--- Measure text dimensions
--- @param ctx userdata ImGui context
--- @param text string Text to measure
--- @return number, number width and height
function M.measure_text(ctx, text)
  local w = ImGui.CalcTextSize(ctx, text)
  local h = ImGui.GetTextLineHeight(ctx)
  return w, h
end

-- ============================================================================
-- INSTANCE MANAGEMENT (strong tables with access tracking for cleanup)
-- ============================================================================

-- Global tracking of all registries for periodic cleanup
local all_registries = setmetatable({}, { __mode = "v" })
local last_cleanup_time = 0
local CLEANUP_INTERVAL = 60.0  -- Cleanup every 60 seconds
local STALE_THRESHOLD = 30.0   -- Remove instances not accessed for 30 seconds

--- Create a new instance registry with access tracking
--- Uses strong references but tracks access time for periodic cleanup
--- @return table Instance registry
function M.create_instance_registry()
  local registry = {
    _instances = {},
    _access_times = {},
  }
  all_registries[#all_registries + 1] = registry
  return registry
end

--- Get or create an instance from the registry
--- @param registry table The instance registry
--- @param id string Unique identifier
--- @param create_fn function Factory function to create new instance
--- @return table The instance
function M.get_or_create_instance(registry, id, create_fn)
  local instances = registry._instances or registry  -- Support both old and new format
  local access_times = registry._access_times

  if not instances[id] then
    instances[id] = create_fn(id)
  end

  -- Track access time for cleanup
  if access_times then
    access_times[id] = reaper.time_precise()
  end

  return instances[id]
end

--- Clean up stale instances from a registry
--- @param registry table The instance registry
--- @param threshold number|nil Seconds of inactivity before cleanup (default 30)
function M.cleanup_stale(registry, threshold)
  threshold = threshold or STALE_THRESHOLD
  local now = reaper.time_precise()
  local instances = registry._instances or registry
  local access_times = registry._access_times

  if not access_times then return end

  for id, last_access in pairs(access_times) do
    if now - last_access > threshold then
      instances[id] = nil
      access_times[id] = nil
    end
  end
end

--- Clean up all instances in a registry
--- @param registry table The instance registry
function M.cleanup_registry(registry)
  local instances = registry._instances or registry
  local access_times = registry._access_times

  for k in pairs(instances) do
    instances[k] = nil
  end
  if access_times then
    for k in pairs(access_times) do
      access_times[k] = nil
    end
  end
end

--- Periodic cleanup of all registries (call from main loop)
function M.periodic_cleanup()
  local now = reaper.time_precise()
  if now - last_cleanup_time < CLEANUP_INTERVAL then
    return
  end
  last_cleanup_time = now

  for _, registry in ipairs(all_registries) do
    M.cleanup_stale(registry)
  end
end

-- ============================================================================
-- OPTIONS PARSING
-- ============================================================================

--- Parse and validate widget options with defaults
--- @param opts table|nil User-provided options
--- @param defaults table Default values
--- @return table Merged options
function M.parse_opts(opts, defaults)
  -- Type check to catch incorrect API usage
  if opts ~= nil and type(opts) ~= "table" then
    error("parse_opts: expected table or nil for opts, got " .. type(opts) ..
          ". Did you use the old API format instead of opts table?", 2)
  end

  opts = opts or {}
  local result = {}

  -- Copy defaults first
  for k, v in pairs(defaults) do
    result[k] = v
  end

  -- Override with user options
  for k, v in pairs(opts) do
    result[k] = v
  end

  return result
end

--- Resolve unique ID from options
--- @param opts table Options containing id and/or panel_state
--- @param default_prefix string Default ID prefix if none provided
--- @return string Unique identifier
function M.resolve_id(opts, default_prefix)
  local base_id = opts.id or default_prefix

  -- Panel context: prefix with panel ID
  if opts.panel_state and opts.panel_state._panel_id then
    return string.format("%s_%s", opts.panel_state._panel_id, base_id)
  end

  return base_id
end

--- Get draw list from options or window
--- @param ctx userdata ImGui context
--- @param opts table Options potentially containing draw_list
--- @return userdata Draw list
function M.get_draw_list(ctx, opts)
  return opts.draw_list or ImGui.GetWindowDrawList(ctx)
end

--- Get position from options or cursor
--- @param ctx userdata ImGui context
--- @param opts table Options potentially containing x, y
--- @return number, number x and y coordinates
function M.get_position(ctx, opts)
  if opts.x and opts.y then
    return opts.x, opts.y
  end
  return ImGui.GetCursorScreenPos(ctx)
end

--- Get size from options with defaults
--- @param opts table Options containing width/height or size
--- @param default_width number Default width
--- @param default_height number Default height
--- @return number, number width and height
function M.get_size(opts, default_width, default_height)
  local width = opts.width or opts.size or default_width
  local height = opts.height or opts.size or default_height
  return width, height
end

-- ============================================================================
-- STATE HANDLING
-- ============================================================================

--- Common widget state structure
--- @param id string Widget identifier
--- @return table State object
function M.create_base_state(id)
  return {
    id = id,
    hover_alpha = 0,
    focus_alpha = 0,
    disabled_alpha = 0,
  }
end

--- Update hover animation
--- @param state table Widget state
--- @param dt number Delta time
--- @param is_hovered boolean Current hover state
--- @param is_active boolean Current active/pressed state
--- @param field string Field name to animate (required)
--- @param speed number Optional animation speed (defaults to Anim.HOVER_SPEED)
function M.update_hover_animation(state, dt, is_hovered, is_active, field, speed)
  Anim.update_hover(state, dt, is_hovered, is_active, field, speed)
end

--- Check if widget is interactive (not disabled, not blocked)
--- @param opts table Widget options
--- @return boolean True if widget can be interacted with
function M.is_interactive(opts)
  return not opts.disabled and not opts.is_blocking
end

--- Get hover and active state for a rectangular region
--- @param ctx userdata ImGui context
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param width number Width
--- @param height number Height
--- @param opts table Widget options (checks disabled state)
--- @return boolean, boolean is_hovered, is_active
function M.get_interaction_state(ctx, x, y, width, height, opts)
  if not M.is_interactive(opts) then
    return false, false
  end

  local is_hovered = ImGui.IsMouseHoveringRect(ctx, x, y, x + width, y + height)
  local is_active = is_hovered and ImGui.IsMouseDown(ctx, 0)

  return is_hovered, is_active
end

-- ============================================================================
-- COLOR UTILITIES
-- ============================================================================

--- Get state-adjusted colors for a widget
--- @param base_colors table Base color configuration
--- @param opts table Widget options (disabled state)
--- @param is_hovered boolean Hover state
--- @param is_active boolean Active state
--- @param hover_alpha number Hover animation alpha (0-1)
--- @return number, number, number, number bg, border_inner, border_outer, text colors
function M.get_state_colors(base_colors, opts, is_hovered, is_active, hover_alpha)
  local bg = base_colors.bg or base_colors.bg_color
  local border_inner = base_colors.border_inner or base_colors.border_inner_color
  local border_outer = base_colors.border_outer or base_colors.border_outer_color
  local text = base_colors.text or base_colors.text_color

  -- Disabled state
  if opts.disabled then
    return
      base_colors.bg_disabled or Colors.with_opacity(Colors.desaturate(bg, 0.5), 0.5),
      base_colors.border_inner_disabled or Colors.with_opacity(Colors.desaturate(border_inner, 0.5), 0.5),
      base_colors.border_outer_disabled or Colors.with_opacity(Colors.desaturate(border_outer, 0.5), 0.5),
      base_colors.text_disabled or Colors.with_opacity(Colors.desaturate(text, 0.5), 0.5)
  end

  -- Active state
  if is_active then
    return
      base_colors.bg_active or Colors.adjust_brightness(bg, 0.85),
      base_colors.border_inner_active or Colors.adjust_brightness(border_inner, 0.85),
      border_outer,
      base_colors.text_active or text
  end

  -- Hover state (with animation)
  if hover_alpha > 0.01 then
    local hover_bg = base_colors.bg_hover or Colors.adjust_brightness(bg, 1.15)
    local hover_border = base_colors.border_inner_hover or Colors.adjust_brightness(border_inner, 1.15)
    local hover_text = base_colors.text_hover or text

    return
      Colors.lerp(bg, hover_bg, hover_alpha),
      Colors.lerp(border_inner, hover_border, hover_alpha),
      border_outer,
      Colors.lerp(text, hover_text, hover_alpha)
  end

  return bg, border_inner, border_outer, text
end

--- Apply disabled visual effect to a color
--- @param color number RGBA color
--- @param opts table Widget options
--- @return number Modified color
function M.apply_disabled_effect(color, opts)
  if opts.disabled then
    return Colors.with_opacity(Colors.desaturate(color, 0.5), 0.5)
  end
  return color
end

-- ============================================================================
-- DRAWING UTILITIES
-- ============================================================================

--- Converts corner_rounding config to ImGui corner flags.
--- Logic:
---   - nil corner_rounding = standalone element, return 0 (caller handles default)
---   - corner_rounding exists with flags = specific corners rounded
---   - corner_rounding exists with no flags = middle element, explicitly no rounding
--- @param corner_rounding table|nil Corner rounding configuration from layout engine
--- @return integer ImGui DrawFlags for corner rounding
function M.get_corner_flags(corner_rounding)
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

  if flags == 0 then
    return ImGui.DrawFlags_RoundCornersNone
  end

  return flags
end

--- Draw standard widget background with borders
--- @param dl userdata Draw list
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param width number Width
--- @param height number Height
--- @param bg_color number Background color
--- @param border_inner number Inner border color
--- @param border_outer number Outer border color
--- @param rounding number Corner rounding
--- @param corner_flags number|nil ImGui corner flags
function M.draw_background(dl, x, y, width, height, bg_color, border_inner, border_outer, rounding, corner_flags)
  corner_flags = corner_flags or 0
  local inner_rounding = math.max(0, rounding - 2)

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, bg_color, inner_rounding, corner_flags)

  -- Inner border
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + width - 1, y + height - 1, border_inner, inner_rounding, corner_flags, 1)

  -- Outer border
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, border_outer, inner_rounding, corner_flags, 1)
end

--- Draw centered text
--- @param ctx userdata ImGui context
--- @param dl userdata Draw list
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param width number Container width
--- @param height number Container height
--- @param text string Text to draw
--- @param color number Text color
function M.draw_centered_text(ctx, dl, x, y, width, height, text, color)
  local text_w = ImGui.CalcTextSize(ctx, text)
  local text_h = ImGui.GetTextLineHeight(ctx)
  local text_x = x + (width - text_w) * 0.5
  local text_y = y + (height - text_h) * 0.5
  ImGui.DrawList_AddText(dl, text_x, text_y, color, text)
end

-- ============================================================================
-- INTERACTION UTILITIES
-- ============================================================================

--- Create invisible button for interaction detection
--- @param ctx userdata ImGui context
--- @param id string Unique identifier
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param width number Width
--- @param height number Height
--- @param opts table Widget options
--- @return boolean, boolean clicked, right_clicked
function M.create_interaction_area(ctx, id, x, y, width, height, opts)
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. id, width, height)

  if not M.is_interactive(opts) then
    return false, false
  end

  local clicked = ImGui.IsItemClicked(ctx, 0)
  local right_clicked = ImGui.IsItemClicked(ctx, 1)

  return clicked, right_clicked
end

--- Handle tooltip display
--- @param ctx userdata ImGui context
--- @param opts table Widget options containing tooltip
function M.handle_tooltip(ctx, opts)
  if ImGui.IsItemHovered(ctx) and opts.tooltip then
    ImGui.SetTooltip(ctx, opts.tooltip)
  end
end

--- Advance cursor after drawing
--- @param ctx userdata ImGui context
--- @param x number Original X position
--- @param y number Original Y position
--- @param width number Widget width
--- @param height number Widget height
--- @param advance string|nil Direction: "horizontal", "vertical", or "none"
function M.advance_cursor(ctx, x, y, width, height, advance)
  advance = advance or "vertical"

  if advance == "horizontal" then
    ImGui.SetCursorScreenPos(ctx, x + width, y)
  elseif advance == "vertical" then
    ImGui.SetCursorScreenPos(ctx, x, y + height)
  end
  -- "none" = don't advance
end

-- ============================================================================
-- RESULT BUILDER
-- ============================================================================

--- Create standardized result table
--- @param base table Base result values
--- @return table Result table
function M.create_result(base)
  return {
    clicked = base.clicked or false,
    right_clicked = base.right_clicked or false,
    changed = base.changed or false,
    value = base.value,
    width = base.width or 0,
    height = base.height or 0,
    hovered = base.hovered or false,
    active = base.active or false,
  }
end

-- ============================================================================
-- DEFAULT OPTION STRUCTURES
-- ============================================================================

--- Standard widget options defaults
M.DEFAULTS = {
  -- Common
  id = nil,
  x = nil,
  y = nil,
  width = nil,
  height = nil,
  draw_list = nil,

  -- State
  disabled = false,
  is_blocking = false,

  -- Style
  rounding = 0,

  -- Interaction
  tooltip = nil,
  on_click = nil,
  on_right_click = nil,
  on_change = nil,

  -- Panel integration
  panel_state = nil,

  -- Cursor control
  advance = "vertical",
}

return M
