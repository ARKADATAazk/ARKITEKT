-- @noindex
-- arkitekt/gui/widgets/primitives/checkbox.lua
-- Standardized checkbox component with Arkitekt styling
-- Uses unified opts-based API

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('arkitekt.gui.style.defaults')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

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
  size = 18,

  -- State
  checked = false,
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
-- INSTANCE MANAGEMENT (weak table to prevent memory leaks)
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
  Base.update_hover_animation(self, dt, is_hovered, is_active, 12.0)

  -- Check animation
  local target_check = is_checked and 1.0 or 0.0
  local check_speed = 15.0
  self.check_alpha = self.check_alpha + (target_check - self.check_alpha) * check_speed * dt
  self.check_alpha = math.max(0, math.min(1, self.check_alpha))
end

-- ============================================================================
-- CONFIG RESOLUTION
-- ============================================================================

local function resolve_config(opts)
  -- Start with button colors as base
  local base = {
    -- OFF state colors
    bg_color = Style.BUTTON_COLORS.bg,
    bg_hover_color = Style.BUTTON_COLORS.bg_hover,
    bg_active_color = Style.BUTTON_COLORS.bg_active,
    border_outer_color = Style.BUTTON_COLORS.border_outer,
    border_inner_color = Style.BUTTON_COLORS.border_inner,
    border_hover_color = Style.BUTTON_COLORS.border_hover,
    border_active_color = Style.BUTTON_COLORS.border_active,

    -- ON state colors (teal variant)
    bg_on_color = Style.BUTTON_COLORS.toggle_teal.bg_on,
    bg_on_hover_color = Style.BUTTON_COLORS.toggle_teal.bg_on_hover,
    bg_on_active_color = Style.BUTTON_COLORS.toggle_teal.bg_on_active,
    border_outer_on_color = Style.BUTTON_COLORS.border_outer,
    border_inner_on_color = Style.BUTTON_COLORS.toggle_teal.border_inner_on,
    border_on_hover_color = Style.BUTTON_COLORS.toggle_teal.border_inner_on_hover,
    border_on_active_color = Style.BUTTON_COLORS.toggle_teal.border_inner_on_active,

    -- Checkmark and label
    check_color = Style.BUTTON_COLORS.toggle_teal.text_on,
    label_color = Style.COLORS.TEXT_NORMAL,
    label_hover_color = Style.COLORS.TEXT_HOVER,
    label_disabled_color = Style.COLORS.TEXT_DISABLED or Colors.with_alpha(Style.COLORS.TEXT_NORMAL, 0x80),
  }

  return Style.apply_defaults(base, opts)
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_checkbox(ctx, dl, x, y, config, instance, is_checked, total_width)
  local size = config.size
  local is_disabled = config.disabled or false
  local is_blocking = config.is_blocking or false

  -- Check hover using GetMousePos (exactly like combo)
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = not is_disabled and not is_blocking and
                     mx >= x and mx < x + total_width and my >= y and my < y + size
  local is_active = not is_disabled and not is_blocking and
                    is_hovered and ImGui.IsMouseDown(ctx, 0)

  -- Update animation BEFORE getting colors (exactly like combo)
  local dt = ImGui.GetDeltaTime(ctx)
  instance:update(dt, is_hovered, is_active, is_checked)

  -- Calculate colors based on state
  local bg_color, border_inner, border_outer

  if is_disabled then
    -- Disabled state
    bg_color = config.bg_disabled_color or Colors.with_alpha(Colors.desaturate(config.bg_color, 0.5), 0x80)
    border_inner = Colors.with_alpha(Colors.desaturate(config.border_inner_color, 0.5), 0x80)
    border_outer = Colors.with_alpha(Colors.desaturate(config.border_outer_color, 0.5), 0x80)
  elseif is_checked or instance.check_alpha > 0.01 then
    -- Checked or animating to checked
    local base_bg = is_active and config.bg_on_active_color or
                    (instance.hover_alpha > 0.01 and
                      Style.RENDER.lerp_color(config.bg_on_color, config.bg_on_hover_color, instance.hover_alpha) or
                      config.bg_on_color)
    local base_border = is_active and config.border_on_active_color or
                        (instance.hover_alpha > 0.01 and
                          Style.RENDER.lerp_color(config.border_inner_on_color, config.border_on_hover_color, instance.hover_alpha) or
                          config.border_inner_on_color)

    -- Blend with unchecked colors if animating
    if instance.check_alpha < 0.99 then
      local unchecked_bg = is_active and config.bg_active_color or
                           (instance.hover_alpha > 0.01 and
                             Style.RENDER.lerp_color(config.bg_color, config.bg_hover_color, instance.hover_alpha) or
                             config.bg_color)
      local unchecked_border = is_active and config.border_active_color or
                               (instance.hover_alpha > 0.01 and
                                 Style.RENDER.lerp_color(config.border_inner_color, config.border_hover_color, instance.hover_alpha) or
                                 config.border_inner_color)

      bg_color = Style.RENDER.lerp_color(unchecked_bg, base_bg, instance.check_alpha)
      border_inner = Style.RENDER.lerp_color(unchecked_border, base_border, instance.check_alpha)
    else
      bg_color = base_bg
      border_inner = base_border
    end

    border_outer = config.border_outer_on_color
  else
    -- Unchecked
    bg_color = is_active and config.bg_active_color or
               (instance.hover_alpha > 0.01 and
                 Style.RENDER.lerp_color(config.bg_color, config.bg_hover_color, instance.hover_alpha) or
                 config.bg_color)
    border_inner = is_active and config.border_active_color or
                   (instance.hover_alpha > 0.01 and
                     Style.RENDER.lerp_color(config.border_inner_color, config.border_hover_color, instance.hover_alpha) or
                     config.border_inner_color)
    border_outer = config.border_outer_color
  end

  local rounding = config.rounding or 0
  local inner_rounding = math.max(0, rounding - 2)

  -- Apply visual alpha
  local visual_alpha = config.alpha or 1.0
  bg_color = Colors.with_alpha(bg_color, math.floor(((bg_color & 0xFF) / 255) * visual_alpha * 255))
  border_inner = Colors.with_alpha(border_inner, math.floor(((border_inner & 0xFF) / 255) * visual_alpha * 255))
  border_outer = Colors.with_alpha(border_outer, math.floor(((border_outer & 0xFF) / 255) * visual_alpha * 255))

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + size, y + size, bg_color, inner_rounding)

  -- Draw borders
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + size - 1, y + size - 1, border_inner, inner_rounding, 0, 1)
  ImGui.DrawList_AddRect(dl, x, y, x + size, y + size, border_outer, inner_rounding, 0, 1)

  -- Draw checkmark
  if instance.check_alpha > 0.01 then
    local check_color = config.check_color
    if is_disabled then
      check_color = Colors.with_alpha(Colors.desaturate(check_color, 0.5), 0x80)
    end
    check_color = Colors.with_alpha(check_color, math.floor(instance.check_alpha * visual_alpha * 255))

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

  -- Get checked state
  local is_checked = opts.checked
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
      label_color = Style.RENDER.lerp_color(config.label_color, config.label_hover_color, instance.hover_alpha)
    else
      label_color = config.label_color
    end

    -- Apply visual alpha
    local visual_alpha = config.alpha or 1.0
    label_color = Colors.with_alpha(label_color, math.floor(((label_color & 0xFF) / 255) * visual_alpha * 255))

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
--- @return boolean toggled Whether checkbox was toggled
function M.draw_at_cursor(ctx, label, checked, opts, id)
  opts = opts or {}
  opts.label = label
  opts.checked = checked
  if id then opts.id = id end
  -- Don't set x/y so it uses cursor position
  local result = M.draw(ctx, opts)
  return result.toggled
end

return M
