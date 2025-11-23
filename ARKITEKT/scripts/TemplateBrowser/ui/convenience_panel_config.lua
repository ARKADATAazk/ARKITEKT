-- @noindex
-- TemplateBrowser/ui/convenience_panel_config.lua
-- Panel container configuration for convenience panel (Tags/VSTs mini tabs)

local M = {}

function M.create(callbacks, is_overlay_mode)
  return {
    -- Disable grid pattern background
    background_pattern = {
      enabled = false,
    },

    header = {
      enabled = true,
      height = 30,
      elements = {
        -- Tags tab button (flex = 1 for equal width)
        {
          id = "conv_tags_tab",
          type = "button",
          flex = 1,
          spacing_before = 0,
          config = {
            label = "TAGS",
            on_click = function() callbacks.on_tab_change("tags") end,
            style_active = function() return callbacks.get_active_tab() == "tags" end,
          },
        },
        -- VSTs tab button (flex = 1 for equal width)
        {
          id = "conv_vsts_tab",
          type = "button",
          flex = 1,
          spacing_before = 0,
          config = {
            label = "VSTS",
            on_click = function() callbacks.on_tab_change("vsts") end,
            style_active = function() return callbacks.get_active_tab() == "vsts" end,
          },
        },
      },
    },

    padding = 8,
  }
end

return M
