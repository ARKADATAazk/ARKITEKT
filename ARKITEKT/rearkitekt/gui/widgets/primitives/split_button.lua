-- @noindex
-- ReArkitekt/gui/widgets/primitives/split_button.lua
-- Split button component: button + dropdown combined
-- Allows clicking the button itself or clicking dropdown arrow for options

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('rearkitekt.gui.style.defaults')
local ContextMenu = require('rearkitekt.gui.widgets.overlays.context_menu')

local M = {}

-- Instance storage for animation state
local instances = {}

-- ============================================================================
-- INSTANCE MANAGEMENT
-- ============================================================================

local SplitButton = {}
SplitButton.__index = SplitButton

function SplitButton.new(id)
  local instance = setmetatable({
    id = id,
    button_hover_alpha = 0,
    arrow_hover_alpha = 0,
  }, SplitButton)
  return instance
end

function SplitButton:update(dt, button_hovered, arrow_hovered, is_toggled)
  local alpha_speed = 12.0

  -- Button hover (also active when toggled)
  local button_target = (button_hovered or is_toggled) and 1.0 or 0.0
  self.button_hover_alpha = self.button_hover_alpha + (button_target - self.button_hover_alpha) * alpha_speed * dt
  self.button_hover_alpha = math.max(0, math.min(1, self.button_hover_alpha))

  -- Arrow hover
  local arrow_target = arrow_hovered and 1.0 or 0.0
  self.arrow_hover_alpha = self.arrow_hover_alpha + (arrow_target - self.arrow_hover_alpha) * alpha_speed * dt
  self.arrow_hover_alpha = math.max(0, math.min(1, self.arrow_hover_alpha))
end

local function get_or_create_instance(unique_id)
  if not instances[unique_id] then
    instances[unique_id] = SplitButton.new(unique_id)
  end
  return instances[unique_id]
end

-- ============================================================================
-- CONTEXT DETECTION
-- ============================================================================

local function resolve_context(config, state_or_id)
  local context = {
    unique_id = nil,
    corner_rounding = nil,
    is_panel_context = false,
  }

  if type(state_or_id) == "table" and state_or_id._panel_id then
    context.is_panel_context = true
    context.unique_id = string.format("%s_%s", state_or_id._panel_id, config.id or "split_button")
    context.corner_rounding = config.corner_rounding
  else
    context.unique_id = type(state_or_id) == "string" and state_or_id or (config.id or "split_button")
    context.corner_rounding = nil
  end

  return context
end

-- ============================================================================
-- CORNER ROUNDING
-- ============================================================================

local function get_corner_flags(corner_rounding, is_left_part)
  if not corner_rounding then
    return 0
  end

  local flags = 0

  if is_left_part then
    -- Button part: only round left corners if specified
    if corner_rounding.round_top_left then
      flags = flags | ImGui.DrawFlags_RoundCornersTopLeft
    end
    if corner_rounding.round_bottom_left then
      flags = flags | ImGui.DrawFlags_RoundCornersBottomLeft
    end
  else
    -- Arrow part: only round right corners if specified
    if corner_rounding.round_top_right then
      flags = flags | ImGui.DrawFlags_RoundCornersTopRight
    end
    if corner_rounding.round_bottom_right then
      flags = flags | ImGui.DrawFlags_RoundCornersBottomRight
    end
  end

  if flags == 0 then
    return ImGui.DrawFlags_RoundCornersNone
  end

  return flags
end

-- ============================================================================
-- DRAWING
-- ============================================================================

