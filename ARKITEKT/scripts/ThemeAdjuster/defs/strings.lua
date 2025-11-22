-- @noindex
-- ThemeAdjuster/defs/strings.lua
-- All UI text: tooltips, messages, labels

local M = {}

-- ============================================================================
-- GLOBAL VIEW TOOLTIPS
-- ============================================================================

M.GLOBAL = {
  gamma = "Adjust overall brightness/gamma of the theme\nRange: 0.50 (darker) to 2.00 (brighter)\nDefault: 1.00",
  highlights = "Adjust brightness of highlights (bright areas)\nRange: -2.00 (darker) to +2.00 (brighter)\nDefault: 0.00",
  midtones = "Adjust brightness of midtones (medium brightness areas)\nRange: -2.00 (darker) to +2.00 (brighter)\nDefault: 0.00",
  shadows = "Adjust brightness of shadows (dark areas)\nRange: -2.00 (darker) to +2.00 (brighter)\nDefault: 0.00",
  saturation = "Adjust color saturation/intensity\nRange: 0% (grayscale) to 200% (vibrant)\nDefault: 100%",
  tint = "Adjust color temperature/tint\nRange: -180° (cooler/blue) to +180° (warmer/orange)\nDefault: 0°",
  affect_project_colors = "When enabled, global color adjustments also affect project track colors\nWhen disabled, only theme colors are affected",
  custom_color_track_names = "When enabled, track names use the track's custom color\nWhen disabled, track names use the default theme text color",
}

-- ============================================================================
-- TCP VIEW TOOLTIPS
-- ============================================================================

M.TCP = {
  layout_button = "Switch to editing Layout %s parameters\nEach layout (A/B/C) has independent settings",
  set_default_layout = "Set Layout %s as the default for new tracks\nNew tracks will use this layout automatically",
  apply_size = "Apply Layout %s at %s scale to selected tracks\nTracks will immediately switch to this layout and size",

  indent = "Folder indentation width\nGLOBAL: Affects all layouts (A/B/C)",
  control_align = "Control alignment behavior\nGLOBAL: Affects all layouts (A/B/C)",
  label_measure = "Enable dynamic track name width based on text length\nGLOBAL: Affects all layouts (A/B/C)",
  label_size = "Track name field width\nPer-layout: Each layout (A/B/C) has its own value",
  vol_size = "Volume control size (fader or knob)\nPer-layout: Each layout (A/B/C) has its own value",
  meter_size = "Meter width in pixels\nPer-layout: Each layout (A/B/C) has its own value",
  input_size = "Input monitoring control size\nPer-layout: Each layout (A/B/C) has its own value",
  meter_loc = "Meter position (left/right of controls)\nPer-layout: Each layout (A/B/C) has its own value",
  sep_sends = "Separate send controls from main control area\nPer-layout: Each layout (A/B/C) has its own value",
  fxparms_size = "FX parameters area size\nPer-layout: Each layout (A/B/C) has its own value",
  recmon_size = "Record monitoring control size\nPer-layout: Each layout (A/B/C) has its own value",
  pan_size = "Pan control size\nPer-layout: Each layout (A/B/C) has its own value",
  width_size = "Width control size\nPer-layout: Each layout (A/B/C) has its own value",

  vis_header = "Control when each element is visible in the TCP\nCheck boxes to HIDE elements under specific conditions",
  vis_if_mixer = "Hide when mixer (MCP) is visible",
  vis_if_not_selected = "Hide when track is not selected",
  vis_if_not_armed = "Hide when track is not armed for recording",
  vis_always_hide = "Always hide this element",
}

M.TCP_VIS_ELEMENTS = {
  tcp_Record_Arm = "Record Arm button visibility conditions",
  tcp_Monitor = "Monitor button visibility conditions",
  tcp_Input = "Input selector visibility conditions",
  tcp_Fx = "FX button visibility conditions",
  tcp_Pan = "Pan control visibility conditions",
  tcp_Width = "Width control visibility conditions",
  tcp_Volume = "Volume control visibility conditions",
  tcp_Phase = "Phase invert button visibility conditions",
  tcp_Recmon = "Record monitoring controls visibility conditions",
  tcp_Fxparms = "FX parameters area visibility conditions",
  tcp_PanWidth = "Combined pan/width control visibility conditions",
  tcp_Io = "I/O button visibility conditions",
}

-- ============================================================================
-- MCP VIEW TOOLTIPS
-- ============================================================================

