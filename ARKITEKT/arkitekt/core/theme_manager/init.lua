-- @noindex
-- arkitekt/core/theme_manager/init.lua
-- Dynamic theme system with algorithmic color palette generation
--
-- Generates entire UI color palette from a single base color using HSL manipulation.
-- Supports REAPER theme auto-sync and manual theme presets.
--
-- =============================================================================
-- PRIMARY API (theme modes)
-- =============================================================================
--
--   local ThemeManager = require('arkitekt.core.theme_manager')
--
--   ThemeManager.set_dark()   -- Dark preset (~14% lightness)
--   ThemeManager.set_light()  -- Light preset (~88% lightness)
--   ThemeManager.adapt()      -- Sync with REAPER's current theme
--
--   -- Or use set_mode() for UI selectors:
--   ThemeManager.set_mode("dark")   -- "dark", "light", or "adapt"
--
-- =============================================================================
-- RULE WRAPPERS (for defining theme-reactive values)
-- =============================================================================
--
--   offsetFromBase(delta)           - Fixed delta from BG_BASE
--   offsetFromBase(dark, light)     - Different deltas, SNAP at t=0.5
--   lerpDarkLight(dark, light)      - Smooth interpolation between values
--   snapAtMidpoint(dark, light)     - Discrete snap at t=0.5
--   snapAt(threshold, dark, light)  - Discrete snap at custom threshold
--
-- =============================================================================
-- ADVANCED API
-- =============================================================================
--
--   ThemeManager.apply_theme("dark")
--   ThemeManager.generate_and_apply(base_bg)   -- Everything derived from one color
--   ThemeManager.transition_to_theme("light", 0.3)
--   local sync = ThemeManager.create_live_sync(1.0)

local Colors = require('arkitekt.core.colors')
local Style = require('arkitekt.gui.style')

-- Submodules
local Palette = require('arkitekt.defs.palette')
local Engine = require('arkitekt.core.theme_manager.engine')
local Presets = require('arkitekt.core.theme_manager.presets')
local Integration = require('arkitekt.core.theme_manager.integration')
local Registry = require('arkitekt.core.theme_manager.registry')
local Debug = require('arkitekt.core.theme_manager.debug')

local M = {}

-- =============================================================================
-- RE-EXPORTS
-- =============================================================================

-- DSL wrappers (short names - primary API)
M.snap = Palette.snap
M.lerp = Palette.lerp
M.offset = Palette.offset

-- DSL wrappers (legacy aliases - deprecated)
M.snapAtMidpoint = Palette.snapAtMidpoint
M.lerpDarkLight = Palette.lerpDarkLight
M.offsetFromBase = Palette.offsetFromBase
M.snapAt = Palette.snapAt

-- Palette structure
M.presets, M.anchors = Palette.presets, Palette.anchors
M.palette = Palette.palette  -- Flat palette (primary)
M.from_bg = Palette.from_bg  -- Legacy section view
M.specific, M.values = Palette.specific, Palette.values  -- Legacy section views

-- Presets API
M.get_theme_names, M.get_primary_presets = Presets.get_names, Presets.get_primary

-- Debug and validation
M.debug_enabled, M.toggle_debug = Debug.debug_enabled, Debug.toggle_debug
M.enable_debug, M.disable_debug = Debug.enable_debug, Debug.disable_debug
M.validate, M.get_validation_summary = Debug.validate, Debug.get_validation_summary

-- Script palette registration (unified API)
M.register_script_palette = Registry.register_palette
M.unregister_script_palette = Registry.unregister_palette
M.get_registered_palettes = Registry.get_all_palettes
M.script_palettes = Registry.script_palettes
M.clear_script_cache = Registry.clear_cache

-- Transitions
M.transition_to_palette, M.transition_to_theme, M.create_live_sync =
  Integration.transition_to_palette, Integration.transition_to_theme, Integration.create_live_sync

-- =============================================================================
-- STATE
-- =============================================================================

--- Current active theme mode
--- @type string|nil "dark", "light", "adapt", or nil if custom
M.current_mode = nil

-- =============================================================================
-- CORE API: Theme Lightness and Rules
-- =============================================================================

--- Get current theme's base lightness (0.0-1.0)
--- @return number Lightness of current BG_BASE
function M.get_theme_lightness()
  if not Style.COLORS.BG_BASE then return Palette.anchors.dark end
  local _, _, l = Colors.rgb_to_hsl(Style.COLORS.BG_BASE)
  return l
end

--- Get current interpolation factor t
--- @return number t value (0.0 at dark, 1.0 at light)
function M.get_current_t()
  local lightness = M.get_theme_lightness()
  if M.current_mode == "dark" then return 0 end
  if M.current_mode == "light" then return 1 end
  return Engine.compute_t(lightness)
