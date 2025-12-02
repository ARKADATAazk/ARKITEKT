-- @noindex
-- arkitekt/core/cursor.lua
-- Cursor tracking and crossing detection utilities
-- Used for detecting fast cursor movement through trigger zones or item lists

local M = {}

-- ============================================================================
-- EDGE CROSSING DETECTION
-- ============================================================================
-- Detects when cursor crosses through a zone edge between frames
-- (for fast movement that might skip the hover zone)

--- Check if cursor crossed through an edge between frames
--- @param edge string Edge direction ('left', 'right', 'top', 'bottom')
--- @param prev_x number Previous cursor X (or nil if not tracked)
--- @param prev_y number Previous cursor Y (or nil if not tracked)
--- @param curr_x number Current cursor X
--- @param curr_y number Current cursor Y
--- @param bounds table Area bounds {x, y, w, h}
--- @param y_padding number? Vertical padding for Y range check (default 0)
--- @param x_padding number? Horizontal padding for X range check (default 0)
--- @return boolean True if cursor crossed through the edge
function M.crossed_edge(edge, prev_x, prev_y, curr_x, curr_y, bounds, y_padding, x_padding)
  if not prev_x or not prev_y then return false end

  y_padding = y_padding or 0
  x_padding = x_padding or 0

  if edge == 'left' then
    -- Was inside (right of left edge), now outside to the left
    local was_inside = prev_x > bounds.x
    local now_outside = curr_x < bounds.x
    local in_y_range = curr_y >= (bounds.y - y_padding) and curr_y <= (bounds.y + bounds.h + y_padding)
    return was_inside and now_outside and in_y_range

  elseif edge == 'right' then
    -- Was inside (left of right edge), now outside to the right
    local was_inside = prev_x < (bounds.x + bounds.w)
    local now_outside = curr_x > (bounds.x + bounds.w)
    local in_y_range = curr_y >= (bounds.y - y_padding) and curr_y <= (bounds.y + bounds.h + y_padding)
    return was_inside and now_outside and in_y_range

  elseif edge == 'top' then
    -- Was inside (below top edge), now outside above
    local was_inside = prev_y > bounds.y
    local now_outside = curr_y < bounds.y
    local in_x_range = curr_x >= (bounds.x - x_padding) and curr_x <= (bounds.x + bounds.w + x_padding)
    return was_inside and now_outside and in_x_range

  elseif edge == 'bottom' then
    -- Was inside (above bottom edge), now outside below
    local was_inside = prev_y < (bounds.y + bounds.h)
    local now_outside = curr_y > (bounds.y + bounds.h)
    local in_x_range = curr_x >= (bounds.x - x_padding) and curr_x <= (bounds.x + bounds.w + x_padding)
    return was_inside and now_outside and in_x_range
  end

  return false
end

-- ============================================================================
-- ITEM LIST CROSSING DETECTION
-- ============================================================================
-- Detects which items in a vertical/horizontal list were crossed between frames
-- (for paint-drag operations that might skip items with fast movement)

--- Get indices of items crossed between previous and current Y position
--- @param prev_y number Previous cursor Y
--- @param curr_y number Current cursor Y
--- @param first_item_y number Y position of first item's top edge
--- @param item_height number Height of each item (including margin)
--- @param item_count number Total number of items
--- @param scroll_offset number? Scroll offset to subtract (default 0)
--- @return table Array of crossed item indices (1-based)
function M.crossed_items_vertical(prev_y, curr_y, first_item_y, item_height, item_count, scroll_offset)
  if not prev_y or item_count <= 0 then return {} end

  scroll_offset = scroll_offset or 0

  -- Adjust for scroll
  local adj_prev_y = prev_y + scroll_offset
  local adj_curr_y = curr_y + scroll_offset

  -- Determine direction and range
  local min_y = math.min(adj_prev_y, adj_curr_y)
  local max_y = math.max(adj_prev_y, adj_curr_y)

  -- Find items in range
  local crossed = {}
  for i = 1, item_count do
    local item_top = first_item_y + (i - 1) * item_height
    local item_bottom = item_top + item_height

    -- Item is crossed if any part of it is within the cursor's travel range
    if item_bottom >= min_y and item_top <= max_y then
      crossed[#crossed + 1] = i
    end
  end

  return crossed
end

--- Get indices of items crossed between previous and current X position
--- @param prev_x number Previous cursor X
--- @param curr_x number Current cursor X
--- @param first_item_x number X position of first item's left edge
--- @param item_width number Width of each item (including margin)
--- @param item_count number Total number of items
--- @param scroll_offset number? Scroll offset to subtract (default 0)
--- @return table Array of crossed item indices (1-based)
function M.crossed_items_horizontal(prev_x, curr_x, first_item_x, item_width, item_count, scroll_offset)
  if not prev_x or item_count <= 0 then return {} end

  scroll_offset = scroll_offset or 0

  -- Adjust for scroll
  local adj_prev_x = prev_x + scroll_offset
  local adj_curr_x = curr_x + scroll_offset

  -- Determine range
  local min_x = math.min(adj_prev_x, adj_curr_x)
  local max_x = math.max(adj_prev_x, adj_curr_x)

  -- Find items in range
  local crossed = {}
  for i = 1, item_count do
    local item_left = first_item_x + (i - 1) * item_width
    local item_right = item_left + item_width

    -- Item is crossed if any part of it is within the cursor's travel range
    if item_right >= min_x and item_left <= max_x then
      crossed[#crossed + 1] = i
    end
  end

  return crossed
end

-- ============================================================================
-- CURSOR STATE HELPER
-- ============================================================================
-- Simple helper for tracking cursor position across frames

local CursorState = {}
CursorState.__index = CursorState

--- Create a new cursor state tracker
--- @return table CursorState instance
function M.new_state()
  return setmetatable({
    prev_x = nil,
    prev_y = nil,
    curr_x = nil,
    curr_y = nil,
  }, CursorState)
end

--- Update cursor state with new position
--- @param x number Current X position
--- @param y number Current Y position
function CursorState:update(x, y)
  self.prev_x = self.curr_x
  self.prev_y = self.curr_y
  self.curr_x = x
  self.curr_y = y
end

--- Get previous position
--- @return number|nil, number|nil Previous X and Y
function CursorState:get_previous()
  return self.prev_x, self.prev_y
end

--- Get current position
--- @return number|nil, number|nil Current X and Y
function CursorState:get_current()
  return self.curr_x, self.curr_y
end

--- Check if cursor crossed an edge
--- @param edge string Edge direction
--- @param bounds table Area bounds
--- @param y_padding number? Y padding
--- @param x_padding number? X padding
--- @return boolean
function CursorState:crossed_edge(edge, bounds, y_padding, x_padding)
  return M.crossed_edge(edge, self.prev_x, self.prev_y, self.curr_x, self.curr_y, bounds, y_padding, x_padding)
end

--- Get crossed items in vertical list
--- @param first_item_y number First item Y
--- @param item_height number Item height
--- @param item_count number Item count
--- @param scroll_offset number? Scroll offset
--- @return table Crossed indices
function CursorState:crossed_items_vertical(first_item_y, item_height, item_count, scroll_offset)
  return M.crossed_items_vertical(self.prev_y, self.curr_y, first_item_y, item_height, item_count, scroll_offset)
end

--- Reset state
function CursorState:reset()
  self.prev_x = nil
  self.prev_y = nil
  self.curr_x = nil
  self.curr_y = nil
end

return M
