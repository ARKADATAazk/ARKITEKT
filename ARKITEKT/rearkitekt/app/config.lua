-- @noindex
-- ReArkitekt/app/config.lua
-- Single source of truth for all application defaults

local M = {}

M.PROFILER_ENABLED = false  -- Set to true to enable profiler

M.defaults = {
  window = {
    title           = "Arkitekt App",
    content_padding = 12,
    min_size        = { w = 400, h = 300 },
    initial_size    = { w = 900, h = 600 },
    initial_pos     = { x = 100, y = 100 },
    
    -- Background colors
    bg_color_floating = nil,  -- nil = use ImGui default
    bg_color_docked   = 0x282828FF,  -- Slightly lighter for docked mode
    
    -- Fullscreen/Viewport mode settings
    fullscreen = {
      enabled = false,  -- Whether to use fullscreen/viewport mode
      use_viewport = true,  -- Use full REAPER viewport vs parent window
      fade_in_duration = 0.3,  -- seconds
      fade_out_duration = 0.3,  -- seconds
      fade_speed = 10.0,  -- Animation speed multiplier (higher = faster)
      
      scrim_enabled = true,  -- Show dark background scrim
      scrim_color = 0x000000FF,
      scrim_opacity = 0.85,
      
      window_bg_override = nil,  -- Override window background color (nil = use default)
      window_opacity = 1.0,  -- Overall window content opacity
      
      -- Window flags for fullscreen mode
      hide_titlebar = true,
      no_resize = true,
      no_move = true,
      no_collapse = true,
      no_scrollbar = true,
      no_scroll_with_mouse = true,
      
      -- Close behavior
      show_close_button = true,  -- Show floating close button on hover
      close_on_background_click = true,  -- Right-click on scrim/background to close
      close_on_background_left_click = false,  -- Left-click on background to close
      close_button_proximity = 150,  -- Distance in pixels to show close button
      
      -- Close button styling
      close_button = {
        size = 32,
        margin = 16,
        bg_color = 0x000000FF,
        bg_opacity = 0.6,
        bg_opacity_hover = 0.8,
        icon_color = 0xFFFFFFFF,
        hover_color = 0xFF4444FF,
        active_color = 0xFF0000FF,
      },
    },
  },

  fonts = {
    default        = 13,
    title          = 13,
    version        = 11,
    titlebar_version_monospace = 10, 
    family_regular = "Inter_18pt-Regular.ttf",
    family_bold    = "Inter_18pt-SemiBold.ttf",
    family_mono = 'JetBrainsMono-Regular.ttf',
  },

  titlebar = {
    height          = 26,
    pad_h           = 12,
    pad_v           = 0,
    button_width    = 44,
    button_spacing  = 0,
    button_style    = "minimal",
    separator       = true,
    bg_color        = nil,
    bg_color_active = nil,
    text_color      = nil,
    icon_size       = 18,
    icon_spacing    = 8,
    version_spacing = 6,
    version_color   = 0x888888FF,
    show_icon       = true,
    enable_maximize = true,
    
    -- Button colors (minimal style)
    button_maximize_normal  = 0x00000000,
    button_maximize_hovered = 0x57C290FF,
    button_maximize_active  = 0x60FFFFFF,
    button_close_normal     = 0x00000000,
    button_close_hovered    = 0xCC3333FF,
    button_close_active     = 0xFF1111FF,
    
    -- Button colors (filled style)
    button_maximize_filled_normal  = 0x808080FF,
    button_maximize_filled_hovered = 0x999999FF,
    button_maximize_filled_active  = 0x666666FF,
    button_close_filled_normal     = 0xCC3333FF,
    button_close_filled_hovered    = 0xFF4444FF,
    button_close_filled_active     = 0xFF1111FF,
  },

  status_bar = {
    height = 20,
  },

  dependencies = {
    hub_path = "ARKITEKT.lua",  -- Relative path to the hub/launcher file from project root
  },
}

function M.get_defaults()
  return M.defaults
end

function M.get(path)
  local keys = {}
  for key in path:gmatch("[^.]+") do
    table.insert(keys, key)
  end
  
  local value = M.defaults
  for _, key in ipairs(keys) do
    if type(value) ~= "table" then
      return nil
    end
    value = value[key]
  end
  
  return value
end

return M