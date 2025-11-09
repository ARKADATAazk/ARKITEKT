-- @noindex
-- ReArkitekt/gui/widgets/controls/dropdown.lua
-- Standalone dropdown/combobox widget with ReArkitekt styling
-- Can be used anywhere, with optional panel integration

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('rearkitekt.gui.widgets.controls.style_defaults')
local Tooltip = require('rearkitekt.gui.widgets.controls.tooltip')

local M = {}

-- Instance storage (internal to component)
local instances = {}

-- ============================================================================
-- CONTEXT DETECTION
-- ============================================================================

local function resolve_context(config, state_or_id)
  local context = {
    unique_id = nil,
    corner_rounding = nil,
    is_panel_context = false,
  }
  
  -- Check if we're in a panel context
  if type(state_or_id) == "table" and state_or_id._panel_id then
    context.is_panel_context = true
    context.unique_id = string.format("%s_%s", state_or_id._panel_id, config.id or "dropdown")
    context.corner_rounding = config.corner_rounding
  else
    -- Standalone context
    context.unique_id = type(state_or_id) == "string" and state_or_id or (config.id or "dropdown")
    context.corner_rounding = nil
  end
  
  return context
end

-- ============================================================================
-- INSTANCE MANAGEMENT
-- ============================================================================

local Dropdown = {}
Dropdown.__index = Dropdown

function Dropdown.new(id, config, initial_value, initial_direction)
  local instance = setmetatable({
    id = id,
    config = config,
    current_value = initial_value,
    sort_direction = initial_direction or "asc",
    hover_alpha = 0,
    is_open = false,
    popup_hover_index = -1,
  }, Dropdown)
  
  return instance
end

function Dropdown:get_current_index()
  if not self.current_value then return 1 end
  
  local options = self.config.options or {}
  for i, opt in ipairs(options) do
    local value = type(opt) == "table" and opt.value or opt
    if value == self.current_value then
      return i
    end
  end
  
  return 1
end

function Dropdown:get_display_text()
  local options = self.config.options or {}
  
  if not self.current_value then
    return options[1] and (type(options[1]) == "table" and options[1].label or tostring(options[1])) or ""
  end
  
  for _, opt in ipairs(options) do
    local value = type(opt) == "table" and opt.value or opt
    local label = type(opt) == "table" and opt.label or tostring(opt)
    if value == self.current_value then
      return label
    end
  end
  
  return ""
end

