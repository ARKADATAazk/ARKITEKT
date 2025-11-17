-- @noindex
-- TemplateBrowser/ui/template_container_config.lua
-- Panel container configuration for template grid

local Colors = require('rearkitekt.core.colors')

local M = {}

function M.create(callbacks)
  return {
    bg_color = Colors.hexrgb("#1A1A1A"),
    border_thickness = 0,
    border_color = Colors.hexrgb("#3A3A3A"),
    rounding = 0,
    padding = 10,

    header = {
      enabled = true,
      height = 56,  -- Height for two rows: controls (26px) + spacing (4px) + chips (18px + padding)
      bg_color = Colors.hexrgb("#252525"),
      padding = {
        left = 8,
        right = 8,
        top = 4,
        bottom = 4,
      },
      elements = {
        -- All-in-one header controls (search, sort, filter chips)
        {
          id = "template_header_controls",
          type = "template_header_controls",
          flex = 1,
          spacing_before = 0,
          config = {
            get_template_count = callbacks.get_template_count,
            get_search_query = callbacks.get_search_query,
            on_search_changed = callbacks.on_search_changed,
            get_sort_mode = callbacks.get_sort_mode,
            on_sort_changed = callbacks.on_sort_changed,
            get_filter_items = callbacks.get_filter_items,
            on_filter_remove = callbacks.on_filter_remove,
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
