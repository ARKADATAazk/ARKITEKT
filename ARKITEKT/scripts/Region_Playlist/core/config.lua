-- @noindex
-- Region_Playlist/core/config.lua
-- Structural config + semantic colors (widget chrome comes from library defaults)

local Colors = require('rearkitekt.core.colors')
local TransportIcons = require('Region_Playlist.ui.views.transport.transport_icons')

local M = {}
local hexrgb = Colors.hexrgb

-- Animation speeds
M.ANIMATION = {
  HOVER_SPEED = 12.0,
  FADE_SPEED = 8.0,
}

-- Semantic operation colors (move/copy/delete visual feedback)
M.ACCENT = {
  GREEN = hexrgb("#42E896"),   -- Move operation
  PURPLE = hexrgb("#9C87E8"),  -- Copy operation
  RED = hexrgb("#E84A4A"),     -- Delete operation
}

-- Dimmed tile appearance
M.DIM = {
  FILL = hexrgb("#00000088"),
  STROKE = hexrgb("#FFFFFF33"),
}

-- Transport dimensions and styling (using library design language)
M.TRANSPORT = {
  height = 72,
  padding = 12,
  spacing = 12,
  panel_bg_color = hexrgb("#131313c9"),
  
  -- View mode button (bottom-left corner)
  view_mode = {
    size = 30,  -- Match settings icon size
    rounding = 4,
    bg_color = hexrgb("#252525"),
    bg_hover = hexrgb("#2A2A2A"),
    border_inner = hexrgb("#404040"),
    border_hover = hexrgb("#505050"),
    border_outer = hexrgb("#000000DD"),
    icon_color = hexrgb("#CCCCCC"),
    animation_speed = 12.0,
  },

  -- Corner buttons (panel feature)
  corner_buttons = {
    size = 30,
    margin = 8,
    bottom_right = {
      custom_draw = function(ctx, dl, x, y, width, height, is_hovered, is_active, color)
        TransportIcons.draw_tool(dl, x, y, width, height, color)
      end,
      tooltip = "Settings (coming soon)",
      on_click = function()
        reaper.ShowConsoleMsg("Settings button clicked (coming soon)\n")
      end,
    },
  },

  -- Central display (library-styled double border)
  display = {
    bg_color = hexrgb("#252525"),
    border_inner = hexrgb("#404040"),
    border_outer = hexrgb("#000000DD"),
    rounding = 6,
    time_color = hexrgb("#CCCCCC"),
    time_playing_color = hexrgb("#FFFFFF"),
    status_color = hexrgb("#888888"),
    region_color = hexrgb("#CCCCCC"),
    track_color = hexrgb("#404040"),  -- Lighter track for better visibility
    fill_color = hexrgb("#41E0A3"),
    progress_height = 3,
  },
  
  -- Transport FX (background, gradient, glow, border)
  fx = {
    rounding = 8,
    specular = { height = 40, strength = 0.02 },
    inner_glow = { size = 20, strength = 0.08 },
    border = { color = hexrgb("#000000"), thickness = 1 },
    hover = { specular_boost = 1.5, glow_boost = 1.3, transition_speed = 6.0 },
    gradient = {
      fade_speed = 8.0,
      ready_color = hexrgb("#838383ff"),  -- Dark grey when not playing
      fill_opacity = 0.3,      -- transparency of region gradient over panel bg
      fill_saturation = 0.8,
      fill_brightness = 0.8,
    },
    jump_flash = {
      fade_speed = 3.0,        -- How fast the flash fades out (higher = faster)
      max_opacity = 0.85,      -- Maximum gradient opacity during flash
    },
    progress = { height = 3, track_color = hexrgb("#1D1D1D") },
  },
  
  -- Background pattern (panel grid/dots behind gradient)
  background_pattern = {
    primary = { type = 'dots', spacing = 50, color = hexrgb("#0000001c"), dot_size = 2.5 },
    secondary = { enabled = true, type = 'dots', spacing = 5, color = hexrgb("#141414d0"), dot_size = 1.5 },
  },
  
  -- Jump controls (compact, library-styled)
  jump = {
    height = 28,
  },
}

