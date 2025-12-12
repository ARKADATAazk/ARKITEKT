-- @noindex
-- arkitekt/gui/widgets/modal/defaults.lua
-- Default styling configuration for Modal widget
-- Derived from overlay/defaults.lua with modern patterns

local M = {}

-- Lazy load Theme to avoid circular dependency
local _Theme
local function get_theme()
  if not _Theme then
    local ok, theme = pcall(require, 'arkitekt.theme')
    if ok then _Theme = theme end
  end
  return _Theme
end

--- Build theme-reactive modal config
--- @return table Modal configuration with theme-derived colors
local function build_config()
  local Theme = get_theme()

  -- Use Theme.COLORS if available, otherwise fall back to dark defaults
  local bg_chrome = Theme and Theme.COLORS and Theme.COLORS.BG_CHROME or 0x121212FF
  local border_outer = Theme and Theme.COLORS and Theme.COLORS.BORDER_OUTER or 0x404040FF
  local text_normal = Theme and Theme.COLORS and Theme.COLORS.TEXT_NORMAL or 0xFFFFFFFF
  local text_dimmed = Theme and Theme.COLORS and Theme.COLORS.TEXT_DIMMED or 0x666666FF

  -- Determine if we're in a light theme (t > 0.5)
  local is_light = Theme and Theme.get_t and Theme.get_t() > 0.5 or false

  return {
    -- Scrim (darkened background behind modal)
    scrim = {
      color = 0x0F0F0FFF,  -- Darker grey
      opacity = 0.94,
    },

    -- Modal sheet/panel
    sheet = {
      background = {
        color = bg_chrome,
        opacity = 0.99,
      },

      shadow = {
        enabled = true,
        layers = 4,
        max_offset = 12,
        base_alpha = is_light and 30 or 20,
      },

      border = {
        outer_color = border_outer,
        outer_opacity = is_light and 0.5 or 0.7,
        outer_thickness = 1.5,
        inner_color = is_light and 0x000000FF or 0xFFFFFFFF,
        inner_opacity = is_light and 0.08 or 0.10,
        inner_thickness = 1.0,
      },

      header = {
        height = 42,
        text_color = text_normal,
        text_opacity = 1.0,

        divider_color = text_dimmed,
        divider_opacity = 0.31,
        divider_thickness = 1.0,
        divider_fade_width = 60,

        highlight_color = is_light and 0x000000FF or 0xFFFFFFFF,
        highlight_opacity = 0.06,
        highlight_thickness = 1.0,
      },

      rounding = 12,
      padding = 20,
    },

    -- Close button
    close_button = {
      size = 28,
      margin = 12,
      proximity = 100,  -- Distance to start showing button
      icon_color = 0xAAAAAAFF,
      hover_color = 0xFFFFFFFF,
      bg_color = 0x000000FF,
      bg_opacity = 0.3,
      bg_opacity_hover = 0.5,
    },

    -- Animation (durations in seconds)
    animation = {
      fade_in_duration = 1.0,   -- seconds - slower fade in
      fade_out_duration = 0.5,  -- seconds - faster fade out (half of fade in)
      fade_curve = 'smootherstep',
    },

    -- Behavior defaults
    -- NOTE: disable_background is NOT supported by Modal because the main UI
    -- is rendered BEFORE Modal.Begin() is called. Callers should wrap their
    -- main UI with Ark.BeginDisabled/EndDisabled based on modal open state.
    behavior = {
      close_on_escape = true,
      close_on_scrim_click = true,
      close_on_scrim_right_click = true,
      show_close_button = true,
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

return M
