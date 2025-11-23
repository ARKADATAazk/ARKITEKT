-- @noindex
-- TemplateBrowser/ui/template_container_config.lua
-- Panel container configuration for template grid
-- All visual styling comes from library defaults

local M = {}

function M.create(callbacks, is_overlay_mode)
  return {
    header = {
      enabled = true,
      height = 30,
      elements = {
        -- Search field (left side)
        {
          id = "search",
          type = "search_field",
          width = 200,
          spacing_before = 0,
          config = {
            placeholder = "Search templates...",
            get_value = callbacks.get_search_query,
            on_change = callbacks.on_search_changed,
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
        -- Sort dropdown (right side, grouped)
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
              { value = "usage", label = "Most Used" },
              { value = "insertion", label = "Recently Added" },
              { value = "color", label = "Color" },
            },
            enable_mousewheel = true,
            on_change = callbacks.on_sort_changed,
          },
        },
        -- Grid/List toggle button (grouped with sort, no spacing)
        {
          id = "view_toggle",
          type = "button",
          width = 60,
          spacing_before = 0,
          config = {
            label = callbacks.get_view_mode_label,
            on_click = callbacks.on_view_toggle,
            tooltip = "Toggle view mode",
            tooltip_delay = 0.5,
          },
        },
      },
    },
  }
end

return M
