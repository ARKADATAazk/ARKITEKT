-- @noindex
-- TemplateBrowser/ui/recent_panel_config.lua
-- Panel container configuration for recent/favorites templates

local ImGui = require 'imgui' '0.10'
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
      height = 32,  -- Compact header with dropdown and view toggle
      bg_color = header_bg,
      padding = {
        left = 8,
        right = 8,
        top = 4,
        bottom = 4,
      },
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
        -- View mode toggle (right side) - optional, can be added if needed
        -- {
        --   id = "view_toggle",
        --   type = "button",
        --   align = "right",
        --   width = 60,
        --   spacing_before = 8,
        --   config = {
        --     label = "Grid",  -- or "List"
        --     on_click = callbacks.on_view_mode_toggle,
        --   },
        -- },
      },
    },

    scroll = {
      enabled = true,
      flags = ImGui.WindowFlags_HorizontalScrollbar,
      custom_scrollbar = false,
    },
  }
end

return M
