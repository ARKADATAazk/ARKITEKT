-- @noindex
-- arkitekt/gui/widgets/primitives/button.lua
-- Standardized button component with Arkitekt styling
-- Uses unified opts-based API

local ImGui = require('arkitekt.core.imgui')
local Theme = require('arkitekt.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = 'button',

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  width = nil,  -- nil = auto-calculate from content
  height = 24,

  -- Content
  label = '',
  icon = '',           -- Font icon character
  icon_font = nil,     -- Font for icon
  icon_size = 16,      -- Font icon size
  draw_icon = nil,     -- Custom icon callback: function(dl, x, y, w, h, color)

  -- State
  is_disabled = false,
  is_toggled = false,
  is_blocking = false,

  -- Style
  rounding = 0,
  padding_x = 10,
  preset_name = nil,  -- Use a named preset from Theme (legacy)
  preset = nil,       -- Semantic preset: 'primary', 'danger', 'success', 'secondary'

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
  advance = 'vertical',

  -- Custom rendering
  custom_draw = nil,
  draw_list = nil,
}

-- ============================================================================
-- INSTANCE MANAGEMENT (strong tables with access tracking for cleanup)
-- ============================================================================

-- Strong tables required - weak tables cause flickering due to inter-frame GC
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
  Base.update_hover_animation(self, dt, is_hovered, is_active, 'hover_alpha')
end

-- ============================================================================
-- COLOR DERIVATION (Theme-aware HSL-based)
-- ============================================================================

-- Determine if current theme is light based on BG_BASE lightness
local function is_light_theme()
  local bg = Theme.COLORS.BG_BASE
  local _, _, l = Colors.RgbToHsl(bg)
  return l > 0.5
end

-- Derive state colors using HSL lightness shifts
-- For dark themes: hover = lighter, active = even lighter
-- For light themes: hover = darker, active = even darker
local function derive_state_color(base, state)
  local light = is_light_theme()
  local sign = light and -1 or 1

  if state == 'hover' then
    return Colors.AdjustLightness(base, sign * 0.06)
  elseif state == 'active' then
    return Colors.AdjustLightness(base, sign * 0.12)
  elseif state == 'disabled' then
    return Colors.WithOpacity(Colors.Desaturate(base, 0.5), 0.5)
  end
  return base
end

-- Get simple button colors with smooth hover animation
-- Uses Theme.COLORS directly (like combo/dropdown) for consistent ratios
local function get_simple_colors(is_toggled, is_hovered, is_active, is_disabled, accent_color, hover_alpha)
  local C = Theme.COLORS
  hover_alpha = hover_alpha or 0

  -- Base colors (normal state)
  local bg_base = C.BG_BASE
  local bg_hover = C.BG_HOVER
  local bg_active = C.BG_ACTIVE
  local text_base = C.TEXT_NORMAL
  local text_hover = C.TEXT_HOVER
  local border_inner = C.BORDER_INNER
  local border_hover = C.BORDER_HOVER
  local border_active = C.BORDER_ACTIVE
  local border_outer = C.BORDER_OUTER

  -- Toggle ON state uses accent color
  if is_toggled then
    bg_base = accent_color or C.ACCENT_WHITE
    bg_hover = Colors.AdjustLightness(bg_base, 0.06)
    bg_active = Colors.AdjustLightness(bg_base, 0.12)
    text_base = C.TEXT_BRIGHT
    text_hover = C.TEXT_BRIGHT
    border_inner = accent_color or C.ACCENT_WHITE_BRIGHT
    border_hover = Colors.AdjustLightness(border_inner, 0.08)
    border_active = Colors.AdjustLightness(border_inner, -0.05)
  end

  -- Derive final colors based on state
  local bg, text, border
  if is_disabled then
    bg = derive_state_color(bg_base, 'disabled')
    text = C.TEXT_DIMMED
    border = derive_state_color(border_inner, 'disabled')
  elseif is_active then
    -- Active state (pressed) - no lerp, immediate
    bg = bg_active
    text = C.TEXT_BRIGHT
    border = border_active
  elseif hover_alpha > 0.01 then
    -- Hover with smooth lerp (like combo/dropdown)
    bg = Colors.Lerp(bg_base, bg_hover, hover_alpha)
    text = Colors.Lerp(text_base, text_hover, hover_alpha)
    border = Colors.Lerp(border_inner, border_hover, hover_alpha)
  else
    -- Normal state
    bg = bg_base
    text = text_base
    border = border_inner
  end

  return bg, border, border_outer, text
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
    bg = Colors.Lerp(bg, hover_bg, hover_alpha)
    border_inner = Colors.Lerp(border_inner, hover_border, hover_alpha)
    text = Colors.Lerp(text, hover_text, hover_alpha)
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
-- BUTTON PRESETS (Semantic, Theme-controlled)
-- ============================================================================

