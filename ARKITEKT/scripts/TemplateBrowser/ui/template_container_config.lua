-- @noindex
-- TemplateBrowser/ui/template_container_config.lua
-- Panel container configuration for template grid
-- All visual styling comes from library defaults

local M = {}

function M.create(callbacks, is_overlay_mode)
  return {
    header = {
      enabled = true,
      height = 56,  -- Height for two rows: controls (26px) + spacing (4px) + chips (18px + padding)
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
  }
end

return M
