-- @noindex
-- Arkitekt/gui/widgets/overlay/config.lua
-- Configuration for modal overlay and sheet appearance
--
-- THEME INTEGRATION:
-- Colors are now derived from Theme Manager for dark/light theme support.
-- The overlay will automatically adapt to the current theme.

local Colors = require('arkitekt.core.colors')
local ConfigUtil = require('arkitekt.core.config')
local Constants = require('arkitekt.defs.app')
local Timing = require('arkitekt.defs.timing')

local M = {}
local hexrgb = Colors.Hexrgb

-- Lazy load Theme to avoid circular dependency
local _Theme
local function get_theme()
  if not _Theme then
    local ok, theme = pcall(require, 'arkitekt.core.theme')
    if ok then _Theme = theme end
  end
  return _Theme
end

--- Build theme-reactive overlay config
--- @return table Overlay configuration with theme-derived colors
local function build_config()
  local Theme = get_theme()

  -- Use Theme.COLORS if available, otherwise fall back to dark defaults
  local bg_chrome = Theme and Theme.COLORS and Theme.COLORS.BG_CHROME or hexrgb('#121212')
  local border_outer = Theme and Theme.COLORS and Theme.COLORS.BORDER_OUTER or hexrgb('#404040')
  local text_normal = Theme and Theme.COLORS and Theme.COLORS.TEXT_NORMAL or hexrgb('#FFFFFF')
  local text_dimmed = Theme and Theme.COLORS and Theme.COLORS.TEXT_DIMMED or hexrgb('#666666')

  -- Determine if we're in a light theme (t > 0.5)
  local is_light = Theme and Theme.get_t and Theme.get_t() > 0.5 or false

  return {
    scrim = {
      color = bg_chrome,
      opacity = 0.99,
    },

    sheet = {
      background = {
        color = bg_chrome,
        opacity = 0.99,
      },

      shadow = {
        enabled = true,
        layers = 4,
        max_offset = 12,
        base_alpha = is_light and 30 or 20,  -- Stronger shadows for light theme
      },

      border = {
        outer_color = border_outer,
        outer_opacity = is_light and 0.5 or 0.7,
        outer_thickness = 1.5,
        inner_color = is_light and hexrgb('#000000') or hexrgb('#FFFFFF'),
        inner_opacity = is_light and 0.08 or 0.10,
        inner_thickness = 1.0,
      },

      gradient = {
        top_enabled = false,
        top_color = is_light and hexrgb('#000000') or hexrgb('#FFFFFF'),
        top_height = 80,
        top_max_alpha = 0.06,

        bottom_enabled = false,
        bottom_color = is_light and hexrgb('#FFFFFF') or hexrgb('#000000'),
        bottom_height = 60,
        bottom_max_alpha = 0.08,
      },

      header = {
        height = 42,
        text_color = text_normal,
        text_opacity = 1.0,

        divider_color = text_dimmed,
        divider_opacity = 0.31,
        divider_thickness = 1.0,
        divider_fade_width = 60,

        highlight_color = is_light and hexrgb('#000000') or hexrgb('#FFFFFF'),
        highlight_opacity = 0.06,
        highlight_thickness = 1.0,
      },

      rounding = 12,
    },
  }
end

-- Cache for config (invalidated when theme changes)
local _config_cache = nil
local _config_cache_t = nil

function M.get()
  local Theme = get_theme()
  local current_t = Theme and Theme.get_t and Theme.get_t() or 0

  -- Rebuild config if theme changed
  if not _config_cache or _config_cache_t ~= current_t then
    _config_cache = build_config()
    _config_cache_t = current_t
  end

  return _config_cache
end

--- Force refresh of config (call when theme changes)
function M.refresh()
  _config_cache = nil
  _config_cache_t = nil
end

function M.override(overrides)
  local config = M.get()

  if not overrides then
    return ConfigUtil.deepMerge({}, config)  -- Return deep copy
  end

  -- Deep merge config with overrides
  return ConfigUtil.deepMerge(config, overrides)
end

function M.Reset()
  current_config = nil
end

-- ============================================================================
-- OVERLAY MANAGER CONFIGURATION HELPER
-- ============================================================================

-- Create a complete overlay configuration using framework defaults
-- Only override what's truly app-specific (like render function, ID, etc.)
-- @param opts Table with optional overrides:
--   - id: Required, unique overlay ID
--   - render: Required, render function(ctx, alpha, bounds)
--   - on_close: Optional, cleanup function
--   - should_passthrough: Optional, function() -> boolean to skip overlay chrome
--   - use_viewport: Optional, boolean (default: true)
--   - fade_duration: Optional, number in seconds
--   - fade_curve: Optional, easing curve name
--   - show_close_button: Optional, boolean
--   - close_on_background_click: Optional, boolean
--   - close_on_background_right_click: Optional, boolean
--   - close_on_scrim: Optional, boolean
--   - esc_to_close: Optional, boolean
--   - close_button_size: Optional, number
--   - close_button_margin: Optional, number
--   - close_button_proximity: Optional, number
--   - content_padding: Optional, number
--   - scrim_color: Optional, color int
--   - scrim_opacity: Optional, 0.0-1.0
-- @return Complete overlay configuration table
function M.create_overlay_config(opts)
  assert(opts and opts.id, 'Overlay config requires "id" field')
  assert(opts.render, 'Overlay config requires "render" function')

  local C = Constants.OVERLAY
  local config = M.get()

  return {
    id = opts.id,
    use_viewport = opts.use_viewport == nil and C.DEFAULT_USE_VIEWPORT or opts.use_viewport,

    -- Animation
    fade_duration = opts.fade_duration or Timing.FADE.normal,
    fade_curve = opts.fade_curve or Timing.EASING.default_fade,

    -- Close button
    show_close_button = opts.show_close_button == nil and C.DEFAULT_SHOW_CLOSE_BUTTON or opts.show_close_button,
    close_button_size = opts.close_button_size or C.CLOSE_BUTTON_SIZE,
    close_button_margin = opts.close_button_margin or C.CLOSE_BUTTON_MARGIN,
    close_button_proximity = opts.close_button_proximity or C.CLOSE_BUTTON_PROXIMITY,

    -- Close behavior (use inverted ternary to handle false values correctly)
    close_on_background_click = opts.close_on_background_click == nil and C.DEFAULT_CLOSE_ON_BG_CLICK or opts.close_on_background_click,
    close_on_background_right_click = opts.close_on_background_right_click == nil and C.DEFAULT_CLOSE_ON_BG_RIGHT_CLICK or opts.close_on_background_right_click,
    close_on_scrim = opts.close_on_scrim == nil and C.DEFAULT_CLOSE_ON_SCRIM or opts.close_on_scrim,
    esc_to_close = opts.esc_to_close == nil and C.DEFAULT_ESC_TO_CLOSE or opts.esc_to_close,

    -- Layout
    content_padding = opts.content_padding or C.CONTENT_PADDING,

    -- Appearance
    scrim_color = opts.scrim_color or config.scrim.color,
    scrim_opacity = opts.scrim_opacity or C.SCRIM_OPACITY,

    -- Required callbacks
    render = opts.render,
    on_close = opts.on_close,

    -- Optional passthrough callback (for drag-to-REAPER, radial menus, etc.)
    should_passthrough = opts.should_passthrough,
  }
end

return M