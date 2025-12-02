-- @noindex
-- arkitekt/gui/widgets/experimental/audio/waveform.lua
-- EXPERIMENTAL: Waveform visualization widget for audio peak data
-- Extracted from ItemPicker visualization system
-- Displays audio waveform from peak data array with optional filling

local ImGui = require('arkitekt.platform.imgui')
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Performance: Cache ImGui functions
local DrawList_AddLine = ImGui.DrawList_AddLine
local DrawList_AddPolyline = ImGui.DrawList_AddPolyline
local DrawList_AddConvexPolyFilled = ImGui.DrawList_AddConvexPolyFilled

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = nil,

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  width = 400,
  height = 100,

  -- Data
  peaks = nil,          -- Peak data array (required) - format: [max1, max2, ..., min1, min2, ...]
  quality = 1.0,        -- Quality multiplier (0.5 = half resolution, 2.0 = double)

  -- State
  disabled = false,

  -- Style
  color = nil,          -- Waveform color
  is_filled = true,     -- Filled polygons vs outline

  -- Callbacks
  tooltip = nil,

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- STATE MANAGEMENT (for caching polylines)
-- ============================================================================

local instances = Base.create_instance_registry()

local function create_state(id)
  return {
    id = id,
    cached_polylines = {},  -- cache_key -> {norm_top, norm_bottom}
  }
end

-- ============================================================================
-- WAVEFORM PROCESSING
-- ============================================================================

--- Downsample waveform to target width for performance
--- @param waveform table Peak data array
--- @param target_width number Target pixel width
--- @return table Downsampled peak data
local function downsample_waveform(waveform, target_width)
  if not waveform then return nil end

  -- Cache math functions for performance
  local max = math.max
  local min = math.min
  local huge = math.huge

  local source_len = #waveform / 2
  if target_width >= source_len then
    return waveform
  end

  local downsampled = {}
  local samples_per_pixel = source_len / target_width

  -- Downsample using max-min aggregation
  for i = 1, target_width do
    local start_idx = (i - 1) * samples_per_pixel + 1
    local end_idx = i * samples_per_pixel

    -- Find max in range
    local max_val = -huge
    for j = start_idx, end_idx do
      local idx = j // 1  -- Floor to integer
      if idx >= 1 and idx <= source_len then
        max_val = max(max_val, waveform[idx])
      end
    end
    downsampled[i] = max_val

    -- Find min in range (second half of array)
    local min_val = huge
    for j = start_idx, end_idx do
      local idx = j // 1
      if idx >= 1 and idx <= source_len then
        min_val = min(min_val, waveform[source_len + idx])
      end
    end
    downsampled[target_width + i] = min_val
  end

  return downsampled
end

--- Generate normalized polyline coordinates (0-1 range) for caching
--- @param waveform table Peak data array
--- @return table, table norm_top, norm_bottom coordinate arrays
local function generate_normalized_polylines(waveform)
  if not waveform or #waveform == 0 then
    return nil, nil
  end

  local negative_index = #waveform / 2

  -- Top waveform (positive peaks)
  local norm_top = {}
  local norm_top_idx = 1
  for i = 1, negative_index do
    local max_val = waveform[i]
    if max_val then
      local norm_x = (i - 1) / (negative_index - 1)  -- Normalized X (0-1)
      local norm_y = max_val  -- Already normalized (-1 to 1)
      norm_top[norm_top_idx] = norm_x
      norm_top[norm_top_idx + 1] = norm_y
      norm_top_idx = norm_top_idx + 2
    end
  end

  -- Bottom waveform (negative peaks)
  local norm_bottom = {}
  local norm_bottom_idx = 1
  for i = 1, negative_index do
    local min_val = waveform[i + negative_index]
    if min_val then
      local norm_x = (i - 1) / (negative_index - 1)  -- Normalized X (0-1)
      local norm_y = min_val  -- Already normalized (-1 to 1)
      norm_bottom[norm_bottom_idx] = norm_x
      norm_bottom[norm_bottom_idx + 1] = norm_y
      norm_bottom_idx = norm_bottom_idx + 2
    end
  end

  return norm_top, norm_bottom
end

-- ============================================================================
-- RENDERING
-- ============================================================================

