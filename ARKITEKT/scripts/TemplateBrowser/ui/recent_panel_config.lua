-- @noindex
-- TemplateBrowser/ui/recent_panel_config.lua
-- Panel container configuration for recent/favorites templates

local Colors = require('rearkitekt.core.colors')

local M = {}

function M.create(callbacks, is_overlay_mode)
  -- Use solid backgrounds like Region Playlist (no transparency)
  local panel_bg = Colors.hexrgb("#1A1A1AFF")
  local header_bg = Colors.hexrgb("#1E1E1EFF")

  return {
    bg_color = panel_bg,
    border_thickness = 1,
    border_color = Colors.hexrgb("#000000DD"),
    rounding = 8,
    padding = 8,

    -- Background pattern matching Region Playlist
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
      enabled = true,
      height = 32,  -- Compact header with just dropdown
      bg_color = header_bg,
      padding = {
        left = 8,
        right = 8,
        top = 4,
        bottom = 4,
      },
      elements = {
        -- Quick access dropdown (Recents/Favorites/Most Used)
        {
          id = "quick_access_dropdown",
          type = "quick_access_dropdown",
          flex = 0,
          spacing_before = 0,
          config = {
            get_mode = callbacks.get_quick_access_mode,
            on_mode_changed = callbacks.on_quick_access_mode_changed,
          },
        },
      },
    },

    scroll = {
      enabled = true,
      flags = 0,
    },
  }
end

return M
