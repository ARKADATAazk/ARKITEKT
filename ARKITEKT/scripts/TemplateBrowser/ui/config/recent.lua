-- @noindex
-- TemplateBrowser/ui/config/recent.lua
-- Panel container configuration for recent/favorites templates
-- All visual styling comes from library defaults

local ImGui = require('arkitekt.core.imgui')

local M = {}

function M.create(callbacks, is_overlay_mode)
  return {
    header = {
      enabled = true,
      height = 30,
      elements = {
        -- Grid/List toggle button (left side)
        {
          id = 'view_toggle',
          type = 'button',
          width = 60,
          spacing_before = 0,
          config = {
            label = callbacks.get_view_mode_label,
            on_click = callbacks.on_view_toggle,
            tooltip = 'Toggle view mode',
            tooltip_delay = 0.5,
          },
        },
        -- Quick access mode dropdown
        {
          id = 'quick_access_mode',
          type = 'combo',
          width = 120,
          spacing_before = 4,
          config = {
            tooltip = 'Quick Access',
            tooltip_delay = 0.5,
            enable_sort = false,
            get_value = callbacks.get_quick_access_mode,
            options = {
              { value = 'inbox', label = 'Inbox' },
              { value = 'recents', label = 'Recents' },
              { value = 'favorites', label = 'Favorites' },
              { value = 'most_used', label = 'Most Used' },
            },
            enable_mousewheel = true,
            on_change = callbacks.on_quick_access_mode_changed,
          },
        },
        -- Spacer
        {
          id = 'spacer1',
          type = 'separator',
          flex = 1,
          spacing_before = 0,
          config = { show_line = false },
        },
        -- Sort dropdown (right side)
        {
          id = 'sort',
          type = 'combo',
          width = 120,
          spacing_before = 0,
          config = {
            tooltip = 'Sort by',
            tooltip_delay = 0.5,
            enable_sort = false,
            get_value = callbacks.get_sort_mode,
            options = {
              { value = 'alphabetical', label = 'Alphabetical' },
              { value = 'color', label = 'Color' },
              { value = 'insertion', label = 'Recently Added' },
            },
            enable_mousewheel = true,
            on_change = callbacks.on_sort_changed,
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