--- Render filled waveform using convex polygons
local function render_filled(dl, x, y, w, h, norm_top, norm_bottom, color)
  local waveform_height = h / 2 * 0.95
  local zero_line = y + h / 2

  -- Top polygon (max peaks + zero line closure)
  local top_fill_table = {}
  local top_idx = 1

  -- Top waveform points (left to right)
  for i = 1, #norm_top, 2 do
    top_fill_table[top_idx] = x + norm_top[i] * w  -- Scale X
    top_fill_table[top_idx + 1] = zero_line + norm_top[i + 1] * waveform_height  -- Scale Y
    top_idx = top_idx + 2
  end

  -- Close polygon along zero line (right to left)
  top_fill_table[top_idx] = x + w
  top_fill_table[top_idx + 1] = zero_line
  top_idx = top_idx + 2
  top_fill_table[top_idx] = x
  top_fill_table[top_idx + 1] = zero_line

  -- Bottom polygon (min peaks + zero line closure)
  local bottom_fill_table = {}
  local bottom_idx = 1

  -- Bottom waveform points (left to right)
  for i = 1, #norm_bottom, 2 do
    bottom_fill_table[bottom_idx] = x + norm_bottom[i] * w  -- Scale X
    bottom_fill_table[bottom_idx + 1] = zero_line + norm_bottom[i + 1] * waveform_height  -- Scale Y
    bottom_idx = bottom_idx + 2
  end

  -- Close polygon along zero line (right to left)
  bottom_fill_table[bottom_idx] = x + w
  bottom_fill_table[bottom_idx + 1] = zero_line
  bottom_idx = bottom_idx + 2
  bottom_fill_table[bottom_idx] = x
  bottom_fill_table[bottom_idx + 1] = zero_line

  -- Draw filled polygons
  if #top_fill_table >= 8 then  -- Need at least 4 points (8 values)
    local top_fill_array = reaper.new_array(top_fill_table)
    DrawList_AddConvexPolyFilled(dl, top_fill_array, color)
  end

  if #bottom_fill_table >= 8 then
    local bottom_fill_array = reaper.new_array(bottom_fill_table)
    DrawList_AddConvexPolyFilled(dl, bottom_fill_array, color)
  end
end

--- Render outline waveform using polylines
local function render_outline(dl, x, y, w, h, norm_top, norm_bottom, color)
  local waveform_height = h / 2 * 0.95
  local zero_line = y + h / 2

  -- Top polyline
  local top_points_table = {}
  local top_idx = 1
  for i = 1, #norm_top, 2 do
    top_points_table[top_idx] = x + norm_top[i] * w  -- Scale X
    top_points_table[top_idx + 1] = zero_line + norm_top[i + 1] * waveform_height  -- Scale Y
    top_idx = top_idx + 2
  end

  -- Bottom polyline
  local bottom_points_table = {}
  local bottom_idx = 1
  for i = 1, #norm_bottom, 2 do
    bottom_points_table[bottom_idx] = x + norm_bottom[i] * w  -- Scale X
    bottom_points_table[bottom_idx + 1] = zero_line + norm_bottom[i + 1] * waveform_height  -- Scale Y
    bottom_idx = bottom_idx + 2
  end

  -- Draw outline polylines
  if #top_points_table >= 4 then
    local top_array = reaper.new_array(top_points_table)
    DrawList_AddPolyline(dl, top_array, color, ImGui.DrawFlags_None, 1.0)
  end

  if #bottom_points_table >= 4 then
    local bottom_array = reaper.new_array(bottom_points_table)
    DrawList_AddPolyline(dl, bottom_array, color, ImGui.DrawFlags_None, 1.0)
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a waveform widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { width, height, hovered }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "waveform")

  -- Get or create state (for polyline caching)
  local state = Base.get_or_create_instance(instances, unique_id, create_state, ctx)

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local w = opts.width or 400
  local h = opts.height or 100

  -- Validate peak data
  local peaks = opts.peaks
  if not peaks or #peaks == 0 then
    -- No data - just draw placeholder
    local bg_color = Colors.with_opacity(Theme.COLORS.BG_BASE, 0.3)
    ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color)

    -- Advance cursor
    Base.advance_cursor(ctx, x, y, w, h, opts.advance)

    return Base.create_result({
      width = w,
      height = h,
      hovered = false,
    })
  end

  -- Apply quality multiplier to target width
  local quality = opts.quality or 1.0
  local target_width = (w * quality) // 1

  -- Downsample waveform if needed
  local display_waveform = downsample_waveform(peaks, target_width)

  -- Generate cache key
  local cache_key = string.format("%s_%d", unique_id, target_width)

  -- Check cache for normalized polylines
  local cached = state.cached_polylines[cache_key]
  local norm_top, norm_bottom

  if cached then
    norm_top = cached.norm_top
    norm_bottom = cached.norm_bottom
  else
    -- Generate and cache normalized coordinates
    norm_top, norm_bottom = generate_normalized_polylines(display_waveform)

    if norm_top and norm_bottom then
      state.cached_polylines[cache_key] = {
        norm_top = norm_top,
        norm_bottom = norm_bottom,
      }
    end
  end

  -- Get color
  local color = opts.color or Theme.COLORS.ACCENT_PRIMARY

  -- Render waveform
  if norm_top and norm_bottom then
    if opts.is_filled then
      render_filled(dl, x, y, w, h, norm_top, norm_bottom, color)
    else
      render_outline(dl, x, y, w, h, norm_top, norm_bottom, color)
    end
  end

  -- Create invisible button for interaction/tooltip
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, w, h)
  local hovered = ImGui.IsItemHovered(ctx)

  -- Tooltip
  if hovered and opts.tooltip then
    if ImGui.BeginTooltip(ctx) then
      ImGui.Text(ctx, opts.tooltip)
      ImGui.EndTooltip(ctx)
    end
  end

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, w, h, opts.advance)

  -- Return standardized result
  return Base.create_result({
    width = w,
    height = h,
    hovered = hovered,
  })
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.Waveform(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
