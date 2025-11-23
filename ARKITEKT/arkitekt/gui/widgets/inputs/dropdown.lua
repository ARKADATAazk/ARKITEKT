-- @noindex
-- Arkitekt/gui/widgets/controls/dropdown.lua
-- Standalone dropdown/combobox widget with Arkitekt styling
-- Can be used anywhere, with optional panel integration

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Style = require('arkitekt.gui.style.defaults')
local Tooltip = require('arkitekt.gui.widgets.overlays.tooltip')
local ContextMenu = require('arkitekt.gui.widgets.overlays.context_menu')

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
    footer_interacting = false,  -- Track if user is interacting with footer
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

  -- If button_label is configured, use it when current_value is nil
  -- This allows the button to show a label without it appearing in the dropdown menu
  if not self.current_value then
    if self.config.button_label then
      return self.config.button_label
    end
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
  if cfg.enable_sort and self.current_value ~= nil then
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
  
  -- Right-click to toggle sort direction (only when enabled)
  if cfg.enable_sort and right_clicked and self.current_value then
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
  
  -- Draw popup (using context_menu for consistent shadow/styling)
  local popup_changed = false
  local popup_cfg = cfg.popup

  -- Use ContextMenu.begin for popup with shadow effect
  if ContextMenu.begin(ctx, self.id .. "_popup", {
    bg_color = popup_cfg.bg_color,
    border_color = popup_cfg.border_color,
    rounding = popup_cfg.rounding,
    padding = popup_cfg.padding,
    border_thickness = popup_cfg.border_thickness,
    min_width = math.max(width * 1.5, 180),
  }) then
    local popup_dl = ImGui.GetWindowDrawList(ctx)
    self.popup_hover_index = -1
    self.footer_interacting = false

    -- Calculate popup width (increased for better appearance)
    local max_text_width = 0
    local options = cfg.options or {}
    for _, opt in ipairs(options) do
      local label = type(opt) == "table" and opt.label or tostring(opt)
      local text_w, _ = ImGui.CalcTextSize(ctx, label)
      max_text_width = math.max(max_text_width, text_w)
    end

    -- Use larger popup width: 1.5x button width or text-based, whichever is larger
    local min_popup_width = math.max(width * 1.5, 180)
    local popup_width = math.max(min_popup_width, max_text_width + popup_cfg.item_padding_x * 2 + 40)
    
    -- Draw items
    for i, opt in ipairs(options) do
      local value = type(opt) == "table" and opt.value or opt
      local label = type(opt) == "table" and opt.label or tostring(opt)
      local is_checkbox = type(opt) == "table" and opt.checkbox or false
      local is_checked = type(opt) == "table" and opt.checked or false

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

      -- Draw checkbox if enabled
      local text_x = item_x + popup_cfg.item_padding_x
      if is_checkbox then
        local checkbox_size = 14
        local checkbox_x = text_x
        local checkbox_y = item_y + (item_h - checkbox_size) * 0.5

        -- Checkbox background
        local checkbox_bg = is_checked and popup_cfg.item_selected_color or popup_cfg.item_bg_color
        ImGui.DrawList_AddRectFilled(popup_dl, checkbox_x, checkbox_y, checkbox_x + checkbox_size, checkbox_y + checkbox_size, checkbox_bg, 2)

        -- Checkbox border (no corner flags - use default rounding)
        ImGui.DrawList_AddRect(popup_dl, checkbox_x, checkbox_y, checkbox_x + checkbox_size, checkbox_y + checkbox_size, item_text, 2)

        -- Checkmark if checked
        if is_checked then
          local padding = 3
          ImGui.DrawList_AddLine(popup_dl,
            checkbox_x + padding, checkbox_y + checkbox_size * 0.5,
            checkbox_x + checkbox_size * 0.4, checkbox_y + checkbox_size - padding,
            item_text, 2)
          ImGui.DrawList_AddLine(popup_dl,
            checkbox_x + checkbox_size * 0.4, checkbox_y + checkbox_size - padding,
            checkbox_x + checkbox_size - padding, checkbox_y + padding,
            item_text, 2)
        end

        text_x = text_x + checkbox_size + 8
      end

      local text_w, text_h = ImGui.CalcTextSize(ctx, label)
      local text_y = item_y + (item_h - text_h) * 0.5

      ImGui.DrawList_AddText(popup_dl, text_x, text_y, item_text, label)

      ImGui.InvisibleButton(ctx, self.id .. "_item_" .. i, item_w, item_h)

      if ImGui.IsItemClicked(ctx, 0) then
        if is_checkbox then
          -- For checkbox items, toggle the checked state and call on_checkbox_change
          if cfg.on_checkbox_change then
            cfg.on_checkbox_change(value, not is_checked)
          end
          popup_changed = true
          -- Don't close popup for checkboxes
        else
          -- For regular items, set current value and close popup
          self.current_value = value
          if cfg.on_change then
            cfg.on_change(value)
          end
          -- If sorting is enabled but the selected option is 'No Sort', reset direction to asc
          if cfg.enable_sort and value == nil then
            self.sort_direction = "asc"
            if cfg.on_direction_change then
              cfg.on_direction_change(self.sort_direction)
            end
          end
          popup_changed = true
          ImGui.CloseCurrentPopup(ctx)
          self.is_open = false
        end
      end

      if is_selected and not is_checkbox then
        ImGui.SetItemDefaultFocus(ctx)
      end
    end
    
    -- >>> FOOTER CONTENT (BEGIN)
    -- Render optional footer content (e.g., sliders, buttons)
    if cfg.footer_content then
      -- Add separator before footer
      local sep_x, sep_y = ImGui.GetCursorScreenPos(ctx)
      ImGui.Dummy(ctx, popup_width, 6)
      local sep_y2 = sep_y + 3
      -- Enhanced separator with subtle glow effect
      ImGui.DrawList_AddLine(popup_dl, sep_x + 8, sep_y2, sep_x + popup_width - 8, sep_y2, cfg.popup.border_color, 1)
      
      -- Track footer region for interaction detection
      local footer_start_y = sep_y + 4
      
      -- Call user-provided footer rendering function
      local footer_ctx = {
        ctx = ctx,
        dl = popup_dl,
        width = popup_width,
        padding = popup_cfg.item_padding_x,
      }
      cfg.footer_content(footer_ctx)
      
      -- Check if mouse is in footer region (prevent close on footer interaction)
      local footer_end_y = ImGui.GetCursorScreenPos(ctx)
      local mx, my = ImGui.GetMousePos(ctx)
      if my >= footer_start_y and my <= footer_end_y then
        self.footer_interacting = true
      end
    end
    -- <<< FOOTER CONTENT (END)

    ContextMenu.end_menu(ctx)
  else
    self.is_open = false
  end
  
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

    -- Prefer config.current_value over panel state (allows explicit control)
    if config.current_value ~= nil then
      initial_value = config.current_value
    end

    instance = Dropdown.new(context.unique_id, config, initial_value, initial_direction)
    instances[context.unique_id] = instance
  else
    -- Update config
    instance.config = config

    -- If config provides a current_value, update the instance
    -- This allows external state to control the dropdown value
    if config.current_value ~= nil then
      instance.current_value = config.current_value
    end

    -- Don't auto-sync from panel state on every frame
    -- The instance is the source of truth during interaction
    -- Sync happens via sync_to_state after draw
  end
  
  -- Defensive: if current_value is accidentally a table, extract the actual value
  if type(instance.current_value) == "table" then
    instance.current_value = instance.current_value.value
  end
  
  -- Defensive: if current_value is nil ("No Sort"), always force direction to asc
  if instance.current_value == nil then
    if instance.sort_direction ~= "asc" then
      instance.sort_direction = "asc"
      -- Trigger callback to update app state
      if config.on_direction_change then
        config.on_direction_change("asc")
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
  
  -- Return width first (for layout), then changed status
  return width, changed
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
