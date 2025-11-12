-- @noindex
-- Region_Playlist/app/config.lua
-- Structural config + semantic colors (widget chrome comes from library defaults)

local Colors = require('rearkitekt.core.colors')

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
  
  -- View mode button (left)
  view_mode = {
    size = 32,
    rounding = 4,
    bg_color = hexrgb("#252525"),
    bg_hover = hexrgb("#2A2A2A"),
    border_inner = hexrgb("#404040"),
    border_hover = hexrgb("#505050"),
    border_outer = hexrgb("#000000DD"),
    icon_color = hexrgb("#CCCCCC"),
    animation_speed = 12.0,
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
    track_color = hexrgb("#1D1D1D"),
    fill_color = hexrgb("#41E0A3"),
    progress_height = 3,
  },
  
  -- Jump controls (compact, library-styled)
  jump = {
    height = 28,
  },
}

-- Quantize settings
M.QUANTIZE = {
  default_lookahead = 0.30,
  min_lookahead = 0.20,
  max_lookahead = 1.0,
  
  grid_options = {
    { label = "Measure", value = "measure" },
    { label = "1 Bar (4/4)", value = "4.0" },
    { label = "1/2 Note", value = "2.0" },
    { label = "1/4 Note", value = "1.0" },
    { label = "1/8 Note", value = "0.5" },
    { label = "1/16 Note", value = "0.25" },
    { label = "1/32 Note", value = "0.125" },
    { label = "1/64 Note", value = "0.0625" },
  },
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
  return {
    header = {
      enabled = true,
      height = 23,
      elements = {
        {
          id = "tabs",
          type = "tab_strip",
          flex = 1,
          spacing_before = 0,
          config = {
            spacing = 0,
            min_width = 60,
            max_width = 150,
            padding_x = 8,
            chip_radius = 4,
            -- All colors handled by library defaults
            on_tab_create = callbacks.on_tab_create,
            on_tab_change = callbacks.on_tab_change,
            on_tab_delete = callbacks.on_tab_delete,
            on_tab_reorder = callbacks.on_tab_reorder,
            on_overflow_clicked = callbacks.on_overflow_clicked,
          },
        },
      },
    },
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
            -- All colors handled by library defaults
            on_click = callbacks.on_mode_toggle,
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
            -- All colors handled by library defaults
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
            -- All colors handled by library defaults
            on_change = callbacks.on_sort_changed,
            on_direction_change = callbacks.on_sort_direction_changed,
          },
        },
      },
    },
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
