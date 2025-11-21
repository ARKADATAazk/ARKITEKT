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
M.last_clicked_folder = nil -- Last clicked folder path (for shift-click range selection)
M.selected_template = nil   -- Currently selected template
M.search_query = ""         -- Search filter
M.filter_tags = {}          -- Active tag filters
M.filter_fx = {}            -- Active FX filters (table of FX name -> true)
M.left_panel_tab = "directory"  -- Current tab: "directory", "vsts", "tags"
M.sort_mode = "alphabetical"     -- Template sorting: "alphabetical", "usage", "insertion", "color"
M.template_view_mode = "grid"    -- Template view mode: "grid" or "list"
M.grid_tile_width = 180     -- Grid mode tile width (adjustable with SHIFT+MouseWheel)
M.list_tile_width = 450     -- List mode tile width (adjustable with SHIFT+MouseWheel)
M.quick_access_mode = "recents" -- Quick access mode: "recents", "favorites", "most_used"
M.quick_access_search = ""  -- Quick access panel search query
M.quick_access_sort = "alphabetical" -- Quick access sort: "alphabetical", "color", "insertion"
M.quick_access_view_mode = "grid" -- Quick access view mode: "grid" or "list"

-- Folder open/close state (path -> bool)
M.folder_open_state = {}

-- Rename state
M.renaming_item = nil       -- Item being renamed (folder node, template, or tag name)
M.renaming_type = nil       -- "folder", "template", or "tag"
M.rename_buffer = ""        -- Text input buffer for rename

-- Drag and drop state
M.dragging_item = nil       -- Item being dragged
M.dragging_type = nil       -- "folder" or "template"

-- Conflict resolution state
M.conflict_pending = nil    -- Pending conflict info { templates, target_folder, operation }
M.conflict_resolution = nil -- User's choice: "overwrite", "keep_both", "cancel"

-- Panel layout state
M.separator1_ratio = nil    -- Ratio for first separator (left column width)
M.separator2_ratio = nil    -- Ratio for second separator (left+middle width)
M.explorer_height_ratio = nil  -- Ratio for explorer vs tags panel height
M.quick_access_separator_position = nil  -- Height of main grid (above quick access panel)

-- Undo manager
M.undo_manager = nil

-- Status bar
M.status_message = ""        -- Current status message
M.status_type = "info"       -- Message type: "error", "warning", "success", "info"
M.status_timestamp = 0       -- When message was set (for auto-clear)

-- Keyboard shortcuts
M.focus_search = false       -- Request to focus search box
M.grid_navigation = nil      -- Grid navigation action: "navigate_left", "navigate_right", etc.

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
  M.last_clicked_folder = nil
  M.selected_template = nil
  M.search_query = ""
  M.filter_tags = {}
  M.filter_fx = {}
  M.left_panel_tab = "directory"
  M.sort_mode = "alphabetical"
  M.template_view_mode = "grid"
  M.grid_tile_width = config.TILE and config.TILE.GRID_DEFAULT_WIDTH or 180
  M.list_tile_width = config.TILE and config.TILE.LIST_DEFAULT_WIDTH or 450
  M.quick_access_mode = "recents"
  M.quick_access_search = ""
  M.quick_access_sort = "alphabetical"
  M.quick_access_view_mode = "grid"
  M.folder_open_state = {}
  M.renaming_item = nil
  M.renaming_type = nil
  M.rename_buffer = ""
  M.dragging_item = nil
  M.dragging_type = nil

  -- Conflict resolution
  M.conflict_pending = nil
  M.conflict_resolution = nil

  -- Status bar
  M.status_message = ""
  M.status_type = "info"
  M.status_timestamp = 0

  -- Keyboard shortcuts
  M.focus_search = false
  M.grid_navigation = nil

  -- Panel layout defaults
  M.separator1_ratio = config.FOLDERS_PANEL_WIDTH_RATIO or 0.22
  M.separator2_ratio = (config.FOLDERS_PANEL_WIDTH_RATIO or 0.22) + (config.TEMPLATES_PANEL_WIDTH_RATIO or 0.50)
  M.explorer_height_ratio = 0.6
  M.quick_access_separator_position = 350  -- Default main grid height (px)

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

-- Set status bar message
-- @param message string: Message to display
-- @param msg_type string: "error", "warning", "success", "info" (default: "info")
function M.set_status(message, msg_type)
  M.status_message = message or ""
  M.status_type = msg_type or "info"
  M.status_timestamp = reaper.time_precise()
end

-- Clear status bar message
function M.clear_status()
  M.status_message = ""
  M.status_type = "info"
  M.status_timestamp = 0
end

return M