--- Semantic button presets - defined by Theme colors
--- Provides controlled vocabulary for button variations
local function get_preset_colors(preset_name)
  local C = Theme.COLORS

  if preset_name == 'primary' then
    return {
      bg = C.ACCENT_PRIMARY or C.ACCENT_WHITE,
      text = C.TEXT_BRIGHT or C.TEXT_NORMAL,
    }
  elseif preset_name == 'secondary' then
    return {
      bg = C.BG_HOVER or C.BG_BASE,
      text = C.TEXT_NORMAL,
    }
  elseif preset_name == 'danger' then
    return {
      bg = C.DANGER or 0xFF4444FF,  -- Fallback red
      text = C.TEXT_BRIGHT or C.TEXT_NORMAL,
    }
  elseif preset_name == 'success' then
    return {
      bg = C.ACCENT_SUCCESS or C.SUCCESS or 0x44FF44FF,  -- Fallback green
      text = C.TEXT_BRIGHT or C.TEXT_NORMAL,
    }
  end

  -- Default: no preset
  return nil
end

-- ============================================================================
-- CONFIG RESOLUTION (Dynamic - reads Theme.COLORS each call)
-- ============================================================================

local function resolve_config(opts)
  -- OPTIMIZATION: opts already has metatable fallback to DEFAULTS from Base.parse_opts
  -- No need to copy everything! Just use opts directly as config
  local config = opts

  -- Handle semantic presets (primary, danger, success, secondary)
  -- These take priority over legacy preset_name system
  if opts.preset then
    local preset_colors = get_preset_colors(opts.preset)
    if preset_colors then
      config._use_simple_colors = false
      config._preset_colors = preset_colors
    end
  end

  -- Determine if we should use simple (auto-derived) colors or complex preset
  -- Use simple colors when:
  --   1. No preset or preset_name specified, OR
  --   2. Using BUTTON_TOGGLE_WHITE or similar basic toggle preset
  local use_simple = not opts.preset and not opts.preset_name
  local is_toggle_preset = opts.preset_name and opts.preset_name:find('TOGGLE')

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
  local is_disabled = config.is_disabled or false
  local is_toggled = config.is_toggled or false

  -- Create InvisibleButton FIRST so IsItemHovered works for everything
  -- (DrawList rendering uses explicit coordinates, doesn't care about cursor)
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, '##' .. unique_id, width, height)

  -- Now use IsItemHovered for all hover checks (single source of truth)
  local is_hovered = not is_disabled and not config.is_blocking and ImGui.IsItemHovered(ctx)
  local is_active = not is_disabled and not config.is_blocking and
                    is_hovered and ImGui.IsMouseDown(ctx, 0)

  -- Update animation
  local dt = ImGui.GetDeltaTime(ctx)
  instance:update(dt, is_hovered, is_active)

  -- Get colors - check for preset colors first, then simplified, then legacy
  local bg_color, border_inner, border_outer, text_color
  if config._preset_colors then
    -- Semantic preset colors (primary, danger, success, secondary)
    local preset = config._preset_colors
    local base_bg = preset.bg
    local base_text = preset.text

    -- Apply hover/active state modulation
    if is_disabled then
      bg_color = Colors.Darken(base_bg, 0.3)
      text_color = Colors.Darken(base_text, 0.5)
    elseif is_active then
      bg_color = Colors.Darken(base_bg, 0.15)
      text_color = base_text
    elseif is_hovered then
      -- Smooth hover blend using instance.hover_alpha
      local hover_bg = Colors.Lighten(base_bg, 0.1)
      bg_color = Colors.Blend(base_bg, hover_bg, instance.hover_alpha)
      text_color = base_text
    else
      bg_color = base_bg
      text_color = base_text
    end

    -- Preset buttons have subtle borders
    border_inner = Colors.Lighten(bg_color, 0.15)
    border_outer = Colors.Darken(bg_color, 0.2)

  elseif config._use_simple_colors then
    -- Simplified approach with smooth hover animation (like combo/dropdown)
    bg_color, border_inner, border_outer, text_color =
      get_simple_colors(is_toggled, is_hovered, is_active, is_disabled, config._accent_color, instance.hover_alpha)
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
  local label = config.label or ''
  local icon = config.icon or ''
  local icon_font = config.icon_font
  local icon_size = config.icon_size
  local draw_icon = config.draw_icon

  if config.custom_draw then
    config.custom_draw(ctx, dl, x, y, width, height, is_hovered, is_active, text_color)
  elseif draw_icon then
    -- Custom icon drawing callback
    draw_icon(dl, x, y, width, height, text_color)
    -- Draw label if present (centered to the right of icon area or below)
    if label ~= '' then
      local label_w = ImGui.CalcTextSize(ctx, label)
      local label_h = ImGui.GetTextLineHeight(ctx)
      ImGui.DrawList_AddText(dl, x + (width - label_w) * 0.5, y + (height - label_h) * 0.5, text_color, label)
    end
  elseif icon ~= '' or label ~= '' then
    if icon_font and icon ~= '' then
      ImGui.PushFont(ctx, icon_font, icon_size or 16)
      local icon_w, icon_h = ImGui.CalcTextSize(ctx, icon), ImGui.GetTextLineHeight(ctx)
      ImGui.PopFont(ctx)

      local label_w = label ~= '' and ImGui.CalcTextSize(ctx, label) or 0
      local spacing = (label ~= '') and 4 or 0
      local start_x = x + (width - icon_w - spacing - label_w) * 0.5

      ImGui.PushFont(ctx, icon_font, icon_size or 16)
      ImGui.DrawList_AddText(dl, start_x, y + (height - icon_h) * 0.5, text_color, icon)
      ImGui.PopFont(ctx)

      if label ~= '' then
        local label_h = ImGui.GetTextLineHeight(ctx)
        ImGui.DrawList_AddText(dl, start_x + icon_w + spacing, y + (height - label_h) * 0.5, text_color, label)
      end
    else
      local display_text = icon .. (icon ~= '' and label ~= '' and ' ' or '') .. label
      local text_w = ImGui.CalcTextSize(ctx, display_text)
      ImGui.DrawList_AddText(dl, x + (width - text_w) * 0.5, y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5, text_color, display_text)
    end
  end

  -- Check for clicks (InvisibleButton already created at start)
  local clicked = not is_disabled and not config.is_blocking and ImGui.IsItemClicked(ctx, 0)
  local right_clicked = not is_disabled and not config.is_blocking and ImGui.IsItemClicked(ctx, 1)

  return is_hovered, is_active, clicked, right_clicked
