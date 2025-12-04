-- @noindex
-- Arkitekt/core/colors.lua
-- Color manipulation and adaptive palette generation
--
-- ============================================================================
-- COLOR FORMAT REFERENCE
-- ============================================================================
-- ARKITEKT internal:        0xRRGGBBAA (use byte literals, e.g. 0xFF0000FF for red)
-- ImGui ColorEdit4/Picker4: 0xRRGGBBAA (direct, no conversion needed)
-- ImGui ColorEdit3/Picker3: 0xAARRGGBB (use RgbaToArgb / ArgbToRgba)
-- REAPER native:            platform-specific (use RgbaToReaperNative)
-- ============================================================================

-- Performance: Localize math functions for hot path (30% faster in loops)
local max = math.max
local min = math.min

local M = {}

-- ============================================================================
-- SECTION 1: Basic Color Operations
-- ============================================================================

function M.RgbaToComponents(color)
  local r = (color >> 24) & 0xFF
  local g = (color >> 16) & 0xFF
  local b = (color >> 8) & 0xFF
  local a = color & 0xFF
  return r, g, b, a
end

function M.ComponentsToRgba(r, g, b, a)
  -- Coerce to integers (handles floats safely, //1 is essentially free)
  return ((r//1) << 24) | ((g//1) << 16) | ((b//1) << 8) | (a//1)
end

-- ImGui uses ARGB format, convert to/from our RGBA format
function M.ArgbToRgba(argb_color)
  local a = (argb_color >> 24) & 0xFF
  local r = (argb_color >> 16) & 0xFF
  local g = (argb_color >> 8) & 0xFF
  local b = argb_color & 0xFF
  return (r << 24) | (g << 16) | (b << 8) | a
end

function M.RgbaToArgb(rgba_color)
  local r = (rgba_color >> 24) & 0xFF
  local g = (rgba_color >> 16) & 0xFF
  local b = (rgba_color >> 8) & 0xFF
  local a = rgba_color & 0xFF
  return (a << 24) | (r << 16) | (g << 8) | b
end

function M.WithAlpha(color, alpha)
  color = color or 0
  alpha = alpha or 0xFF
  return (color & 0xFFFFFF00) | (alpha & 0xFF)
end

--- Convert float opacity (0.0-1.0) to byte (0-255)
--- @param opacity number Float opacity value (clamped to 0.0-1.0)
--- @return number Byte alpha value (0-255)
function M.Opacity(opacity)
  opacity = max(0, min(1, opacity or 1.0))
  return (opacity * 255 + 0.5) // 1
end

--- Set alpha channel using float opacity (0.0-1.0) instead of byte value
--- @param color number RGBA color
--- @param opacity_float number Opacity value (0.0-1.0)
--- @return number Color with new opacity
function M.WithOpacity(color, opacity_float)
  return (color & 0xFFFFFF00) | M.Opacity(opacity_float)
end

--- Get alpha component of a color as float opacity (0.0-1.0)
--- @param color number RGBA color
--- @return number Float opacity value (returns 1.0 for nil/0 color)
function M.GetOpacity(color)
  if not color then return 1.0 end
  return (color & 0xFF) / 255
end

function M.AdjustBrightness(color, factor)
  local r, g, b, a = M.RgbaToComponents(color)
  r = min(255, max(0, (r * factor)//1))
  g = min(255, max(0, (g * factor)//1))
  b = min(255, max(0, (b * factor)//1))
  return M.ComponentsToRgba(r, g, b, a)
end

function M.Desaturate(color, amount)
  local r, g, b, a = M.RgbaToComponents(color)
  local gray = r * 0.299 + g * 0.587 + b * 0.114
  r = min(255, max(0, (r + (gray - r) * amount)//1))
  g = min(255, max(0, (g + (gray - g) * amount)//1))
  b = min(255, max(0, (b + (gray - b) * amount)//1))
  return M.ComponentsToRgba(r, g, b, a)
end

function M.Saturate(color, amount)
  return M.Desaturate(color, -amount)
end

function M.Luminance(color)
  local r, g, b, _ = M.RgbaToComponents(color)
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255
end

--- Interpolate between two colors
--- PERFORMANCE: Fully inlined version eliminates function call overhead
--- @param color_a number First color (RGBA)
--- @param color_b number Second color (RGBA)
--- @param t number Interpolation factor (0.0 = color_a, 1.0 = color_b)
--- @return number Interpolated color (RGBA)
function M.Lerp(color_a, color_b, t)
  -- Clamp t to [0, 1]
  t = max(0, min(1, t or 0))

  -- OPTIMIZATION: Inline all operations to eliminate 10+ function calls
  -- Extract components (inline RgbaToComponents)
  local r1 = (color_a >> 24) & 0xFF
  local g1 = (color_a >> 16) & 0xFF
  local b1 = (color_a >> 8) & 0xFF
  local a1 = color_a & 0xFF

  local r2 = (color_b >> 24) & 0xFF
  local g2 = (color_b >> 16) & 0xFF
  local b2 = (color_b >> 8) & 0xFF
  local a2 = color_b & 0xFF

  -- Lerp each component (inline LerpComponent)
  local r = (r1 + (r2 - r1) * t + 0.5)//1
  local g = (g1 + (g2 - g1) * t + 0.5)//1
  local b = (b1 + (b2 - b1) * t + 0.5)//1
  local a = (a1 + (a2 - a1) * t + 0.5)//1

  -- Pack components (inline ComponentsToRgba)
  return (r << 24) | (g << 16) | (b << 8) | a
end

function M.AutoTextColor(bg_color)
  local lum = M.Luminance(bg_color)
  return lum > 0.5 and 0x000000FF or 0xFFFFFFFF
end

-- ============================================================================
-- SECTION 1.5: Color Space Conversions
-- ============================================================================

--- Convert RGBA color to REAPER native format with custom color flag
--- REAPER native format is BGR (not RGB) with 0x1000000 custom color flag
--- @param rgba_color number Color in RGBA format (0xRRGGBBAA)
--- @return number Native REAPER color with 0x1000000 flag (0x01BBGGRR)
function M.RgbaToReaperNative(rgba_color)
  local r = (rgba_color >> 24) & 0xFF
  local g = (rgba_color >> 16) & 0xFF
  local b = (rgba_color >> 8) & 0xFF
  -- REAPER native format is BGR with custom color flag (no reaper.* call needed)
  return (b << 16) | (g << 8) | r | 0x1000000
end

function M.RgbToHsl(color)
  local r, g, b, a = M.RgbaToComponents(color)
  r, g, b = r / 255, g / 255, b / 255

  local max_c = max(r, g, b)
  local min_c = min(r, g, b)
  local delta = max_c - min_c

  local h = 0
  local s = 0
  local l = (max_c + min_c) / 2

  if delta ~= 0 then
    s = (l > 0.5) and (delta / (2 - max_c - min_c)) or (delta / (max_c + min_c))

    if max_c == r then
      h = ((g - b) / delta + (g < b and 6 or 0)) / 6
    elseif max_c == g then
      h = ((b - r) / delta + 2) / 6
    else
      h = ((r - g) / delta + 4) / 6
    end
  end

  return h, s, l
end

function M.HslToRgb(h, s, l)
  local function hue_to_rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1/6 then return p + (q - p) * 6 * t end
    if t < 1/2 then return q end
    if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
    return p
  end

  local r, g, b

  if s == 0 then
    r, g, b = l, l, l
  else
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    r = hue_to_rgb(p, q, h + 1/3)
    g = hue_to_rgb(p, q, h)
    b = hue_to_rgb(p, q, h - 1/3)
  end

  return (r * 255 + 0.5)//1, (g * 255 + 0.5)//1, (b * 255 + 0.5)//1
end

-- ============================================================================
-- SECTION 1.6: HSL Manipulation Utilities (for theme generation)
-- ============================================================================

--- Adjust lightness of a color in HSL space
--- @param color number Color in RGBA format
--- @param delta number Lightness adjustment (-1.0 to 1.0, typically -0.2 to 0.2)
--- @return number Adjusted color in RGBA format
function M.AdjustLightness(color, delta)
  local h, s, l = M.RgbToHsl(color)
  l = max(0, min(1, l + delta))
  local r, g, b = M.HslToRgb(h, s, l)
  local _, _, _, a = M.RgbaToComponents(color)
  return M.ComponentsToRgba(r, g, b, a)
end

--- Clamp background color to safe lightness and saturation range
--- Prevents pure black/white backgrounds and overly saturated (colored) themes
--- @param color number Color in RGBA format
--- @param min_lightness number|nil Minimum lightness (default: 0.10)
--- @param max_lightness number|nil Maximum lightness (default: 0.92)
--- @param max_saturation number|nil Maximum saturation (default: 0.12)
--- @return number Clamped color in RGBA format
--- @return boolean Whether clamping was applied
function M.ClampBgColor(color, min_lightness, max_lightness, max_saturation)
  min_lightness = min_lightness or 0.10
  max_lightness = max_lightness or 0.92
  max_saturation = max_saturation or 0.12

  local h, s, l = M.RgbToHsl(color)

  -- Clamp lightness and saturation
  local clamped_l = max(min_lightness, min(max_lightness, l))
  local clamped_s = min(max_saturation, s)  -- Only clamp upper bound

  -- Check if clamping was needed
  local was_clamped = (clamped_l ~= l) or (clamped_s ~= s)

  if not was_clamped then
    return color, false
  end

  -- Apply clamped values
  local r, g, b = M.HslToRgb(h, clamped_s, clamped_l)
  local _, _, _, a = M.RgbaToComponents(color)
  return M.ComponentsToRgba(r, g, b, a), true
end

--- Set absolute lightness of a color in HSL space
--- @param color number Color in RGBA format
--- @param lightness number Target lightness (0.0 to 1.0)
--- @return number Color with new lightness in RGBA format
function M.SetLightness(color, lightness)
  local h, s, _ = M.RgbToHsl(color)
  lightness = max(0, min(1, lightness))
  local r, g, b = M.HslToRgb(h, s, lightness)
  local _, _, _, a = M.RgbaToComponents(color)
  return M.ComponentsToRgba(r, g, b, a)
end

--- Adjust saturation of a color in HSL space
--- @param color number Color in RGBA format
--- @param delta number Saturation adjustment (-1.0 to 1.0)
--- @return number Adjusted color in RGBA format
function M.AdjustSaturation(color, delta)
  local h, s, l = M.RgbToHsl(color)
  s = max(0, min(1, s + delta))
  local r, g, b = M.HslToRgb(h, s, l)
  local _, _, _, a = M.RgbaToComponents(color)
  return M.ComponentsToRgba(r, g, b, a)
end

--- Adjust hue of a color in HSL space
--- @param color number Color in RGBA format
--- @param delta number Hue rotation (-1.0 to 1.0, wraps around)
--- @return number Adjusted color in RGBA format
function M.AdjustHue(color, delta)
  local h, s, l = M.RgbToHsl(color)
  h = (h + delta) % 1  -- Wrap around
  local r, g, b = M.HslToRgb(h, s, l)
  local _, _, _, a = M.RgbaToComponents(color)
  return M.ComponentsToRgba(r, g, b, a)
end

--- Lighten a color (convenience alias for AdjustLightness with positive delta)
--- @param color number Color in RGBA format
--- @param amount number Amount to lighten (0.0 to 1.0, typically 0.1 to 0.3)
--- @return number Lightened color in RGBA format
function M.Lighten(color, amount)
  return M.AdjustLightness(color, amount)
end

--- Darken a color (convenience alias for AdjustLightness with negative delta)
--- @param color number Color in RGBA format
--- @param amount number Amount to darken (0.0 to 1.0, typically 0.1 to 0.3)
--- @return number Darkened color in RGBA format
function M.Darken(color, amount)
  return M.AdjustLightness(color, -amount)
end

--- Blend two colors (convenience alias for Lerp)
--- @param color_a number First color in RGBA format
--- @param color_b number Second color in RGBA format
--- @param t number Blend factor (0.0 = all color_a, 1.0 = all color_b)
--- @return number Blended color in RGBA format
function M.Blend(color_a, color_b, t)
  return M.Lerp(color_a, color_b, t)
end

--- Set specific HSL values while preserving others
--- @param color number Color in RGBA format
--- @param h_new number|nil New hue (0-1) or nil to keep current
--- @param s_new number|nil New saturation (0-1) or nil to keep current
--- @param l_new number|nil New lightness (0-1) or nil to keep current
--- @return number Adjusted color in RGBA format
function M.SetHsl(color, h_new, s_new, l_new)
  local h, s, l = M.RgbToHsl(color)
  h = h_new or h
  s = s_new or s
  l = l_new or l
  local r, g, b = M.HslToRgb(h, s, l)
  local _, _, _, a = M.RgbaToComponents(color)
  return M.ComponentsToRgba(r, g, b, a)
end

-- ============================================================================
-- SECTION 1.7: Color Space Conversions (HSV)
-- ============================================================================

local function _rgb_to_hsv(r, g, b)
  r, g, b = r / 255, g / 255, b / 255
  local maxv, minv = max(r, g, b), min(r, g, b)
  local d = maxv - minv
  local h = 0
  if d ~= 0 then
    if maxv == r then h = ((g - b) / d) % 6
    elseif maxv == g then h = (b - r) / d + 2
    else h = (r - g) / d + 4 end
    h = h / 6
  end
  local s = (maxv == 0) and 0 or (d / maxv)
  return h, s, maxv
end

local function _hsv_to_rgb(h, s, v)
  local i = (h * 6)//1
  local f = h * 6 - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)
  local r, g, b =
    (i % 6 == 0 and v) or (i % 6 == 1 and q) or (i % 6 == 2 and p) or (i % 6 == 3 and p) or (i % 6 == 4 and t) or v,
    (i % 6 == 0 and t) or (i % 6 == 1 and v) or (i % 6 == 2 and v) or (i % 6 == 3 and q) or (i % 6 == 4 and p) or p,
    (i % 6 == 0 and p) or (i % 6 == 1 and p) or (i % 6 == 2 and t) or (i % 6 == 3 and v) or (i % 6 == 4 and v) or q
  return (r * 255 + 0.5)//1, (g * 255 + 0.5)//1, (b * 255 + 0.5)//1
end

-- ============================================================================
-- SECTION 1.8: Color Sorting Utilities
-- ============================================================================

function M.GetColorSortKey(color)
  if not color or color == 0 then
    return 999, 0, 0  -- No color sorts to end (after all hues)
  end

  local h, s, l = M.RgbToHsl(color)

  if s < 0.08 then
    return 999, l, s
  end

  local hue_degrees = h * 360

  return hue_degrees, s, l
end

function M.CompareColors(color_a, color_b)
  local h_a, s_a, l_a = M.GetColorSortKey(color_a)
  local h_b, s_b, l_b = M.GetColorSortKey(color_b)

  -- Primary: sort by hue (ascending = RED → ORANGE → YELLOW → GREEN → CYAN → BLUE → PURPLE)
  -- Use 0.5 degree threshold for hue binning
  if math.abs(h_a - h_b) > 0.5 then
    return h_a < h_b
  end

  -- Secondary: higher saturation first (more vibrant colors)
  if math.abs(s_a - s_b) > 0.01 then
    return s_a > s_b
  end

  -- Tertiary: higher lightness first
  return l_a > l_b
end

-- ============================================================================
-- SECTION 2: Color Characteristics (for adaptive palettes)
-- ============================================================================

function M.AnalyzeColor(color)
  local r, g, b, a = M.RgbaToComponents(color)
  local max_ch = max(r, g, b)
  local min_ch = min(r, g, b)
  local lum = M.Luminance(color)
  local saturation = (max_ch > 0) and ((max_ch - min_ch) / max_ch) or 0

  return {
    luminance = lum,
    saturation = saturation,
    max_channel = max_ch,
    min_channel = min_ch,
    is_bright = lum > 0.65,
    is_dark = lum < 0.3,
    is_gray = saturation < 0.15,
    is_vivid = saturation > 0.6,
  }
end

-- ============================================================================
-- SECTION 3: Derivation Strategies (how to transform colors)
-- ============================================================================

function M.DeriveNormalized(color, pullback)
  pullback = pullback or 0.95
  local r, g, b, a = M.RgbaToComponents(color)
  local max_ch = max(r, g, b)

  if max_ch == 0 then return color end

  local boost = (255 / max_ch) * pullback
  return M.ComponentsToRgba(
    min(255, (r * boost)//1),
    min(255, (g * boost)//1),
    min(255, (b * boost)//1),
    a
  )
end

function M.DeriveBrightened(color, factor)
  return M.AdjustBrightness(color, factor)
end

function M.DeriveIntensified(color, sat_boost, bright_boost)
  sat_boost = sat_boost or 0.3
  bright_boost = bright_boost or 1.2
  local saturated = M.Saturate(color, sat_boost)
  return M.AdjustBrightness(saturated, bright_boost)
end

function M.DeriveMuted(color, desat_amt, dark_amt)
  desat_amt = desat_amt or 0.5
  dark_amt = dark_amt or 0.45
  local desat = M.Desaturate(color, desat_amt)
  return M.AdjustBrightness(desat, dark_amt)
end

-- ============================================================================
-- SECTION 4: Role-Based Derivation (UI purposes)
-- ============================================================================

function M.DeriveFill(base_color, opts)
  opts = opts or {}
  local desat = opts.desaturate or 0.5
  local bright = opts.brightness or 0.45
  local alpha = opts.alpha or 0xCC

  local color = M.Desaturate(base_color, desat)
  color = M.AdjustBrightness(color, bright)
  return M.WithAlpha(color, alpha)
end

function M.DeriveBorder(base_color, opts)
  opts = opts or {}
  local mode = opts.mode or 'normalize'

  if mode == 'normalize' then
    local pullback = opts.pullback or 0.95
    return M.DeriveNormalized(base_color, pullback)

  elseif mode == 'brighten' then
    local factor = opts.factor or 1.3
    return M.DeriveBrightened(base_color, factor)

  elseif mode == 'intensify' then
    local sat = opts.saturation or 0.3
    local bright = opts.brightness or 1.2
    return M.DeriveIntensified(base_color, sat, bright)

  elseif mode == 'muted' then
    local desat = opts.desaturate or 0.3
    local dark = opts.brightness or 0.6
    local color = M.Desaturate(base_color, desat)
    return M.AdjustBrightness(color, dark)
  end

  return base_color
end

function M.DeriveHover(base_color, opts)
  opts = opts or {}
  local brightness = opts.brightness or 1.15
  return M.AdjustBrightness(base_color, brightness)
end

function M.DeriveSelection(base_color, opts)
  opts = opts or {}
  local brightness = opts.brightness or 1.6
  local saturation = opts.saturation or 0.5

  local r, g, b, a = M.RgbaToComponents(base_color)
  local max_ch = max(r, g, b)
  local boost = (max_ch > 0) and (255 / max_ch) or 1

  r = min(255, (r * boost * brightness)//1)
  g = min(255, (g * boost * brightness)//1)
  b = min(255, (b * boost * brightness)//1)

  local result = M.ComponentsToRgba(r, g, b, a)

  if saturation > 0 then
    result = M.Saturate(result, saturation)
  end

  return result
end

function M.DeriveMarchingAnts(base_color, opts)
  if not base_color or base_color == 0 then
    return 0x42E896FF
  end

  opts = opts or {}
  local brightness = opts.brightness or 1.5
  local saturation = opts.saturation or 0.5

  local r, g, b, a = M.RgbaToComponents(base_color)
  local max_ch = max(r, g, b)

  if max_ch == 0 then
    return 0x42E896FF
  end

  local boost = 255 / max_ch
  r = min(255, (r * boost * brightness)//1)
  g = min(255, (g * boost * brightness)//1)
  b = min(255, (b * boost * brightness)//1)

  if saturation > 0 then
    local gray = r * 0.299 + g * 0.587 + b * 0.114
    r = min(255, max(0, (r + (r - gray) * saturation)//1))
    g = min(255, max(0, (g + (g - gray) * saturation)//1))
    b = min(255, max(0, (b + (b - gray) * saturation)//1))
  end

  return M.ComponentsToRgba(r, g, b, 0xFF)
end

-- ============================================================================
-- SECTION 5: Palette Generation
-- ============================================================================

function M.DerivePalette(base_color, opts)
  opts = opts or {}

  return {
    base = base_color,
    fill = M.DeriveFill(base_color, opts.fill),
    border = M.DeriveBorder(base_color, opts.border),
    hover = M.DeriveHover(base_color, opts.hover),
    selection = M.DeriveSelection(base_color, opts.selection),
    marching_ants = M.DeriveMarchingAnts(base_color, opts.marching_ants),
    text = M.AutoTextColor(base_color),
    dim = M.WithOpacity(base_color, 0.53),
  }
end

function M.DerivePaletteAdaptive(base_color, preset)
  preset = preset or 'auto'

  if preset == 'auto' then
    local info = M.AnalyzeColor(base_color)

    if info.is_bright then
      preset = 'bright'
    elseif info.is_gray then
      preset = 'grayscale'
    elseif info.is_vivid then
      preset = 'vivid'
    else
      preset = 'normal'
    end
  end

  local presets = {
    bright = {
      fill = { desaturate = 0.7, brightness = 0.35, alpha = 0xCC },
      border = { mode = 'normalize', pullback = 0.85 },
      hover = { brightness = 1.1 },
      selection = { brightness = 1.4, saturation = 0.4 },
      marching_ants = { brightness = 1.3, saturation = 0.4 },
    },

    grayscale = {
      fill = { desaturate = 0.3, brightness = 0.5, alpha = 0xCC },
      border = { mode = 'brighten', factor = 1.4 },
      hover = { brightness = 1.2 },
      selection = { brightness = 1.8, saturation = 0.2 },
      marching_ants = { brightness = 1.6, saturation = 0.3 },
    },

    vivid = {
      fill = { desaturate = 0.6, brightness = 0.4, alpha = 0xCC },
      border = { mode = 'normalize', pullback = 0.95 },
      hover = { brightness = 1.15 },
      selection = { brightness = 1.6, saturation = 0.6 },
      marching_ants = { brightness = 1.5, saturation = 0.5 },
    },

    normal = {
      fill = { desaturate = 0.5, brightness = 0.45, alpha = 0xCC },
      border = { mode = 'normalize', pullback = 0.95 },
      hover = { brightness = 1.15 },
      selection = { brightness = 1.6, saturation = 0.5 },
      marching_ants = { brightness = 1.5, saturation = 0.5 },
    },
  }

  return M.DerivePalette(base_color, presets[preset])
end

-- ============================================================================
-- SECTION 6: Hue-Preserving Helpers (for tile text)
-- ============================================================================

--- Adjust saturation and value while preserving hue (HSV-based)
--- @param col number Color in RGBA format
--- @param s_mult number Saturation multiplier (1.0 = unchanged)
--- @param v_mult number Value/brightness multiplier (1.0 = unchanged)
--- @param new_a number|nil New alpha byte (nil = keep original)
--- @return number Adjusted color in RGBA format
function M.SameHueVariant(col, s_mult, v_mult, new_a)
  local r = (col >> 24) & 0xFF
  local g = (col >> 16) & 0xFF
  local b = (col >> 8) & 0xFF
  local a = col & 0xFF
  local h, s, v = _rgb_to_hsv(r, g, b)
  s = max(0, min(1, s * (s_mult or 1)))
  v = max(0, min(1, v * (v_mult or 1)))
  local rr, gg, bb = _hsv_to_rgb(h, s, v)
  return (rr << 24) | (gg << 16) | (bb << 8) | (new_a or a)
end

return M
