-- @noindex
-- arkitekt/core/theme/init.lua
-- Unified theme system - THE single source of truth for all UI colors
--
-- This module consolidates:
--   - Runtime color store (Theme.COLORS)
--   - DSL definitions and color generation
--   - Config builders for widgets
--   - Theme presets and REAPER integration
--
-- =============================================================================
-- USAGE
-- =============================================================================
--
--   local Theme = require('arkitekt.core.theme')
--
--   -- Read colors (widgets do this every frame)
--   local bg = Theme.COLORS.BG_BASE
--   local text = Theme.COLORS.TEXT_NORMAL
--
--   -- Build widget configs
--   local btn_config = Theme.build_button_config()
--   local danger_btn = Theme.build_colored_button_config("danger")
--
--   -- Set theme mode
--   Theme.set_dark()
--   Theme.set_light()
--   Theme.adapt()  -- sync with REAPER
--
-- =============================================================================

local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

-- =============================================================================
-- RUNTIME COLOR STORE
-- =============================================================================
-- This is THE single source of truth. All widgets read from here.
-- ThemeManager writes generated colors here.

M.COLORS = {
  -- Default fallback values (dark theme)
  -- These are overwritten when a theme is applied

  -- Backgrounds
  BG_BASE        = hexrgb("#242424FF"),
  BG_HOVER       = hexrgb("#2A2A2AFF"),
  BG_ACTIVE      = hexrgb("#303030FF"),
  BG_HEADER      = hexrgb("#1E1E1EFF"),
  BG_PANEL       = hexrgb("#1A1A1AFF"),
  BG_CHROME      = hexrgb("#0F0F0FFF"),
  BG_TRANSPARENT = hexrgb("#00000000"),

  -- Borders
  BORDER_OUTER  = hexrgb("#000000DD"),
  BORDER_INNER  = hexrgb("#2f2f2fff"),
  BORDER_HOVER  = hexrgb("#505050FF"),
  BORDER_ACTIVE = hexrgb("#B0B0B077"),
  BORDER_FOCUS  = hexrgb("#7B7B7BFF"),

  -- Text
  TEXT_NORMAL = hexrgb("#CCCCCCFF"),
  TEXT_HOVER  = hexrgb("#FFFFFFFF"),
  TEXT_ACTIVE = hexrgb("#FFFFFFFF"),
  TEXT_DIMMED = hexrgb("#AAAAAAFF"),
  TEXT_DARK   = hexrgb("#707070FF"),
  TEXT_BRIGHT = hexrgb("#EEEEEEFF"),

  -- Accents
  ACCENT_PRIMARY      = hexrgb("#4A9EFF"),
  ACCENT_TEAL         = hexrgb("#295650FF"),
  ACCENT_TEAL_BRIGHT  = hexrgb("#41E0A3FF"),
  ACCENT_WHITE        = hexrgb("#2f2f2fff"),
  ACCENT_WHITE_BRIGHT = hexrgb("#585858ff"),
  ACCENT_TRANSPARENT  = hexrgb("#43434388"),
  ACCENT_SUCCESS      = hexrgb("#4CAF50"),
  ACCENT_WARNING      = hexrgb("#FFA726"),
  ACCENT_DANGER       = hexrgb("#EF5350"),

  -- Patterns
  PATTERN_PRIMARY   = hexrgb("#30303060"),
  PATTERN_SECONDARY = hexrgb("#30303020"),
}

-- =============================================================================
-- DSL DEFINITIONS (imported from defs/colors)
-- =============================================================================

local Palette = require('arkitekt.defs.colors')

-- Re-export DSL wrappers
M.snap = Palette.snap
M.lerp = Palette.lerp
M.offset = Palette.offset
M.bg = Palette.bg

-- Re-export palette structure
M.presets = Palette.presets
M.anchors = Palette.anchors
M.colors = Palette.colors

-- =============================================================================
-- ENGINE (color generation)
-- =============================================================================

