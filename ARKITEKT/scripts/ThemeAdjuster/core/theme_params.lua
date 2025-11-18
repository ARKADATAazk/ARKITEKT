-- @noindex
-- ThemeAdjuster/core/theme_params.lua
-- REAPER theme parameter indexing and access layer

local M = {}

-- Parameter index cache: paramsIdx[layout][param_name] = numeric_index
-- Layouts: 'A', 'B', 'C', 'global'
local paramsIdx = {}

-- Currently active layout for each panel
local activeLayout = {
  tcp = 'A',
  mcp = 'A',
  envcp = 'A',
  trans = 'A'
}

-- ============================================================================
-- PARAMETER INDEXING
-- ============================================================================

-- Build parameter index on startup by scanning all theme parameters
function M.index_parameters()
  paramsIdx = {
    ['A'] = {},
    ['B'] = {},
    ['C'] = {},
    ['global'] = {}
  }

  local i = 1
  while true do
    local name, desc = reaper.ThemeLayout_GetParameter(i)
    if name == nil then break end

    -- Parse parameter description: "A_tcp_LabelSize" → layout='A', param='tcp_LabelSize'
    local layout_char = string.sub(desc, 1, 1)
    local param_name = string.sub(desc, 3)  -- Skip "A_"

    -- Map layout prefix to index key
    local layout_key
    if layout_char == 'A' then layout_key = 'A'
    elseif layout_char == 'B' then layout_key = 'B'
    elseif layout_char == 'C' then layout_key = 'C'
    elseif layout_char == 'g' then layout_key = 'global'  -- "glb_" prefix
    else layout_key = 'A' end  -- Default to A for unprefixed params

    if paramsIdx[layout_key] then
      paramsIdx[layout_key][param_name] = i
    end

    i = i + 1
  end

  -- Global color parameters (negative indices)
  paramsIdx.global['gamma'] = -1000
  paramsIdx.global['shadows'] = -1001
  paramsIdx.global['midtones'] = -1002
  paramsIdx.global['highlights'] = -1003
  paramsIdx.global['saturation'] = -1004
  paramsIdx.global['tint'] = -1005
  paramsIdx.global['affect_project_colors'] = -1006
end

-- ============================================================================
-- PARAMETER ACCESS
-- ============================================================================

-- Global parameters (affect all layouts)
local GLOBAL_PARAMS = {
  tcp_indent = true,
  tcp_control_align = true,
  tcp_LabelMeasure = true,
  mcp_indent = true,
  mcp_align = true,
  envcp_folder_indent = true,
  envcp_LabelMeasure = true,
}

-- Get parameter index for current active layout
-- param: parameter name (e.g., 'tcp_LabelSize', 'mcp_border')
-- Returns: numeric index or nil
function M.get_param_index(param)
  -- Handle global parameters (no layout variants)
  if GLOBAL_PARAMS[param] or string.match(param, '^glb_') then
    return paramsIdx['A'][param] or paramsIdx.global[param]
  end

  -- Extract panel prefix (tcp, mcp, envcp, trans)
  local panel = string.match(param, '^([^_]+)_')
  if not panel then return nil end

  -- envcp and trans don't have A/B/C variants (only one layout)
  if panel == 'envcp' or panel == 'trans' then
    return paramsIdx['A'][param]
  end

  -- Get layout-specific parameter
  local layout = activeLayout[panel] or 'A'
  return paramsIdx[layout][param]
end

-- Get parameter value
function M.get_param(param)
  local idx = M.get_param_index(param)
  if not idx then return nil end

  local name, desc, value, default, min, max = reaper.ThemeLayout_GetParameter(idx)
  return {
    index = idx,
    name = name,
    desc = desc,
    value = value,
    default = default,
    min = min,
    max = max
  }
end

-- Set parameter value
-- persist: true = save immediately, false = defer save (for dragging)
function M.set_param(param, value, persist)
  persist = persist == nil and true or persist

  local idx = M.get_param_index(param)
  if not idx then
    reaper.ShowConsoleMsg("ThemeAdjuster: Unknown parameter '" .. param .. "'\n")
    return false
  end

  local ok = pcall(reaper.ThemeLayout_SetParameter, idx, value, persist)
  if ok and persist then
    pcall(reaper.ThemeLayout_RefreshAll)
  end
  return ok
