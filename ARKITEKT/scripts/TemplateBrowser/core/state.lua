-- @noindex
-- TemplateBrowser/core/state.lua
-- Application state management

local M = {}

-- State container
M.folders = {}              -- Folder tree structure
M.templates = {}            -- All templates
M.filtered_templates = {}   -- Currently visible templates
M.metadata = nil            -- Persistent metadata (tags, notes, UUIDs)

-- UI State
M.selected_folder = nil     -- Currently selected folder path (single-select mode)
M.selected_folders = {}     -- Selected folders (multi-select mode: path -> true)
M.selected_template = nil   -- Currently selected template
M.search_query = ""         -- Search filter
M.filter_tags = {}          -- Active tag filters
M.filter_fx = {}            -- Active FX filters (table of FX name -> true)
M.left_panel_tab = "directory"  -- Current tab: "directory", "vsts", "tags"
M.sort_mode = "alphabetical"     -- Template sorting: "alphabetical", "usage", "insertion", "color"
M.tile_width = 180          -- Template tile width (controls column count)

-- Folder open/close state (path -> bool)
M.folder_open_state = {}

-- Rename state
M.renaming_item = nil       -- Item being renamed (folder node, template, or tag name)
M.renaming_type = nil       -- "folder", "template", or "tag"
M.rename_buffer = ""        -- Text input buffer for rename

-- Drag and drop state
M.dragging_item = nil       -- Item being dragged
M.dragging_type = nil       -- "folder" or "template"

-- Panel layout state
M.separator1_ratio = nil    -- Ratio for first separator (left column width)
M.separator2_ratio = nil    -- Ratio for second separator (left+middle width)
M.explorer_height_ratio = nil  -- Ratio for explorer vs tags panel height

-- Undo manager
M.undo_manager = nil

-- Internal
M.exit = false
M.overlay_alpha = 1.0
M.reparse_armed = false  -- Force reparse button armed state

function M.initialize(config)
  M.config = config
  M.folders = {}
  M.templates = {}
  M.filtered_templates = {}
  M.metadata = nil
  M.reparse_armed = false
  M.selected_folder = nil
  M.selected_folders = {}
  M.selected_template = nil
  M.search_query = ""
  M.filter_tags = {}
  M.filter_fx = {}
  M.left_panel_tab = "directory"
  M.sort_mode = "alphabetical"
  M.tile_width = 180
  M.folder_open_state = {}
  M.renaming_item = nil
  M.renaming_type = nil
  M.rename_buffer = ""
  M.dragging_item = nil
  M.dragging_type = nil

  -- Panel layout defaults
  M.separator1_ratio = config.FOLDERS_PANEL_WIDTH_RATIO or 0.22
  M.separator2_ratio = (config.FOLDERS_PANEL_WIDTH_RATIO or 0.22) + (config.TEMPLATES_PANEL_WIDTH_RATIO or 0.50)
  M.explorer_height_ratio = 0.6

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