-- Quantize settings (single source of truth)
M.QUANTIZE = {
  default_mode = "measure",
  default_lookahead = 0.30,
  min_lookahead = 0.20,
  max_lookahead = 1.0,

  -- Quantize mode options for UI dropdowns
  -- Values map to quantize.lua mode detection: strings for named modes, numbers for grid divisions
  options = {
    { value = "4bar", label = "4 Bars" },
    { value = "2bar", label = "2 Bars" },
    { value = "measure", label = "1 Bar" },
    { value = "beat", label = "Beat" },
    { value = 1, label = "1/1" },
    { value = 0.5, label = "1/2" },
    { value = 0.25, label = "1/4" },
    { value = 0.125, label = "1/8" },
    { value = 0.0625, label = "1/16" },
    { value = 0.03125, label = "1/32" },
  },
}

-- Transport button layout priorities (modular system)
-- Lower priority = more important (shown first, hidden last)
M.TRANSPORT_BUTTONS = {
  play = { priority = 1, width = 34 },      -- Always show
  jump = { priority = 2, width = 46 },      -- Always show
  quantize = { priority = 3, width = 85 },
  playback = { priority = 4, width_dropdown = 90, width_buttons = 300 },  -- Shuffle(60) + Override(130) + Follow(110)
  loop = { priority = 5, width = 34 },
  stop = { priority = 6, width = 34 },
}

-- Responsive breakpoints for transport layout
M.TRANSPORT_LAYOUT = {
  -- When to combine quantize + playback into single "PB" dropdown
  ultra_compact_width = 250,

  -- When to use playback dropdown instead of separate buttons
  compact_width = 400,
}

-- Separator dimensions
M.SEPARATOR = {
  horizontal = {
    default_position = 180,
    min_active_height = 100,
    min_pool_height = 100,
    gap = 8,
    thickness = 6,
  },
  vertical = {
    default_position = 280,
    min_active_width = 200,
    min_pool_width = 200,
    gap = 8,
    thickness = 6,
  },
}

-- Active container: tabs only
-- All visual styling comes from library defaults
function M.get_active_container_config(callbacks)
  -- Base config
  local tab_config = {
    spacing = 0,
    min_width = 60,
    max_width = 150,
    padding_x = 8,
    chip_radius = 4,
  }

  -- Auto-merge all callbacks (no manual whitelist needed)
  for key, value in pairs(callbacks or {}) do
    if type(key) == "string" and key:match("^on_") and type(value) == "function" then
      tab_config[key] = value
    end
  end

  return {
    header = {
      enabled = true,
      height = 24,
      elements = {
        {
          id = "tabs",
          type = "tab_strip",
          flex = 1,
          spacing_before = 0,
          config = tab_config,
        },
      },
    },
    corner_buttons = {
      size = 24,
      margin = 8,
      bottom_left = {
        custom_draw = function(ctx, dl, x, y, width, height, is_hovered, is_active, color)
          TransportIcons.draw_bolt(dl, x, y, width, height, color)
        end,
        tooltip = "Actions",
        on_click = callbacks.on_actions_button_click,
      },
    },
    corner_buttons_always_visible = true,
  }
end

-- Pool container: mode toggle, search, sort
-- All visual styling comes from library defaults
function M.get_pool_container_config(callbacks)
  return {
    header = {
      enabled = true,
      height = 30,
      elements = {
        {
          id = "mode_toggle",
          type = "button",
          width = 100,
          spacing_before = 0,
          config = {
            label = "Regions",
            on_click = callbacks.on_mode_toggle,
            on_right_click = callbacks.on_mode_toggle_right,
          },
        },
        {
          id = "spacer1",
          type = "separator",
          flex = 1,
          spacing_before = 0,
          config = { show_line = false },
        },
        {
          id = "search",
          type = "search_field",
          width = 200,
          spacing_before = 0,
          config = {
            placeholder = "Search...",
            on_change = callbacks.on_search_changed,
          },
        },
        {
          id = "sort",
          type = "dropdown_field",
          width = 120,
          spacing_before = 0,
          config = {
            tooltip = "Sort by",
            tooltip_delay = 0.5,
            enable_sort = true,
            options = {
              { value = nil, label = "No Sort" },
              { value = "color", label = "Color" },
              { value = "index", label = "Index" },
              { value = "alpha", label = "Alphabetical" },
              { value = "length", label = "Length" },
            },
            enable_mousewheel = true,
            on_change = callbacks.on_sort_changed,
            on_direction_change = callbacks.on_sort_direction_changed,
          },
        },
      },
    },
    corner_buttons = {
      size = 24,
      margin = 8,
      bottom_left = {
        custom_draw = function(ctx, dl, x, y, width, height, is_hovered, is_active, color)
          TransportIcons.draw_bolt(dl, x, y, width, height, color)
        end,
        tooltip = "Actions",
        on_click = function()
          if callbacks.on_actions_click then
            callbacks.on_actions_click()
          end
        end,
      },
    },
    corner_buttons_always_visible = true,
  }