local Engine = require('arkitekt.core.theme_manager.engine')
local Presets = require('arkitekt.core.theme_manager.presets')
local Integration = require('arkitekt.core.theme_manager.integration')
local Registry = require('arkitekt.core.theme_manager.registry')
local Debug = require('arkitekt.core.theme_manager.debug')

-- Current theme mode
M.current_mode = nil

--- Get current theme's base lightness (0.0-1.0)
function M.get_theme_lightness()
  if not M.COLORS.BG_BASE then return Palette.anchors.dark end
  local _, _, l = Colors.rgb_to_hsl(M.COLORS.BG_BASE)
  return l
end

--- Get current interpolation factor t (0.0 = dark, 1.0 = light)
function M.get_t()
  local lightness = M.get_theme_lightness()
  if M.current_mode == "dark" then return 0 end
  if M.current_mode == "light" then return 1 end
  return Engine.compute_t(lightness)
end

-- Alias for compatibility
M.get_current_t = M.get_t

--- Generate palette and apply to Theme.COLORS
function M.generate_and_apply(base_bg)
  local palette = Engine.generate_palette(base_bg)
  for key, value in pairs(palette) do
    M.COLORS[key] = value
  end
  Registry.clear_cache()
end

--- Generate palette without applying
function M.generate_palette(base_bg)
  return Engine.generate_palette(base_bg)
end

--- Get current colors (for transitions)
function M.get_current_colors()
  local current = {}
  for key, value in pairs(M.COLORS) do
    current[key] = value
  end
  return current
end

-- =============================================================================
-- THEME API
-- =============================================================================

--- Apply dark preset
function M.set_dark()
  return M.set_mode("dark")
end

--- Apply light preset
function M.set_light()
  return M.set_mode("light")
end

--- Adapt to REAPER's current theme
function M.adapt()
  return M.set_mode("adapt")
end

--- Set theme by mode name
--- @param mode string "dark", "light", or "adapt"
--- @param persist boolean|nil Whether to save preference (default: true)
function M.set_mode(mode, persist)
  if persist == nil then persist = true end
  local success = false

  if mode == "adapt" then
    success = Integration.sync_with_reaper()
  elseif Presets.exists(mode) then
    success = Presets.apply(mode)
  end

  if success then
    M.current_mode = mode
    Registry.clear_cache()
    if persist then
      Integration.save_mode(mode)
    end
  end

  return success
end

--- Get current theme mode
function M.get_mode()
  return M.current_mode
end

--- Initialize theme from saved preference or default
function M.init(default_mode)
  default_mode = default_mode or "adapt"
  local saved_mode = Integration.load_mode()
  local mode_to_apply = saved_mode

  if not mode_to_apply or (mode_to_apply ~= "dark" and mode_to_apply ~= "light" and mode_to_apply ~= "adapt") then
    mode_to_apply = default_mode
  end

  return M.set_mode(mode_to_apply, saved_mode == nil)
end

-- =============================================================================
-- TRANSITIONS
-- =============================================================================

M.transition_to_palette = Integration.transition_to_palette
M.transition_to_theme = Integration.transition_to_theme
M.create_live_sync = Integration.create_live_sync

-- =============================================================================
-- REGISTRY (script palettes)
-- =============================================================================

M.register_script_palette = Registry.register_palette
M.unregister_script_palette = Registry.unregister_palette
M.get_registered_palettes = Registry.get_all_palettes
M.script_palettes = Registry.script_palettes
M.clear_script_cache = Registry.clear_cache

--- Get computed palette for a script
function M.get_script_palette(script_name)
  return Registry.get_computed_palette(script_name, M.get_t())
end

-- =============================================================================
-- DEBUG
-- =============================================================================

-- Use function to get current state (not a stale copy)
function M.is_debug_enabled()
  return Debug.debug_enabled
end

M.toggle_debug = Debug.toggle_debug
M.enable_debug = Debug.enable_debug
M.disable_debug = Debug.disable_debug
M.validate = Debug.validate
M.get_validation_summary = Debug.get_validation_summary

