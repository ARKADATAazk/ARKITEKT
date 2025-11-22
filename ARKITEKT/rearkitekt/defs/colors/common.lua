-- @noindex
-- rearkitekt/defs/colors/common.lua
-- Theme-agnostic colors: palette for assignment, semantic feedback colors

local M = {}

-- =============================================================================
-- USER-ASSIGNABLE COLOR PALETTE
-- Used in context menus for assigning colors to tags, items, regions, etc.
-- =============================================================================

M.PALETTE = {
  {name = "Blue",    hex = "#3B82F6"},
  {name = "Green",   hex = "#10B981"},
  {name = "Amber",   hex = "#F59E0B"},
  {name = "Red",     hex = "#EF4444"},
  {name = "Purple",  hex = "#8B5CF6"},
  {name = "Pink",    hex = "#EC4899"},
  {name = "Teal",    hex = "#14B8A6"},
  {name = "Orange",  hex = "#F97316"},
  {name = "Cyan",    hex = "#06B6D4"},
  {name = "Lime",    hex = "#84CC16"},
  {name = "Rose",    hex = "#F43F5E"},
  {name = "Indigo",  hex = "#6366F1"},
  {name = "Sky",     hex = "#0EA5E9"},
  {name = "Emerald", hex = "#059669"},
  {name = "Violet",  hex = "#7C3AED"},
  {name = "Fuchsia", hex = "#D946EF"},
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
  move = "#42E896FF",         -- Green - move operation
  copy = "#9C87E8FF",         -- Purple - copy operation
  delete = "#E84A4AFF",       -- Red - delete operation
  link = "#4A9EFFFF",         -- Blue - link/reference operation
}

return M
