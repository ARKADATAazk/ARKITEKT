-- @noindex
-- TemplateBrowser/ui/recent_panel_config.lua
-- Panel container configuration for recent/favorites templates

local Colors = require('rearkitekt.core.colors')

local M = {}

function M.create(callbacks, is_overlay_mode)
  -- In overlay mode, use transparent backgrounds to show the overlay scrim
  local panel_bg = is_overlay_mode and Colors.hexrgb("#00000000") or Colors.hexrgb("#1E1E1E")
  local header_bg = is_overlay_mode and Colors.hexrgb("#00000000") or Colors.hexrgb("#252525")

  return {
    bg_color = panel_bg,
    border_thickness = 1,
    border_color = Colors.hexrgb("#333333"),
    rounding = 4,
    padding = 12,

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
