-- @noindex
-- arkitekt/defs/colors/common.lua
-- Theme-agnostic colors: palette for assignment, semantic feedback colors

local M = {}

-- =============================================================================
-- USER-ASSIGNABLE COLOR PALETTE
-- Used in context menus for assigning colors to tags, items, regions, etc.
-- =============================================================================

-- Wwise color palette (28 colors)
-- Organized as 2 rows of 14, grays first in each row
-- id = Wwise color index for API compatibility
M.PALETTE = {
  -- Row 1: Light Gray + dark blues/greens (0-5)
  {id = 26, name = "Light Gray",    hex = "#878787"},
  {id = 0,  name = "Indigo",        hex = "#373EC8"},
  {id = 1,  name = "Royal Blue",    hex = "#1A55CB"},
  {id = 2,  name = "Dark Teal",     hex = "#086868"},
  {id = 3,  name = "Forest Green",  hex = "#186D18"},
  {id = 4,  name = "Olive Green",   hex = "#56730D"},
  {id = 5,  name = "Olive",         hex = "#787211"},
  -- Row 2: Dark Gray + light colors (13-18)
  {id = 27, name = "Dark Gray",     hex = "#646464"},
  {id = 13, name = "Light Indigo",  hex = "#6B6FC2"},
  {id = 14, name = "Periwinkle",    hex = "#6383C5"},
  {id = 15, name = "Teal",          hex = "#438989"},
  {id = 16, name = "Green",         hex = "#539353"},
  {id = 17, name = "Light Olive",   hex = "#80983E"},
  {id = 18, name = "Gold",          hex = "#A09827"},
  -- Row 3: Warm dark colors (6-12)
  {id = 6,  name = "Bronze",        hex = "#795815"},
  {id = 7,  name = "Brown",         hex = "#78440D"},
  {id = 8,  name = "Mahogany",      hex = "#72392C"},
  {id = 9,  name = "Maroon",        hex = "#892424"},
  {id = 10, name = "Purple",        hex = "#7D267D"},
  {id = 11, name = "Lavender",      hex = "#732B97"},
  {id = 12, name = "Violet",        hex = "#5937AE"},
  -- Row 4: Warm light colors (19-25)
  {id = 19, name = "Amber",         hex = "#AB873F"},
  {id = 20, name = "Light Brown",   hex = "#AE7A42"},
  {id = 21, name = "Terra Cotta",   hex = "#AE6656"},
  {id = 22, name = "Rose",          hex = "#B95B5B"},
  {id = 23, name = "Pink",          hex = "#AA50AA"},
  {id = 24, name = "Light Lavender", hex = "#9B56BD"},
  {id = 25, name = "Light Violet",  hex = "#8760E2"},
}

-- Helper: get color by Wwise ID
function M.get_color_by_id(wwise_id)
  for _, color in ipairs(M.PALETTE) do
    if color.id == wwise_id then
      return color.hex
    end
  end
  return nil
end

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
