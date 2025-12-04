-- @noindex
-- Arkitekt/gui/fx/tile_fx_config.lua
-- Granular tile visual configuration
-- Theme-aware: reads from ThemeManager.get_current_rules() when available
--
-- PERF: Call begin_frame() once per frame before rendering tiles.
-- The get() function returns cached config to avoid per-tile overhead.

local Colors = require('arkitekt.core.colors')
local ImGui = require('arkitekt.core.imgui')

-- Performance: Localize ImGui functions
local CalcTextSize = ImGui.CalcTextSize
local GetFrameCount = ImGui.GetFrameCount

local M = {}

-- Per-frame cache
local _cached_config = nil
local _cached_frame = -1

-- ============================================================================
-- TEXT UTILITIES (cached per-frame for performance)
-- ============================================================================

-- Per-frame text measurement cache
local _text_cache = {
  ctx = nil,
  text_height = 0,
  separator_width = 0,
  ellipsis_width = 0,
}

-- Truncated text cache (persists across frames, keyed by item)
-- Structure: { [item_key] = { name = string, width = number, truncated = string } }
local _truncated_cache = {}
local _truncated_cache_frame = -1

--- Get cached text line height (measured once per frame)
--- @param ctx userdata ImGui context
--- @return number Text line height in pixels
function M.get_text_height(ctx)
  if _text_cache.ctx == ctx then
    return _text_cache.text_height
  end
  local _, h = CalcTextSize(ctx, 'Tg')
  _text_cache.ctx = ctx
  _text_cache.text_height = h
  return h
end

--- Get cached separator width (measured once per frame)
--- @param ctx userdata ImGui context
--- @return number Separator width in pixels
function M.get_separator_width(ctx)
  if _text_cache.ctx == ctx and _text_cache.separator_width > 0 then
    return _text_cache.separator_width
  end
  local w = CalcTextSize(ctx, ' ')
  _text_cache.separator_width = w
  _text_cache.ctx = ctx
  return w
end

--- Get cached ellipsis width (measured once per frame)
--- @param ctx userdata ImGui context
--- @return number Ellipsis width in pixels
function M.get_ellipsis_width(ctx)
  if _text_cache.ctx == ctx and _text_cache.ellipsis_width > 0 then
    return _text_cache.ellipsis_width
  end
  local w = CalcTextSize(ctx, '...')
  _text_cache.ellipsis_width = w
  _text_cache.ctx = ctx
  return w
end

