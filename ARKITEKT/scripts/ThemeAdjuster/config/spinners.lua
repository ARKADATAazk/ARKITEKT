-- @noindex
-- ThemeAdjuster/config/spinners.lua
-- Centralized spinner value definitions for all parameter views
-- These match REAPER's Default 6.0 theme parameter options

local M = {}

-- ============================================================================
-- TCP (Track Control Panel) SPINNERS
-- ============================================================================

M.TCP = {
  indent = {'NONE', '1/8', '1/4', '1/2', 1, 2, 'MAX'},
  control_align = {'FOLDER INDENT', 'ALIGNED', 'EXTEND NAME'},
  LabelSize = {'AUTO', 20, 50, 80, 110, 140, 170},
  vol_size = {'KNOB', 40, 70, 100, 130, 160, 190},
  MeterSize = {4, 10, 20, 40, 80, 160, 320},
  InputSize = {'MIN', 25, 40, 60, 90, 150, 200},
  MeterLoc = {'LEFT', 'RIGHT', 'LEFT IF ARMED'},
  sepSends = {'OFF', 'ON'},
  fxparms_size = {'MIN', 50, 75, 100, 125, 150},
  recmon_size = {'MIN', 20, 30, 40, 50},
  pan_size = {'MIN', 40, 60, 80, 100},
  width_size = {'MIN', 40, 60, 80, 100},
}

-- ============================================================================
-- MCP (Mixer Control Panel) SPINNERS
-- ============================================================================

M.MCP = {
  indent = {'NONE', '1/8', '1/4', '1/2', 1, 2, 'MAX'},
  align = {'BOTTOM', 'CENTER'},
  meterExpSize = {4, 10, 20, 40, 80, 160, 320},
  border = {'NONE', 'FILLED', 'BORDER'},
  volText_pos = {'NORMAL', 'SEPARATE'},
  panText_pos = {'NORMAL', 'SEPARATE'},
  extmixer_mode = {'OFF', '1', '2', '3'},
  labelSize = {'MIN', 50, 75, 100, 125, 150},
  volSize = {'MIN', 40, 60, 80, 100, 120},
  fxlist_size = {'MIN', 80, 120, 160, 200},
  sendlist_size = {'MIN', 60, 90, 120, 150},
  io_size = {'MIN', 50, 75, 100, 125},
}

-- ============================================================================
-- ENVCP (Envelope Control Panel) SPINNERS
-- ============================================================================

M.ENVCP = {
  labelSize = {'AUTO', 20, 50, 80, 110, 140, 170},
  fader_size = {'KNOB', 40, 70, 100, 130, 160, 190},
}

-- ============================================================================
-- TRANS (Transport) SPINNERS
-- ============================================================================

M.TRANS = {
  rate_size = {'KNOB', 80, 130, 160, 200, 250, 310, 380},
}

-- ============================================================================
-- FLAT ACCESS (for backwards compatibility with ThemeParams.SPINNER_VALUES)
-- ============================================================================

M.FLAT = {
  -- TCP
  tcp_indent = M.TCP.indent,
  tcp_control_align = M.TCP.control_align,
  tcp_LabelSize = M.TCP.LabelSize,
  tcp_vol_size = M.TCP.vol_size,
  tcp_MeterSize = M.TCP.MeterSize,
  tcp_InputSize = M.TCP.InputSize,
  tcp_MeterLoc = M.TCP.MeterLoc,
  tcp_sepSends = M.TCP.sepSends,
  tcp_fxparms_size = M.TCP.fxparms_size,
  tcp_recmon_size = M.TCP.recmon_size,
  tcp_pan_size = M.TCP.pan_size,
  tcp_width_size = M.TCP.width_size,

  -- MCP
  mcp_indent = M.MCP.indent,
  mcp_align = M.MCP.align,
  mcp_meterExpSize = M.MCP.meterExpSize,
  mcp_border = M.MCP.border,
  mcp_volText_pos = M.MCP.volText_pos,
  mcp_panText_pos = M.MCP.panText_pos,
  mcp_extmixer_mode = M.MCP.extmixer_mode,
  mcp_labelSize = M.MCP.labelSize,
  mcp_volSize = M.MCP.volSize,
  mcp_fxlist_size = M.MCP.fxlist_size,
  mcp_sendlist_size = M.MCP.sendlist_size,
  mcp_io_size = M.MCP.io_size,

  -- ENVCP
  envcp_labelSize = M.ENVCP.labelSize,
  envcp_fader_size = M.ENVCP.fader_size,

  -- TRANS
  trans_rate_size = M.TRANS.rate_size,
}

return M
