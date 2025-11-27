-- @noindex
-- WalterBuilder/ui/canvas/track_renderer.lua
-- Renders TCP tracks vertically on the canvas

local ImGui = require 'imgui' '0.10'
local ark = require('arkitekt')
local TrackDefaults = require('WalterBuilder.defs.track_defaults')

local hexrgb = ark.Colors.hexrgb

local M = {}
local Renderer = {}
Renderer.__index = Renderer

-- Track visualization colors
local COLORS = {
  -- Track backgrounds
  BG_NORMAL = hexrgb("#1E1E1E"),
  BG_SELECTED = hexrgb("#2A3A4A"),
  BG_ARMED = hexrgb("#3A2A2A"),
  BG_FOLDER = hexrgb("#252525"),

  -- Track borders
  BORDER_NORMAL = hexrgb("#3A3A3A"),
  BORDER_SELECTED = hexrgb("#5588CC"),
  BORDER_FOLDER = hexrgb("#4A4A4A"),

  -- Text colors
  TEXT_NORMAL = hexrgb("#AAAAAA"),
  TEXT_SELECTED = hexrgb("#FFFFFF"),
  TEXT_MUTED = hexrgb("#666666"),

  -- State indicators
  ARMED = hexrgb("#CC4444"),
  MUTED = hexrgb("#888844"),
  SOLOED = hexrgb("#44AA44"),

  -- Folder indent
  FOLDER_LINE = hexrgb("#4A4A4AFF"),

  -- Separator
  SEPARATOR = hexrgb("#2A2A2A"),
}

function M.new(opts)
  opts = opts or {}

  local self = setmetatable({
    -- Folder indent per level (pixels)
    folder_indent = opts.folder_indent or 18,

    -- Show track numbers
    show_numbers = opts.show_numbers ~= false,

    -- Show folder lines
    show_folder_lines = opts.show_folder_lines ~= false,
  }, Renderer)

  return self
end

-- Get background color for a track
function Renderer:get_track_bg_color(track, is_selected)
  if is_selected then
    return COLORS.BG_SELECTED
  elseif track.armed then
    return COLORS.BG_ARMED
  elseif track.folder_state ~= 0 then
    return COLORS.BG_FOLDER
  else
    return COLORS.BG_NORMAL
  end
end

-- Get border color for a track
function Renderer:get_track_border_color(track, is_selected)
  if is_selected then
    return COLORS.BORDER_SELECTED
  elseif track.folder_state ~= 0 then
    return COLORS.BORDER_FOLDER
  else
    return COLORS.BORDER_NORMAL
  end
end

