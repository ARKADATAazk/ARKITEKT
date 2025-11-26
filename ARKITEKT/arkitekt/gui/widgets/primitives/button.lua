-- @noindex
-- arkitekt/gui/widgets/primitives/button.lua
-- Standardized button component with Arkitekt styling
-- Uses unified opts-based API

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = "button",

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  width = nil,  -- nil = auto-calculate from content
  height = 24,

  -- Content
  label = "",
  icon = "",
  icon_font = nil,
  icon_size = 16,

  -- State
  disabled = false,
  is_toggled = false,
  is_blocking = false,

  -- Style
  rounding = 0,
  padding_x = 10,
  preset_name = nil,  -- Use a named preset from Theme
  preset = nil,       -- Use a custom preset table

  -- Colors (nil = use Theme.BUTTON defaults)
  bg_color = nil,
  bg_hover_color = nil,
  bg_active_color = nil,
  bg_disabled_color = nil,
  bg_on_color = nil,
  bg_on_hover_color = nil,
  bg_on_active_color = nil,
  border_inner_color = nil,
  border_inner_hover_color = nil,
  border_inner_active_color = nil,
  border_inner_disabled_color = nil,
  border_inner_on_color = nil,
  border_outer_color = nil,
  border_outer_disabled_color = nil,
  text_color = nil,
  text_hover_color = nil,
  text_active_color = nil,
  text_disabled_color = nil,
  text_on_color = nil,

  -- Callbacks
  on_click = nil,
  on_right_click = nil,
  tooltip = nil,

  -- Panel integration
  panel_state = nil,
  corner_rounding = nil,

  -- Cursor control
  advance = "vertical",

  -- Custom rendering
  custom_draw = nil,
  draw_list = nil,
}

-- ============================================================================
-- INSTANCE MANAGEMENT (strong tables with access tracking for cleanup)
-- ============================================================================

local instances = Base.create_instance_registry()

local Button = {}
Button.__index = Button

function Button.new(id)
  return setmetatable({
    id = id,
    hover_alpha = 0,
  }, Button)
end

function Button:update(dt, is_hovered, is_active)
  Base.update_hover_animation(self, dt, is_hovered, is_active, "hover_alpha")
end

-- ============================================================================
-- COLOR DERIVATION (Theme-aware HSL-based)
-- ============================================================================

-- Determine if current theme is light based on BG_BASE lightness
local function is_light_theme()
  local bg = Theme.COLORS.BG_BASE
  local _, _, l = Colors.rgb_to_hsl(bg)
  return l > 0.5
end

-- Derive state colors using HSL lightness shifts
-- For dark themes: hover = lighter, active = even lighter
-- For light themes: hover = darker, active = even darker
local function derive_state_color(base, state)
  local light = is_light_theme()
  local sign = light and -1 or 1

  if state == 'hover' then
    return Colors.adjust_lightness(base, sign * 0.06)
  elseif state == 'active' then
    return Colors.adjust_lightness(base, sign * 0.12)
  elseif state == 'disabled' then
    return Colors.with_opacity(Colors.desaturate(base, 0.5), 0.5)
  end
  return base
end

-- Get simple button colors with automatic state derivation
-- This replaces the complex preset system for most use cases
local function get_simple_colors(is_toggled, is_hovered, is_active, is_disabled, accent_color)
  local C = Theme.COLORS

  -- Base colors
  local bg_base = C.BG_BASE
  local text_base = C.TEXT_NORMAL
  local border_inner = C.BORDER_INNER
  local border_outer = C.BORDER_OUTER

  -- Toggle ON state uses accent color
  if is_toggled then
    bg_base = accent_color or C.ACCENT_WHITE
    text_base = C.TEXT_BRIGHT
    border_inner = accent_color or C.ACCENT_WHITE_BRIGHT
  end

  -- Derive state colors
  local bg, text
  if is_disabled then
    bg = derive_state_color(bg_base, 'disabled')
    text = C.TEXT_DIMMED
    border_inner = derive_state_color(border_inner, 'disabled')
  elseif is_active then
    bg = derive_state_color(bg_base, 'active')
    text = C.TEXT_BRIGHT
  elseif is_hovered then
    bg = derive_state_color(bg_base, 'hover')
    text = C.TEXT_HOVER
    border_inner = derive_state_color(border_inner, 'hover')
  else
    bg = bg_base
    text = text_base
  end

  return bg, border_inner, border_outer, text
end

