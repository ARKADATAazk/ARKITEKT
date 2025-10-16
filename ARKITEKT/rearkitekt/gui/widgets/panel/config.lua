-- @noindex
-- ReArkitekt/gui/widgets/panel/config.lua
-- Default configuration for panel with integrated header design
-- Updated with standard ReArkitekt styling as defaults

local M = {}

-- Standard ReArkitekt color palette
local function hexrgb(hex)
  if hex:sub(1, 1) == "#" then hex = hex:sub(2) end
  local h = tonumber(hex, 16)
  if not h then return 0xFFFFFFFF end
  return (#hex == 8) and h or ((h << 8) | 0xFF)
end

M.DEFAULTS = {
  bg_color = hexrgb("#1A1A1AFF"),
  border_color = hexrgb("#000000DD"),
  border_thickness = 1,
  rounding = 8,
  padding = 8,
  
  disable_window_drag = true,
  
  scroll = {
    flags = 0,
    custom_scrollbar = false,
    bg_color = 0x00000000,
  },
  
  anti_jitter = {
    enabled = true,
    track_scrollbar = true,
    height_threshold = 5,
  },
  
  background_pattern = {
    enabled = true,
    primary = {
      type = 'grid',
      spacing = 50,
      color = hexrgb("#14141490"),
      dot_size = 2.5,
      line_thickness = 1.5,
    },
    secondary = {
      enabled = true,
      type = 'grid',
      spacing = 5,
      color = hexrgb("#14141420"),
      dot_size = 1.5,
      line_thickness = 0.5,
    },
  },
  
  header = {
    enabled = false,
    height = 30,
    bg_color = hexrgb("#2E2E2EFF"),
    border_color = hexrgb("#00000066"),
    rounding = 8,
    
    padding = {
      left = 0,
      right = 0,
      top = 0,
      bottom = 0,
    },
    
    elements = {},
  },
}

-- Standard element styling (used by all header elements)
M.ELEMENT_STYLE = {
  button = {
    bg_color = hexrgb("#252525FF"),
    bg_hover_color = hexrgb("#2A2A2AFF"),
    bg_active_color = hexrgb("#202020FF"),
    border_outer_color = hexrgb("#000000DD"),
    border_inner_color = hexrgb("#404040FF"),
    border_hover_color = hexrgb("#505050FF"),
    text_color = hexrgb("#CCCCCCFF"),
    text_hover_color = hexrgb("#FFFFFFFF"),
    text_active_color = hexrgb("#FFFFFFFF"),
  },
  
  dropdown = {
    bg_color = hexrgb("#252525FF"),
    bg_hover_color = hexrgb("#2A2A2AFF"),
    bg_active_color = hexrgb("#2A2A2AFF"),
    border_outer_color = hexrgb("#000000DD"),
    border_inner_color = hexrgb("#404040FF"),
    border_hover_color = hexrgb("#505050FF"),
    border_active_color = hexrgb("#B0B0B077"),
    text_color = hexrgb("#CCCCCCFF"),
    text_hover_color = hexrgb("#FFFFFFFF"),
    text_active_color = hexrgb("#FFFFFFFF"),
    rounding = 0,
    padding_x = 10,
    padding_y = 6,
    arrow_size = 6,
    arrow_color = hexrgb("#CCCCCCFF"),
    arrow_hover_color = hexrgb("#FFFFFFFF"),
    enable_mousewheel = true,
  },
  
  search = {
    placeholder = "Search...",
    fade_speed = 8.0,
    bg_color = hexrgb("#252525FF"),
    bg_hover_color = hexrgb("#2A2A2AFF"),
    bg_active_color = hexrgb("#2A2A2AFF"),
    border_outer_color = hexrgb("#000000DD"),
    border_inner_color = hexrgb("#404040FF"),
    border_hover_color = hexrgb("#505050FF"),
    border_active_color = hexrgb("#B0B0B077"),
    text_color = hexrgb("#CCCCCCFF"),
  },
  
  separator = {
    show_line = false,
  },
}

M.TAB_MODE_DEFAULTS = {
  header = {
    enabled = true,
    height = 20,
    bg_color = hexrgb("#2E2E2EFF"),
    border_color = hexrgb("#00000066"),
    rounding = 8,
    
    padding = {
      left = 0,
      right = 0,
      top = 0,
      bottom = 0,
    },
    
    elements = {
      {
        id = "tabs",
        type = "tab_strip",
        flex = 1,
        spacing_before = 0,
        config = {
          spacing = 0,
          min_width = 60,
          max_width = 180,
          padding_x = 5,
          
          border_outer_color = hexrgb("#000000DD"),
          border_inner_color = hexrgb("#404040FF"),
          border_hover_color = hexrgb("#505050FF"),
          border_active_color = hexrgb("#7B7B7BFF"),
          
          bg_color = hexrgb("#252525FF"),
          bg_hover_color = hexrgb("#2A2A2AFF"),
          bg_active_color = hexrgb("#303030FF"),
          
          text_color = hexrgb("#AAAAAAFF"),
          text_hover_color = hexrgb("#FFFFFFFF"),
          text_active_color = hexrgb("#FFFFFFFF"),
          
          chip_radius = 4,
          
          plus_button = {
            width = 23,
            border_outer_color = hexrgb("#000000DD"),
            border_inner_color = hexrgb("#404040FF"),
            border_hover_color = hexrgb("#505050FF"),
            bg_color = hexrgb("#252525FF"),
            bg_hover_color = hexrgb("#2A2A2AFF"),
            bg_active_color = hexrgb("#2A2A2AFF"),
            text_color = hexrgb("#AAAAAAFF"),
            text_hover_color = hexrgb("#FFFFFFFF"),
            text_active_color = hexrgb("#FFFFFFFF"),
          },
          
          overflow_button = {
            min_width = 21,
            padding_x = 8,
            border_outer_color = hexrgb("#000000DD"),
            border_inner_color = hexrgb("#404040FF"),
            border_hover_color = hexrgb("#505050FF"),
            bg_color = hexrgb("#252525FF"),
            bg_hover_color = hexrgb("#2A2A2AFF"),
            bg_active_color = hexrgb("#2A2A2AFF"),
            text_color = hexrgb("#707070FF"),
            text_hover_color = hexrgb("#CCCCCCFF"),
            text_active_color = hexrgb("#FFFFFFFF"),
          },
          
          track = {
            enabled = false,
          },
          
          context_menu = {
            bg_color = hexrgb("#1E1E1EFF"),
            hover_color = hexrgb("#2E2E2EFF"),
            text_color = hexrgb("#CCCCCCFF"),
            separator_color = hexrgb("#404040FF"),
            padding = 8,
            item_height = 24,
          },
          
          on_tab_create = nil,
          on_tab_change = nil,
          on_tab_delete = nil,
          on_tab_reorder = nil,
          on_overflow_clicked = nil,
        },
      },
    },
  },
}

-- Helper to apply default element styling
function M.apply_element_defaults(element_type, config)
  local defaults = M.ELEMENT_STYLE[element_type]
  if not defaults then return config end
  
  config = config or {}
  for k, v in pairs(defaults) do
    if config[k] == nil then
      config[k] = v
    end
  end
  
  return config
end

return M