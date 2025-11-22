-- @noindex
-- Region_Playlist/ui/tooltips.lua
-- Centralized tooltip definitions for Region Playlist UI

local M = {}

-- Transport button tooltips
M.TRANSPORT = {
  play = "Play Region Playlist",
  stop = "Stop playback and reset to beginning",
  pause = "Pause / Resume\nLeft-click: Toggle pause/resume",
  loop = "Loop playlist when reaching the end",
  jump = "Jump Forward\nSkip to next region in playlist",

  shuffle = "Shuffle\nLeft-click: Toggle shuffle mode\nRight-click: Shuffle options (True Shuffle / Random / Re-shuffle)",

  override_transport = "Override Transport\nWhen enabled, playing from REAPER transport will use Region Playlist instead of normal playback",

  follow_viewport = "Follow Viewport\nAutomatically scroll viewport to follow playhead during playlist playback (continuous scrolling)",
}

-- Quantize dropdown tooltip
M.quantize = "Grid/Quantize Mode\nControls timing for jump-to-next actions"

-- View mode tooltips
M.VIEW_MODES = {
  timeline = "Timeline View\nShow regions as horizontal timeline",
  list = "List View\nShow regions as vertical list",
}

-- Status bar messages
M.STATUS_MESSAGES = {
  override_enabled = "Override Transport: Enabled - REAPER transport now uses Region Playlist",
  override_disabled = "Override Transport: Disabled - REAPER transport uses normal playback",

  follow_viewport_enabled = "Follow Viewport: Enabled - Viewport will follow playhead",
  follow_viewport_disabled = "Follow Viewport: Disabled - Viewport position locked",

  shuffle_enabled = "Shuffle: Enabled",
  shuffle_disabled = "Shuffle: Disabled",

  loop_enabled = "Loop Playlist: Enabled",
  loop_disabled = "Loop Playlist: Disabled",
}

return M
