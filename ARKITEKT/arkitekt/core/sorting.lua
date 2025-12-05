-- @noindex
-- arkitekt/core/sorting.lua
-- Reusable sorting utilities for lists with common comparators

local Colors = require('arkitekt.core.colors')

-- Performance: Localize math functions
local abs = abs

local M = {}

-- =============================================================================
-- BUILT-IN COMPARATORS
-- =============================================================================

-- Alphabetical comparison (case-insensitive)
-- Accessor: item.name (override with opts.get_value)
function M.compare_alpha(a, b, opts)
  opts = opts or {}
  local get = opts.get_value or function(x) return x.name or '' end
  local val_a = get(a) or ''
  local val_b = get(b) or ''
  return val_a:lower() < val_b:lower()
end

-- Numeric index comparison
-- Accessor: item.index or item.rid (override with opts.get_value)
function M.compare_index(a, b, opts)
  opts = opts or {}
  local get = opts.get_value or function(x) return x.index or x.rid or 0 end
  return get(a) < get(b)
end

-- Length/duration comparison
-- Accessor: item.length or (item['end'] - item.start) (override with opts.get_value)
function M.compare_length(a, b, opts)
  opts = opts or {}
  local get = opts.get_value or function(x)
    if x.length then return x.length end
    if x.total_duration then return x.total_duration end
    return (x['end'] or 0) - (x.start or 0)
  end
  return get(a) < get(b)
end

-- Color comparison by hue (RED → ORANGE → YELLOW → GREEN → CYAN → BLUE → PURPLE)
-- Grayscale colors sort to the end
-- Accessor: item.color or item.chip_color (override with opts.get_value)
function M.compare_color(a, b, opts)
  opts = opts or {}
  local get = opts.get_value or function(x) return x.color or x.chip_color or 0 end

  local color_a = get(a)
  local color_b = get(b)

  -- Get hue-based sort keys
  local h_a, s_a, l_a = M.get_color_sort_key(color_a)
  local h_b, s_b, l_b = M.get_color_sort_key(color_b)

  -- Primary: sort by hue (ascending = red→purple)
  if abs(h_a - h_b) > 0.5 then
    return h_a < h_b
  end

  -- Secondary: higher saturation first (more vibrant)
  if abs(s_a - s_b) > 0.01 then
    return s_a > s_b
  end

  -- Tertiary: higher lightness first
  return l_a > l_b
end

-- Get sort key for a color (hue in degrees, with grayscale at end)
-- Returns: hue (0-360, or 999 for grayscale), saturation, lightness
function M.get_color_sort_key(color)
  if not color or color == 0 then
    return 999, 0, 0  -- No color sorts to end
  end

  local h, s, l = Colors.RgbToHsl(color)

  -- Grayscale (low saturation) sorts to end
  if s < 0.08 then
    return 999, l, s
  end

  -- Convert hue to degrees (0-360)
  local hue_degrees = h * 360

  return hue_degrees, s, l
end

-- =============================================================================
-- COMPARATOR REGISTRY
-- =============================================================================

-- Built-in comparators lookup table
M.COMPARATORS = {
  alpha = M.compare_alpha,
  alphabetical = M.compare_alpha,  -- Alias
  name = M.compare_alpha,          -- Alias
  index = M.compare_index,
  length = M.compare_length,
  duration = M.compare_length,     -- Alias
  color = M.compare_color,
}

-- Register a custom comparator
-- @param name string Comparator name
-- @param comparator function(a, b, opts) -> boolean
function M.register(name, comparator)
  M.COMPARATORS[name] = comparator
end

-- =============================================================================
-- MAIN SORTING API
-- =============================================================================

-- Apply sorting to a list (in place)
-- @param list table The list to sort
-- @param opts table Options:
--   mode: string (comparator name) or function(a, b, opts) -> boolean
--   direction: 'asc' (default) or 'desc'
--   get_value: optional accessor function for the comparator
-- @return table The sorted list (same reference)
function M.apply(list, opts)
  if not list then return {} end
  opts = opts or {}
  local mode = opts.mode
  local direction = opts.direction or 'asc'

  -- No mode = no sorting
  if not mode then
    return list
  end

  -- Resolve comparator (string lookup or direct function)
  local comparator
  if type(mode) == 'function' then
    comparator = mode
  else
    comparator = M.COMPARATORS[mode]
  end

  if not comparator then
    return list  -- Unknown mode, no sorting
  end

  -- Sort with comparator
  table.sort(list, function(a, b)
    return comparator(a, b, opts)
  end)

  -- Reverse if descending
  if direction == 'desc' then
    M.reverse(list)
  end

  return list
end

-- Reverse a list in place
-- @param list table The list to reverse
-- @return table The reversed list (same reference)
function M.reverse(list)
  if not list then return {} end
  local n = #list
  for i = 1, n // 2 do
    list[i], list[n - i + 1] = list[n - i + 1], list[i]
  end
  return list
end

-- =============================================================================
-- CONVENIENCE WRAPPERS
-- =============================================================================

-- Sort by alphabetical order
function M.by_alpha(list, direction)
  return M.apply(list, { mode = 'alpha', direction = direction })
end

-- Sort by index
function M.by_index(list, direction)
  return M.apply(list, { mode = 'index', direction = direction })
end

-- Sort by length/duration
function M.by_length(list, direction)
  return M.apply(list, { mode = 'length', direction = direction })
end

-- Sort by color (hue order)
function M.by_color(list, direction)
  return M.apply(list, { mode = 'color', direction = direction })
end

return M
