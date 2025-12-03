-- @noindex
-- arkitekt/gui/widgets/experimental/spectrum_analyzer.lua
-- EXPERIMENTAL: Spectrum analyzer visualization for frequency domain analysis
-- Displays FFT bins as vertical bars with logarithmic frequency and dB scaling

local ImGui = require('arkitekt.platform.imgui')
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- dB color thresholds (matches VUMeter)
local DB_GREEN = -18
local DB_YELLOW = -9
local DB_ORANGE = -3
local DB_RED = 0

-- Default frequency range for display
local DEFAULT_MIN_FREQ = 20     -- Hz
local DEFAULT_MAX_FREQ = 20000  -- Hz

-- Performance: Cache ImGui functions
local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled
local DrawList_AddLine = ImGui.DrawList_AddLine

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
  height = 150,

  -- Data
  bins = nil,           -- FFT magnitude data (required) - array of dB values
  bin_count = nil,      -- Number of bins (default = #bins)
  min_freq = 20,        -- Minimum frequency (Hz)
  max_freq = 20000,     -- Maximum frequency (Hz)
  sample_rate = 44100,  -- Sample rate for frequency calculation

  -- Range
  min_db = -60,         -- Minimum dB level
  max_db = 0,           -- Maximum dB level

  -- State
  disabled = false,

  -- Style
  color = nil,              -- Single color mode
  is_gradient = true,       -- Use gradient colors (green → yellow → orange → red)
  color_green = nil,
  color_yellow = nil,
  color_orange = nil,
  color_red = nil,
  bg_color = nil,           -- Background color (optional)
  bar_spacing = 1,          -- Spacing between bars (pixels)
  bar_rounding = 0,         -- Bar corner rounding

  -- Display
  is_logarithmic = true,    -- Logarithmic frequency spacing
  show_grid = false,        -- Show frequency grid lines
  show_peak_hold = false,   -- Show peak hold indicators

  -- Callbacks
  tooltip = nil,

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Convert linear magnitude to dB
local function magnitude_to_db(mag)
  if mag <= 0 then return -math.huge end
  return 20 * math.log(mag, 10)
end

--- Map frequency to X position (linear or logarithmic)
local function freq_to_x(freq, min_freq, max_freq, width, is_log)
  if is_log then
    local log_min = math.log(min_freq)
    local log_max = math.log(max_freq)
    local log_freq = math.log(freq)
    return ((log_freq - log_min) / (log_max - log_min)) * width
  else
    return ((freq - min_freq) / (max_freq - min_freq)) * width
  end
end

--- Get color for dB level
local function get_level_color(db, opts)
  if not opts.is_gradient or opts.color then
    return opts.color or Theme.COLORS.ACCENT_PRIMARY
  end

  local color_green = opts.color_green or Colors.hexrgb("#33FF66")
  local color_yellow = opts.color_yellow or Colors.hexrgb("#FFFF33")
  local color_orange = opts.color_orange or Colors.hexrgb("#FF9933")
  local color_red = opts.color_red or Colors.hexrgb("#FF3333")

  if db >= DB_RED then
    return color_red
  elseif db >= DB_ORANGE then
    -- Interpolate between orange and red
    local t = (db - DB_ORANGE) / (DB_RED - DB_ORANGE)
    return Colors.lerp_color(color_orange, color_red, t)
  elseif db >= DB_YELLOW then
    -- Interpolate between yellow and orange
    local t = (db - DB_YELLOW) / (DB_ORANGE - DB_YELLOW)
    return Colors.lerp_color(color_yellow, color_orange, t)
  elseif db >= DB_GREEN then
    -- Interpolate between green and yellow
    local t = (db - DB_GREEN) / (DB_YELLOW - DB_GREEN)
    return Colors.lerp_color(color_green, color_yellow, t)
  else
    return color_green
  end
end

--- Normalize dB value to 0-1 range
local function normalize_db(db, min_db, max_db)
  if db <= min_db then return 0 end
  if db >= max_db then return 1 end
  return (db - min_db) / (max_db - min_db)
end

-- ============================================================================
-- RENDERING
-- ============================================================================

--- Render spectrum analyzer bars
local function render_spectrum(ctx, dl, x, y, w, h, bins, opts)
  local bin_count = opts.bin_count or #bins
  local bar_spacing = opts.bar_spacing or 1
  local bar_width = (w / bin_count) - bar_spacing

  if bar_width < 1 then
    bar_width = 1
    bar_spacing = 0
  end

  -- Calculate frequency per bin
  local nyquist = opts.sample_rate / 2
  local freq_per_bin = nyquist / bin_count

  -- Render bars
  for i = 1, bin_count do
    local bin_db = bins[i] or opts.min_db

    -- Calculate frequency for this bin
    local bin_freq = (i - 1) * freq_per_bin

    -- Skip bins outside frequency range
    if bin_freq >= opts.min_freq and bin_freq <= opts.max_freq then
      -- Calculate X position (logarithmic or linear)
      local bar_x
      if opts.is_logarithmic then
        bar_x = x + freq_to_x(bin_freq, opts.min_freq, opts.max_freq, w, true)
      else
        bar_x = x + ((i - 1) / bin_count) * w
      end

      -- Calculate bar height based on dB level
      local normalized = normalize_db(bin_db, opts.min_db, opts.max_db)
      local bar_h = normalized * h

      if bar_h > 0 then
        local bar_y = y + h - bar_h

        -- Get color for this dB level
        local color = get_level_color(bin_db, opts)

        -- Draw bar
        DrawList_AddRectFilled(dl, bar_x, bar_y, bar_x + bar_width, y + h, color, opts.bar_rounding or 0)
      end
    end
  end
end

--- Render frequency grid lines (optional)
local function render_grid(ctx, dl, x, y, w, h, opts)
  -- Standard frequency markers: 100Hz, 1kHz, 10kHz
  local markers = {100, 1000, 10000}
  local grid_color = Colors.with_opacity(Theme.COLORS.TEXT_NORMAL or Colors.hexrgb("#FFFFFF"), 0.2)

  for _, freq in ipairs(markers) do
    if freq >= opts.min_freq and freq <= opts.max_freq then
      local marker_x = x + freq_to_x(freq, opts.min_freq, opts.max_freq, w, opts.is_logarithmic)
      DrawList_AddLine(dl, marker_x, y, marker_x, y + h, grid_color, 1)
    end
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a spectrum analyzer widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { width, height, hovered }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "spectrum_analyzer")

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local w = opts.width or 400
  local h = opts.height or 150

  -- Validate bin data
  local bins = opts.bins
  if not bins or #bins == 0 then
    -- No data - draw placeholder
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

  -- Background (optional)
  if opts.bg_color then
    ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, opts.bg_color)
  end

  -- Render grid (optional)
  if opts.show_grid then
    render_grid(ctx, dl, x, y, w, h, opts)
  end

  -- Render spectrum
  render_spectrum(ctx, dl, x, y, w, h, bins, opts)

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
-- CONVENIENCE CONSTRUCTORS
-- ============================================================================

--- Standard spectrum analyzer (20Hz - 20kHz)
function M.standard(ctx, opts)
  opts = opts or {}
  opts.min_freq = 20
  opts.max_freq = 20000
  opts.is_logarithmic = true
  return M.draw(ctx, opts)
end

--- Bass spectrum analyzer (20Hz - 500Hz)
function M.bass(ctx, opts)
  opts = opts or {}
  opts.min_freq = 20
  opts.max_freq = 500
  opts.is_logarithmic = true
  return M.draw(ctx, opts)
end

--- Midrange spectrum analyzer (200Hz - 5kHz)
function M.midrange(ctx, opts)
  opts = opts or {}
  opts.min_freq = 200
  opts.max_freq = 5000
  opts.is_logarithmic = true
  return M.draw(ctx, opts)
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.SpectrumAnalyzer(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