end

--- Measure button width based on content (internal - use via opts.width or auto-calculation)
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return number Calculated width
local function measure(ctx, opts)
  opts = opts or {}

  -- Only use explicit width if it's > 0 (width = 0 means auto-calculate)
  if opts.width and opts.width > 0 then
    return opts.width
  end

  local config = resolve_config(opts)
  local label = config.label or ''
  local icon = config.icon or ''
  local display_text = icon .. (icon ~= '' and label ~= '' and ' ' or '') .. label

  local text_w = ImGui.CalcTextSize(ctx, display_text)
  local padding = config.padding_x or 10

  return text_w + padding * 2
end

-- ============================================================================
-- PUBLIC API (Standardized)
-- ============================================================================

--- Draw a button widget
--- Supports both positional and opts-based parameters:
--- - Positional: Ark.Button(ctx, label, width, height)
--- - Opts table: Ark.Button(ctx, {label = '...', width = 100, ...})
--- @param ctx userdata ImGui context
--- @param label_or_opts string|table Label string or opts table
--- @param width number|nil Button width (positional only)
--- @param height number|nil Button height (positional only)
--- @return table Result { clicked, right_clicked, width, height, hovered, active }
function M.Draw(ctx, label_or_opts, width, height)
  -- Hybrid parameter detection
  local opts
  if type(label_or_opts) == 'table' then
    -- Opts table passed directly
    opts = label_or_opts
  elseif type(label_or_opts) == 'string' then
    -- Positional params - map to opts
    opts = {
      label = label_or_opts,
      width = width,
      height = height,
    }
  else
    -- No params or just ctx - empty opts
    opts = {}
  end

  opts = Base.parse_opts(opts, DEFAULTS)
  local config = resolve_config(opts)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, 'button')

  -- Get or create instance
  local instance = Base.get_or_create_instance(instances, unique_id, Button.new, ctx)

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Calculate size (width = 0 means auto-calculate, so check > 0)
  local final_width = (opts.width and opts.width > 0) and opts.width or measure(ctx, opts)
  local final_height = (opts.height and opts.height > 0) and opts.height or 24

  -- Render button (InvisibleButton created first, then DrawList rendering)
  local is_hovered, is_active, clicked, right_clicked = render_button(ctx, dl, x, y, final_width, final_height, config, instance, unique_id)

  -- Handle callbacks
  if clicked and config.on_click then
    config.on_click()
  end
  if right_clicked and config.on_right_click then
    config.on_right_click()
  end

  -- Handle tooltip (uses is_hovered from render_button)
  if is_hovered and opts.tooltip then
    local tooltip_text = type(opts.tooltip) == 'function' and opts.tooltip() or opts.tooltip
    if tooltip_text then
      ImGui.SetTooltip(ctx, tooltip_text)
    end
  end

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, final_width, final_height, opts.advance)

  -- Return standardized result
  return Base.create_result({
    clicked = clicked,
    right_clicked = right_clicked,
    width = final_width,
    height = final_height,
    hovered = is_hovered,
    active = is_active,
  })
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.Button(ctx, ...) → M.Draw(ctx, ...)
-- Hybrid return: positional mode returns boolean (ImGui style), opts mode returns result object
return setmetatable(M, {
  __call = function(_, ctx, label_or_opts, width, height)
    -- Detect mode based on first parameter type
    if type(label_or_opts) == 'table' then
      -- Opts mode: Return full result object for power users
      return M.Draw(ctx, label_or_opts)
    else
      -- Positional mode: Return boolean like ImGui for ergonomics
      -- Create new opts table (can't reuse - causes ID conflicts)
      local result = M.Draw(ctx, {
        label = label_or_opts,
        width = width,
        height = height,
      })
      return result.clicked  -- ImGui-compatible return
    end
  end
})
