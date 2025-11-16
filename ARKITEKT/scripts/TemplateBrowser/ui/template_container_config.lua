-- @noindex
-- TemplateBrowser/ui/template_container_config.lua
-- Panel container configuration for template grid

local M = {}

function M.create(callbacks)
  return {
    id = "templates_container",
    bg_color = 0x1A1A1AFF,
    border_thickness = 0,
    border_color = 0x3A3A3AFF,
    rounding = 0,
    padding = 10,

    header = {
      enabled = true,
      height = 30,
      bg_color = 0x252525FF,
      elements = {
        -- Template count label
        {
          id = "template_count",
          type = "button",
          width = 120,
          spacing_before = 0,
          config = {
            label = function(state)
              local count = callbacks.get_template_count and callbacks.get_template_count() or 0
              return string.format("%d template%s", count, count == 1 and "" or "s")
            end,
            interactive = false,
            style = {
              bg_color = 0x00000000,  -- Transparent
              text_color = 0xAAAAAAFF,
            },
          },
        },

        -- Flexible spacer
        {
          id = "spacer1",
          type = "separator",
          flex = 1,
          spacing_before = 0,
          config = { show_line = false },
        },

        -- Search field
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

        -- Sort dropdown
        {
          id = "sort",
          type = "dropdown_field",
          width = 140,
          spacing_before = 8,
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
      },
    },

    scroll = {
      enabled = true,
      flags = 0,
    },
  }
end

return M
