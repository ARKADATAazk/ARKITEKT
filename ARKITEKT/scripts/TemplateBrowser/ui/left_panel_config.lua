-- @noindex
-- TemplateBrowser/ui/left_panel_config.lua
-- Panel container configuration for left panel (Directory/VSTs/Tags)

local M = {}

function M.create(callbacks, is_overlay_mode)
  return {
    header = {
      enabled = true,
      height = 30,
      elements = {
        -- Directory tab button
        {
          id = "directory_tab",
          type = "button",
          width = 90,
          spacing_before = 0,
          config = {
            label = "DIRECTORY",
            on_click = function() callbacks.on_tab_change("directory") end,
            style_active = function() return callbacks.get_active_tab() == "directory" end,
          },
        },
        -- VSTs tab button
        {
          id = "vsts_tab",
          type = "button",
          width = 60,
          spacing_before = 0,
          config = {
            label = "VSTS",
            on_click = function() callbacks.on_tab_change("vsts") end,
            style_active = function() return callbacks.get_active_tab() == "vsts" end,
          },
        },
        -- Tags tab button
        {
          id = "tags_tab",
          type = "button",
          width = 60,
          spacing_before = 0,
          config = {
            label = "TAGS",
            on_click = function() callbacks.on_tab_change("tags") end,
            style_active = function() return callbacks.get_active_tab() == "tags" end,
          },
        },
        -- Spacer to push everything to left
        {
          id = "spacer1",
          type = "separator",
          flex = 1,
          spacing_before = 0,
          config = { show_line = false },
        },
      },
    },
  }
end

return M