function Dropdown:handle_mousewheel(ctx, is_hovered)
  if not self.config.enable_mousewheel or not is_hovered then return false end
  
  local wheel = ImGui.GetMouseWheel(ctx)
  if wheel == 0 then return false end
  
  local current_idx = self:get_current_index()
  local new_idx = current_idx
  local options = self.config.options or {}
  
  if wheel > 0 then
    new_idx = math.max(1, current_idx - 1)
  else
    new_idx = math.min(#options, current_idx + 1)
  end
  
  if new_idx ~= current_idx then
    local new_opt = options[new_idx]
    local new_value = type(new_opt) == "table" and new_opt.value or new_opt
    self.current_value = new_value
    
    if self.config.on_change then
      self.config.on_change(new_value)
    end
    
    return true
  end
  
  return false
end

function Dropdown:draw(ctx, dl, x, y, width, height, corner_rounding)
  local cfg = self.config
  
  local x1, y1 = x, y
  local x2, y2 = x + width, y + height
  
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x1 and mx < x2 and my >= y1 and my < y2
  
  -- Animate hover alpha
  local target_alpha = (is_hovered or self.is_open) and 1.0 or 0.0
  local alpha_speed = 12.0
  local dt = ImGui.GetDeltaTime(ctx)
  self.hover_alpha = self.hover_alpha + (target_alpha - self.hover_alpha) * alpha_speed * dt
  self.hover_alpha = math.max(0, math.min(1, self.hover_alpha))
  
  -- Get state colors
  local bg_color = cfg.bg_color
  local text_color = cfg.text_color
  local border_inner = cfg.border_inner_color
  local arrow_color = cfg.arrow_color
  
  if self.is_open then
    bg_color = cfg.bg_active_color
    text_color = cfg.text_active_color
    border_inner = cfg.border_active_color
    arrow_color = cfg.arrow_hover_color
  elseif self.hover_alpha > 0.01 then
    bg_color = Style.RENDER.lerp_color(cfg.bg_color, cfg.bg_hover_color, self.hover_alpha)
    text_color = Style.RENDER.lerp_color(cfg.text_color, cfg.text_hover_color, self.hover_alpha)
    border_inner = Style.RENDER.lerp_color(cfg.border_inner_color, cfg.border_hover_color, self.hover_alpha)
    arrow_color = Style.RENDER.lerp_color(cfg.arrow_color, cfg.arrow_hover_color, self.hover_alpha)
  end
  
  -- Calculate rounding
  local rounding = corner_rounding and corner_rounding.rounding or cfg.rounding
  local corner_flags = Style.RENDER.get_corner_flags(corner_rounding)
  
  -- Draw background and borders
  Style.RENDER.draw_control_background(dl, x1, y1, width, height, bg_color, border_inner, cfg.border_outer_color, rounding, corner_flags)
  
  -- Draw text
  local display_text = self:get_display_text()
  local dir_indicator = ""
  if self.current_value ~= nil then
    dir_indicator = (self.sort_direction == "asc") and "↑ " or "↓ "
  end
  
  local full_text = dir_indicator .. display_text
  local text_w, text_h = ImGui.CalcTextSize(ctx, full_text)
  local text_x = x1 + cfg.padding_x
  local text_y = y1 + (height - text_h) * 0.5
  
  ImGui.DrawList_AddText(dl, text_x, text_y, text_color, full_text)
  
  -- Draw arrow
  local arrow_x = x2 - cfg.padding_x - cfg.arrow_size
  local arrow_y = y1 + height * 0.5
  local arrow_half = cfg.arrow_size
  
  ImGui.DrawList_AddTriangleFilled(dl,
    arrow_x - arrow_half, arrow_y - arrow_half * 0.5,
    arrow_x + arrow_half, arrow_y - arrow_half * 0.5,
    arrow_x, arrow_y + arrow_half * 0.7,
    arrow_color)
  
  -- Interaction
  ImGui.SetCursorScreenPos(ctx, x1, y1)
  ImGui.InvisibleButton(ctx, self.id .. "_btn", width, height)
  
  local clicked = ImGui.IsItemClicked(ctx, 0)
  local right_clicked = ImGui.IsItemClicked(ctx, 1)
  local wheel_changed = self:handle_mousewheel(ctx, is_hovered)
  
  -- Right-click to toggle sort direction
  if right_clicked and self.current_value then
    self.sort_direction = (self.sort_direction == "asc") and "desc" or "asc"
    if cfg.on_direction_change then
      cfg.on_direction_change(self.sort_direction)
    end
  end
  
  -- Tooltip
  if is_hovered and cfg.tooltip then
    Tooltip.show_delayed(ctx, cfg.tooltip, {
      delay = cfg.tooltip_delay or Style.TOOLTIP.delay
    })
  else
    if not is_hovered then
      Tooltip.reset()
    end
  end
  
  -- Open popup
  if clicked then
    ImGui.OpenPopup(ctx, self.id .. "_popup")
    self.is_open = true
  end
  
  -- Draw popup
  local popup_changed = false
  local popup_cfg = cfg.popup
  
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, popup_cfg.padding, popup_cfg.padding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, popup_cfg.rounding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding, popup_cfg.rounding)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, popup_cfg.border_thickness)
  
  ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, popup_cfg.bg_color)
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, popup_cfg.border_color)
  
  if ImGui.BeginPopup(ctx, self.id .. "_popup") then
    local popup_dl = ImGui.GetWindowDrawList(ctx)
    self.popup_hover_index = -1
    
    -- Calculate popup width
    local max_text_width = 0
    local options = cfg.options or {}
    for _, opt in ipairs(options) do
      local label = type(opt) == "table" and opt.label or tostring(opt)
      local text_w, _ = ImGui.CalcTextSize(ctx, label)
      max_text_width = math.max(max_text_width, text_w)
    end
    
    local popup_width = math.max(width, max_text_width + popup_cfg.item_padding_x * 2 + 20)
    
    -- Draw items
    for i, opt in ipairs(options) do
      local value = type(opt) == "table" and opt.value or opt
      local label = type(opt) == "table" and opt.label or tostring(opt)
      
      local is_selected = value == self.current_value
      
      local item_x, item_y = ImGui.GetCursorScreenPos(ctx)
      local item_w = popup_width
      local item_h = popup_cfg.item_height
      
      local item_hovered = ImGui.IsMouseHoveringRect(ctx, item_x, item_y, item_x + item_w, item_y + item_h)
      if item_hovered then
        self.popup_hover_index = i
      end
      
      local item_bg = popup_cfg.item_bg_color
      local item_text = popup_cfg.item_text_color
      
      if is_selected then
        item_bg = popup_cfg.item_selected_color
        item_text = popup_cfg.item_selected_text_color
      end
      
      if item_hovered then
        item_bg = is_selected and popup_cfg.item_active_color or popup_cfg.item_hover_color
        item_text = popup_cfg.item_text_hover_color
      end
      
      ImGui.DrawList_AddRectFilled(popup_dl, item_x, item_y, item_x + item_w, item_y + item_h, item_bg, 2)
      
      local text_w, text_h = ImGui.CalcTextSize(ctx, label)
      local text_x = item_x + popup_cfg.item_padding_x
      local text_y = item_y + (item_h - text_h) * 0.5
      
      ImGui.DrawList_AddText(popup_dl, text_x, text_y, item_text, label)
      
      ImGui.InvisibleButton(ctx, self.id .. "_item_" .. i, item_w, item_h)
      
      if ImGui.IsItemClicked(ctx, 0) then
        self.current_value = value
        if cfg.on_change then
          cfg.on_change(value)
        end
        popup_changed = true
        ImGui.CloseCurrentPopup(ctx)
        self.is_open = false
      end
      
      if is_selected then
        ImGui.SetItemDefaultFocus(ctx)
      end
    end
    
    ImGui.EndPopup(ctx)
  else
    self.is_open = false
  end
  
  ImGui.PopStyleColor(ctx, 2)
  ImGui.PopStyleVar(ctx, 4)
  
  return clicked or wheel_changed or popup_changed or right_clicked