local function get_state_colors(config, is_disabled, is_toggled, is_active, hover_alpha)
  if is_disabled then
    return config.bg_disabled_color or derive_state_color(config.bg_color, 'disabled'),
           config.border_inner_disabled_color or derive_state_color(config.border_inner_color, 'disabled'),
           config.border_outer_disabled_color or derive_state_color(config.border_outer_color, 'disabled'),
           config.text_disabled_color or derive_state_color(config.text_color, 'disabled')
  end

  local prefix = is_toggled and '_on' or ''
  local bg = config['bg' .. prefix .. '_color'] or config.bg_color
  local border_inner = config['border_inner' .. prefix .. '_color'] or config.border_inner_color
  local border_outer = config['border_outer' .. prefix .. '_color'] or config.border_outer_color
  local text = config['text' .. prefix .. '_color'] or config.text_color

  if is_active then
    local active_suffix = prefix .. '_active_color'
    bg = config['bg' .. active_suffix] or derive_state_color(bg, 'active')
    border_inner = config['border' .. (is_toggled and '_on_active_color' or '_active_color')] or derive_state_color(border_inner, 'active')
    text = config['text' .. active_suffix] or text
  elseif hover_alpha > 0.01 then
    local hover_suffix = prefix .. '_hover_color'
    local hover_bg = config['bg' .. hover_suffix] or derive_state_color(bg, 'hover')
    local hover_border = config['border' .. (is_toggled and '_on_hover_color' or '_hover_color')] or derive_state_color(border_inner, 'hover')
    local hover_text = config['text' .. hover_suffix] or text
    bg = Colors.lerp(bg, hover_bg, hover_alpha)
    border_inner = Colors.lerp(border_inner, hover_border, hover_alpha)
    text = Colors.lerp(text, hover_text, hover_alpha)
  end

  return bg, border_inner, border_outer, text
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

  if flags == 0 then
    return ImGui.DrawFlags_RoundCornersNone
  end

  return flags
end

-- ============================================================================
-- CONFIG RESOLUTION (Dynamic - reads Theme.COLORS each call)
-- ============================================================================

local function resolve_config(opts)
  -- Start with defaults merged with opts
  local config = {}

  -- Copy defaults
  for k, v in pairs(DEFAULTS) do
    config[k] = v
  end

  -- Apply user overrides first (so we know if preset_name is set)
  for k, v in pairs(opts) do
    if v ~= nil then
      config[k] = v
    end
  end

  -- Determine if we should use simple (auto-derived) colors or complex preset
  -- Use simple colors when:
  --   1. No preset_name specified, OR
  --   2. Using BUTTON_TOGGLE_WHITE or similar basic toggle preset
  local use_simple = not opts.preset_name and not opts.preset
  local is_toggle_preset = opts.preset_name and opts.preset_name:find("TOGGLE")

  if use_simple or is_toggle_preset then
    -- Mark for simple color derivation (handled in render)
    config._use_simple_colors = true
    config._accent_color = nil  -- Will use ACCENT_WHITE by default for toggles

    -- For custom accent, check if user specified one
    if opts.accent_color then
      config._accent_color = opts.accent_color
    end
  else
    -- Legacy: use complex preset system
    local base_config = Theme.build_button_config()
    for k, v in pairs(base_config) do
      if config[k] == nil then
        config[k] = v
      end
    end

    if opts.preset_name then
      Theme.apply_preset(config, opts.preset_name)
    elseif opts.preset and type(opts.preset) == 'table' then
      for k, v in pairs(opts.preset) do
        config[k] = v
      end
    end
  end

  return config
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_button(ctx, dl, x, y, width, height, config, instance, unique_id)
  local is_disabled = config.disabled or false
  local is_toggled = config.is_toggled or false

  -- Check hover using IsMouseHoveringRect (ImGui built-in, respects clipping)
  local is_hovered = not is_disabled and not config.is_blocking and
                     ImGui.IsMouseHoveringRect(ctx, x, y, x + width, y + height)
  local is_active = not is_disabled and not config.is_blocking and
                    is_hovered and ImGui.IsMouseDown(ctx, 0)

  -- Update animation
  local dt = ImGui.GetDeltaTime(ctx)
  instance:update(dt, is_hovered, is_active)

  -- Get colors - use simplified system when marked, otherwise legacy
  local bg_color, border_inner, border_outer, text_color
  if config._use_simple_colors then
    -- New simplified approach: auto-derive all state colors
    bg_color, border_inner, border_outer, text_color =
      get_simple_colors(is_toggled, is_hovered, is_active, is_disabled, config._accent_color)
  else
    -- Legacy: complex config-based approach with hover animation
    bg_color, border_inner, border_outer, text_color =
      get_state_colors(config, is_disabled, is_toggled, is_active, instance.hover_alpha)
  end

  -- Calculate rounding
  local rounding = config.rounding or 0
  if config.corner_rounding then
    rounding = config.corner_rounding.rounding or rounding
  end
  local inner_rounding = math.max(0, rounding - 2)
  local corner_flags = get_corner_flags(config.corner_rounding)

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, bg_color, inner_rounding, corner_flags)

  -- Draw borders
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + width - 1, y + height - 1, border_inner, inner_rounding, corner_flags, 1)
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, border_outer, inner_rounding, corner_flags, 1)

  -- Draw content
  local label = config.label or ""
  local icon = config.icon or ""
  local icon_font = config.icon_font
  local icon_size = config.icon_size

  if config.custom_draw then
    config.custom_draw(ctx, dl, x, y, width, height, is_hovered, is_active, text_color)
  elseif icon ~= "" or label ~= "" then
    if icon_font and icon ~= "" then
      ImGui.PushFont(ctx, icon_font, icon_size or 16)
      local icon_w, icon_h = ImGui.CalcTextSize(ctx, icon), ImGui.GetTextLineHeight(ctx)
      ImGui.PopFont(ctx)

      local label_w = label ~= "" and ImGui.CalcTextSize(ctx, label) or 0
      local spacing = (label ~= "") and 4 or 0
      local start_x = x + (width - icon_w - spacing - label_w) * 0.5

      ImGui.PushFont(ctx, icon_font, icon_size or 16)
      ImGui.DrawList_AddText(dl, start_x, y + (height - icon_h) * 0.5, text_color, icon)
      ImGui.PopFont(ctx)

      if label ~= "" then
        local label_h = ImGui.GetTextLineHeight(ctx)
        ImGui.DrawList_AddText(dl, start_x + icon_w + spacing, y + (height - label_h) * 0.5, text_color, label)
      end
    else
      local display_text = icon .. (icon ~= "" and label ~= "" and " " or "") .. label
      local text_w = ImGui.CalcTextSize(ctx, display_text)
      ImGui.DrawList_AddText(dl, x + (width - text_w) * 0.5, y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5, text_color, display_text)
    end
  end

  -- Create InvisibleButton AFTER drawing for click detection
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, width, height)

  -- Check for clicks
  local clicked = not is_disabled and not config.is_blocking and ImGui.IsItemClicked(ctx, 0)
  local right_clicked = not is_disabled and not config.is_blocking and ImGui.IsItemClicked(ctx, 1)

  return is_hovered, is_active, clicked, right_clicked