end

--- Get computed values for current theme
--- @return table Values from M.values resolved for current t
function M.get_current_values()
  local t = M.get_current_t()
  local values = {}
  for key, def in pairs(Palette.values) do
    values[key] = Engine.resolve_value and Engine.resolve_value(def, t) or def
  end
  return values
end

--- Get computed palette for a script
--- @param script_name string Name of the script
--- @return table|nil Computed palette (colors as RGBA, values as numbers), or nil if not registered
function M.get_script_palette(script_name)
  return Registry.get_computed_palette(script_name, M.get_current_t())
end

-- =============================================================================
-- CORE API: Palette Generation
-- =============================================================================

--- Generate palette from base color and apply to Style.COLORS
--- All colors (text, accent, etc.) are derived from the single base color
--- @param base_bg number Background color
function M.generate_and_apply(base_bg)
  Engine.generate_and_apply(base_bg)
  Registry.clear_cache()
end

--- Generate complete UI color palette from base color (without applying)
--- All colors (text, accent, etc.) are derived from the single base color
--- @param base_bg number Background color in RGBA format
--- @return table Color palette
function M.generate_palette(base_bg)
  return Engine.generate_palette(base_bg)
end

--- Apply a preset theme by name
--- @param name string Theme name from M.themes
--- @return boolean Success
function M.apply_theme(name)
  local success = Presets.apply(name)
  if success then
    Registry.clear_cache()
  end
  return success
end

--- Get current color values (for debugging or transitions)
--- @return table Copy of current Style.COLORS
function M.get_current_colors()
  return Engine.get_current_colors()
end

-- =============================================================================
-- CORE API: REAPER Integration
-- =============================================================================

--- Sync theme with REAPER's current theme
--- @return boolean Success
function M.sync_with_reaper()
  local success = Integration.sync_with_reaper()
  if success then
    Registry.clear_cache()
  end
  return success
end

-- =============================================================================
-- SIMPLE API: Primary Theme Selection
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
--- @return boolean Success
function M.adapt()
  return M.set_mode("adapt")
end

--- Set theme by mode name (for UI selectors)
--- @param mode string "dark", "light", or "adapt"
--- @param persist boolean|nil Whether to save preference (default: true)
--- @return boolean Success
function M.set_mode(mode, persist)
  if persist == nil then persist = true end
  local success = false

  if mode == "adapt" then
    success = M.sync_with_reaper()
  elseif Presets.exists(mode) then
    success = M.apply_theme(mode)
  end

  if success then
    M.current_mode = mode
    if persist then
      Integration.save_mode(mode)
    end
  end

  return success
end

--- Get current theme mode
--- @return string|nil
function M.get_mode()
  return M.current_mode
end

--- Load saved theme mode from REAPER ExtState
--- @return string|nil Saved theme mode or nil if not set
function M.load_saved_mode()
  return Integration.load_mode()
end

--- Initialize theme from saved preference or default
--- @param default_mode string|nil Default mode if no saved preference ("adapt" if nil)
--- @return boolean Success
function M.init(default_mode)
  default_mode = default_mode or "adapt"

  -- Try to load saved preference
  local saved_mode = Integration.load_mode()

  -- Use saved mode if valid, otherwise use default
  local mode_to_apply = saved_mode
  if not mode_to_apply or (mode_to_apply ~= "dark" and mode_to_apply ~= "light" and mode_to_apply ~= "adapt") then
    mode_to_apply = default_mode
  end

  -- Apply theme (don't persist again if loading saved preference)
  return M.set_mode(mode_to_apply, saved_mode == nil)
end

-- =============================================================================
-- UTILITIES
-- =============================================================================

--- Adapt a color to the current theme using a "pull factor"
--- @param base_color number Base color in RGBA format
--- @param pull_factor number|nil How much to pull toward theme lightness (0.0-1.0, default 0.5)
--- @return number Adapted color in RGBA format
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
-- DEBUG WINDOW
-- =============================================================================

--- Render debug window showing current theme state
--- @param ctx userdata ImGui context
--- @param ImGui table ImGui library reference
function M.render_debug_window(ctx, ImGui)
  Debug.render_debug_window(ctx, ImGui, {
    lightness = M.get_theme_lightness(),
    t = M.get_current_t(),
    mode = M.current_mode,
  })
end

--- Check for F12 key press to toggle debug window
--- @param ctx userdata ImGui context
--- @param ImGui table ImGui library reference
function M.check_debug_hotkey(ctx, ImGui)
  Debug.check_debug_hotkey(ctx, ImGui)
end

return M