function M.render_debug_window(ctx, ImGui)
  Debug.render_debug_window(ctx, ImGui, {
    lightness = M.get_theme_lightness(),
    t = M.get_t(),
    mode = M.current_mode,
  })
end

function M.check_debug_hotkey(ctx, ImGui)
  Debug.check_debug_hotkey(ctx, ImGui)
end

-- =============================================================================
-- PRESETS API
-- =============================================================================

M.get_theme_names = Presets.get_names
M.get_primary_presets = Presets.get_primary
M.apply_theme = function(name)
  local success = Presets.apply(name)
  if success then Registry.clear_cache() end
  return success
end

-- =============================================================================
-- UTILITIES
-- =============================================================================

--- Adapt a color to the current theme
function M.adapt_color(base_color, pull_factor)
  pull_factor = pull_factor or 0.5
  local theme_l = M.get_theme_lightness()
  local base_h, base_s, base_l = Colors.rgb_to_hsl(base_color)
  local target_l = base_l + (theme_l - base_l) * pull_factor
  target_l = math.max(0, math.min(1, target_l))
  local r, g, b = Colors.hsl_to_rgb(base_h, base_s, target_l)
  local _, _, _, a = Colors.rgba_to_components(base_color)
  return Colors.components_to_rgba(r, g, b, a)
end

-- =============================================================================
-- CONFIG BUILDERS
-- =============================================================================
-- These build widget configs from Theme.COLORS every call.
-- Enables dynamic theming - colors update automatically.

--- Build button config from current Theme.COLORS
function M.build_button_config()
  return {
    bg_color = M.COLORS.BG_BASE,
    bg_hover_color = M.COLORS.BG_HOVER,
    bg_active_color = M.COLORS.BG_ACTIVE,
    bg_disabled_color = Colors.adjust_lightness(M.COLORS.BG_BASE, -0.05),
    border_outer_color = M.COLORS.BORDER_OUTER,
    border_inner_color = M.COLORS.BORDER_INNER,
    border_hover_color = M.COLORS.BORDER_HOVER,
    border_active_color = M.COLORS.BORDER_ACTIVE,
    border_inner_disabled_color = Colors.adjust_lightness(M.COLORS.BORDER_INNER, -0.05),
    border_outer_disabled_color = M.COLORS.BORDER_OUTER,
    text_color = M.COLORS.TEXT_NORMAL,
    text_hover_color = M.COLORS.TEXT_HOVER,
    text_active_color = M.COLORS.TEXT_ACTIVE,
    text_disabled_color = M.COLORS.TEXT_DIMMED,
    padding_x = 10,
    padding_y = 6,
    rounding = 0,
  }
end

--- Build colored button config (danger, success, warning, info)
function M.build_colored_button_config(variant)
  local prefix = "BUTTON_" .. string.upper(variant) .. "_"
  local bg = M.COLORS[prefix .. "BG"]
  local hover = M.COLORS[prefix .. "HOVER"]
  local active = M.COLORS[prefix .. "ACTIVE"]
  local text = M.COLORS[prefix .. "TEXT"]

  if not bg then return M.build_button_config() end

  return {
    bg_color = bg,
    bg_hover_color = hover,
    bg_active_color = active,
    bg_disabled_color = Colors.adjust_saturation(Colors.adjust_lightness(bg, -0.1), -0.4),
    border_outer_color = Colors.adjust_lightness(bg, -0.18),
    border_inner_color = Colors.adjust_lightness(bg, 0.12),
    border_hover_color = Colors.adjust_lightness(hover, 0.10),
    border_active_color = Colors.adjust_lightness(active, -0.10),
    border_inner_disabled_color = Colors.adjust_lightness(bg, -0.15),
    border_outer_disabled_color = Colors.adjust_lightness(bg, -0.20),
    text_color = text,
    text_hover_color = text,
    text_active_color = text,
    text_disabled_color = Colors.adjust_lightness(text, -0.3),
    padding_x = 10,
    padding_y = 6,
    rounding = 0,
  }
end

