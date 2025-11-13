-- @noindex
-- ReArkitekt/gui/widgets/panel/config.lua
-- Default configuration for panel with enhanced features

local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- Standard ReArkitekt color palette
local function hexrgb(hex)
  if hex:sub(1, 1) == "#" then hex = hex:sub(2) end
  local h = tonumber(hex, 16)
  if not h then return hexrgb("#FFFFFF") end
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
    bg_color = hexrgb("#00000000"),
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
  
  -- Header configuration
  header = {
    enabled = false,
    height = 30,
    position = "top", -- "top" or "bottom"
    bg_color = hexrgb("#1E1E1EFF"),
    border_color = hexrgb("#00000066"),
    rounding = 8,
    
    -- IMPORTANT: Keep left/right padding at 0 so corner rounding on
    -- first/last buttons is visible. Otherwise rounded corners are hidden.
    padding = {
      left = 0,
      right = 0,
      top = 0,
      bottom = 0,
    },
    
    elements = {},
  },
  
  -- Corner buttons (shown when header is disabled, or if corner_buttons_always_visible = true)
  corner_buttons = nil,
  -- Example:
  -- corner_buttons = {
  --   size = 30,
  --   margin = 8,
  --   bottom_left = {
  --     icon = "⚙",
  --     label = "",
  --     tooltip = "Settings",
  --     on_click = function() ... end,
  --     bg_color = hexrgb("#252525FF"),
  --     bg_hover_color = hexrgb("#2A2A2AFF"),
  --     text_color = hexrgb("#CCCCCCFF"),
  --   },
  --   bottom_right = { ... },
  --   top_left = { ... },
  --   top_right = { ... },
  -- },
  
  corner_buttons_always_visible = false, -- Show corner buttons even with header
}

-- Standard element styling (used by all header elements)
M.ELEMENT_STYLE = {
  button = {
    -- Base button colors for panel context
    -- NOTE: Toggle colors are NOT defined here - use preset_name in your button config
    --       to apply toggle styles (e.g., preset_name = "BUTTON_TOGGLE_TEAL")
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

-- Example: Header with left/right alignment
M.ALIGNED_HEADER_EXAMPLE = {
  header = {
    enabled = true,
    height = 30,
    position = "top",
    bg_color = hexrgb("#1E1E1EFF"),
    border_color = hexrgb("#00000066"),
    rounding = 8,
    
    padding = {
      left = 0,
      right = 0,
    },
    
    elements = {
      -- Left-aligned elements
      {
        id = "title",
        type = "button",
        align = "left",
        spacing_before = 0,
        config = {
          label = "My Panel",
        }
      },
      {
        id = "search",
        type = "search_field",
        align = "left",
        width = 200,
        spacing_before = 8,
        config = {
          placeholder = "Search...",
        }
      },
      
      -- Right-aligned elements
      {
        id = "sort",
        type = "dropdown_field",
        align = "right",
        width = 120,
        spacing_before = 8,
        config = {
          enable_sort = true,
          options = {
            { label = "Name", value = "name" },
            { label = "Date", value = "date" },
          },
        }
      },
      {
        id = "settings",
        type = "button",
        align = "right",
        spacing_before = 8,
        config = {
          label = "⚙",
        }
      },
    },
  },
}

-- Example: Bottom header configuration
M.BOTTOM_HEADER_EXAMPLE = {
  header = {
    enabled = true,
    height = 30,
    position = "bottom", -- Header at bottom
    bg_color = hexrgb("#1E1E1EFF"),
    border_color = hexrgb("#00000066"),
    rounding = 8,
    
    elements = {
      {
        id = "status",
        type = "button",
        config = {
          label = "Status: Ready",
        }
      },
    },
  },
}

-- Example: Tab mode with corner buttons
M.TAB_MODE_WITH_CORNER_BUTTONS = {
  header = {
    enabled = true,
    height = 20,
    bg_color = hexrgb("#2E2E2EFF"),
    border_color = hexrgb("#00000066"),
    rounding = 8,
    
    elements = {
      {
        id = "tabs",
        type = "tab_strip",
        flex = 1,
        config = {
          -- tab strip config
        },
      },
    },
  },
  
  corner_buttons = {
    size = 24,
    margin = 8,
    bottom_left = {
      icon = "+",
      tooltip = "Add item",
      on_click = function() print("Add clicked") end,
    },
  },
  
  corner_buttons_always_visible = true,
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
