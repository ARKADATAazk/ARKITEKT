-- @noindex
-- rearkitekt/defs/colors/common.lua
-- Theme-agnostic colors: palette for assignment, semantic feedback colors

local M = {}

-- =============================================================================
-- USER-ASSIGNABLE COLOR PALETTE
-- Used in context menus for assigning colors to tags, items, regions, etc.
-- =============================================================================

-- Wwise color palette (28 colors)
M.PALETTE = {
  {name = "Indigo",        hex = "#373EC8"},
  {name = "Royal Blue",    hex = "#1A55CB"},
  {name = "Dark Teal",     hex = "#086868"},
  {name = "Forest Green",  hex = "#186D18"},
  {name = "Olive Green",   hex = "#56730D"},
  {name = "Olive",         hex = "#787211"},
  {name = "Bronze",        hex = "#795815"},
  {name = "Brown",         hex = "#78440D"},
  {name = "Mahogany",      hex = "#72392C"},
  {name = "Maroon",        hex = "#892424"},
  {name = "Purple",        hex = "#7D267D"},
  {name = "Lavender",      hex = "#732B97"},
  {name = "Violet",        hex = "#5937AE"},
  {name = "Light Indigo",  hex = "#6B6FC2"},
  {name = "Periwinkle",    hex = "#6383C5"},
  {name = "Teal",          hex = "#438989"},
  {name = "Green",         hex = "#539353"},
  {name = "Light Olive",   hex = "#80983E"},
  {name = "Gold",          hex = "#A09827"},
  {name = "Amber",         hex = "#AB873F"},
  {name = "Light Brown",   hex = "#AE7A42"},
  {name = "Terra Cotta",   hex = "#AE6656"},
  {name = "Rose",          hex = "#B95B5B"},
  {name = "Pink",          hex = "#AA50AA"},
  {name = "Light Lavender", hex = "#9B56BD"},
  {name = "Light Violet",  hex = "#8760E2"},
  {name = "Light Gray",    hex = "#878787"},
  {name = "Dark Gray",     hex = "#646464"},
}

-- Helper: get palette as flat array of hex values
function M.get_palette_colors()
  local colors = {}
  for i, color in ipairs(M.PALETTE) do
    colors[i] = color.hex
  end
  return colors
end

-- Helper: get color by name
function M.get_color_by_name(name)
  for _, color in ipairs(M.PALETTE) do
    if color.name == name then
      return color.hex
    end
  end
  return nil
end

-- =============================================================================
-- SEMANTIC COLORS (feedback, status)
-- These are theme-agnostic - same meaning across themes
-- =============================================================================

M.SEMANTIC = {
  -- Feedback
  success = "#42E896FF",      -- Green - positive actions, ready states
  warning = "#E0B341FF",      -- Yellow/Orange - caution, pending
  error = "#E04141FF",        -- Red - errors, failures, destructive
  info = "#4A9EFFFF",         -- Blue - information, loading

  -- Status states
  ready = "#41E0A3FF",        -- Green - system ready
  playing = "#FFFFFFFF",      -- White - active playback
  idle = "#888888FF",         -- Gray - inactive
  muted = "#CC2222FF",        -- Dark red - muted/disabled text
}

-- =============================================================================
-- OPERATION COLORS (drag/drop, actions)
-- =============================================================================

M.OPERATIONS = {
  move = "#CCCCCCFF",         -- Light gray - move operation
  copy = "#06B6D4FF",         -- Cyan - copy operation
  delete = "#E84A4AFF",       -- Red - delete operation
  link = "#4A9EFFFF",         -- Blue - link/reference operation
}

return M
