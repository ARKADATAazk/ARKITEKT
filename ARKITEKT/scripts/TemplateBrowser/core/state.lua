-- @noindex
-- TemplateBrowser/core/state.lua
-- Application state management

local M = {}

-- State container
M.folders = {}              -- Folder tree structure
M.templates = {}            -- All templates
M.filtered_templates = {}   -- Currently visible templates
M.tags = {}                 -- Tag definitions
M.template_tags = {}        -- Template -> tags mapping

-- UI State
M.selected_folder = nil     -- Currently selected folder path
M.selected_template = nil   -- Currently selected template
M.search_query = ""         -- Search filter
M.filter_tags = {}          -- Active tag filters

-- Internal
M.exit = false
M.overlay_alpha = 1.0

function M.initialize(config)
  M.config = config
  M.folders = {}
  M.templates = {}
  M.filtered_templates = {}
  M.tags = {}
  M.template_tags = {}
  M.selected_folder = nil
  M.selected_template = nil
  M.search_query = ""
  M.filter_tags = {}
end

function M.cleanup()
  -- Save state/preferences if needed
end

function M.request_exit()
  M.exit = true
end

return M