end

-- Region tiles structural config
function M.get_region_tiles_config(layout_mode)
  return {
    layout_mode = layout_mode or 'horizontal',
    
    tile_config = {
      border_thickness = 0.5,
      rounding = 6,
    },
    
    container = {
      border_thickness = 1,
      rounding = 8,
      padding = 8,
      
      scroll = {
        flags = 0,
        custom_scrollbar = false,
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
          line_thickness = 1.5,
        },
        secondary = {
          enabled = true,
          type = 'grid',
          spacing = 5,
          line_thickness = 0.5,
        },
      },
      
      header = {
        enabled = false,
      },
    },
    
    responsive_config = {
      enabled = true,
      min_tile_height = 30,
      base_tile_height_active = 72,
      base_tile_height_pool = 72,
      scrollbar_buffer = 24,
      height_hysteresis = 12,
      stable_frames_required = 2,
      round_to_multiple = 1,
      gap_scaling = {
        enabled = true,
        min_gap = 3,
        max_gap = 12,
      },
    },
    
    hover_config = {
      animation_speed_hover = M.ANIMATION.HOVER_SPEED,
      hover_brightness_factor = 1.5,
      hover_border_lerp = 0.5,
      base_fill_desaturation = 0.4,
      base_fill_brightness = 0.4,
      base_fill_alpha = hexrgb("#00000066"),
    },
    
    dim_config = {
      fill_color = M.DIM.FILL,
      stroke_color = M.DIM.STROKE,
      stroke_thickness = 1.5,
      rounding = 6,
    },
    
    drop_config = {
      move_mode = {
        line = { 
          width = 2, 
          color = M.ACCENT.GREEN,
          glow_width = 12, 
          glow_color = hexrgb("#42E89633") 
        },
        caps = { 
          width = 8, 
          height = 3, 
          color = M.ACCENT.GREEN,
          rounding = 0, 
          glow_size = 3, 
          glow_color = hexrgb("#42E89644") 
        },
      },
      copy_mode = {
        line = { 
          width = 2, 
          color = M.ACCENT.PURPLE,
          glow_width = 12, 
          glow_color = hexrgb("#9C87E833") 
        },
        caps = { 
          width = 8, 
          height = 3, 
          color = M.ACCENT.PURPLE,
          rounding = 0, 
          glow_size = 3, 
          glow_color = hexrgb("#9C87E844") 
        },
      },
      pulse_speed = 2.5,
    },
    
    ghost_config = {
      tile = {
        width = 60,
        height = 40,
        stroke_thickness = 1.5,
        rounding = 4,
        global_opacity = 0.70,
      },
      stack = {
        max_visible = 3,
        offset_x = 3,
        offset_y = 3,
        scale_factor = 0.94,
        opacity_falloff = 0.70,
      },
      badge = {
        border_thickness = 1,
        rounding = 6,
        padding_x = 6,
        padding_y = 3,
        offset_x = 35,
        offset_y = -35,
        min_width = 20,
        min_height = 18,
        shadow = {
          enabled = true,
          offset = 2,
        },
      },
      copy_mode = {
        stroke_color = M.ACCENT.PURPLE,
        glow_color = hexrgb("#9C87E833"),
        badge_accent = M.ACCENT.PURPLE,
        indicator_text = "+",
        indicator_color = M.ACCENT.PURPLE,
      },
      move_mode = {
        stroke_color = M.ACCENT.GREEN,
        glow_color = Colors.hexrgb("#42E89633"),
        badge_accent = M.ACCENT.GREEN,
      },
      delete_mode = {
        stroke_color = M.ACCENT.RED,
        glow_color = Colors.hexrgb("#E84A4A33"),
        badge_accent = M.ACCENT.RED,
        indicator_text = "-",
        indicator_color = M.ACCENT.RED,
      },
    },

    wheel_config = {
      step = 1,
    },
  }
end

return M
