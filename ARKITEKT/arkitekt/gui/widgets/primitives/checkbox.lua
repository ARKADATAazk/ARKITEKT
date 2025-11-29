-- @noindex
-- arkitekt/gui/widgets/primitives/checkbox.lua
-- Standardized checkbox component with Arkitekt styling
-- Uses unified opts-based API

local ImGui = require('arkitekt.platform.imgui')
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')
local Anim = require('arkitekt.core.animation')

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = "checkbox",

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  size = 22,

  -- State
  checked = false,
  is_checked = false,  -- Alias for 'checked' (for compatibility)
  disabled = false,
  is_blocking = false,

  -- Content
  label = "",

  -- Style
  rounding = 0,
  alpha = 1.0,  -- Visual alpha for fade animations
  label_spacing = 8,

  -- Colors - OFF state (unchecked)
  bg_color = nil,
  bg_hover_color = nil,
  bg_active_color = nil,
  bg_disabled_color = nil,
  border_outer_color = nil,
  border_inner_color = nil,
  border_hover_color = nil,
  border_active_color = nil,

  -- Colors - ON state (checked)
  bg_on_color = nil,
  bg_on_hover_color = nil,
  bg_on_active_color = nil,
  border_outer_on_color = nil,
  border_inner_on_color = nil,
  border_on_hover_color = nil,
  border_on_active_color = nil,

  -- Checkmark and label colors
  check_color = nil,
  label_color = nil,
  label_hover_color = nil,
  label_disabled_color = nil,

  -- Callbacks
  on_change = nil,
  tooltip = nil,

  -- Panel integration
  panel_state = nil,

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- INSTANCE MANAGEMENT (strong tables with access tracking for cleanup)
-- ============================================================================

local instances = Base.create_instance_registry()

local Checkbox = {}
Checkbox.__index = Checkbox

function Checkbox.new(id)
  return setmetatable({
    id = id,
    hover_alpha = 0,
    check_alpha = 0,
  }, Checkbox)
end

function Checkbox:update(dt, is_hovered, is_active, is_checked)
  -- Hover animation
  Base.update_hover_animation(self, dt, is_hovered, is_active, "hover_alpha")

  -- Check animation
  local target_check = is_checked and 1.0 or 0.0
  self.check_alpha = Anim.animate_value(self.check_alpha, target_check, dt, Anim.CHECK_SPEED)
end

-- ============================================================================
-- CONFIG RESOLUTION (Dynamic - reads Theme.COLORS each call)
-- ============================================================================

