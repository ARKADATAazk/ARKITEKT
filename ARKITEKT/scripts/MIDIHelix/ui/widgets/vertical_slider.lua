-- @noindex
-- MIDIHelix/ui/widgets/vertical_slider.lua
-- Ex Machina-style vertical slider with specular/gradient effects

local ImGui = require('arkitekt.core.imgui')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')
local TileRenderer = require('arkitekt.gui.renderers.tile.renderer')

local M = {}

-- Performance: Cache math functions
local min, max, floor = math.min, math.max, math.floor

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = 'vslider',

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size (Ex Machina style)
  width = 30,
  height = 150,

  -- Value
  value = 0,
  min = 0,
  max = 12,
  default = nil,
  step = 1,

  -- State
  is_disabled = false,

  -- Style
  rounding = 2,
  fill_color = nil,      -- Tab accent color for fill
  track_color = nil,     -- Track background
  border_color = nil,

  -- Label
  label = nil,           -- Label below slider

  -- Tile renderer config
  tile_config = nil,

  -- Callbacks
  on_change = nil,

  -- Cursor control
  advance = 'horizontal',
}

-- Default tile config for slider fill
local FILL_CONFIG = {
  rounding = 2,
  fill_opacity = 0.9,
  fill_saturation = 0.85,
  fill_brightness = 1.0,
  gradient_intensity = 0.2,
  gradient_opacity = 0.5,
  specular_strength = 0.3,
  specular_coverage = 0.35,
  inner_shadow_strength = 0.2,
  border_opacity = 0.7,
  border_saturation = 0.6,
  border_brightness = 0.5,
  border_thickness = 1,
  glow_layers = 0,
  glow_strength = 0,
  hover_fill_boost = 0.1,
  hover_specular_boost = 0.2,
}

-- ============================================================================
-- COLORS (from config/colors.lua defaults)
-- ============================================================================

local DEFAULT_COLORS = {
  TRACK_BG = 0x202020FF,
  TRACK_BORDER = 0x404040FF,
  FILL = 0x4A90D9FF,
  LABEL = 0x909090FF,
}

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_track(dl, x, y, w, h, rounding, colors)
  -- Track background (recessed look)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, colors.track_bg, rounding)

  -- Inner shadow at top
  local shadow_h = 3
  local shadow_color = 0x00000040
  ImGui.DrawList_AddRectFilled(dl, x + 1, y + 1, x + w - 1, y + shadow_h, shadow_color, rounding)

  -- Track border
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, colors.track_border, rounding, 0, 1)
end

local function render_fill(ctx, dl, x, y, w, fill_h, base_color, config, hover_factor)
  if fill_h < 2 then return end

  -- Use tile renderer for rich fill effect
  TileRenderer.render_complete_fast(
    ctx, dl,
    x + 1, y, x + w - 1, y + fill_h,
    base_color, config,
    false,         -- is_selected
    hover_factor,  -- hover_factor
    0, 0,          -- playback_progress, playback_fade
    nil, nil,      -- border_color_override, progress_color_override
    nil, false     -- stripe_color, stripe_enabled
  )
end

local function render_label(ctx, dl, x, y, w, label, color)
  if not label then return end

  local text_w = ImGui.CalcTextSize(ctx, label)
  local text_x = x + (w - text_w) / 2
  ImGui.DrawList_AddText(dl, text_x, y, color, label)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a vertical slider widget (Ex Machina style)
