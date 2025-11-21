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
      height = 30,
      elements = {
        -- Quick access mode dropdown (left side)
        {
          id = "quick_access_mode",
          type = "dropdown_field",
          width = 120,
          spacing_before = 0,
          config = {
            tooltip = "Quick Access",
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
        -- Spacer
        {
          id = "spacer1",
          type = "separator",
          flex = 1,
          spacing_before = 0,
          config = { show_line = false },
        },
        -- Search field (right side, grouped with sort and view)
        {
          id = "search",
          type = "search_field",
          width = 150,
          spacing_before = 0,
          config = {
            placeholder = "Search...",
            get_value = callbacks.get_search_query,
            on_change = callbacks.on_search_changed,
          },
        },
        -- Sort dropdown (grouped with search and view, no spacing)
        {
          id = "sort",
          type = "dropdown_field",
          width = 120,
          spacing_before = 0,
          config = {
            tooltip = "Sort by",
            tooltip_delay = 0.5,
            enable_sort = false,
            get_value = callbacks.get_sort_mode,
            options = {
              { value = "alphabetical", label = "Alphabetical" },
              { value = "color", label = "Color" },
              { value = "insertion", label = "Recently Added" },
            },
            enable_mousewheel = true,
            on_change = callbacks.on_sort_changed,
          },
        },
        -- Grid/List toggle button (grouped with search and sort, no spacing)
        {
          id = "view_toggle",
          type = "button",
          width = 60,
          spacing_before = 0,
          config = {
            label = callbacks.get_view_mode_label,  -- Function-based dynamic label
            on_click = callbacks.on_view_toggle,
            tooltip = "Toggle view mode",
            tooltip_delay = 0.5,
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
