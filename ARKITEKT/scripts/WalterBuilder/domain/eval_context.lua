-- @noindex
-- WalterBuilder/domain/eval_context.lua
-- WALTER evaluation context and variable management
--
-- Manages the context variables used during expression evaluation.
-- Provides defaults for visualization when runtime state isn't available.

local M = {}

-- Custom context overrides (set by UI)
local custom_context = {}

-- Evaluation context with default values
-- These provide reasonable defaults for visualization when runtime state isn't available
local DEFAULT_CONTEXT = {
  -- Parent dimensions (use larger values to reveal more elements)
  w = 400,  -- Default TCP width (wider to show more)
  h = 150,  -- Default TCP height (taller to pass height thresholds)
  scale = 1.0,
  lscale = 1.0,  -- Layout scale (used by some themes)

  -- Common pre-computed variables (typical values at 100% DPI)
  -- tcp_padding is an array [padding_x, padding_y]
  tcp_padding = { 7, 7 },
  element_h = 20,

  -- meter_sec is an array [x, y, w, h] representing the meter section bounds
  -- Computed from: + + + * scale + [0 0 tcp_MeterSize{0}] [0 0 34] [folder_sec{2} 0 0 h] ...
  -- At default values: x=folder_sec=20, y=0, w=tcp_MeterSize+34=84, h=parent_h=150
  meter_sec = { 20, 0, 84, 150 },

  -- main_sec is the main controls section [x, y, w, h]
  main_sec = { 104, 0, 200, 150 },  -- x starts after meter_sec

  -- folder_sec defines the folder/indent area [x, y, w]
  folder_sec = { 0, 0, 20 },

  -- Default element coordinates (used when element isn't evaluated yet but is referenced)
  -- tcp.mute is referenced by tcp.meter expression: tcp.mute{2} = mute width
  ['tcp.mute'] = { 60, 7, 21, 20 },  -- [x, y, w, h] - typical mute button
  ['tcp.solo'] = { 60, 27, 21, 20 }, -- Solo button (below mute when stacked)

  -- Meter positioning variables (these control tcp.meter position)
  -- tcp_MeterSize is a user preference (1-7), maps to pixel widths
  -- From rtconfig indexParams: 'A_tcp_MeterSize' 2 1 7 4 (default=4)
  tcp_MeterSize = 50,  -- Pixel width at default setting (4) at 1.0 scale
  tcp_MeterSize_min = 18,  -- Minimum meter width
  meterRight = 0,  -- 0=left, 1=right side meter position
  tcp_MeterLoc = 0,  -- Meter location preference

  -- Solo/mute flip threshold (height where solo/mute switch from stacked to side-by-side)
  soloFlip_h = 51,  -- At heights >= 51px, solo flips to side-by-side

  -- Folder section (affects meter_sec calculation)
  tcp_control_align = 0,  -- Control alignment mode (0, 1, or 2)
  tcp_indent = 5,  -- Folder indent per depth level

  -- Track state variables (defaults for visualization)
  recarm = 1,  -- Show record arm button
  recmon = 1,  -- Show record monitor
  track_selected = 1,  -- Show as if track is selected
  mixer_visible = 0,
  trackcolor_valid = 1,  -- Show track color
  folderstate = 0,
  folderdepth = 0,
  maxfolderdepth = 3,
  supercollapsed = 0,

  -- Common conditionals (assume visible/enabled by default)
  is_solo_flipped = 0,
  hide_mute_group = 0,
  hide_fx_group = 0,
  hide_pan_group = 0,
  hide_io_group = 0,
  hide_recarm_group = 0,
  hide_recmon_group = 0,
  hide_label_group = 0,
  hide_volume_group = 0,
  trackpanmode = 6,  -- Stereo pan mode (shows both pan and width)

  -- Theme variant
  theme_version = 1,
  theme_variant = 0,

  -- Main font
  main_font = 1,

  -- Height thresholds (set low to show elements)
  labelHide_h = 0,
  panHide_h = 0,
  volumeHide_h = 0,
  recinputHide_h = 0,
  fxHide_h = 0,
  ioHide_h = 0,
  phaseHide_h = 0,
  envHide_h = 0,
  recarmHide_h = 0,
  recmonHide_h = 0,
  recmodeHide_h = 0,
  folderHide_h = 0,
  meterHide_h = 0,
  fixed_lanes_hide_h = 0,

  -- Show flags (opposite of hide, some themes use these)
  show_recarm_group = 1,
  show_recmon_group = 1,
  show_recmode_group = 1,
  show_env_group = 1,

  -- Flow element widths (computed by rtconfig, we provide defaults)
  tcp_LabelSize = 80,
  tcp_VolSize = 50,
  tcp_PanSize = 40,
  tcp_InSize = 40,
  tcpLabelAutoMeasured = 80,  -- Simulated runtime label width
  tcp_LabelPair = 80,
  tcp_VolPair = 50,
  tcp_vol_len_offs = 0,
  tcp_label_len_offs = 0,

  -- OVR (override) widths for flow elements (dotted names flattened)
  ['OVR.tcp_recarm.width'] = 20,
  ['OVR.tcp_recmon.width'] = 15,
  ['OVR.tcp_io.width'] = 34,
  ['OVR.tcp_fx.width'] = 24,
  ['OVR.tcp_env.width'] = 41,
  ['OVR.tcp_recmode.width'] = 39,

  -- Flow groups as coordinate arrays [x, y, w, h]
  -- These get updated during flow positioning but need defaults for expressions like fx_group{2}
  pan_group = { 0, 0, 40, 20 },   -- width = tcp_PanSize default
  fx_group = { 0, 0, 24, 20 },    -- width = OVR.tcp_fx.width default
  input_group = { 0, 0, 40, 20 }, -- width = tcp_InSize default
}

-- Get the DEFAULT_CONTEXT table (for iteration)
function M.get_defaults()
  return DEFAULT_CONTEXT
end

-- Get default context value for a key
function M.get_default_value(key)
  return DEFAULT_CONTEXT[key]
end

-- Get custom context value (returns override or default)
function M.get_value(key)
  if custom_context[key] ~= nil then
    return custom_context[key]
  end
  return DEFAULT_CONTEXT[key]
end

-- Set custom context value
function M.set_value(key, value)
  if value == DEFAULT_CONTEXT[key] then
    custom_context[key] = nil  -- Remove override if it matches default
  else
    custom_context[key] = value
  end
end

-- Reset all custom context values to defaults
function M.reset()
  custom_context = {}
end

-- Check if context has been modified from defaults
function M.is_modified()
  for k, v in pairs(custom_context) do
    if v ~= nil then
      return true
    end
  end
  return false
end

-- Build a full evaluation context (defaults + custom overrides)
function M.build_eval_context()
  local ctx = {}
  for k, v in pairs(DEFAULT_CONTEXT) do
    ctx[k] = v
  end
  for k, v in pairs(custom_context) do
    ctx[k] = v
  end
  return ctx
end

-- Get list of context variables that can be controlled via UI
-- Returns list of { key, label, type, default, min, max }
function M.get_controllable_vars()
  return {
    -- Dimensions
    { key = 'w', label = 'Track Width', type = 'int', default = 400, min = 100, max = 800 },
    { key = 'h', label = 'Track Height', type = 'int', default = 150, min = 40, max = 300 },
    { key = 'scale', label = 'DPI Scale', type = 'float', default = 1.0, min = 0.5, max = 2.0 },

    -- Meter positioning (tcp_MeterSize controls meter width, meterRight flips position)
    { key = 'tcp_MeterSize', label = 'Meter Width', type = 'int', default = 50, min = 10, max = 150 },
    { key = 'meterRight', label = 'Meter on Right', type = 'bool', default = 0 },

    -- Flow element widths
    { key = 'tcp_LabelSize', label = 'Label Width', type = 'int', default = 80, min = 0, max = 200 },
    { key = 'tcp_VolSize', label = 'Volume Width', type = 'int', default = 50, min = 0, max = 100 },
    { key = 'tcp_PanSize', label = 'Pan Width', type = 'int', default = 40, min = 0, max = 100 },

    -- Visibility toggles
    { key = 'hide_mute_group', label = 'Hide Mute/Solo', type = 'bool', default = 0 },
    { key = 'hide_fx_group', label = 'Hide FX', type = 'bool', default = 0 },
    { key = 'hide_pan_group', label = 'Hide Pan', type = 'bool', default = 0 },
    { key = 'hide_volume_group', label = 'Hide Volume', type = 'bool', default = 0 },
    { key = 'hide_io_group', label = 'Hide I/O', type = 'bool', default = 0 },
    { key = 'hide_recarm_group', label = 'Hide Record Arm', type = 'bool', default = 0 },
    { key = 'hide_label_group', label = 'Hide Label', type = 'bool', default = 0 },

    -- Track state
    { key = 'is_solo_flipped', label = 'Solo Flipped', type = 'bool', default = 0 },
    { key = 'recarm', label = 'Record Armed', type = 'bool', default = 1 },
    { key = 'track_selected', label = 'Track Selected', type = 'bool', default = 1 },
    { key = 'folderstate', label = 'Is Folder', type = 'bool', default = 0 },
  }
end

return M
