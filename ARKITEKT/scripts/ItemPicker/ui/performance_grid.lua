-- @noindex
-- ItemPicker/ui/performance_grid.lua
-- Performance-optimized grid wrapper for Item Picker
-- Adds resize handling with scroll position maintenance to prevent disorientation

local ImGui = require 'imgui' '0.10'
local Grid = require('rearkitekt.gui.widgets.grid.core')

local M = {}

-- Wrap Grid.new to add performance optimizations specific to Item Picker
function M.new(opts)
  local base_grid = Grid.new(opts)

  -- Add resize tracking state
  base_grid._perf_last_avail_w = nil
  base_grid._perf_last_avail_h = nil

  -- Store original draw method (not render!)
  local original_draw = base_grid.draw

  -- Override draw to add resize handling
  base_grid.draw = function(self, ctx)
    -- Get available space BEFORE calling original draw
    local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

    -- Detect resize
    local resize_threshold = 5  -- pixels - ignore tiny fluctuations
    local did_resize = false
    local scroll_percent = 0

    if self._perf_last_avail_w and self._perf_last_avail_h then
      local w_diff = math.abs(avail_w - self._perf_last_avail_w)
      local h_diff = math.abs(avail_h - self._perf_last_avail_h)
      did_resize = (w_diff > resize_threshold or h_diff > resize_threshold)

      -- Store scroll percentage before resize
      if did_resize then
        local scroll_y = ImGui.GetScrollY(ctx)
        local max_scroll = ImGui.GetScrollMaxY(ctx)
        if max_scroll > 0 then
          scroll_percent = scroll_y / max_scroll
        end
      end
    end

    self._perf_last_avail_w = avail_w
    self._perf_last_avail_h = avail_h

    -- If resizing, intercept rect_track:to() calls and use teleport instead
    if did_resize then
      -- Store original :to method
      local original_to = self.rect_track.to

      -- Temporarily replace :to with :teleport during layout calculation
      self.rect_track.to = function(track, id, rect)
        track:teleport(id, rect)
      end

      -- Call original draw (this will calculate layout and call rect_track:to)
      original_draw(self, ctx)

      -- Restore original :to method
      self.rect_track.to = original_to

      -- Restore scroll percentage
      local max_scroll = ImGui.GetScrollMaxY(ctx)
      if max_scroll > 0 then
        local new_scroll_y = scroll_percent * max_scroll
        ImGui.SetScrollY(ctx, new_scroll_y)
      end
    else
      -- Normal draw (smooth animations)
      original_draw(self, ctx)
    end
  end

  return base_grid
end

return M
