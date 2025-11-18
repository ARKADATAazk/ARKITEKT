-- @noindex
-- ReArkitekt/gui/widgets/primitives/split_button.lua
-- Split button component: button + dropdown combined
-- Allows clicking the button itself or clicking dropdown arrow for options

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('rearkitekt.gui.style.defaults')
local Dropdown = require('rearkitekt.gui.widgets.inputs.dropdown')

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

function SplitButton:update(dt, button_hovered, arrow_hovered, is_active)
  local alpha_speed = 12.0

  -- Button hover
  local button_target = (button_hovered or is_active) and 1.0 or 0.0
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

  -- Split button layout
  local arrow_width = 20
  local button_width = width - arrow_width

  -- Check hover states
  local button_hovered = mx >= x and mx < x + button_width and my >= y and my < y + height
  local arrow_hovered = mx >= x + button_width and mx < x + width and my >= y and my < y + height

  -- Get config
  local is_toggled = config.is_toggled or false
  local label = config.label or "Button"

  -- Update animation
  instance:update(dt, button_hovered, arrow_hovered, is_toggled)

  -- Use button config colors
  local bg_off = config.bg_color
  local bg_off_hover = config.bg_hover_color or config.bg_color
  local bg_on = config.bg_on_color or config.bg_color
  local bg_on_hover = config.bg_on_hover_color or bg_on

  local border_off = config.border_outer_color
  local border_on = config.border_outer_on_color or border_off

  local text_off = config.text_color
  local text_on = config.text_on_color or text_off

  -- Button background
  local button_bg = is_toggled
    and (button_hovered and bg_on_hover or bg_on)
    or (button_hovered and bg_off_hover or bg_off)

  -- Arrow background
  local arrow_bg = is_toggled
    and (arrow_hovered and bg_on_hover or bg_on)
    or (arrow_hovered and bg_off_hover or bg_off)

  local border_color = is_toggled and border_on or border_off
  local text_color = is_toggled and text_on or text_off

  local rounding = 4

  -- Draw button part
  ImGui.DrawList_AddRectFilled(dl, x, y, x + button_width, y + height, button_bg, rounding, ImGui.DrawFlags_RoundCornersLeft)
  ImGui.DrawList_AddRect(dl, x, y, x + button_width, y + height, border_color, rounding, ImGui.DrawFlags_RoundCornersLeft, 1)

  -- Draw arrow part
  ImGui.DrawList_AddRectFilled(dl, x + button_width, y, x + width, y + height, arrow_bg, rounding, ImGui.DrawFlags_RoundCornersRight)
  ImGui.DrawList_AddRect(dl, x + button_width, y, x + width, y + height, border_color, rounding, ImGui.DrawFlags_RoundCornersRight, 1)

  -- Draw separator line between button and arrow
  ImGui.DrawList_AddLine(dl, x + button_width, y + 4, x + button_width, y + height - 4, border_color, 1)

  -- Draw text
  local tw, th = ImGui.CalcTextSize(ctx, label)
  ImGui.DrawList_AddText(dl, x + (button_width - tw) / 2, y + (height - th) / 2, text_color, label)

  -- Draw dropdown arrow (▼)
  local arrow_size = 6
  local arrow_x = x + button_width + (arrow_width - arrow_size) / 2
  local arrow_y = y + (height - arrow_size / 2) / 2

  -- Triangle pointing down
  ImGui.DrawList_AddTriangleFilled(dl,
    arrow_x, arrow_y,  -- Top left
    arrow_x + arrow_size, arrow_y,  -- Top right
    arrow_x + arrow_size / 2, arrow_y + arrow_size / 2,  -- Bottom center
    text_color
  )

  -- Handle clicks
  ImGui.SetCursorScreenPos(ctx, x, y)

  -- Button click
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, context.unique_id .. "_button", button_width, height)
  local button_clicked = ImGui.IsItemClicked(ctx, 0)

  -- Arrow click (dropdown)
  ImGui.SetCursorScreenPos(ctx, x + button_width, y)
  ImGui.InvisibleButton(ctx, context.unique_id .. "_arrow", arrow_width, height)
  local arrow_clicked = ImGui.IsItemClicked(ctx, 0)

  -- Tooltips
  if button_hovered and config.tooltip then
    ImGui.SetTooltip(ctx, config.tooltip)
  end

  -- Trigger callbacks
  if button_clicked and config.on_click then
    config.on_click()
  end

  -- Handle dropdown
  if arrow_clicked then
    ImGui.OpenPopup(ctx, context.unique_id .. "_dropdown")
  end

  -- Render dropdown menu
  if config.dropdown_options and ImGui.BeginPopup(ctx, context.unique_id .. "_dropdown") then
    for _, option in ipairs(config.dropdown_options) do
      if option.type == "checkbox" then
        local rv, new_checked = ImGui.Checkbox(ctx, option.label, option.checked or false)
        if rv and option.on_change then
          option.on_change(option.value, new_checked)
        end
      elseif option.type == "item" then
        if ImGui.MenuItem(ctx, option.label) then
          if option.on_click then
            option.on_click(option.value)
          end
        end
      end
    end
    ImGui.EndPopup(ctx)
  end

  return width
end

function M.measure(ctx, config, state)
  return config.width or 100
end

return M
