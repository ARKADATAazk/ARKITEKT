-- @noindex
-- WalterBuilder/domain/coordinate.lua
-- CoordinateList model and math for WALTER coordinate system
--
-- WALTER coordinates: [x, y, w, h, left_attach, top_attach, right_attach, bottom_attach]
-- Attachments (0-1) control how edges scale with parent size:
--   0 = edge stays at absolute position
--   1 = edge moves with parent edge
--   0.5 = edge moves at half rate

local M = {}

-- Create a new coordinate list with defaults
function M.new(opts)
  opts = opts or {}
  return {
    x = opts.x or opts[1] or 0,
    y = opts.y or opts[2] or 0,
    w = opts.w or opts[3] or 0,
    h = opts.h or opts[4] or 0,
    ls = opts.ls or opts[5] or 0,  -- left scale/attach
    ts = opts.ts or opts[6] or 0,  -- top scale/attach
    rs = opts.rs or opts[7] or 0,  -- right scale/attach
    bs = opts.bs or opts[8] or 0,  -- bottom scale/attach
  }
end

-- Parse WALTER coordinate list string: '[0 0 20 20 0 0 1 1]'
function M.parse(str)
  if not str or str == '' then return nil end

  -- Extract values from brackets
  local values = {}
  for num in str:gmatch('[%-%.%d]+') do
    values[#values + 1] = tonumber(num)
  end

  if #values == 0 then return nil end

  return M.new({
    x = values[1] or 0,
    y = values[2] or 0,
    w = values[3] or 0,
    h = values[4] or 0,
    ls = values[5] or 0,
    ts = values[6] or 0,
    rs = values[7] or 0,
    bs = values[8] or 0,
  })
end

-- Serialize coordinate list to WALTER format
function M.serialize(coord)
  if not coord then return '[0]' end

  -- Check if we can use shortened form
  local parts = {coord.x, coord.y, coord.w, coord.h, coord.ls, coord.ts, coord.rs, coord.bs}

  -- Find last non-zero value
  local last_nonzero = 0
  for i = 8, 1, -1 do
    if parts[i] ~= 0 then
      last_nonzero = i
      break
    end
  end

  -- Build output with only necessary values
  if last_nonzero == 0 then
    return '[0]'
  end

  local out = {}
  for i = 1, last_nonzero do
    -- Format numbers nicely (no trailing decimals for integers)
    local v = parts[i]
    if v == math.floor(v) then
      out[i] = tostring(math.floor(v))
    else
      out[i] = string.format('%.2f', v):gsub('%.?0+$', '')
    end
  end

  return '[' .. table.concat(out, ' ') .. ']'
end

-- Compute actual rectangle given parent dimensions
-- This is the core WALTER simulation logic
function M.compute_rect(coord, parent_w, parent_h)
  if not coord then
    return { x = 0, y = 0, w = 0, h = 0 }
  end

  local x, y, w, h = coord.x, coord.y, coord.w, coord.h
  local ls, ts, rs, bs = coord.ls, coord.ts, coord.rs, coord.bs

  -- Handle negative coordinates without attachments as right/bottom-relative
  -- This is a common theme pattern where elements are positioned relative to
  -- a computed section boundary rather than using the attachment system
  if x < 0 and ls == 0 and rs == 0 then
    -- Negative x with no horizontal attachments = right-relative
    x = parent_w + x
  end
  if y < 0 and ts == 0 and bs == 0 then
    -- Negative y with no vertical attachments = bottom-relative
    y = parent_h + y
  end

  -- Handle negative dimensions (stretch from edge)
  -- e.g., w=-27 means 'stretch to 27px from right edge'
  if w < 0 and rs == 0 then
    w = parent_w - x + w
  end
  if h < 0 and bs == 0 then
    h = parent_h - y + h
  end

  -- Edge positions considering attachments
  -- Left edge = base_x + (left_attach * parent_width)
  -- Right edge = base_x + base_w + (right_attach * parent_width)
  local left = x + ls * parent_w
  local top = y + ts * parent_h
  local right = x + w + rs * parent_w
  local bottom = y + h + bs * parent_h

  return {
    x = left,
    y = top,
    w = right - left,
    h = bottom - top,
  }
end

-- Get attachment behavior type for an axis
-- Returns: 'fixed', 'stretch', 'move', 'scale'
function M.get_axis_behavior(start_attach, end_attach)
  local s, e = start_attach or 0, end_attach or 0

  if s == 0 and e == 0 then
    return 'fixed'  -- Both edges fixed - element doesn't respond to parent size
  elseif s == 0 and e ~= 0 then
    return 'stretch_end'  -- Start fixed, end moves - element stretches from start
  elseif s ~= 0 and e == 0 then
    return 'stretch_start'  -- Start moves, end fixed - element stretches from end
  elseif s == e then
    return 'move'  -- Both edges move equally - element moves, size stays constant
  else
    return 'scale'  -- Complex scaling behavior
  end
end

-- Get horizontal behavior
function M.get_horizontal_behavior(coord)
  return M.get_axis_behavior(coord.ls, coord.rs)
end

-- Get vertical behavior
function M.get_vertical_behavior(coord)
  return M.get_axis_behavior(coord.ts, coord.bs)
end

-- Clone a coordinate
function M.clone(coord)
  if not coord then return M.new() end
  return M.new({
    x = coord.x,
    y = coord.y,
    w = coord.w,
    h = coord.h,
    ls = coord.ls,
    ts = coord.ts,
    rs = coord.rs,
    bs = coord.bs,
  })
end

-- Check if two coordinates are equal
function M.equals(a, b)
  if not a and not b then return true end
  if not a or not b then return false end
  return a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h
    and a.ls == b.ls and a.ts == b.ts and a.rs == b.rs and a.bs == b.bs
end

-- Add two coordinates (for WALTER + operator)
function M.add(a, b)
  return M.new({
    x = a.x + b.x,
    y = a.y + b.y,
    w = a.w + b.w,
    h = a.h + b.h,
    ls = a.ls + b.ls,
    ts = a.ts + b.ts,
    rs = a.rs + b.rs,
    bs = a.bs + b.bs,
  })
end

-- Subtract coordinates (for WALTER - operator)
function M.subtract(a, b)
  return M.new({
    x = a.x - b.x,
    y = a.y - b.y,
    w = a.w - b.w,
    h = a.h - b.h,
    ls = a.ls - b.ls,
    ts = a.ts - b.ts,
    rs = a.rs - b.rs,
    bs = a.bs - b.bs,
  })
end

return M
