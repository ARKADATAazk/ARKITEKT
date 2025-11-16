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

-- Folder open/close state (path -> bool)
M.folder_open_state = {}

-- Rename state
M.renaming_item = nil       -- Item being renamed (folder node or template)
M.renaming_type = nil       -- "folder" or "template"
M.rename_buffer = ""        -- Text input buffer for rename

-- Drag and drop state
M.dragging_item = nil       -- Item being dragged
M.dragging_type = nil       -- "folder" or "template"

-- Undo manager
M.undo_manager = nil

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
  M.folder_open_state = {}
  M.renaming_item = nil
  M.renaming_type = nil
  M.rename_buffer = ""
  M.dragging_item = nil
  M.dragging_type = nil

  -- Create undo manager
  local Undo = require('TemplateBrowser.domain.undo')
  M.undo_manager = Undo.new()
end

function M.cleanup()
  -- Save state/preferences if needed
end

function M.request_exit()
  M.exit = true
end

return M