-- Draw a single track
function Renderer:draw_track(ctx, dl, x, y, w, track, opts)
  opts = opts or {}
  local is_selected = opts.selected or false
  local track_index = opts.index or 0

  local h = track.height
  local indent = track.folder_depth * self.folder_indent

  -- Track background
  local bg_color = self:get_track_bg_color(track, is_selected)

  -- Custom track color overlay
  if track.color then
    -- Blend custom color with background
    local r = (track.color >> 24) & 0xFF
    local g = (track.color >> 16) & 0xFF
    local b = (track.color >> 8) & 0xFF
    -- Draw a subtle color strip on the left
    ImGui.DrawList_AddRectFilled(dl, x, y, x + 4, y + h, track.color)
    -- Tint the background slightly
    local tint = ((r // 4) << 24) | ((g // 4) << 16) | ((b // 4) << 8) | 0x40
    bg_color = bg_color + (tint & 0x1F1F1F40)
  end

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x + indent, y, x + w, y + h, bg_color)

  -- Border (bottom separator)
  ImGui.DrawList_AddLine(dl, x, y + h - 1, x + w, y + h - 1, COLORS.SEPARATOR, 1)

  -- Selection border
  if is_selected then
    ImGui.DrawList_AddRect(dl, x + indent, y, x + w, y + h, COLORS.BORDER_SELECTED, 0, 0, 2)
  end

  -- Folder indent lines
  if self.show_folder_lines and track.folder_depth > 0 then
    for i = 1, track.folder_depth do
      local line_x = x + (i - 1) * self.folder_indent + 8
      ImGui.DrawList_AddLine(dl, line_x, y, line_x, y + h, COLORS.FOLDER_LINE, 1)
    end
  end

  -- Track number
  local text_x = x + indent + 8
  local text_y = y + 4

  if self.show_numbers then
    local num_str = tostring(track_index)
    local num_color = is_selected and COLORS.TEXT_SELECTED or COLORS.TEXT_MUTED
    ImGui.DrawList_AddText(dl, text_x, text_y, num_color, num_str)
    text_x = text_x + 20
  end

  -- Folder icon
  if track.folder_state == 1 then
    -- Open folder
    ImGui.DrawList_AddText(dl, text_x, text_y, COLORS.TEXT_NORMAL, "▼")
    text_x = text_x + 14
  elseif track.folder_state == -1 or track.folder_state == -2 then
    -- Closed folder or last in folder
    ImGui.DrawList_AddText(dl, text_x, text_y, COLORS.TEXT_MUTED, "▶")
    text_x = text_x + 14
  end

  -- Track name
  local name_color = is_selected and COLORS.TEXT_SELECTED
                   or (track.muted and COLORS.TEXT_MUTED or COLORS.TEXT_NORMAL)
  ImGui.DrawList_AddText(dl, text_x, text_y, name_color, track.name)

  -- State indicators (right side)
  local indicator_x = x + w - 50

  -- Armed indicator
  if track.armed then
    ImGui.DrawList_AddRectFilled(dl, indicator_x, y + 4, indicator_x + 12, y + 16, COLORS.ARMED, 2)
    ImGui.DrawList_AddText(dl, indicator_x + 2, y + 3, 0xFFFFFFFF, "R")
    indicator_x = indicator_x - 16
  end

  -- Mute indicator
  if track.muted then
    ImGui.DrawList_AddRectFilled(dl, indicator_x, y + 4, indicator_x + 12, y + 16, COLORS.MUTED, 2)
    ImGui.DrawList_AddText(dl, indicator_x + 2, y + 3, 0xFFFFFFFF, "M")
    indicator_x = indicator_x - 16
  end

  -- Solo indicator
  if track.soloed then
    ImGui.DrawList_AddRectFilled(dl, indicator_x, y + 4, indicator_x + 12, y + 16, COLORS.SOLOED, 2)
    ImGui.DrawList_AddText(dl, indicator_x + 2, y + 3, 0xFFFFFFFF, "S")
  end

  return h
end

-- Draw all tracks
function Renderer:draw_tracks(ctx, dl, x, y, w, tracks, opts)
  opts = opts or {}
  local selected_track = opts.selected_track

  local current_y = y
  local total_height = 0

  for i, track in ipairs(tracks) do
    if track.visible then
      local is_selected = (track == selected_track)

      local h = self:draw_track(ctx, dl, x, current_y, w, track, {
        selected = is_selected,
        index = i,
      })

      current_y = current_y + h
      total_height = total_height + h
    end
  end

  return total_height
end

-- Draw elements within a track context
function Renderer:draw_track_elements(ctx, dl, track_x, track_y, track_w, track, elements, element_renderer, opts)
  opts = opts or {}

  -- Elements are drawn relative to the track position
  -- The track acts as the "parent" container for WALTER coordinates
  local track_h = track.height
  local indent = track.folder_depth * self.folder_indent

  -- Adjust for folder indent
  local content_x = track_x + indent
  local content_w = track_w - indent

  -- Draw each element positioned within this track
  for _, elem in ipairs(elements) do
    -- Compute element rectangle using track as parent
    local rect = elem:compute_rect(content_w, track_h)

    -- Offset by track position
    rect.x = rect.x + content_x
    rect.y = rect.y + track_y

    -- Draw using the element renderer
    if element_renderer then
      element_renderer:draw_element_at_rect(ctx, dl, rect, elem, opts)
    end
  end
end

return M
