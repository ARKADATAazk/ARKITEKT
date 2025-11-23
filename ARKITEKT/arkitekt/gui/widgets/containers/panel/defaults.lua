-- @noindex
-- Arkitekt/gui/widgets/panel/config.lua
-- Default configuration for panel with enhanced features

local Style = require('arkitekt.gui.style.defaults')
local C = Style.COLORS          -- Shared primitives
local PC = Style.PANEL_COLORS   -- Panel-specific colors

local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local Config = require('arkitekt.core.config')

local M = {}

M.DEFAULTS = {
  bg_color = PC.bg_panel,
  border_color = PC.border_panel,
  border_thickness = 1,
  rounding = 8,
  padding = 8,

  disable_window_drag = true,

  scroll = {
    flags = 0,
    custom_scrollbar = false,
    bg_color = PC.bg_scrollbar,
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
      color = PC.pattern_primary,
      dot_size = 2.5,
      line_thickness = 1.5,
    },
    secondary = {
      enabled = true,
      type = 'grid',
      spacing = 5,
      color = PC.pattern_secondary,
      dot_size = 1.5,
      line_thickness = 0.5,
    },
  },

  -- Header configuration
  header = {
    enabled = false,
    height = 30,
    position = "top", -- "top" or "bottom"
    bg_color = PC.bg_header,
    border_color = PC.border_header,
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
  --   min_width_to_show = 150, -- Hide corner buttons if panel width < this value (responsive behavior)
  --   bottom_left = {
  --     icon = "⚙",
  --     label = "",
  --     tooltip = "Settings",
  --     on_click = function() ... end,
  --     bg_color = C.BG_BASE,
  --     bg_hover_color = C.BG_HOVER,
  --     text_color = C.TEXT_NORMAL,
  --   },
  --   bottom_right = { ... },
  --   top_left = { ... },
  --   top_right = { ... },
  -- },

  corner_buttons_always_visible = false, -- Show corner buttons even with header

  -- Sidebar configuration (vertical button bars on left/right sides)
  left_sidebar = {
    enabled = false,
    width = 36,
    bg_color = PC.bg_header,
    border_color = PC.border_header,
    valign = "center",  -- "top", "center", "bottom"
    padding = {
      top = 4,
      bottom = 4,
    },
    button_size = 28,
    button_spacing = 4,
    elements = {},  -- Array of button configs
  },

  right_sidebar = {
    enabled = false,
    width = 36,
    bg_color = PC.bg_header,
    border_color = PC.border_header,
    valign = "center",
    padding = {
      top = 4,
      bottom = 4,
    },
    button_size = 28,
    button_spacing = 4,
    elements = {},
  },
}

-- Standard element styling (used by all header elements)
M.ELEMENT_STYLE = {
  button = {
    -- Base button colors for panel context
    -- NOTE: Toggle colors are NOT defined here - use preset_name in your button config
    --       to apply toggle styles (e.g., preset_name = "BUTTON_TOGGLE_TEAL")
    bg_color = C.BG_BASE,
    bg_hover_color = C.BG_HOVER,
    bg_active_color = C.BG_ACTIVE,
    border_outer_color = C.BORDER_OUTER,
    border_inner_color = C.BORDER_INNER,
    border_hover_color = C.BORDER_HOVER,
    text_color = C.TEXT_NORMAL,
    text_hover_color = C.TEXT_HOVER,
    text_active_color = C.TEXT_ACTIVE,
  },

  dropdown = {
    bg_color = C.BG_BASE,
    bg_hover_color = C.BG_HOVER,
    bg_active_color = C.BG_HOVER,
    border_outer_color = C.BORDER_OUTER,
    border_inner_color = C.BORDER_INNER,
    border_hover_color = C.BORDER_HOVER,
    border_active_color = C.BORDER_ACTIVE,
    text_color = C.TEXT_NORMAL,
    text_hover_color = C.TEXT_HOVER,
    text_active_color = C.TEXT_ACTIVE,
    rounding = 0,
    padding_x = 10,
    padding_y = 6,
    arrow_size = 6,
    arrow_color = C.TEXT_NORMAL,
    arrow_hover_color = C.TEXT_HOVER,
    enable_mousewheel = true,
  },

  search = {
    placeholder = "Search...",
    fade_speed = 8.0,
    bg_color = C.BG_BASE,
    bg_hover_color = C.BG_HOVER,
    bg_active_color = C.BG_HOVER,
    border_outer_color = C.BORDER_OUTER,
    border_inner_color = C.BORDER_INNER,
    border_hover_color = C.BORDER_HOVER,
    border_active_color = C.BORDER_ACTIVE,
    text_color = C.TEXT_NORMAL,
  },
  
  separator = {
    show_line = false,
  },
}

-- Aliases for element types (header uses _field suffix)
M.ELEMENT_STYLE.dropdown_field = M.ELEMENT_STYLE.dropdown
M.ELEMENT_STYLE.search_field = M.ELEMENT_STYLE.search

-- Example: Header with left/right alignment
M.ALIGNED_HEADER_EXAMPLE = {
  header = {
    enabled = true,
    height = 30,
    position = "top",
    bg_color = PC.bg_header,
    border_color = PC.border_header,
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
    bg_color = PC.bg_header,
    border_color = PC.border_header,
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
    bg_color = PC.bg_tab,
    border_color = PC.border_header,
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

  return Config.apply_defaults(defaults, config)
end

return M