end

-- ============================================================================
-- INSTANCE MANAGEMENT
-- ============================================================================

local function get_or_create_instance(context, config, state_or_id)
  local instance = instances[context.unique_id]
  
  if not instance then
    -- Get initial values from state (if panel context)
    local initial_value = nil
    local initial_direction = "asc"
    
    if context.is_panel_context then
      initial_value = state_or_id.dropdown_value
      initial_direction = state_or_id.dropdown_direction or "asc"
    end
    
    instance = Dropdown.new(context.unique_id, config, initial_value, initial_direction)
    instances[context.unique_id] = instance
  else
    -- Update config
    instance.config = config
    
    -- Sync with panel state if needed
    if context.is_panel_context then
      if state_or_id.dropdown_value and state_or_id.dropdown_value ~= instance.current_value then
        instance.current_value = state_or_id.dropdown_value
      end
      if state_or_id.dropdown_direction and state_or_id.dropdown_direction ~= instance.sort_direction then
        instance.sort_direction = state_or_id.dropdown_direction
      end
    end
  end
  
  return instance
end

local function sync_to_state(instance, state_or_id, context)
  if context.is_panel_context then
    state_or_id.dropdown_value = instance.current_value
    state_or_id.dropdown_direction = instance.sort_direction
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function M.draw(ctx, dl, x, y, width, height, user_config, state_or_id)
  -- Apply style defaults
  local config = Style.apply_defaults(Style.DROPDOWN, user_config)
  
  -- Resolve context (panel vs standalone)
  local context = resolve_context(config, state_or_id)
  
  -- Get or create instance
  local instance = get_or_create_instance(context, config, state_or_id)
  
  -- Draw dropdown
  local changed = instance:draw(ctx, dl, x, y, width, height, context.corner_rounding)
  
  -- Sync state back
  sync_to_state(instance, state_or_id, context)
  
  return changed
end

function M.measure(ctx, user_config)
  local config = Style.apply_defaults(Style.DROPDOWN, user_config)
  return config.width or 120
end

-- ============================================================================
-- STATE ACCESSORS (for standalone use)
-- ============================================================================

function M.get_value(id)
  local instance = instances[id]
  return instance and instance.current_value or nil
end

function M.set_value(id, value)
  local instance = instances[id]
  if instance then
    instance.current_value = value
  end
end

function M.get_direction(id)
  local instance = instances[id]
  return instance and instance.sort_direction or "asc"
end

function M.set_direction(id, direction)
  local instance = instances[id]
  if instance then
    instance.sort_direction = direction
  end
end

return M
