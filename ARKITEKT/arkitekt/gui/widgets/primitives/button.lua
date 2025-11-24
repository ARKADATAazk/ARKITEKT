-- @noindex
-- arkitekt/gui/widgets/primitives/button.lua
-- Standardized button component with Arkitekt styling
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
  preset_name = nil,  -- Use a named preset from Style
  preset = nil,       -- Use a custom preset table

  -- Colors (nil = use Style.BUTTON defaults)
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
-- INSTANCE MANAGEMENT (weak table to prevent memory leaks)
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
  Base.update_hover_animation(self, dt, is_hovered, is_active, 12.0)
end

-- ============================================================================
-- COLOR DERIVATION
-- ============================================================================

local function derive_state_color(base, state)
  if state == 'hover' then
    return Colors.adjust_brightness(base, 1.15)
  elseif state == 'active' then
    return Colors.adjust_brightness(base, 0.85)
  elseif state == 'disabled' then
    return Colors.with_alpha(Colors.desaturate(base, 0.5), 0x80)
  end
  return base
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
    bg = Style.RENDER.lerp_color(bg, hover_bg, hover_alpha)
    border_inner = Style.RENDER.lerp_color(border_inner, hover_border, hover_alpha)
    text = Style.RENDER.lerp_color(text, hover_text, hover_alpha)
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
-- CONFIG RESOLUTION
-- ============================================================================

local function resolve_config(opts)
  local base = Style.BUTTON

  -- Apply preset if specified
  if opts.preset_name and Style[opts.preset_name] then
    base = Style.apply_defaults(base, Style[opts.preset_name])
  elseif opts.preset and type(opts.preset) == 'table' then
    base = Style.apply_defaults(base, opts.preset)
  end

  return Style.apply_defaults(base, opts)
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_button(ctx, dl, x, y, width, height, config, instance, unique_id)
  local is_disabled = config.disabled or false
  local is_toggled = config.is_toggled or false

  -- Check hover using GetMousePos (exactly like combo)
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = not is_disabled and not config.is_blocking and
                     mx >= x and mx < x + width and my >= y and my < y + height
  local is_active = not is_disabled and not config.is_blocking and
                    is_hovered and ImGui.IsMouseDown(ctx, 0)

  -- Update animation BEFORE getting colors (exactly like combo)
  local dt = ImGui.GetDeltaTime(ctx)
  instance:update(dt, is_hovered, is_active)

  -- Get colors using the smoothly animated hover_alpha
  local bg_color, border_inner, border_outer, text_color =
    get_state_colors(config, is_disabled, is_toggled, is_active, instance.hover_alpha)

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

  -- Create InvisibleButton AFTER drawing (exactly like combo)
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

  -- Handle tooltip (use is_hovered from GetMousePos, like combo)
  if is_hovered and opts.tooltip then
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
