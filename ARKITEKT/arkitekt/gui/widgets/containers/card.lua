-- @noindex
-- arkitekt/gui/widgets/containers/card.lua
-- Card container with accent bar - supports horizontal layouts

local ImGui = require('arkitekt.core.imgui')
local Colors = require('arkitekt.core.colors')

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  bg_color = 0x141414FF,        -- Dark background (RGB 20,20,20)
  border_color = 0x000000FF,    -- Black border
  header_color = 0x777777FF,    -- Header text color
  accent_color = nil,           -- Left accent bar + bottom glow
  accent_width = 3,             -- Accent bar width
  rounding = 6,                 -- Corner rounding
  padding = 10,                 -- Internal padding
  min_height = 0,               -- Minimum height (0 = auto)
  glow_height = 24,             -- Bottom glow gradient height
}

-- ============================================================================
-- STATE
-- ============================================================================

local card_stack = {}

-- ============================================================================
-- BEGIN / END
-- ============================================================================

function M.Begin(ctx, opts)
  opts = opts or {}

  local id = opts.id or 'card'
  local title = opts.title or ''
  local width = opts.width
  local min_height = opts.min_height or DEFAULTS.min_height

  local bg_color = opts.bg_color or DEFAULTS.bg_color
  local border_color = opts.border_color or DEFAULTS.border_color
  local header_color = opts.header_color or DEFAULTS.header_color
  local accent_color = opts.accent_color
  local accent_width = opts.accent_width or DEFAULTS.accent_width
  local rounding = opts.rounding or DEFAULTS.rounding
  local padding = opts.padding or DEFAULTS.padding
  local glow_height = opts.glow_height or DEFAULTS.glow_height

  -- Calculate width
  if not width or width == 0 then
    width = ImGui.GetContentRegionAvail(ctx)
  end

  -- Get starting position
  local start_x, start_y = ImGui.GetCursorScreenPos(ctx)

  -- Store state
  local state = {
    id = id,
    title = title,
    width = width,
    min_height = min_height,
    bg_color = bg_color,
    border_color = border_color,
    header_color = header_color,
    accent_color = accent_color,
    accent_width = accent_width,
    rounding = rounding,
    padding = padding,
    glow_height = glow_height,
    start_x = start_x,
    start_y = start_y,
  }
  table.insert(card_stack, state)

  -- Draw background first (before content)
  -- Use min_height or estimate for initial draw
  local bg_height = min_height > 0 and min_height or 80
  local dl = ImGui.GetWindowDrawList(ctx)
  if bg_color then
    ImGui.DrawList_AddRectFilled(dl, start_x, start_y, start_x + width, start_y + bg_height, bg_color, rounding)
  end

  -- Begin a group to contain everything
  ImGui.BeginGroup(ctx)

  -- Reserve width with invisible button (ensures consistent width)
  ImGui.InvisibleButton(ctx, '##card_width_' .. id, width, 1)

  -- Content area with padding
  local content_offset = padding
  if accent_color then
    content_offset = content_offset + accent_width + 2
  end

  -- Draw header
  if title ~= '' then
    ImGui.SetCursorScreenPos(ctx, start_x + content_offset, start_y + padding)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, header_color)
    ImGui.Text(ctx, title)
    ImGui.PopStyleColor(ctx)
  end

  -- Position cursor for content
  local content_y = start_y + padding
  if title ~= '' then
    content_y = content_y + ImGui.GetTextLineHeight(ctx) + 4
  end
  ImGui.SetCursorScreenPos(ctx, start_x + content_offset, content_y)

  return true
end

function M.End(ctx)
  if #card_stack == 0 then
    return
  end

  local state = table.remove(card_stack)

  -- Add bottom padding - submit a Dummy to extend group bounds
  local cur_x, cur_y = ImGui.GetCursorScreenPos(ctx)
  ImGui.SetCursorScreenPos(ctx, cur_x, cur_y + state.padding)
  ImGui.Dummy(ctx, state.width, 1)  -- Required after SetCursorScreenPos to grow group

  ImGui.EndGroup(ctx)

  -- Get group bounds
  local group_x1, group_y1 = ImGui.GetItemRectMin(ctx)
  local group_x2, group_y2 = ImGui.GetItemRectMax(ctx)

  -- Apply minimum height
  local height = group_y2 - state.start_y
  if state.min_height > 0 and height < state.min_height then
    height = state.min_height
    group_y2 = state.start_y + height
  end

  -- Card bounds
  local x1 = state.start_x
  local y1 = state.start_y
  local x2 = state.start_x + state.width
  local y2 = group_y2

  local dl = ImGui.GetWindowDrawList(ctx)

  -- Extend background if actual height exceeds initial estimate
  local initial_bg_height = state.min_height > 0 and state.min_height or 80
  if state.bg_color and height > initial_bg_height then
    -- Draw extension from initial height to actual height
    ImGui.DrawList_AddRectFilled(dl, x1, y1 + initial_bg_height, x2, y2,
      state.bg_color, state.rounding, ImGui.DrawFlags_RoundCornersBottom)
  end

  -- Draw bottom glow gradient (sunset effect)
  if state.accent_color and state.glow_height > 0 then
    local glow_h = math.min(state.glow_height, height * 0.5)  -- Don't exceed half the card
    local glow_top = y2 - glow_h
    local bands = 12  -- Number of gradient bands

    for i = 0, bands - 1 do
      local t = i / bands  -- 0 at top, approaching 1 at bottom
      local band_y1 = glow_top + (glow_h * i / bands)
      local band_y2 = glow_top + (glow_h * (i + 1) / bands)

      -- Opacity increases toward bottom: 0 -> 0.25 (subtle glow)
      local alpha = math.floor(t * t * 0.25 * 255)  -- Quadratic falloff for softer gradient
      local glow_color = Colors.WithOpacity(state.accent_color, alpha / 255)

      -- Draw band (respect rounding at bottom corners)
      local flags = 0
      if i == bands - 1 then
        flags = ImGui.DrawFlags_RoundCornersBottom
      end
      ImGui.DrawList_AddRectFilled(dl, x1, band_y1, x2, band_y2, glow_color, state.rounding, flags)
    end
  end

  -- Draw accent bar (left edge)
  if state.accent_color then
    ImGui.DrawList_AddRectFilled(dl, x1, y1, x1 + state.accent_width, y2,
      state.accent_color, state.rounding, ImGui.DrawFlags_RoundCornersLeft)
  end

  -- Draw border (dark)
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, state.border_color, state.rounding, 0, 1)

  -- Advance cursor to after the card (for proper layout)
  ImGui.SetCursorScreenPos(ctx, state.start_x, y2 + 4)
  ImGui.Dummy(ctx, state.width, 1)  -- Reserve space for layout
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return M