--- Get or compute truncated text (cached by item key and width)
--- @param ctx userdata ImGui context
--- @param item_key string Unique item identifier
--- @param text string Full text to truncate
--- @param max_width number Maximum width in pixels
--- @return string Truncated text (with ellipsis if needed)
function M.get_truncated_text(ctx, item_key, text, max_width)
  if not text or max_width <= 0 then return '' end

  -- Round width to nearest 2px to avoid cache misses from floating point drift
  local width_key = ((max_width + 1) // 2) * 2

  -- Check cache
  local cached = _truncated_cache[item_key]
  if cached and cached.name == text and cached.width == width_key then
    return cached.truncated
  end

  -- Quick length-based estimate to skip CalcTextSize for short text
  local len = #text
  if len * 12 < max_width then
    -- Almost certainly fits - cache and return
    _truncated_cache[item_key] = { name = text, width = width_key, truncated = text }
    return text
  end

  -- Check if full text fits
  local text_width = CalcTextSize(ctx, text)
  if text_width <= max_width then
    _truncated_cache[item_key] = { name = text, width = width_key, truncated = text }
    return text
  end

  -- Need to truncate - use binary search
  local ellipsis_width = M.get_ellipsis_width(ctx)
  if max_width <= ellipsis_width then
    _truncated_cache[item_key] = { name = text, width = width_key, truncated = '' }
    return ''
  end

  local available_width = max_width - ellipsis_width
  local low, high = 1, len
  local best = 0

  while low <= high do
    local mid = (low + high) // 2
    local truncated = text:sub(1, mid)
    if CalcTextSize(ctx, truncated) <= available_width then
      best = mid
      low = mid + 1
    else
      high = mid - 1
    end
  end

  local result = best > 0 and (text:sub(1, best) .. '...') or '...'
  _truncated_cache[item_key] = { name = text, width = width_key, truncated = result }
  return result
end

--- Clear truncated text cache (call when items change significantly)
function M.clear_truncated_cache()
  _truncated_cache = {}
end

-- Static defaults (used as fallback when ThemeManager not available)
M.STATIC_DEFAULTS = {
  -- Shape
  rounding = 6,  -- Max rounding (scaled dynamically by responsive system)

  -- Fill layer (dark theme defaults)
  fill_opacity = 0.4,
  fill_saturation = 0.4,
  fill_brightness = 0.5,

  -- Border
  border_opacity = 1.0,
  border_saturation = 1,
  border_brightness = 1.6,
  border_thickness = 1.0,

  -- Index number (#1, #2, etc.) - region-colored
  index_saturation = 1,
  index_brightness = 1.6,

  -- Separator bullet (•) - region-colored
  separator_saturation = 1,
  separator_brightness = 1.6,
  separator_alpha = 0x99,

  -- Region name text - neutral white/gray (brightness adjusts the base neutral color)
  name_brightness = 1.0,
  name_base_color = 0xDDE3E9FF,

  -- Duration/bars text - region-colored
  duration_saturation = 0.3,
  duration_brightness = 1,
  duration_alpha = 0x88,

  -- Gradient
  gradient_intensity = 0.16,
  gradient_opacity = 0.03,

  -- Specular
  specular_strength = 0.06,
  specular_coverage = 0.25,

  -- Inner shadow
  inner_shadow_strength = 0.20,

  -- Marching ants (uses border_saturation and border_brightness for color)
  ants_enabled = true,
  ants_replace_border = true,
  ants_thickness = 1,
  ants_dash = 36,   -- 4x longer for fewer draw calls
  ants_gap = 27,
  ants_speed = 40,
  ants_inset = 0,
  ants_alpha = 0xFF,

  -- Selection glow
  glow_strength = 0.4,
  glow_layers = 3,

  -- Hover
  hover_fill_boost = 0.06,
  hover_specular_boost = 0.5,

  -- Diagonal stripes (for playlists)
  stripe_enabled = true,  -- Toggle on/off
  stripe_spacing = 10,     -- Distance between stripes in pixels
  stripe_thickness = 4,    -- Line thickness
  stripe_opacity = 0.02,   -- Opacity (0.0 to 1.0)
}

-- Legacy alias
M.DEFAULT = M.STATIC_DEFAULTS

--- Build fresh config from theme (internal, called by begin_frame)
local function _build_config()
  -- Try to get Theme (may not be loaded yet on first frame)
  local ok, Theme = pcall(require, 'arkitekt.theme')
  if not ok or not Theme or not Theme.COLORS then
    return M.STATIC_DEFAULTS
  end

  -- Build config: start with static defaults, override with Theme.COLORS values
  local config = {}
  for k, v in pairs(M.STATIC_DEFAULTS) do
    config[k] = v
  end

  -- Apply theme values from Theme.COLORS (single source of truth)
  if Theme.COLORS.TILE_FILL_BRIGHTNESS then
    config.fill_brightness = Theme.COLORS.TILE_FILL_BRIGHTNESS
  end
  if Theme.COLORS.TILE_FILL_SATURATION then
    config.fill_saturation = Theme.COLORS.TILE_FILL_SATURATION
  end
  if Theme.COLORS.TILE_FILL_OPACITY then
    config.fill_opacity = Theme.COLORS.TILE_FILL_OPACITY
  end
  if Theme.COLORS.TILE_NAME_COLOR then
    config.name_base_color = Theme.COLORS.TILE_NAME_COLOR
  end

  return config
end

--- Cache config for the current frame
--- Call once per frame before rendering tiles
--- @param ctx userdata ImGui context (used to get frame count)
function M.begin_frame(ctx)
  local frame = GetFrameCount(ctx)
  if frame ~= _cached_frame then
    _cached_config = _build_config()
    _cached_frame = frame
    -- Reset per-frame text cache when frame changes
    _text_cache.ctx = nil
  end
end

--- Get theme-aware tile config (cached per frame)
--- Call begin_frame() once per frame before using this
--- @return table Tile config with theme-appropriate values
function M.get()
  -- Return cached config if available, otherwise build fresh
  -- (This handles first-frame and cases where begin_frame wasn't called)
  if _cached_config then
    return _cached_config
  end
  return _build_config()
end

--- Get theme-aware config with custom overrides
--- @param overrides table Values to override from theme-aware defaults
--- @return table Merged config
function M.override(overrides)
  local base = M.get()  -- Use theme-aware values as base
  local config = {}
  for k, v in pairs(base) do
    config[k] = overrides[k] == nil and v or overrides[k]
  end
  return config
end

return M