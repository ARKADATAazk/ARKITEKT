-- @noindex
-- TemplateBrowser/ui/template_container_config.lua
-- Panel container configuration for template grid

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
      height = 56,  -- Height for two rows: controls (26px) + spacing (4px) + chips (18px + padding)
      bg_color = header_bg,
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