--- @param ctx userdata ImGui context
--- @param opts_or_id string|table ID string or options table
--- @param value number|nil Current value (positional mode)
--- @param min_val number|nil Minimum value (positional mode)
--- @param max_val number|nil Maximum value (positional mode)
--- @return table Result { changed, value, hovered, active }
function M.Draw(ctx, opts_or_id, value, min_val, max_val)
  -- Handle positional vs opts mode
  local opts
  if type(opts_or_id) == 'table' then
    opts = opts_or_id
  else
    opts = {
      id = opts_or_id,
      value = value,
      min = min_val,
      max = max_val,
    }
  end

  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, 'vslider')

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get dimensions
  local w = opts.width
  local h = opts.height

  -- Get value range
  local v_min = opts.min
  local v_max = opts.max
  local v_default = opts.default or v_min
  local v = Base.clamp(opts.value or v_default, v_min, v_max)

  -- Colors
  local colors = {
    track_bg = opts.track_color or DEFAULT_COLORS.TRACK_BG,
    track_border = opts.border_color or DEFAULT_COLORS.TRACK_BORDER,
    fill = opts.fill_color or DEFAULT_COLORS.FILL,
    label = DEFAULT_COLORS.LABEL,
  }

  -- Tile config
  local config = opts.tile_config or FILL_CONFIG

  -- Disabled state
  local actx = Base.get_context(ctx)
  local disabled = opts.is_disabled or actx:is_disabled()
  local changed = false

  -- Create invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, '##' .. unique_id, w, h)

  local hovered = not disabled and ImGui.IsItemHovered(ctx)
  local active = not disabled and ImGui.IsItemActive(ctx)

  -- Handle drag interaction (vertical: drag up = increase)
  if active then
    local my = select(2, ImGui.GetMousePos(ctx))
    -- Invert: top = max, bottom = min
    local t = 1.0 - Base.clamp((my - y) / h, 0, 1)
    local new_value = v_min + t * (v_max - v_min)

    -- Snap to step
    if opts.step and opts.step > 0 then
      new_value = floor((new_value - v_min) / opts.step + 0.5) * opts.step + v_min
    end

    new_value = Base.clamp(new_value, v_min, v_max)
    if new_value ~= v then
      v = new_value
      changed = true
    end
  end

  -- Double-click to reset
  if hovered and ImGui.IsMouseDoubleClicked(ctx, 0) then
    v = v_default
    changed = true
  end

  -- Mouse wheel support
  if hovered then
    local wheel = ImGui.GetMouseWheel(ctx)
    if wheel ~= 0 then
      local step = opts.step or 1
      v = Base.clamp(v + wheel * step, v_min, v_max)
      changed = true
    end
  end

  -- Calculate fill height (from bottom)
  local t = (v - v_min) / (v_max - v_min)
  local fill_h = floor(t * (h - 2) + 0.5)
  local fill_y = y + h - fill_h - 1

  -- Hover factor for effects
  local hover_factor = (hovered or active) and 0.3 or 0

  -- Render
  render_track(dl, x, y, w, h, opts.rounding, colors)

  if fill_h > 0 then
    render_fill(ctx, dl, x, fill_y, w, fill_h, colors.fill, config, hover_factor)
  end

  -- Tooltip
  if hovered then
    if ImGui.BeginTooltip(ctx) then
      ImGui.Text(ctx, string.format('%.0f', v))
      ImGui.EndTooltip(ctx)
    end
  end

  -- Label below slider
  if opts.label then
    local label_y = y + h + 4
    render_label(ctx, dl, x, label_y, w, opts.label, colors.label)
  end

  -- Call change callback
  if changed and opts.on_change then
    opts.on_change(v)
  end

  -- Advance cursor
  local total_h = opts.label and (h + 20) or h
  Base.advance_cursor(ctx, x, y, w, total_h, opts.advance)

  -- Return result
  return Base.create_result({
    changed = changed,
    value = v,
    hovered = hovered,
    active = active,
    width = w,
    height = total_h,
  })
end

-- ============================================================================
-- CONVENIENCE FUNCTIONS
-- ============================================================================

--- Draw a row of vertical sliders
--- @param ctx userdata ImGui context
--- @param opts table Options with: sliders = {{id, value, label}, ...}, values returned
--- @return table Results keyed by slider id
function M.DrawRow(ctx, opts)
  local Layout = require('scripts.MIDIHelix.config.layout')
  local sliders = opts.sliders or {}
  local x = opts.x or Layout.SLIDERS.X
  local y = opts.y or Layout.SLIDERS.Y
  local w = opts.width or Layout.SLIDERS.W
  local h = opts.height or Layout.SLIDERS.H
  local spacing = opts.spacing or Layout.SLIDERS.SPACING
  local fill_color = opts.fill_color

  local results = {}

  for i, slider in ipairs(sliders) do
    local sx = x + (i - 1) * spacing

    local result = M.Draw(ctx, {
      id = slider.id or ('slider_' .. i),
      x = sx,
      y = y,
      width = w,
      height = h,
      value = slider.value or 0,
      min = slider.min or opts.min or 0,
      max = slider.max or opts.max or 12,
      default = slider.default,
      label = slider.label,
      fill_color = fill_color,
      advance = 'none',
    })

    results[slider.id or i] = result
  end

  return results
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.Draw(ctx, ...)
  end
})