--- Build dropdown config from current Theme.COLORS
function M.build_dropdown_config()
  return {
    bg_color = M.COLORS.BG_BASE,
    bg_hover_color = M.COLORS.BG_HOVER,
    bg_active_color = M.COLORS.BG_ACTIVE,
    border_outer_color = M.COLORS.BORDER_OUTER,
    border_inner_color = M.COLORS.BORDER_INNER,
    border_hover_color = M.COLORS.BORDER_HOVER,
    border_active_color = M.COLORS.BORDER_ACTIVE,
    text_color = M.COLORS.TEXT_NORMAL,
    text_hover_color = M.COLORS.TEXT_HOVER,
    text_active_color = M.COLORS.TEXT_ACTIVE,
    arrow_color = M.COLORS.TEXT_NORMAL,
    arrow_hover_color = M.COLORS.TEXT_HOVER,
    rounding = 0,
    padding_x = 10,
    padding_y = 6,
    arrow_size = 6,
    enable_mousewheel = true,
    tooltip_delay = 0.5,
    popup = {
      bg_color = Colors.adjust_lightness(M.COLORS.BG_BASE, -0.02),
      border_color = Colors.adjust_lightness(M.COLORS.BORDER_OUTER, -0.05),
      item_bg_color = M.COLORS.BG_TRANSPARENT,
      item_hover_color = M.COLORS.BG_HOVER,
      item_active_color = M.COLORS.BG_ACTIVE,
      item_text_color = M.COLORS.TEXT_NORMAL,
      item_text_hover_color = M.COLORS.TEXT_HOVER,
      item_selected_color = M.COLORS.BG_ACTIVE,
      item_selected_text_color = M.COLORS.TEXT_BRIGHT,
      rounding = 2,
      padding = 6,
      item_height = 26,
      item_padding_x = 12,
      border_thickness = 1,
    },
  }
end

--- Build search input config
function M.build_search_input_config()
  return {
    placeholder = "Search...",
    fade_speed = 8.0,
    bg_color = M.COLORS.BG_BASE,
    bg_hover_color = M.COLORS.BG_HOVER,
    bg_active_color = M.COLORS.BG_ACTIVE,
    border_outer_color = M.COLORS.BORDER_OUTER,
    border_inner_color = M.COLORS.BORDER_INNER,
    border_hover_color = M.COLORS.BORDER_HOVER,
    border_active_color = M.COLORS.BORDER_ACTIVE,
    text_color = M.COLORS.TEXT_NORMAL,
    padding_x = 6,
    rounding = 0,
    tooltip_delay = 0.5,
  }
end

--- Build tooltip config
function M.build_tooltip_config()
  return {
    bg_color = M.COLORS.BG_HOVER,
    border_color = M.COLORS.BORDER_INNER,
    text_color = M.COLORS.TEXT_BRIGHT,
    padding_x = 8,
    padding_y = 6,
    rounding = 4,
    border_thickness = 1,
    delay = 0.5,
  }
end

--- Build panel colors (for panel widgets)
function M.build_panel_colors()
  return {
    bg_panel = M.COLORS.BG_PANEL,
    border_panel = M.COLORS.BORDER_OUTER,
    bg_header = M.COLORS.BG_HEADER,
    border_header = Colors.with_alpha(hexrgb("#000000"), 0x66),
    bg_tab = M.COLORS.BG_BASE,
    bg_tab_hover = M.COLORS.BG_HOVER,
    bg_tab_active = M.COLORS.BG_ACTIVE,
    text_tab = M.COLORS.TEXT_DIMMED,
    text_tab_hover = M.COLORS.TEXT_HOVER,
    text_tab_active = M.COLORS.TEXT_ACTIVE,
    border_tab_inner = M.COLORS.BORDER_INNER,
    border_tab_hover = M.COLORS.BORDER_HOVER,
    border_tab_focus = M.COLORS.BORDER_FOCUS,
    bg_tab_track = M.COLORS.BG_PANEL,
    border_tab_track = M.COLORS.BORDER_OUTER,
    separator_line = Colors.with_alpha(hexrgb("#303030"), 0x80),
    bg_scrollbar = M.COLORS.BG_TRANSPARENT,
    pattern_primary = M.COLORS.PATTERN_PRIMARY,
    pattern_secondary = M.COLORS.PATTERN_SECONDARY,
  }