end

-- ============================================================================
-- PUBLIC API (Standardized)
-- ============================================================================

--- Draw a button widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { clicked, right_clicked, width, height, hovered, active }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)
  local config = resolve_config(opts)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(opts, "button")

  -- Get or create instance
  local instance = Base.get_or_create_instance(instances, unique_id, Button.new)

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Calculate size
  local width = opts.width or M.measure(ctx, opts)
  local height = opts.height or 24

  -- Render (InvisibleButton is created inside render_button now)
  local is_hovered, is_active, clicked, right_clicked = render_button(ctx, dl, x, y, width, height, config, instance, unique_id)

  -- Handle callbacks
  if clicked and config.on_click then
    config.on_click()
  end
  if right_clicked and config.on_right_click then
    config.on_right_click()
  end

  -- Handle tooltip (can use manual is_hovered check or IsItemHovered on InvisibleButton)
  if ImGui.IsItemHovered(ctx) and opts.tooltip then
    ImGui.SetTooltip(ctx, opts.tooltip)
  end

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, width, height, opts.advance)

  -- Return standardized result
  return Base.create_result({
    clicked = clicked,
    right_clicked = right_clicked,
    width = width,
    height = height,
    hovered = is_hovered,
    active = is_active,
  })
end

--- Measure button width based on content
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return number Calculated width
function M.measure(ctx, opts)
  opts = opts or {}

  if opts.width then
    return opts.width
  end

  local config = resolve_config(opts)
  local label = config.label or ""
  local icon = config.icon or ""
  local display_text = icon .. (icon ~= "" and label ~= "" and " " or "") .. label

  local text_w = ImGui.CalcTextSize(ctx, display_text)
  local padding = config.padding_x or 10

  return text_w + padding * 2
end

--- Draw a button at current ImGui cursor position (convenience function)
--- @param ctx userdata ImGui context
--- @param opts table Widget options (x/y will be set from cursor)
--- @param id string|nil Optional ID override
--- @return boolean clicked Whether button was clicked
function M.draw_at_cursor(ctx, opts, id)
  opts = opts or {}
  if id then opts.id = id end
  -- Don't set x/y so it uses cursor position
  local result = M.draw(ctx, opts)
  return result.clicked
end

--- Clean up all button instances
function M.cleanup()
  Base.cleanup_registry(instances)
end

return M
