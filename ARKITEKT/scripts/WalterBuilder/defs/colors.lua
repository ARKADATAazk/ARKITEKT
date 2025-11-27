-- @noindex
-- WalterBuilder/defs/colors.lua
-- Color definitions for WALTER Builder visualization

local M = {}

-- Attachment behavior visualization colors
-- These colors indicate how elements respond to parent resize

M.ATTACHMENT = {
  -- Fixed - element doesn't respond to parent resize
  FIXED = 0x4A90E2FF,  -- Blue - stable, anchored

  -- Stretch - element stretches in one or both directions
  STRETCH_H = 0x7ED321FF,  -- Green - horizontal stretch
  STRETCH_V = 0x50E3C2FF,  -- Cyan - vertical stretch
  STRETCH_BOTH = 0x9013FEFF,  -- Purple - stretches both ways

  -- Move - element moves but maintains size
  MOVE = 0xF5A623FF,  -- Orange - position changes, size stays

  -- Complex - unusual attachment configuration
  COMPLEX = 0xD0021BFF,  -- Red - needs attention

  -- Edge indicators
  EDGE_ATTACHED = 0x00FF00FF,  -- Bright green - edge will move
  EDGE_FIXED = 0xFF6600FF,  -- Orange - edge stays put
}

-- Semi-transparent versions for overlays
M.ATTACHMENT_ALPHA = {
  FIXED = 0x4A90E240,
  STRETCH_H = 0x7ED32140,
  STRETCH_V = 0x50E3C240,
  STRETCH_BOTH = 0x9013FE40,
  MOVE = 0xF5A62340,
  COMPLEX = 0xD0021B40,
}

-- Element category colors (for palette grouping)
M.CATEGORY = {
  button = 0xE74C3CFF,     -- Red
  fader = 0x3498DBFF,      -- Blue
  label = 0x2ECC71FF,      -- Green
  meter = 0x9B59B6FF,      -- Purple
  container = 0x95A5A6FF,  -- Gray
  input = 0xF39C12FF,      -- Orange
  other = 0x7F8C8DFF,      -- Dark gray
}

-- Canvas colors
M.CANVAS = {
  BACKGROUND = 0x1A1A1AFF,
  GRID = 0x333333FF,
  GRID_MAJOR = 0x444444FF,
  PARENT_BORDER = 0x666666FF,
  PARENT_FILL = 0x222222FF,

  -- Selection
  SELECTED_BORDER = 0x00AAFFFF,
  SELECTED_FILL = 0x00AAFF20,

  -- Hover
  HOVER_BORDER = 0xFFFFFF80,
  HOVER_FILL = 0xFFFFFF10,

  -- Drag handles
  HANDLE_NORMAL = 0xFFFFFFFF,
  HANDLE_HOVER = 0x00FF00FF,
  HANDLE_ACTIVE = 0xFF0000FF,
}

-- Text colors
M.TEXT = {
  NORMAL = 0xCCCCCCFF,
  DIM = 0x888888FF,
  BRIGHT = 0xFFFFFFFF,
  ACCENT = 0x00AAFFFF,
  WARNING = 0xFFAA00FF,
  ERROR = 0xFF4444FF,
}

-- Panel colors
M.PANEL = {
  BACKGROUND = 0x1A1A1AFF,
  HEADER = 0x2A2A2AFF,
  BORDER = 0x333333FF,
  ITEM_HOVER = 0x333333FF,
  ITEM_SELECTED = 0x404040FF,
}

-- Helper: Convert RGBA to individual components
function M.unpack_rgba(color)
  local r = (color >> 24) & 0xFF
  local g = (color >> 16) & 0xFF
  local b = (color >> 8) & 0xFF
  local a = color & 0xFF
  return r, g, b, a
end

-- Helper: Create RGBA from components
function M.pack_rgba(r, g, b, a)
  return ((r & 0xFF) << 24) | ((g & 0xFF) << 16) | ((b & 0xFF) << 8) | (a & 0xFF)
end

-- Helper: Apply alpha to existing color
function M.with_alpha(color, alpha)
  return (color & 0xFFFFFF00) | (alpha & 0xFF)
end

-- Get behavior color for an element
function M.get_behavior_color(h_behavior, v_behavior)
  if h_behavior == "fixed" and v_behavior == "fixed" then
    return M.ATTACHMENT.FIXED
  elseif h_behavior == "stretch_end" or h_behavior == "stretch_start" then
    if v_behavior == "stretch_end" or v_behavior == "stretch_start" then
      return M.ATTACHMENT.STRETCH_BOTH
    else
      return M.ATTACHMENT.STRETCH_H
    end
  elseif v_behavior == "stretch_end" or v_behavior == "stretch_start" then
    return M.ATTACHMENT.STRETCH_V
  elseif h_behavior == "move" or v_behavior == "move" then
    return M.ATTACHMENT.MOVE
  else
    return M.ATTACHMENT.COMPLEX
  end
end

-- Get alpha version of behavior color
function M.get_behavior_color_alpha(h_behavior, v_behavior)
  if h_behavior == "fixed" and v_behavior == "fixed" then
    return M.ATTACHMENT_ALPHA.FIXED
  elseif h_behavior == "stretch_end" or h_behavior == "stretch_start" then
    if v_behavior == "stretch_end" or v_behavior == "stretch_start" then
      return M.ATTACHMENT_ALPHA.STRETCH_BOTH
    else
      return M.ATTACHMENT_ALPHA.STRETCH_H
    end
  elseif v_behavior == "stretch_end" or v_behavior == "stretch_start" then
    return M.ATTACHMENT_ALPHA.STRETCH_V
  elseif h_behavior == "move" or v_behavior == "move" then
    return M.ATTACHMENT_ALPHA.MOVE
  else
    return M.ATTACHMENT_ALPHA.COMPLEX
  end
end

return M