M.MCP = {
  layout_button = "Switch to editing Layout %s parameters\nEach layout (A/B/C) has independent settings",
  set_default_layout = "Set Layout %s as the default for new tracks\nNew tracks will use this layout automatically",
  apply_size = "Apply Layout %s at %s scale to selected tracks\nTracks will immediately switch to this layout and size",

  indent = "Folder indentation width\nGLOBAL: Affects all layouts (A/B/C)",
  align = "Mixer control alignment (bottom or center)\nGLOBAL: Affects all layouts (A/B/C)",
  meter_exp_size = "Expanded meter width in pixels\nPer-layout: Each layout (A/B/C) has its own value",
  border = "Mixer strip border style\nPer-layout: Each layout (A/B/C) has its own value",
  vol_text_pos = "Volume text position\nPer-layout: Each layout (A/B/C) has its own value",
  pan_text_pos = "Pan text position\nPer-layout: Each layout (A/B/C) has its own value",
  extmixer_mode = "Extended mixer mode (off, 1, 2, or 3)\nPer-layout: Each layout (A/B/C) has its own value",
  label_size = "Track name label size\nPer-layout: Each layout (A/B/C) has its own value",
  vol_size = "Volume control size\nPer-layout: Each layout (A/B/C) has its own value",
  fxlist_size = "FX list area size\nPer-layout: Each layout (A/B/C) has its own value",
  sendlist_size = "Send list area size\nPer-layout: Each layout (A/B/C) has its own value",
  io_size = "I/O controls area size\nPer-layout: Each layout (A/B/C) has its own value",

  vis_header = "Control when each element is visible in the MCP\nCheck boxes to HIDE elements under specific conditions",
  vis_if_mixer = "Hide when mixer (MCP) is visible",
  vis_if_not_selected = "Hide when track is not selected",
  vis_if_not_armed = "Hide when track is not armed for recording",
  vis_always_hide = "Always hide this element",

  show_fx = "Toggle FX window visibility for selected tracks\nREAPER Action: Show FX for tracks (40549)",
  show_params = "Toggle FX parameter display in mixer\nREAPER Action: FX parameters (40910)",
  show_sends = "Toggle send list visibility in mixer\nREAPER Action: Show sends (40557)",
  multi_row = "Toggle multi-row mixer layout\nREAPER Action: Toggle multi-row (40371)",
  scroll_to_selected = "Scroll mixer to show selected tracks\nREAPER Action: Scroll to selected (40221)",
  show_icons = "Toggle track icons in mixer\nREAPER Action: Show icons (40903)",
  folder_collapse = "Collapse/expand selected folder tracks\nREAPER Action: Folder collapse (1042)",
}

M.MCP_VIS_ELEMENTS = {
  mcp_Sidebar = "Extend mixer strip with sidebar visibility conditions",
  mcp_Narrow = "Narrow form visibility conditions",
  mcp_Meter_Expansion = "Meter expansion visibility conditions",
  mcp_Labels = "Element labels visibility conditions",
}

-- ============================================================================
-- ENVELOPE VIEW TOOLTIPS
-- ============================================================================

M.ENVELOPE = {
  set_default_layout = "Set as the default envelope layout for new envelopes",
  apply_size = "Apply envelope layout at %s scale to selected envelope lanes",

  label_size = "Envelope name field width",
  fader_size = "Envelope fader/control size",
  folder_indent = "Enable folder indentation for envelope lanes",
}

-- ============================================================================
-- TRANSPORT VIEW TOOLTIPS
-- ============================================================================

M.TRANSPORT = {
  set_default_layout = "Set as the default transport layout",
  apply_size = "Apply transport layout at %s scale",

  rate_size = "Play rate control size (knob or fader sizes)",

  show_play_rate = "Toggle play rate control visibility\nREAPER Action: Show play rate (40531)",
  center_transport = "Center transport in its docker\nREAPER Action: Center transport (40533)",
  time_signature = "Toggle time signature display\nREAPER Action: Show time signature (40680)",
  frames = "Toggle frames display\nREAPER Action: Show frames (42361)",
  dock_transport = "Dock/undock transport window\nREAPER Action: Dock transport (41643)",
}

-- ============================================================================
-- COLORS VIEW TOOLTIPS
-- ============================================================================

M.COLORS = {
  palette_selector = "Choose a color palette to apply to your project tracks",
  color_swatch = "R:%d G:%d B:%d\nClick to apply to selected tracks",
  recolor_all = "Applies this palette to all colored tracks in the project\nPreserves color relationships while changing the color scheme",

  darken_selected = "Darken the colors of selected tracks by 20%",
  darken_all = "Darken all track colors in the project by 20%",
  brighten_selected = "Brighten the colors of selected tracks by 25%",
  brighten_all = "Brighten all track colors in the project by 25%",
}

-- ============================================================================
-- UI LABELS
-- ============================================================================

M.LABELS = {
  demo_button = "Demo",
  search_placeholder = "Search packages...",
  filters_tooltip = "Filter Packages",
  filters_label = "Filters",
}

-- ============================================================================
-- STATUS MESSAGES
-- ============================================================================

M.STATUS = {
  cache_needs_rebuild = "Cache needs rebuild",
  rebuilding_cache = "Rebuilding cache...",
  theme_not_linked = "Theme not linked",
  demo_mode = "Demo Mode - %d packages",
  packages_active = "%d/%d packages active",
  ready = "Ready",
  status_error = "Status Error: %s",
}

-- ============================================================================
-- HELPER FUNCTION
-- ============================================================================

function M.format(tooltip, ...)
  if select('#', ...) > 0 then
    return string.format(tooltip, ...)
  end
  return tooltip
end

return M
