-- @noindex
-- ItemPicker/ui/performance_grid.lua
-- Performance-optimized grid wrapper for Item Picker
-- Adds resize handling with scroll position maintenance to prevent disorientation

local Grid = require('rearkitekt.gui.widgets.grid.core')

local M = {}

-- Wrap Grid.new to add performance optimizations specific to Item Picker
function M.new(opts)
  local base_grid = Grid.new(opts)

  -- Add resize tracking state
  base_grid._perf_last_avail_w = nil
  base_grid._perf_last_avail_h = nil

  -- Store original render method
  local original_render = base_grid.render

  -- Override render to add resize handling
  base_grid.render = function(self, ctx, items)
    -- Get available space BEFORE calling original render
    local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

    -- Detect resize
    local resize_threshold = 5  -- pixels - ignore tiny fluctuations
    local did_resize = false
    local anchor_item_idx = nil
    local anchor_item_y_offset = nil

    if self._perf_last_avail_w and self._perf_last_avail_h then
      local w_diff = math.abs(avail_w - self._perf_last_avail_w)
      local h_diff = math.abs(avail_h - self._perf_last_avail_h)
      did_resize = (w_diff > resize_threshold or h_diff > resize_threshold)

      -- Find anchor item to maintain view position
      if did_resize and #items > 0 then
        local mx, my = ImGui.GetMousePos(ctx)
        local window_x, window_y = ImGui.GetWindowPos(ctx)
        local scroll_y = ImGui.GetScrollY(ctx)

        -- Use mouse Y if over window, otherwise viewport center
        local anchor_y = my
        local mouse_in_window = (mx >= window_x and mx < window_x + avail_w and
                                 my >= window_y and my < window_y + avail_h)

        if not mouse_in_window then
          anchor_y = window_y + avail_h / 2
        end

        -- Find closest item to anchor point using current positions
        local min_dist = math.huge
        for i, item in ipairs(items) do
          local key = self.key(item)
          local current_rect = self.rect_track:get(key)
          if current_rect then
            local item_center_y = (current_rect[2] + current_rect[4]) / 2
            local dist = math.abs(item_center_y - anchor_y)
            if dist < min_dist then
              min_dist = dist
              anchor_item_idx = i
              -- Store offset from content origin (not window origin)
              anchor_item_y_offset = current_rect[2] - (window_y + scroll_y)
            end
          end
        end
      end
    end

    self._perf_last_avail_w = avail_w
    self._perf_last_avail_h = avail_h

    -- If resizing, we'll need to intercept the rect_track:to() calls and use teleport instead
    if did_resize then
      -- Store original :to method
      local original_to = self.rect_track.to

      -- Temporarily replace :to with :teleport during layout calculation
      self.rect_track.to = function(track, id, rect)
        track:teleport(id, rect)
      end

      -- Call original render (this will calculate layout and call rect_track:to)
      original_render(self, ctx, items)

      -- Restore original :to method
      self.rect_track.to = original_to

      -- Adjust scroll to maintain anchor item position
      if anchor_item_idx and anchor_item_idx <= #items then
        local key = self.key(items[anchor_item_idx])
        local new_rect = self.rect_track:get(key)

        if new_rect then
          local window_x, window_y = ImGui.GetWindowPos(ctx)
          local new_item_y = new_rect[2]
          local desired_scroll_y = new_item_y - window_y - anchor_item_y_offset

          -- Clamp to valid scroll range
          local max_scroll = ImGui.GetScrollMaxY(ctx)
          if max_scroll > 0 then
            desired_scroll_y = math.max(0, math.min(desired_scroll_y, max_scroll))
            ImGui.SetScrollY(ctx, desired_scroll_y)
          end
        end
      end
    else
      -- Normal render (smooth animations)
      original_render(self, ctx, items)
    end
  end

  return base_grid
end

return M
