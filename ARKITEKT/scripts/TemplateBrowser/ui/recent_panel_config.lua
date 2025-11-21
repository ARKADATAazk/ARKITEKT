-- @noindex
-- TemplateBrowser/ui/recent_panel_config.lua
-- Panel container configuration for recent/favorites templates
-- All visual styling comes from library defaults

local ImGui = require 'imgui' '0.10'

local M = {}

function M.create(callbacks, is_overlay_mode)
  return {
    header = {
      enabled = true,
      height = 32,  -- Compact header with dropdown
      elements = {
        -- Quick access mode dropdown (left side)
        {
          id = "quick_access_mode",
          type = "dropdown_field",
          align = "left",
          width = 140,
          spacing_before = 0,
          config = {
            tooltip = "Quick Access Mode",
            tooltip_delay = 0.5,
            enable_sort = false,
            get_value = callbacks.get_quick_access_mode,
            options = {
              { value = "recents", label = "Recents" },
              { value = "favorites", label = "Favorites" },
              { value = "most_used", label = "Most Used" },
            },
            enable_mousewheel = true,
            on_change = callbacks.on_quick_access_mode_changed,
          },
        },
      },
    },

    scroll = {
      flags = ImGui.WindowFlags_HorizontalScrollbar,
    },
  }
end

return M
