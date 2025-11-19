-- @noindex
-- ReArkitekt/gui/widgets/overlay/config.lua
-- Configuration for modal overlay and sheet appearance

local Colors = require('rearkitekt.core.colors')
local ConfigUtil = require('rearkitekt.core.config')

local M = {}
local hexrgb = Colors.hexrgb

local default_config = {
  scrim = {
    color = hexrgb("#161616"),
    opacity = 0.99,
  },
  
  sheet = {
    background = {
      color = hexrgb("#161616"),
      opacity = 0.99,
    },
    
    shadow = {
      enabled = true,
      layers = 4,
      max_offset = 12,
      base_alpha = 20,
    },
    
    border = {
      outer_color = hexrgb("#404040"),
      outer_opacity = 0.7,
      outer_thickness = 1.5,
      inner_color = hexrgb("#FFFFFF"),
      inner_opacity = 0.10,
      inner_thickness = 1.0,
    },
    
    gradient = {
      top_enabled = true,
      top_color = hexrgb("#FFFFFF"),
      top_height = 80,
      top_max_alpha = 0.06,
      
      bottom_enabled = true,
      bottom_color = hexrgb("#000000"),
      bottom_height = 60,
      bottom_max_alpha = 0.08,
    },
    
    header = {
      height = 42,
      text_color = hexrgb("#FFFFFF"),
      text_opacity = 1.0,
      
      divider_color = hexrgb("#666666"),
      divider_opacity = 0.31,
      divider_thickness = 1.0,
      divider_fade_width = 60,
      
      highlight_color = hexrgb("#FFFFFF"),
      highlight_opacity = 0.06,
      highlight_thickness = 1.0,
    },
    
    rounding = 12,
  },
}

local current_config = nil

function M.get()
  if not current_config then
    -- Deep copy default config on first access
    current_config = ConfigUtil.deep_merge({}, default_config)
  end
  return current_config
end

function M.override(overrides)
  local config = M.get()

  if not overrides then
    return ConfigUtil.deep_merge({}, config)  -- Return deep copy
  end

  -- Deep merge config with overrides
  return ConfigUtil.deep_merge(config, overrides)
end

function M.reset()
  current_config = nil
end

return M