end

--- Build action chip config (for batch rename, etc.)
function M.build_action_chip_config(variant)
  -- Action chips: colored rectangles with contrasting text
  local configs = {
    wildcard = {
      bg_color = M.COLORS.ACCENT_PRIMARY or hexrgb("#5B8FB9"),
      text_color = M.COLORS.TEXT_DARK or hexrgb("#1a1a1a"),
    },
    tag = {
      bg_color = M.COLORS.ACCENT_WARNING or hexrgb("#8B7355"),
      text_color = M.COLORS.TEXT_DARK or hexrgb("#1a1a1a"),
    },
  }

  local base = configs[variant] or configs.wildcard
  return {
    bg_color = base.bg_color,
    text_color = base.text_color,
    border_color = Colors.with_alpha(hexrgb("#000000"), 100),
    rounding = 2,
    padding_h = 8,
  }
end

-- =============================================================================
-- DYNAMIC PRESETS (toggle button variants)
-- =============================================================================

M.PRESETS = {
  BUTTON_TOGGLE_TEAL = {
    bg_on_color = "ACCENT_TEAL",
    bg_on_hover_color = "ACCENT_TEAL_BRIGHT",
    bg_on_active_color = "ACCENT_TEAL",
    border_inner_on_color = "ACCENT_TEAL_BRIGHT",
    border_inner_on_hover_color = "ACCENT_TEAL_BRIGHT",
    border_inner_on_active_color = "ACCENT_TEAL",
    text_on_color = "ACCENT_TEAL_BRIGHT",
    text_on_hover_color = "ACCENT_TEAL_BRIGHT",
    text_on_active_color = "ACCENT_TEAL_BRIGHT",
  },

  BUTTON_TOGGLE_WHITE = {
    bg_on_color = "ACCENT_WHITE",
    bg_on_hover_color = "ACCENT_WHITE_BRIGHT",
    bg_on_active_color = "ACCENT_WHITE",
    border_inner_on_color = "ACCENT_WHITE_BRIGHT",
    border_inner_on_hover_color = "ACCENT_WHITE_BRIGHT",
    border_inner_on_active_color = "ACCENT_WHITE",
    text_on_color = "TEXT_BRIGHT",
    text_on_hover_color = "TEXT_BRIGHT",
    text_on_active_color = "TEXT_BRIGHT",
  },

  BUTTON_TOGGLE_TRANSPARENT = {
    bg_on_color = "ACCENT_TRANSPARENT",
    bg_on_hover_color = "ACCENT_TRANSPARENT",
    bg_on_active_color = "ACCENT_TRANSPARENT",
    border_inner_on_color = "ACCENT_WHITE_BRIGHT",
    border_inner_on_hover_color = "TEXT_BRIGHT",
    border_inner_on_active_color = "ACCENT_WHITE",
    text_on_color = "TEXT_BRIGHT",
    text_on_hover_color = "TEXT_BRIGHT",
    text_on_active_color = "TEXT_BRIGHT",
  },
}

-- Legacy alias
M.PRESETS.BUTTON_TOGGLE_ACCENT = M.PRESETS.BUTTON_TOGGLE_TEAL

--- Apply a preset to a config (resolves string keys to Theme.COLORS)
function M.apply_preset(config, preset_name)
  local preset = M.PRESETS[preset_name]
  if not preset then return end

  for key, value in pairs(preset) do
    if type(value) == "string" then
      config[key] = M.COLORS[value]
    else
      config[key] = value
    end
  end
end

-- =============================================================================
-- COMPATIBILITY LAYER
-- =============================================================================
-- For gradual migration, Theme can be required as Style

-- Alias commonly accessed things at module level for compatibility
M.TOOLTIP = {
  delay = 0.5,
}

return M
