-- @noindex
-- WalterBuilder/defs/track_defaults.lua
-- Default track properties for TCP visualization
--
-- Based on WALTER rtconfig: tcp_heights, tcp.size, etc.

local M = {}

-- TCP height presets from rtconfig: tcp_heights 2 25 50 64
M.HEIGHTS = {
  SUPERCOLLAPSED = 25,  -- supercollapsed state
  COLLAPSED = 50,       -- collapsed state
  SMALL = 64,           -- small (no recarm)
  NORMAL = 90,          -- normal size (recarm visible)
  LARGE = 120,          -- expanded
}

-- Track states
M.STATES = {
  NORMAL = 'normal',
  SELECTED = 'selected',
  ARMED = 'armed',
  FOLDER_OPEN = 'folder_open',
  FOLDER_CLOSED = 'folder_closed',
}

-- Default track colors (simulating REAPER's track colors)
M.COLORS = {
  { name = 'Default',     color = 0x3A3A3AFF },
  { name = 'Red',         color = 0xCC4444FF },
  { name = 'Orange',      color = 0xCC8844FF },
  { name = 'Yellow',      color = 0xCCCC44FF },
  { name = 'Green',       color = 0x44CC44FF },
  { name = 'Cyan',        color = 0x44CCCCFF },
  { name = 'Blue',        color = 0x4444CCFF },
  { name = 'Purple',      color = 0x8844CCFF },
  { name = 'Pink',        color = 0xCC44AAFF },
}

-- Create a default track
function M.new_track(opts)
  opts = opts or {}
  return {
    id = opts.id or ('track_' .. tostring(os.time()) .. '_' .. math.random(1000)),
    name = opts.name or 'Track',
    height = opts.height or M.HEIGHTS.NORMAL,
    color = opts.color,  -- nil = no custom color
    selected = opts.selected or false,
    armed = opts.armed or false,
    muted = opts.muted or false,
    soloed = opts.soloed or false,
    folder_state = opts.folder_state or 0,  -- 0=normal, 1=folder open, -1=folder closed, -2=last in folder
    folder_depth = opts.folder_depth or 0,
    visible = opts.visible ~= false,
  }
end

-- Default track list for demonstration
function M.get_default_tracks()
  return {
    M.new_track({ name = 'Master Bus', height = M.HEIGHTS.NORMAL, folder_state = 1, color = 0x445566FF }),
    M.new_track({ name = 'Drums', height = M.HEIGHTS.NORMAL, folder_depth = 1, folder_state = 1, color = 0xCC6644FF }),
    M.new_track({ name = 'Kick', height = M.HEIGHTS.SMALL, folder_depth = 2, armed = true }),
    M.new_track({ name = 'Snare', height = M.HEIGHTS.SMALL, folder_depth = 2 }),
    M.new_track({ name = 'Hi-Hat', height = M.HEIGHTS.SMALL, folder_depth = 2, folder_state = -2 }),
    M.new_track({ name = 'Bass', height = M.HEIGHTS.NORMAL, folder_depth = 1, color = 0x4466CCFF }),
    M.new_track({ name = 'Guitar', height = M.HEIGHTS.NORMAL, folder_depth = 1, selected = true, color = 0x66CC44FF }),
    M.new_track({ name = 'Vocals', height = M.HEIGHTS.NORMAL, folder_depth = 1, folder_state = -2, color = 0xCC44AAFF }),
  }
end

-- TCP element groups as seen in rtconfig
M.ELEMENT_GROUPS = {
  -- Main controls that flow in the 'then' macro
  main = {
    'tcp.recarm',
    'tcp.recmon',
    'tcp.label',
    'tcp.volume',
    'tcp.io',
    'tcp.fx',
    'tcp.fxbyp',
    'tcp.env',
    'tcp.pan',
    'tcp.width',
    'tcp.recmode',
    'tcp.recinput',
    'tcp.fxin',
  },
  -- Fixed position elements
  fixed = {
    'tcp.mute',
    'tcp.solo',
    'tcp.phase',
    'tcp.meter',
    'tcp.folder',
    'tcp.foldercomp',
    'tcp.trackidx',
  },
  -- Value labels
  labels = {
    'tcp.volume.label',
    'tcp.pan.label',
    'tcp.width.label',
  },
}

return M
