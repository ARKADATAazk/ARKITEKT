-- @noindex
-- ItemPicker/defs/strings.lua
-- UI text, labels, messages, and tooltips

local M = {}

-- =============================================================================
-- STATUS BAR
-- =============================================================================

M.STATUS = {
  -- Keyboard hints
  hints = "Ctrl+F: Search | Space: Preview | Delete: Disable | Alt+Click: Quick Disable",

  -- Loading status format
  loading_format = "%s Loading items... %d%% (%d Audio, %d MIDI)",

  -- Preview status format
  preview_format = "🔊 Previewing: %s",

  -- Selection format
  selection_audio = "%d Audio",
  selection_midi = "%d MIDI",
  selection_combined = "Selected: %s",

  -- Items count format
  items_format = "Items: %d Audio, %d MIDI",

  -- Spinner characters for loading animation
  spinner_chars = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"},
}

-- =============================================================================
-- SETTINGS PANEL LABELS
-- =============================================================================

M.SETTINGS_LABELS = {
  play_through_track = "Play Item Through Track (will add delay to preview playback)",
  show_muted_tracks = "Show Muted Tracks",
  show_muted_items = "Show Muted Items",
  show_disabled_items = "Show Disabled Items",
  show_favorites_only = "Show Favorites Only",
  show_audio = "Show Audio",
  show_midi = "Show MIDI",
  group_items_by_name = "Group Items by Name",
  enable_tile_fx = "Enable TileFX",
  show_visualization_small = "Show Visualization in Small Tiles",
  enable_region_tags = "Enable Region Tags",
  split_midi_by_track = "Split MIDI by Track",
  show_on_grid = "Show on Tile Grid",
}

-- =============================================================================
-- PANEL HEADERS
-- =============================================================================

M.HEADERS = {
  midi_items = "MIDI Items",
  audio_items = "Audio Items",
}

-- =============================================================================
-- SEARCH
-- =============================================================================

M.SEARCH = {
  placeholder_format = "Search %s...",
}

-- =============================================================================
-- CONTEXT MENU
-- =============================================================================

M.CONTEXT_MENU = {
  insert_item = "Insert Item from ItemPicker",
}

-- =============================================================================
-- CONSOLE MESSAGES (Debug/Status)
-- =============================================================================

M.CONSOLE = {
  -- Disk cache
  cache_initialized = "[ItemPicker] Disk cache initialized, will preload as items load\n",
  cache_loaded = "[ItemPicker] Loaded %d cached visualizations from disk\n",
  cache_project_path = "[ItemPicker Cache] Project path: '%s', name: '%s'\n",

  -- Loading
  loading_start = "=== ItemPicker: Starting lazy loading ===\n",
  loading_complete = "=== ItemPicker: Loading complete! (%.1fms) ===\n",

  -- Warnings
  sws_warning = "[ItemPicker] WARNING: BR_GetMediaItemGUID failed - install SWS extension for stable cache!\n",

  -- Debug
  debug_loaded = "[DEBUG] Loaded: %d audio groups, %d MIDI groups\n",
  debug_grouping = "[GROUPING] Reorganizing items... group_by_name=%s\n",
  debug_cycle_midi = "[CYCLE_MIDI] No content for key: %s\n",
  debug_keys = "[KEY DEBUG] LeftShift=%s RightShift=%s LeftCtrl=%s RightCtrl=%s => shift=%s ctrl=%s\n",
}

-- =============================================================================
-- TOOLTIPS
-- =============================================================================

M.TOOLTIPS = {
  -- Tile tooltips
  tile_click = "Click to select, Ctrl+Click to add to selection",
  tile_drag = "Drag to insert into arrangement",
  tile_right_click = "Right-click for context menu",

  -- Sort modes
  sort_none = "No sorting applied",
  sort_color = "Sort by track color",
  sort_name = "Sort alphabetically by name",
  sort_pool = "Sort by pool/instance count",
  sort_length = "Sort by item length",

  -- Layout modes
  layout_vertical = "MIDI on top, Audio on bottom",
  layout_horizontal = "MIDI on left, Audio on right",

  -- View modes
  view_mixed = "Show both MIDI and Audio",
  view_midi = "Show only MIDI items",
  view_audio = "Show only Audio items",

  -- Settings
  play_through_track = "Route preview through the item's original track for hearing effects",
  group_by_name = "Group items with the same name together",
  tile_fx = "Enable visual effects on tiles (hover glow, selection effects)",
  region_tags = "Display region markers as tags on item tiles",
}

return M
