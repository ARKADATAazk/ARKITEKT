-- @noindex
-- ReArkitekt/gui/widgets/panel/header/dropdown_field.lua
-- Dropdown wrapper for header layout with streamlined design

local Dropdown = require('rearkitekt.gui.widgets.controls.dropdown')

local M = {}

local DEFAULTS = {
  bg_color = 0x252525FF,
  bg_hover_color = 0x2A2A2AFF,
  bg_active_color = 0x2A2A2AFF,
  border_outer_color = 0x000000DD,
  border_inner_color = 0x404040FF,
  border_hover_color = 0x505050FF,
  border_active_color = 0xB0B0B077,
  text_color = 0xCCCCCCFF,
  text_hover_color = 0xFFFFFFFF,
  text_active_color = 0xFFFFFFFF,
  rounding = 0,
  padding_x = 10,
  padding_y = 6,
  arrow_size = 6,
  arrow_color = 0xCCCCCCFF,
  arrow_hover_color = 0xFFFFFFFF,
  enable_mousewheel = true,
}

function M.draw(ctx, dl, x, y, width, height, config, state)
  for k, v in pairs(DEFAULTS) do
    if config[k] == nil then config[k] = v end
  end
  
  local element_id = state.id or "dropdown"
  
  local dropdown_id = string.format("%s_%s", tostring(state._panel_id or "unknown"), element_id)
  
  if not state.dropdown_instance then
    state.dropdown_instance = Dropdown.new({
      id = dropdown_id,
      tooltip = config.tooltip,
      tooltip_delay = config.tooltip_delay,
      options = config.options or {},
      current_value = state.dropdown_value or (config.options and config.options[1] and config.options[1].value),
      sort_direction = state.dropdown_direction or "asc",
      on_change = function(value)
        state.dropdown_value = value
        if config.on_change then
          config.on_change(value)
        end
      end,
      on_direction_change = function(direction)
        state.dropdown_direction = direction
        if config.on_direction_change then
          config.on_direction_change(direction)
        end
      end,
      config = {
        width = width,
        height = height,
        tooltip_delay = config.tooltip_delay,
        bg_color = config.bg_color,
        bg_hover_color = config.bg_hover_color,
        bg_active_color = config.bg_active_color,
        border_outer_color = config.border_outer_color,
        border_inner_color = config.border_inner_color,
        border_hover_color = config.border_hover_color,
        border_active_color = config.border_active_color,
        text_color = config.text_color,
        text_hover_color = config.text_hover_color,
        text_active_color = config.text_active_color,
        rounding = config.rounding,
        padding_x = config.padding_x,
        padding_y = config.padding_y,
        arrow_size = config.arrow_size,
        arrow_color = config.arrow_color,
        arrow_hover_color = config.arrow_hover_color,
        enable_mousewheel = config.enable_mousewheel,
        popup = config.popup or {},
      },
    })
  else
    if state.dropdown_value and state.dropdown_instance.current_value ~= state.dropdown_value then
      state.dropdown_instance:set_value(state.dropdown_value)
    end
    
    if state.dropdown_direction and state.dropdown_instance.sort_direction ~= state.dropdown_direction then
      state.dropdown_instance:set_direction(state.dropdown_direction)
    end
  end
  
  state.dropdown_instance:draw(ctx, x, y, config.corner_rounding)
  
  return width
end

function M.measure(ctx, config)
  return config.width or 120
end

return M