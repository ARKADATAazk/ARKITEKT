-- @noindex
-- RegionPlaylist/defs/strings.lua
-- All UI text: tooltips, messages, labels

local M = {}

-- ============================================================================
-- TRANSPORT TOOLTIPS
-- ============================================================================
M.TRANSPORT = {
  play = "Play Region Playlist",
  stop = "Stop playback and reset to beginning",
  pause = "Pause / Resume\nLeft-click: Toggle pause/resume",
  loop = "Loop playlist when reaching the end",
  jump = "Jump Forward\nSkip to next region in playlist",

  shuffle = "Shuffle\nLeft-click: Toggle shuffle mode\nRight-click: Shuffle options (True Shuffle / Random / Re-shuffle)",

  hijack_transport = "Hijack Transport\nRegion Playlist takes over REAPER's transport when reaching playlist regions during normal playback",

  follow_viewport = "Follow Viewport\nAutomatically scroll viewport to follow playhead during playlist playback (continuous scrolling)",

  quantize = "Grid/Quantize Mode\nControls timing for jump-to-next actions",

  settings = "Settings (coming soon)",
}

-- ============================================================================
-- VIEW MODE TOOLTIPS
-- ============================================================================
M.VIEW_MODES = {
  timeline = "Timeline View\nShow regions as horizontal timeline",
  list = "List View\nShow regions as vertical list",
  switch_to_list = "Switch to List Mode",
  switch_to_timeline = "Switch to Timeline Mode",
}

-- ============================================================================
-- STATUS MESSAGES
-- ============================================================================
M.STATUS = {
  override_enabled = "Hijack Transport: Enabled - Playlist takes over when reaching playlist regions",
  override_disabled = "Hijack Transport: Disabled - Normal timeline playback",

  follow_viewport_enabled = "Follow Viewport: Enabled - Viewport will follow playhead",
  follow_viewport_disabled = "Follow Viewport: Disabled - Viewport position locked",

  shuffle_enabled = "Shuffle: Enabled",
  shuffle_disabled = "Shuffle: Disabled",

  loop_enabled = "Loop Playlist: Enabled",
  loop_disabled = "Loop Playlist: Disabled",
}

-- ============================================================================
-- POOL / CONTAINER
-- ============================================================================
M.POOL = {
  search_placeholder = "Search...",
  sort_tooltip = "Sort by",
  mode_toggle_label = "Regions",
  actions_tooltip = "Actions",

  sort_options = {
    no_sort = "No Sort",
    color = "Color",
    index = "Index",
    alpha = "Alphabetical",
    length = "Length",
  },
}

-- ============================================================================
-- DEFAULT NAMES
-- ============================================================================
M.DEFAULTS = {
  playlist_name = "Playlist",
  untitled = "Untitled",
}

return M
