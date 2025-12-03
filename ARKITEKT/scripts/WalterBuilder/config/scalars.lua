-- @noindex
-- WalterBuilder/defs/scalars.lua
-- Predefined scalar variables in WALTER
--
-- These are read-only variables that can be used in expressions
-- and operator strings for conditional layouts.

local M = {}

-- Universal scalars (available in all contexts)
M.universal = {
  {
    name = 'w',
    description = 'Width of parent, pixels',
    type = 'number',
  },
  {
    name = 'h',
    description = 'Height of parent, pixels',
    type = 'number',
  },
  {
    name = 'reaper_version',
    description = 'REAPER version (e.g., 7.0)',
    type = 'number',
    min_version = '4.15',
  },
  {
    name = 'os_type',
    description = 'OS type: 0=Windows, 1=macOS, 2=Linux',
    type = 'number',
    min_version = '5.972',
  },
}

-- Track-specific scalars (tcp, mcp)
M.track = {
  {
    name = 'folderstate',
    description = 'Folder state: 0=normal, 1=folder, -n=last in folder(s)',
    type = 'number',
  },
  {
    name = 'folderdepth',
    description = 'How many folders deep (0 if not in folder)',
    type = 'number',
  },
  {
    name = 'maxfolderdepth',
    description = 'Highest folder depth of any track',
    type = 'number',
  },
  {
    name = 'mcp_maxfolderdepth',
    description = 'Highest folder depth of any track in mixer',
    type = 'number',
    min_version = '4.15',
  },
  {
    name = 'recarm',
    description = 'Nonzero if track record armed',
    type = 'boolean',
  },
  {
    name = 'tcp_iconsize',
    description = 'Size of track panel icon column, if any',
    type = 'number',
  },
  {
    name = 'mcp_iconsize',
    description = 'Size of mixer icon row, if any',
    type = 'number',
  },
  {
    name = 'mcp_wantextmix',
    description = 'Extended mixer flags: &1=inserts, &2=sends, &4=fx parms',
    type = 'flags',
  },
  {
    name = 'tracknch',
    description = 'Number of track channels (2-64)',
    type = 'number',
  },
  {
    name = 'trackpanmode',
    description = 'Pan mode: 0=classic, 3=balance, 5=stereo, 6=dual',
    type = 'number',
  },
  {
    name = 'tcp_fxparms',
    description = 'Count of TCP FX parameters visible',
    type = 'number',
  },
  {
    name = 'tcp_fxembed',
    description = 'Count of TCP embedded FX visible',
    type = 'number',
    min_version = '6.0',
  },
  {
    name = 'mcp_fxembed',
    description = 'Count of MCP embedded FX visible',
    type = 'number',
    min_version = '6.38',
  },
  {
    name = 'tcp_sends_enabled',
    description = 'User pref to show sends in TCP is enabled',
    type = 'boolean',
    min_version = '7.0',
  },
  {
    name = 'tcp_fxlist_enabled',
    description = 'User pref to show FX inserts in TCP is enabled',
    type = 'boolean',
    min_version = '7.0',
  },
  {
    name = 'send_cnt',
    description = 'Number of sends',
    type = 'number',
    min_version = '7.0',
  },
  {
    name = 'fx_parm_cnt',
    description = 'Number of FX parameters',
    type = 'number',
    min_version = '7.0',
  },
  {
    name = 'fx_cnt',
    description = 'Number of FX inserts',
    type = 'number',
    min_version = '7.0',
  },
  {
    name = 'recfx_cnt',
    description = 'Number of record input FX',
    type = 'number',
    min_version = '7.0',
  },
  {
    name = 'trackcolor_valid',
    description = '1 if track color is set',
    type = 'boolean',
    min_version = '5.0',
  },
  {
    name = 'trackcolor_r',
    description = 'Track color red value (0-255)',
    type = 'number',
    min_version = '5.0',
  },
  {
    name = 'trackcolor_g',
    description = 'Track color green value (0-255)',
    type = 'number',
    min_version = '5.0',
  },
  {
    name = 'trackcolor_b',
    description = 'Track color blue value (0-255)',
    type = 'number',
    min_version = '5.0',
  },
  {
    name = 'mixer_visible',
    description = '1 if the mixer is visible',
    type = 'boolean',
    min_version = '5.972',
  },
  {
    name = 'track_selected',
    description = '1 if track is selected',
    type = 'boolean',
    min_version = '5.972',
  },
  {
    name = 'trackidx',
    description = 'Track index (0 for master, 1+)',
    type = 'number',
    min_version = '6.47',
  },
  {
    name = 'ntracks',
    description = 'Total track count (not including master)',
    type = 'number',
    min_version = '6.47',
  },
  {
    name = 'trackfixedlanes',
    description = 'Number of fixed lanes (or 0)',
    type = 'number',
    min_version = '7.0',
  },
}

-- Transport-specific scalars
M.transport = {
  {
    name = 'trans_flags',
    description = 'Transport flags: &1=centered, &2=playspeed, &4=timesig',
    type = 'flags',
  },
  {
    name = 'trans_docked',
    description = 'Nonzero if transport is docked',
    type = 'boolean',
  },
  {
    name = 'trans_center',
    description = 'Nonzero if transport is centered',
    type = 'boolean',
  },
}

-- Envelope-specific scalars
M.envelope = {
  {
    name = 'envcp_type',
    description = '4 if FX envelope (can display additional controls)',
    type = 'number',
  },
  {
    name = 'env_selected',
    description = '1 if envelope is selected',
    type = 'boolean',
    min_version = '7.0',
  },
}

-- Get all scalars for a context
function M.get_for_context(context)
  local result = {}

  -- Always include universal
  for _, scalar in ipairs(M.universal) do
    result[#result + 1] = scalar
  end

  -- Add context-specific
  if context == 'tcp' or context == 'mcp' or context == 'master.tcp' or context == 'master.mcp' then
    for _, scalar in ipairs(M.track) do
      result[#result + 1] = scalar
    end
  elseif context == 'trans' then
    for _, scalar in ipairs(M.transport) do
      result[#result + 1] = scalar
    end
  elseif context == 'envcp' then
    for _, scalar in ipairs(M.envelope) do
      result[#result + 1] = scalar
    end
  end

  return result
end

-- Get scalar by name
function M.get_scalar(name)
  -- Search all categories
  local all_lists = {M.universal, M.track, M.transport, M.envelope}
  for _, list in ipairs(all_lists) do
    for _, scalar in ipairs(list) do
      if scalar.name == name then
        return scalar
      end
    end
  end
  return nil
end

-- Comparison operators in WALTER
M.operators = {
  {op = '<', desc = 'Less than'},
  {op = '>', desc = 'Greater than'},
  {op = '<=', desc = 'Less than or equal'},
  {op = '>=', desc = 'Greater than or equal'},
  {op = '==', desc = 'Equals'},
  {op = '!=', desc = 'Not equals'},
  {op = '?', desc = 'If nonzero (prefix)'},
  {op = '!', desc = 'If zero (prefix)'},
  {op = '&', desc = 'Bitwise AND'},
}

-- Combinator operators
M.combinators = {
  {op = '+', desc = 'Sum expressions'},
  {op = '-', desc = 'Subtract expressions'},
  {op = '*', desc = 'Multiply expressions'},
  {op = '/', desc = 'Divide expressions'},
  {op = '+:', desc = 'Weighted sum (+:val1:val2)'},
  {op = '*:', desc = 'Offset multiply (*:val1:val2)'},
}

return M
