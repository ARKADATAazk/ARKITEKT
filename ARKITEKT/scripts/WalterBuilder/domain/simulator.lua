-- @noindex
-- WalterBuilder/domain/simulator.lua
-- Simulates WALTER layout given parent dimensions

local Coordinate = require('WalterBuilder.domain.coordinate')

local M = {}

-- Simulate a layout - compute all element rectangles for given parent size
function M.simulate(elements, parent_w, parent_h)
  local results = {}

  for _, element in ipairs(elements) do
    if element.visible then
      local rect = element:compute_rect(parent_w, parent_h)
      results[#results + 1] = {
        element = element,
        rect = rect,
        h_behavior = element:get_horizontal_behavior(),
        v_behavior = element:get_vertical_behavior(),
      }
    end
  end

  return results
end

-- Compute how an element changes between two parent sizes
-- Useful for visualizing stretch behavior
function M.compute_delta(element, size1, size2)
  local rect1 = element:compute_rect(size1.w, size1.h)
  local rect2 = element:compute_rect(size2.w, size2.h)

  return {
    dx = rect2.x - rect1.x,
    dy = rect2.y - rect1.y,
    dw = rect2.w - rect1.w,
    dh = rect2.h - rect1.h,
  }
end

-- Get attachment info for visualization
-- Returns which edges are "attached" (will move/stretch)
function M.get_attachment_info(element)
  local c = element.coords
  return {
    left = {
      attached = c.ls > 0,
      factor = c.ls,
    },
    top = {
      attached = c.ts > 0,
      factor = c.ts,
    },
    right = {
      attached = c.rs > 0,
      factor = c.rs,
    },
    bottom = {
      attached = c.bs > 0,
      factor = c.bs,
    },
  }
end

-- Classify how an element responds to resize
-- Returns a behavior descriptor
function M.classify_behavior(element)
  local h = element:get_horizontal_behavior()
  local v = element:get_vertical_behavior()

  -- Special case: completely fixed
  if h == "fixed" and v == "fixed" then
    return {
      type = "fixed",
      description = "Fixed size and position",
    }
  end

  -- Anchored to corner
  if h == "move" and v == "move" then
    local c = element.coords
    local h_anchor = c.ls == 1 and "right" or (c.ls == 0.5 and "center" or "left")
    local v_anchor = c.ts == 1 and "bottom" or (c.ts == 0.5 and "middle" or "top")
    return {
      type = "anchored",
      h_anchor = h_anchor,
      v_anchor = v_anchor,
      description = string.format("Anchored to %s-%s", v_anchor, h_anchor),
    }
  end

  -- Stretches horizontally
  if (h == "stretch_end" or h == "stretch_start") and (v == "fixed" or v == "move") then
    return {
      type = "stretch_horizontal",
      direction = h == "stretch_end" and "right" or "left",
      description = "Stretches horizontally",
    }
  end

  -- Stretches vertically
  if (v == "stretch_end" or v == "stretch_start") and (h == "fixed" or h == "move") then
    return {
      type = "stretch_vertical",
      direction = v == "stretch_end" and "down" or "up",
      description = "Stretches vertically",
    }
  end

  -- Stretches both ways
  if (h == "stretch_end" or h == "stretch_start") and (v == "stretch_end" or v == "stretch_start") then
    return {
      type = "stretch_both",
      description = "Stretches both directions",
    }
  end

  -- Complex behavior
  return {
    type = "complex",
    h_behavior = h,
    v_behavior = v,
    description = "Complex resize behavior",
  }
end

-- Calculate 9-slice zones for an element
-- This helps visualize which parts stretch vs stay fixed
function M.get_stretch_zones(element, parent_w, parent_h)
  local rect = element:compute_rect(parent_w, parent_h)
  local c = element.coords

  -- Determine stretch factors
  local h_stretches = (c.ls ~= c.rs)  -- Different L/R attachments = stretches
  local v_stretches = (c.ts ~= c.bs)  -- Different T/B attachments = stretches

  return {
    rect = rect,
    h_stretches = h_stretches,
    v_stretches = v_stretches,
    h_factor = c.rs - c.ls,  -- Horizontal stretch factor
    v_factor = c.bs - c.ts,  -- Vertical stretch factor
    h_offset = c.ls,  -- Horizontal movement factor
    v_offset = c.ts,  -- Vertical movement factor
  }
end

-- Hit test - find element at position
function M.hit_test(sim_results, x, y)
  -- Check in reverse order (top elements first in Z-order)
  for i = #sim_results, 1, -1 do
    local result = sim_results[i]
    local r = result.rect
    if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
      return result.element
    end
  end
  return nil
end

-- Find overlapping elements
function M.find_overlaps(sim_results)
  local overlaps = {}

  for i = 1, #sim_results - 1 do
    local r1 = sim_results[i].rect
    for j = i + 1, #sim_results do
      local r2 = sim_results[j].rect

      -- Check for rectangle intersection
      local intersects = not (r1.x + r1.w < r2.x or r2.x + r2.w < r1.x
                           or r1.y + r1.h < r2.y or r2.y + r2.h < r1.y)

      if intersects then
        overlaps[#overlaps + 1] = {
          element1 = sim_results[i].element,
          element2 = sim_results[j].element,
        }
      end
    end
  end

  return overlaps
end

return M