local function resolve_config(opts)
  -- Build config from current Theme.COLORS (enables dynamic theming)
  local config = {
    -- Non-color settings (from opts, which has defaults merged in)
    size = opts.size or DEFAULTS.size,
    disabled = opts.disabled or DEFAULTS.disabled,
    is_blocking = opts.is_blocking or DEFAULTS.is_blocking,
    rounding = opts.rounding or DEFAULTS.rounding,
    alpha = opts.alpha or DEFAULTS.alpha,
    label_spacing = opts.label_spacing or DEFAULTS.label_spacing,

    -- OFF state colors (from dynamic COLORS)
    bg_color = Theme.COLORS.BG_BASE,
    bg_hover_color = Theme.COLORS.BG_HOVER,
    bg_active_color = Theme.COLORS.BG_ACTIVE,
    border_outer_color = Theme.COLORS.BORDER_OUTER,
    border_inner_color = Theme.COLORS.BORDER_INNER,
    border_hover_color = Theme.COLORS.BORDER_HOVER,
    border_active_color = Theme.COLORS.BORDER_ACTIVE,

    -- ON state colors (neutral, uses hover as "on" state)
    bg_on_color = Theme.COLORS.BG_HOVER,
    bg_on_hover_color = Theme.COLORS.BG_HOVER,
    bg_on_active_color = Theme.COLORS.BG_ACTIVE,
    border_outer_on_color = Theme.COLORS.BORDER_OUTER,
    border_inner_on_color = Theme.COLORS.BORDER_HOVER,
    border_on_hover_color = Theme.COLORS.BORDER_HOVER,
    border_on_active_color = Theme.COLORS.BORDER_ACTIVE,

    -- Checkmark and label (derived from text colors)
    check_color = Theme.COLORS.TEXT_DIMMED,
    label_color = Theme.COLORS.TEXT_NORMAL,
    label_hover_color = Theme.COLORS.TEXT_HOVER,
    label_disabled_color = Colors.with_opacity(Theme.COLORS.TEXT_NORMAL, 0.5),
  }

  -- Apply user overrides
  for k, v in pairs(opts) do
    if v ~= nil and config[k] ~= nil then
      config[k] = v
    end
  end

  return config
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_checkbox(ctx, dl, x, y, config, instance, is_checked, total_width)
  local size = config.size
  local is_disabled = config.disabled or false
  local is_blocking = config.is_blocking or false

  -- Check hover using IsMouseHoveringRect (ImGui built-in, respects clipping)
  local is_hovered = not is_disabled and not is_blocking and
                     ImGui.IsMouseHoveringRect(ctx, x, y, x + total_width, y + size)
  local is_active = not is_disabled and not is_blocking and
                    is_hovered and ImGui.IsMouseDown(ctx, 0)

  -- Update animation
  local dt = ImGui.GetDeltaTime(ctx)
  instance:update(dt, is_hovered, is_active, is_checked)

  -- Calculate colors based on state
  local bg_color, border_inner, border_outer

  if is_disabled then
    -- Disabled state
    bg_color = config.bg_disabled_color or Colors.with_opacity(Colors.desaturate(config.bg_color, 0.5), 0.5)
    border_inner = Colors.with_opacity(Colors.desaturate(config.border_inner_color, 0.5), 0.5)
    border_outer = Colors.with_opacity(Colors.desaturate(config.border_outer_color, 0.5), 0.5)
  elseif is_checked or instance.check_alpha > 0.01 then
    -- Checked or animating to checked
    local base_bg = is_active and config.bg_on_active_color or
                    (instance.hover_alpha > 0.01 and
                      Colors.lerp(config.bg_on_color, config.bg_on_hover_color, instance.hover_alpha) or
                      config.bg_on_color)
    local base_border = is_active and config.border_on_active_color or
                        (instance.hover_alpha > 0.01 and
                          Colors.lerp(config.border_inner_on_color, config.border_on_hover_color, instance.hover_alpha) or
                          config.border_inner_on_color)

    -- Blend with unchecked colors if animating
    if instance.check_alpha < 0.99 then
      local unchecked_bg = is_active and config.bg_active_color or
                           (instance.hover_alpha > 0.01 and
                             Colors.lerp(config.bg_color, config.bg_hover_color, instance.hover_alpha) or
                             config.bg_color)
      local unchecked_border = is_active and config.border_active_color or
                               (instance.hover_alpha > 0.01 and
                                 Colors.lerp(config.border_inner_color, config.border_hover_color, instance.hover_alpha) or
                                 config.border_inner_color)

      bg_color = Colors.lerp(unchecked_bg, base_bg, instance.check_alpha)
      border_inner = Colors.lerp(unchecked_border, base_border, instance.check_alpha)
    else
      bg_color = base_bg
      border_inner = base_border
    end

    border_outer = config.border_outer_on_color
  else
    -- Unchecked
    bg_color = is_active and config.bg_active_color or
               (instance.hover_alpha > 0.01 and
                 Colors.lerp(config.bg_color, config.bg_hover_color, instance.hover_alpha) or
                 config.bg_color)
    border_inner = is_active and config.border_active_color or
                   (instance.hover_alpha > 0.01 and
                     Colors.lerp(config.border_inner_color, config.border_hover_color, instance.hover_alpha) or
                     config.border_inner_color)
    border_outer = config.border_outer_color
  end

  local rounding = config.rounding or 0
  local inner_rounding = math.max(0, rounding - 2)

  -- Apply visual alpha
  local visual_alpha = config.alpha or 1.0
  bg_color = Colors.with_alpha(bg_color, Colors.opacity((bg_color & 0xFF) / 255 * visual_alpha))
  border_inner = Colors.with_alpha(border_inner, Colors.opacity((border_inner & 0xFF) / 255 * visual_alpha))
  border_outer = Colors.with_alpha(border_outer, Colors.opacity((border_outer & 0xFF) / 255 * visual_alpha))

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + size, y + size, bg_color, inner_rounding)

  -- Draw borders
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + size - 1, y + size - 1, border_inner, inner_rounding, 0, 1)
  ImGui.DrawList_AddRect(dl, x, y, x + size, y + size, border_outer, inner_rounding, 0, 1)

  -- Draw checkmark
  if instance.check_alpha > 0.01 then
    local check_color = config.check_color
    if is_disabled then
      check_color = Colors.with_opacity(Colors.desaturate(check_color, 0.5), 0.5)
    end
    check_color = Colors.with_alpha(check_color, Colors.opacity(instance.check_alpha * visual_alpha))

    local padding = size * 0.25
    local check_size = size - padding * 2

    local cx = x + padding
    local cy = y + size * 0.5
    local mx = cx + check_size * 0.3
    local my = cy + check_size * 0.3
    local ex = cx + check_size
    local ey = cy - check_size * 0.4

    ImGui.DrawList_AddLine(dl, cx, cy, mx, my, check_color, 2)
    ImGui.DrawList_AddLine(dl, mx, my, ex, ey, check_color, 2)
  end

  return is_hovered, is_active
