-- @noindex
-- Arkitekt/gui/widgets/nodal/config.lua
-- Visual configuration for node system (unified with panel background system)

local Colors = require('arkitekt.core.colors')
local ConfigUtil = require('arkitekt.core.config')

local M = {}
local hexrgb = Colors.hexrgb

M.DEFAULT = {
  node = {
    width = 280,
    min_height = 80,
    header_height = 28,
    rounding = 8,
    padding = 10,
    spacing = 20,
    body_line_height = 18,
    body_padding_top = 6,
    body_padding_bottom = 6,
    trigger_section_padding_top = 8,
  },
  
  trigger_ui = {
    section_label_height = 20,
    item_height = 22,
    item_spacing = 6,
    indent = 10,
    dropdown_width_offset = 20,
    label_width = 50,
    mode_width = 120,
    delete_button_size = 16,
    add_button_height = 24,
    add_button_text = "+ Add Trigger",
  },
  
  port = {
    size = 8,
    offset = 12,
    hitbox_extend = 2.0,
    label_offset = 16,
    sequential_offset_y = 0,
    trigger_start_y = 35,
    trigger_spacing = 20,
  },
  
  connection = {
    thickness = 3,
    control_distance_factor = 0.5,
    dash_length = 8,
    dash_gap = 6,
    animation_speed = 20,
    animation_dot_size = 6,
    hover_thickness_mult = 1.5,
    label_bg_padding = 6,
    label_bg_rounding = 4,
    manhattan_horizontal_offset = 40,
    manhattan_lane_spacing = 30,
    manhattan_approach_offset = 20,
  },
  
  badge = {
    rounding = 4,
    padding_x = 6,
    padding_y = 3,
    margin = 6,
    bg = hexrgb("#14181C"),
    border_alpha = 0x33,
    font_scale = 0.88,
  },
  
  colors = {
    mirror_modes = {
      linked = hexrgb("#41E0A3"),
      detached = hexrgb("#4A9EFF"),
      frozen = hexrgb("#FF9500"),
    },
    
    connection_types = {
      sequential = hexrgb("#88CEFF"),
      trigger = hexrgb("#FF6B9D"),
    },
    
    text = {
      header = hexrgb("#FFFFFF"),
      body = hexrgb("#AAAAAA"),
      port_label = hexrgb("#DDDDDD"),
      trigger_section = hexrgb("#FFFFFF"),
    },
    
    bg_base = hexrgb("#1A1A1A"),
    chip_bg = hexrgb("#1A1A1A"),
    port_glow = hexrgb("#FFFFFF88"),
    connection_label_bg = hexrgb("#1A1A1AEE"),
  },
  
  tile_fx = {
    fill_opacity = 0.35,
    fill_saturation = 0.4,
    fill_brightness = 0.5,
    border_opacity = 1.0,
    border_saturation = 1.0,
    border_brightness = 1.6,
    border_thickness = 1.0,
    gradient_intensity = 0.16,
    gradient_opacity = 0.03,
    specular_strength = 0.06,
    specular_coverage = 0.25,
    inner_shadow_strength = 0.20,
    glow_strength = 0.4,
    glow_layers = 3,
    hover_fill_boost = 0.06,
    hover_specular_boost = 0.5,
    ants_enabled = true,
    ants_replace_border = true,
    ants_thickness = 1,
    ants_dash = 8,
    ants_gap = 6,
    ants_speed = 20,
    ants_alpha = hexrgb("#000000FF"),
  },
  
  background_pattern = {
    enabled = true,
    primary = {
      type = 'grid',
      spacing = 50,
      color = hexrgb("#14141490"),
      line_thickness = 1.5,
    },
    secondary = {
      enabled = true,
      type = 'grid',
      spacing = 5,
      color = hexrgb("#14141420"),
      line_thickness = 0.5,
    },
  },
}

function M.get()
  return M.DEFAULT
end

function M.override(overrides)
  if not overrides then
    return ConfigUtil.deepMerge({}, M.DEFAULT)  -- Return deep copy
  end

  -- Deep merge DEFAULT with overrides
  return ConfigUtil.deepMerge(M.DEFAULT, overrides)
end

return M