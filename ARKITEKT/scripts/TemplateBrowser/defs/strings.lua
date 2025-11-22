-- @noindex
-- TemplateBrowser/defs/strings.lua
-- All UI text: tooltips, messages, labels

local M = {}

-- ============================================================================
-- TOOLTIPS
-- ============================================================================
M.TOOLTIPS = {
  -- Template actions
  template_apply = "Apply template to selected track\nShortcut: Enter",
  template_insert = "Insert template as new track\nShortcut: Shift+Enter",
  template_rename = "Rename template\nShortcut: F2",
  template_archive = "Archive template (safe deletion)\nShortcut: Delete",
  template_star = "Add to Favorites",
  template_unstar = "Remove from Favorites",

  -- Folder actions
  folder_create_physical = "Create physical folder (filesystem)",
  folder_create_virtual = "Create virtual folder (metadata only)",
  folder_rename = "Rename folder\nDouble-click to rename",
  folder_color = "Set folder color",
  folder_delete_virtual = "Delete virtual folder (templates not affected)",

  -- Search and filter
  search_box = "Search templates by name\nShortcut: Ctrl+F",
  sort_alphabetical = "Sort alphabetically",
  sort_usage = "Sort by usage count (most used first)",
  sort_insertion = "Sort by insertion date (newest first)",
  sort_color = "Sort by color (colored first)",
  filter_clear = "Clear all active filters",

  -- Tags
  tag_create = "Create new tag",
  tag_rename = "Double-click to rename tag",
  tag_assign = "Click to assign/unassign tag",
  tag_filter = "Click to filter by this tag",

  -- VSTs
  vst_filter = "Click to filter templates with this VST",
  vst_reparse = "Force re-scan all templates for VSTs\nClick twice to confirm",

  -- Virtual folders
  virtual_folder_info = "Virtual folder - templates can be in multiple virtual folders",
  favorites_folder = "Favorites folder - click star on templates to add here",

  -- Archive
  archive_folder = "Archive folder - safely stores deleted files",

  -- Notes
  notes_field = "Template notes - use for descriptions, credits, etc.",

  -- Status bar
  status_message = "Status messages appear here",
}

-- ============================================================================
-- UI LABELS
-- ============================================================================
M.LABELS = {
  -- Tabs
  directory_tab = "DIRECTORY",
  vsts_tab = "VSTS",
  tags_tab = "TAGS",

  -- Placeholders
  search_templates = "Search templates...",
  search_generic = "Search...",

  -- Sort options
  sort_alphabetical = "Alphabetical",
  sort_most_used = "Most Used",
  sort_recently_added = "Recently Added",
  sort_color = "Color",

  -- Button labels
  force_reparse = "Force Reparse All",
  toggle_view = "Toggle view mode",

  -- Empty states
  no_tags = "No tags yet",
  no_tags_available = "No tags available",
  all_templates = "All Templates",

  -- Info panel
  name_label = "Name:",
  location_label = "Location:",
  notes_label = "Notes:",
  tags_label = "Tags:",
}

-- ============================================================================
-- STATUS MESSAGES
-- ============================================================================
M.STATUS = {
  ready = "Ready",
  scanning = "Scanning templates...",
  parsing_vsts = "Parsing VSTs...",
  templates_loaded = "%d templates loaded",
}

return M