end

-- ============================================================================
-- PUBLIC API (Standardized)
-- ============================================================================

--- Draw a checkbox widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { clicked, changed, value, width, height, hovered, active }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)
  local config = resolve_config(opts)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(opts, "checkbox")

  -- Get or create instance
  local instance = Base.get_or_create_instance(instances, unique_id, Checkbox.new)

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get checked state (accept both 'checked' and 'is_checked' for compatibility)
  local is_checked = opts.checked or opts.is_checked
  if opts.panel_state and opts.panel_state.checkbox_value ~= nil then
    is_checked = opts.panel_state.checkbox_value
  end

  -- Calculate total width (including label) BEFORE rendering
  local size = config.size
  local label = opts.label or ""
  local total_width = size

  if label ~= "" then
    local label_width = ImGui.CalcTextSize(ctx, label)
    total_width = size + config.label_spacing + label_width
  end

  -- Render checkbox box (pass total_width for hover detection)
  local is_hovered, is_active = render_checkbox(ctx, dl, x, y, config, instance, is_checked, total_width)

  -- Render label
  if label ~= "" then
    local label_x = x + size + config.label_spacing
    local label_y = y + (size - ImGui.GetTextLineHeight(ctx)) * 0.5

    local label_color
    if opts.disabled then
      label_color = config.label_disabled_color
    elseif instance.hover_alpha > 0.01 then
      label_color = Colors.lerp(config.label_color, config.label_hover_color, instance.hover_alpha)
    else
      label_color = config.label_color
    end

    -- Apply visual alpha
    local visual_alpha = config.alpha or 1.0
    label_color = Colors.with_alpha(label_color, Colors.opacity((label_color & 0xFF) / 255 * visual_alpha))

    ImGui.DrawList_AddText(dl, label_x, label_y, label_color, label)
  end

  -- Create interaction area
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, total_width, size)

  local clicked = false
  local changed = false
  local new_value = is_checked

  if not opts.disabled and not opts.is_blocking then
    clicked = ImGui.IsItemClicked(ctx, 0)

    if clicked then
      new_value = not is_checked
      changed = true

      -- Update panel state
      if opts.panel_state then
        opts.panel_state.checkbox_value = new_value
      end

      -- Call change callback
      if config.on_change then
        config.on_change(new_value)
      end
    end
  end

  -- Handle tooltip
  Base.handle_tooltip(ctx, opts)

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, total_width, size, opts.advance)

  -- Return standardized result
  return Base.create_result({
    clicked = clicked,
    changed = changed,
    value = new_value,
    width = total_width,
    height = size,
    hovered = is_hovered,
    active = is_active,
  })
end

--- Measure checkbox width including label
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return number Total width
function M.measure(ctx, opts)
  opts = opts or {}
  local size = opts.size or DEFAULTS.size
  local label = opts.label or ""
  local label_spacing = opts.label_spacing or DEFAULTS.label_spacing

  if label == "" then
    return size
  end

  local label_width = ImGui.CalcTextSize(ctx, label)
  return size + label_spacing + label_width
end

--- Clean up all checkbox instances
function M.cleanup()
  Base.cleanup_registry(instances)
end

--- Draw a checkbox at current ImGui cursor position (convenience function)
--- @param ctx userdata ImGui context
--- @param label string Checkbox label
--- @param checked boolean Current state
--- @param opts table|nil Additional options
--- @param id string|nil Optional ID override
--- @return boolean changed Whether checkbox state changed
function M.draw_at_cursor(ctx, label, checked, opts, id)
  opts = opts or {}
  opts.label = label
  opts.checked = checked
  if id then opts.id = id end
  -- Don't set x/y so it uses cursor position
  local result = M.draw(ctx, opts)
  return result.changed
end

return M