function M.draw(ctx, dl, x, y, width, height, user_config, state_or_id)
  -- Resolve base style with optional preset support
  local base = Style.BUTTON
  if user_config then
    if user_config.preset_name and Style[user_config.preset_name] then
      base = Style.apply_defaults(base, Style[user_config.preset_name])
    elseif user_config.preset and type(user_config.preset) == 'table' then
      base = Style.apply_defaults(base, user_config.preset)
    end
  end
  -- Apply style defaults
  local config = Style.apply_defaults(base, user_config)

  local context = resolve_context(config, state_or_id)
  local instance = get_or_create_instance(context.unique_id)

  local dt = ImGui.GetDeltaTime(ctx)
  local mx, my = ImGui.GetMousePos(ctx)

  -- Split button layout (overlap by 1px to share border)
  local arrow_width = 20
  local button_width = width - arrow_width + 1  -- +1 for overlap
  local arrow_x = x + button_width - 1  -- Start 1px before button ends

  -- Check hover states
  local button_hovered = mx >= x and mx < x + button_width - 1 and my >= y and my < y + height
  local arrow_hovered = mx >= arrow_x and mx < x + width and my >= y and my < y + height

  -- Get config
  local is_toggled = config.is_toggled or false
  local label = config.label or "Button"

  -- Update animation
  instance:update(dt, button_hovered, arrow_hovered, is_toggled)

  -- Calculate animated colors (same pattern as button.lua)
  local bg_color, border_inner, border_outer, text_color

  if is_toggled then
    -- Toggle ON colors
    bg_color = config.bg_on_color or config.bg_color
    border_inner = config.border_inner_on_color or config.border_inner_color
    border_outer = config.border_outer_on_color or config.border_outer_color
    text_color = config.text_on_color or config.text_color

    -- Button part hover
    if instance.button_hover_alpha > 0.01 then
      local button_bg_hover = config.bg_on_hover_color or bg_color
      local button_border_hover = config.border_on_hover_color or border_inner
      local button_text_hover = config.text_on_hover_color or text_color

      bg_color = Style.RENDER.lerp_color(bg_color, button_bg_hover, instance.button_hover_alpha)
      border_inner = Style.RENDER.lerp_color(border_inner, button_border_hover, instance.button_hover_alpha)
      text_color = Style.RENDER.lerp_color(text_color, button_text_hover, instance.button_hover_alpha)
    end
  else
    -- Normal colors
    bg_color = config.bg_color
    border_inner = config.border_inner_color
    border_outer = config.border_outer_color
    text_color = config.text_color

    -- Button part hover
    if instance.button_hover_alpha > 0.01 then
      local button_bg_hover = config.bg_hover_color or bg_color
      local button_border_hover = config.border_hover_color or border_inner
      local button_text_hover = config.text_hover_color or text_color

      bg_color = Style.RENDER.lerp_color(bg_color, button_bg_hover, instance.button_hover_alpha)
      border_inner = Style.RENDER.lerp_color(border_inner, button_border_hover, instance.button_hover_alpha)
      text_color = Style.RENDER.lerp_color(text_color, button_text_hover, instance.button_hover_alpha)
    end
  end

  -- Arrow colors (separate hover state)
  local arrow_bg = bg_color
  local arrow_border_inner = border_inner
  local arrow_text = text_color

  if instance.arrow_hover_alpha > 0.01 then
    local arrow_bg_hover = is_toggled and (config.bg_on_hover_color or bg_color) or (config.bg_hover_color or bg_color)
    local arrow_border_hover = is_toggled and (config.border_on_hover_color or border_inner) or (config.border_hover_color or border_inner)
    local arrow_text_hover = is_toggled and (config.text_on_hover_color or text_color) or (config.text_hover_color or text_color)

    arrow_bg = Style.RENDER.lerp_color(bg_color, arrow_bg_hover, instance.arrow_hover_alpha)
    arrow_border_inner = Style.RENDER.lerp_color(border_inner, arrow_border_hover, instance.arrow_hover_alpha)
    arrow_text = Style.RENDER.lerp_color(text_color, arrow_text_hover, instance.arrow_hover_alpha)
  end

  -- Calculate rounding
  local rounding = config.rounding or 0
  if context.corner_rounding then
    rounding = context.corner_rounding.rounding or rounding
  end
  local inner_rounding = math.max(0, rounding - 2)

  -- Corner flags
  local button_corner_flags = get_corner_flags(context.corner_rounding, true)
  local arrow_corner_flags = get_corner_flags(context.corner_rounding, false)

  -- Draw button part (left side)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + button_width, y + height, bg_color, inner_rounding, button_corner_flags)
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + button_width - 1, y + height - 1, border_inner, inner_rounding, button_corner_flags, 1)
  ImGui.DrawList_AddRect(dl, x, y, x + button_width, y + height, border_outer, inner_rounding, button_corner_flags, 1)

  -- Draw arrow part (right side, overlaps by 1px)
  ImGui.DrawList_AddRectFilled(dl, arrow_x, y, x + width, y + height, arrow_bg, inner_rounding, arrow_corner_flags)
  ImGui.DrawList_AddRect(dl, arrow_x + 1, y + 1, x + width - 1, y + height - 1, arrow_border_inner, inner_rounding, arrow_corner_flags, 1)
  ImGui.DrawList_AddRect(dl, arrow_x, y, x + width, y + height, border_outer, inner_rounding, arrow_corner_flags, 1)

  -- Draw subtle separator between button and arrow (more inset to show they're connected)
  local separator_inset = 6
  local separator_color = arrow_bg  -- Use arrow background color for seamless look
  ImGui.DrawList_AddLine(dl, arrow_x, y + separator_inset, arrow_x, y + height - separator_inset, separator_color, 1)

  -- Draw button text (with padding)
  local text_padding_x = 8  -- Horizontal padding for text
  local tw = ImGui.CalcTextSize(ctx, label)
  local text_area_width = button_width - 1 - (text_padding_x * 2)  -- -1 for overlap, -padding on both sides
  local text_x = x + text_padding_x + (text_area_width - tw) * 0.5
  local text_y = y + (height - ImGui.GetTextLineHeight(ctx)) * 0.5
  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, label)

  -- Draw dropdown arrow (▼) - render to whole pixels for crisp display
  local arrow_size = 8  -- Increased from 6
  local arrow_center_x = math.floor(arrow_x + arrow_width * 0.5 + 0.5)  -- Pixel snap center
  local arrow_center_y = math.floor(y + height * 0.5 + 0.5)
  local arrow_half_width = math.floor(arrow_size * 0.5 + 0.5)
  local arrow_height = math.floor(arrow_size * 0.4 + 0.5)  -- Slightly shorter for better proportions

  -- Triangle pointing down (pixel-perfect coordinates)
  ImGui.DrawList_AddTriangleFilled(dl,
    arrow_center_x - arrow_half_width, arrow_center_y - arrow_height * 0.5,  -- Top left
    arrow_center_x + arrow_half_width, arrow_center_y - arrow_height * 0.5,  -- Top right
    arrow_center_x, arrow_center_y + arrow_height * 0.5,  -- Bottom center
    arrow_text
  )

  -- Handle clicks
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. context.unique_id .. "_button", button_width - 1, height)
  local button_clicked = ImGui.IsItemClicked(ctx, 0)

  ImGui.SetCursorScreenPos(ctx, arrow_x, y)
  ImGui.InvisibleButton(ctx, "##" .. context.unique_id .. "_arrow", arrow_width, height)
  local arrow_clicked = ImGui.IsItemClicked(ctx, 0)

  -- Tooltips
  if button_hovered and config.tooltip then
    ImGui.SetTooltip(ctx, config.tooltip)
  end

  -- Trigger button callback
  if button_clicked and config.on_click then
    config.on_click()
  end

  -- Handle dropdown
  if arrow_clicked then
    ImGui.OpenPopup(ctx, context.unique_id .. "_menu")
  end

  -- Render dropdown using context_menu.lua
  if config.dropdown_options then
    if ContextMenu.begin(ctx, context.unique_id .. "_menu") then
      for _, option in ipairs(config.dropdown_options) do
        if option.type == "separator" then
          ContextMenu.separator(ctx)
        elseif option.type == "item" then
          if ContextMenu.item(ctx, option.label) then
            if option.on_click then
              option.on_click(option.value)
            end
          end
        end
      end
      ContextMenu.end_menu(ctx)
    end
  end

  return width, button_clicked
end

function M.measure(ctx, user_config, state)
  local base = Style.BUTTON
  if user_config then
    if user_config.preset_name and Style[user_config.preset_name] then
      base = Style.apply_defaults(base, Style[user_config.preset_name])
    elseif user_config.preset and type(user_config.preset) == 'table' then
      base = Style.apply_defaults(base, user_config.preset)
    end
  end
  local config = Style.apply_defaults(base, user_config)

  return config.width or 100
end

return M
