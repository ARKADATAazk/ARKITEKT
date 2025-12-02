-- @noindex
-- TemplateBrowser/ui/config/info.lua
-- Panel container configuration for template info & tags
-- All visual styling comes from library defaults

local ImGui = require('arkitekt.platform.imgui')

local M = {}

function M.create(callbacks, is_overlay_mode)
  return {
    header = {
      enabled = true,
      height = 30,
      elements = {
        -- Title label (left side)
        {
          id = 'title',
          type = 'label',
          spacing_before = 0,
          config = {
            text = 'Info & Tags',
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
      },
    },

    scroll = {
      flags = ImGui.WindowFlags_None,
    },

    padding = 12,
  }
end

return M