end

-- ============================================================================
-- LAYOUT MANAGEMENT
-- ============================================================================

function M.get_active_layout(panel)
  return activeLayout[panel] or 'A'
end

function M.set_active_layout(panel, layout)
  if layout == 'A' or layout == 'B' or layout == 'C' then
    activeLayout[panel] = layout
    return true
  end
  return false
end

-- Apply layout to selected tracks
-- panel: 'tcp' or 'mcp'
-- layout: 'A', 'B', or 'C'
-- scale: optional scale prefix ('', '150%_', '200%_', etc.)
function M.apply_layout_to_tracks(panel, layout, scale)
  scale = scale or ''
  local prop = (panel == 'tcp') and 'P_TCP_LAYOUT' or 'P_MCP_LAYOUT'
  local layout_string = scale .. layout

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    if reaper.IsTrackSelected(track) then
      reaper.GetSetMediaTrackInfo_String(track, prop, layout_string, true)
    end
  end
end

-- ============================================================================
-- VISIBILITY FLAGS (Bitwise operations)
-- ============================================================================

-- Toggle a visibility flag bit for a parameter
-- param: parameter name (e.g., 'tcp_Record_Arm')
-- flag_bit: 1, 2, 4, or 8
function M.toggle_flag(param, flag_bit)
  local param_data = M.get_param(param)
  if not param_data then return false end

  -- XOR to toggle the bit
  local new_value = param_data.value ~ flag_bit
  return M.set_param(param, new_value, true)
end

-- Check if a flag bit is set
function M.is_flag_set(param, flag_bit)
  local param_data = M.get_param(param)
  if not param_data then return false end

  return (param_data.value & flag_bit) ~= 0
end

-- ============================================================================
-- SPINNER VALUE LISTS
-- ============================================================================

-- These map spinner values to REAPER parameter values
M.SPINNER_VALUES = {
  -- TCP
  tcp_indent = {'NONE', '1/8', '1/4', '1/2', 1, 2, 'MAX'},
  tcp_control_align = {'FOLDER INDENT', 'ALIGNED', 'EXTEND NAME'},
  tcp_LabelSize = {'AUTO', 20, 50, 80, 110, 140, 170},
  tcp_vol_size = {'KNOB', 40, 70, 100, 130, 160, 190},
  tcp_MeterSize = {4, 10, 20, 40, 80, 160, 320},
  tcp_InputSize = {'MIN', 25, 40, 60, 90, 150, 200},
  tcp_MeterLoc = {'LEFT', 'RIGHT', 'LEFT IF ARMED'},
  tcp_sepSends = {'OFF', 'ON'},

  -- MCP
  mcp_indent = {'NONE', '1/8', '1/4', '1/2', 1, 2, 'MAX'},
  mcp_align = {'BOTTOM', 'CENTER'},
  mcp_meterExpSize = {4, 10, 20, 40, 80, 160, 320},
  mcp_border = {'NONE', 'FILLED', 'BORDER'},

  -- ENVCP
  envcp_labelSize = {'MIN', 50, 75, 100, 125, 150},
  envcp_fader_size = {'KNOB', 40, 60, 80, 100, 120},

  -- TRANS
  trans_rateSize = {'MIN', 60, 90, 120, 150, 180, 210},
  trans_rateMode = {'RATE', 'FRAMES'},
}

-- Get spinner index (1-based) from parameter value
function M.get_spinner_index(param, value)
  local values = M.SPINNER_VALUES[param]
  if not values then return 1 end

  for i, v in ipairs(values) do
    if v == value then return i end
  end
  return 1  -- Default to first
end

-- Get parameter value from spinner index (1-based)
function M.get_spinner_value(param, index)
  local values = M.SPINNER_VALUES[param]
  if not values then return nil end

  return values[index] or values[1]
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Call this on startup
function M.initialize()
  M.index_parameters()
  reaper.ShowConsoleMsg("ThemeAdjuster: Indexed " ..
    (#paramsIdx.A or 0) + (#paramsIdx.B or 0) + (#paramsIdx.C or 0) +
    " theme parameters\n")
end

return M
