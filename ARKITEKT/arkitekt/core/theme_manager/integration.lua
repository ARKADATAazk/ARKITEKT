-- @noindex
-- arkitekt/core/theme_manager/integration.lua
-- External system integration
--
-- Handles REAPER theme sync, persistence via ExtState,
-- animated transitions, and live sync polling.

local Colors = require('arkitekt.core.colors')
local Engine = require('arkitekt.core.theme_manager.engine')
local Palette = require('arkitekt.defs.colors.theme')

local M = {}

-- Lazy load Theme to avoid circular dependency
local _Theme
local function get_theme()
  if not _Theme then
    _Theme = require('arkitekt.core.theme')
  end
  return _Theme
end

-- Visual separation offset when syncing with REAPER theme
local REAPER_SYNC_OFFSET = -0.012

-- ExtState section for persistence
local EXTSTATE_SECTION = "ARKITEKT"
local EXTSTATE_TIMESTAMP_KEY = "theme_update_time"

-- =============================================================================
-- REAPER COLOR CONVERSION
-- =============================================================================

--- Convert REAPER native color format to ImGui format (0xRRGGBBAA)
--- REAPER uses native OS format: Windows=0x00BBGGRR, macOS may differ
--- @param reaper_color number REAPER native color
--- @return number|nil ImGui color in RGBA format, or nil on error
local function reaper_to_imgui(reaper_color)
  if reaper_color == -1 then
    return nil
  end
  -- REAPER native (Windows): 0x00BBGGRR -> ImGui: 0xRRGGBBAA
  local b = (reaper_color >> 16) & 0xFF
  local g = (reaper_color >> 8) & 0xFF
  local r = reaper_color & 0xFF
  return (r << 24) | (g << 16) | (b << 8) | 0xFF
end

-- =============================================================================
-- DOCK ADAPTS TO REAPER SETTING
-- =============================================================================

local DOCK_ADAPT_KEY = "dock_adapts_to_reaper"

--- Check if dock adapts to REAPER theme is enabled
--- @return boolean Whether dock adapt is enabled
function M.is_dock_adapt_enabled()
  local saved = reaper.GetExtState(EXTSTATE_SECTION, DOCK_ADAPT_KEY)
  return saved == "1"
end

--- Set dock adapts to REAPER theme setting
--- @param enabled boolean Whether to enable dock adapt
function M.set_dock_adapt_enabled(enabled)
  reaper.SetExtState(EXTSTATE_SECTION, DOCK_ADAPT_KEY, enabled and "1" or "0", true)
end

--- Get REAPER's background color WITHOUT any offset
--- For use when docked to match REAPER exactly
--- @return number|nil ImGui color in RGBA format, or nil on error
function M.get_reaper_bg_color()
  local main_bg_raw = reaper.GetThemeColor("col_main_bg2", 0)
  if main_bg_raw == -1 then
    return nil
  end
  return reaper_to_imgui(main_bg_raw)
end

--- Sync theme with REAPER WITHOUT the lightness offset
--- Used for "Adapt on docking" to match REAPER exactly
--- @return boolean Success
function M.sync_with_reaper_no_offset()
  local main_bg_raw = reaper.GetThemeColor("col_main_bg2", 0)
  if main_bg_raw == -1 then
    return false
  end

  local main_bg = reaper_to_imgui(main_bg_raw)
  if not main_bg then
    return false
  end

  -- Clamp to safe range (prevents extreme REAPER themes from breaking DSL)
  local range_l = Palette.value_ranges.BG_LIGHTNESS
  local range_s = Palette.value_ranges.BG_SATURATION
  local clamped_bg, was_clamped = Colors.clamp_bg_color(
    main_bg,
    range_l.min,
    range_l.max,
    range_s.max
  )

  -- Optional: Warn user if clamping occurred
  if was_clamped then
    reaper.ShowConsoleMsg("[ARKITEKT] REAPER theme adjusted for visual clarity\n")
  end

  -- Generate and apply palette WITHOUT offset (exact REAPER color)
  get_theme().generate_and_apply(clamped_bg)
  return true
end

-- =============================================================================
-- REAPER THEME SYNC
-- =============================================================================

--- Sync theme colors with REAPER's current theme
--- Reads main window background, applies slight offset for visual separation,
--- generates neutral grayscale palette for maximum theme compatibility
--- @return boolean Success (true if colors were read and applied)
function M.sync_with_reaper()
  -- Read single background color from REAPER
  local main_bg_raw = reaper.GetThemeColor("col_main_bg2", 0)

  if main_bg_raw == -1 then
    return false
  end

  -- Convert to ImGui format
  local main_bg = reaper_to_imgui(main_bg_raw)
  if not main_bg then
    return false
  end

  -- Apply lightness offset for subtle visual separation
  local offset_bg = Colors.adjust_lightness(main_bg, REAPER_SYNC_OFFSET)

  -- Clamp to safe range (prevents extreme REAPER themes from breaking DSL)
  local range_l = Palette.value_ranges.BG_LIGHTNESS
  local range_s = Palette.value_ranges.BG_SATURATION
  local clamped_bg, was_clamped = Colors.clamp_bg_color(
    offset_bg,
    range_l.min,
    range_l.max,
    range_s.max
  )

  -- Optional: Warn user if clamping occurred
  if was_clamped then
    reaper.ShowConsoleMsg("[ARKITEKT] REAPER theme adjusted for visual clarity\n")
  end

  -- Generate and apply palette (text color derived automatically)
  get_theme().generate_and_apply(clamped_bg)

  return true
end

--- Create a live sync function that polls REAPER theme changes
--- @param interval number|nil Check interval in seconds (default: 1.0)
--- @return function Function to call in main loop for live sync
function M.create_live_sync(interval)
  interval = interval or 1.0
  local last_check = 0
  local last_bg = nil

  return function()
    local now = reaper.time_precise()
    if now - last_check >= interval then
      last_check = now

      -- Read current REAPER background color
      local current_bg = reaper.GetThemeColor("col_main_bg2", 0)

      -- Only update if color changed and sync succeeds
      if current_bg ~= last_bg and current_bg ~= -1 then
        if M.sync_with_reaper() then
          last_bg = current_bg
        end
      end
    end
  end
end

--- Create cross-app sync function (polls for theme changes from other apps)
--- @param interval number|nil Check interval in seconds (default: 2.0)
--- @param app_name string|nil App name for override resolution
--- @return function Function to call in main loop
function M.create_cross_app_sync(interval, app_name)
  interval = interval or 2.0
  local last_check = 0
  local last_timestamp = reaper.GetExtState(EXTSTATE_SECTION, EXTSTATE_TIMESTAMP_KEY)

  return function()
    local now = reaper.time_precise()
    if now - last_check >= interval then
      last_check = now

      local current_timestamp = reaper.GetExtState(EXTSTATE_SECTION, EXTSTATE_TIMESTAMP_KEY)

      -- If timestamp changed, reload theme
      if current_timestamp ~= last_timestamp and current_timestamp ~= "" then
        last_timestamp = current_timestamp

        -- Reload with app fallback (respects app override)
        local mode = M.load_mode(app_name)
        if mode then
          get_theme().set_mode(mode, false, app_name)  -- false = don't persist!
        end
      end
    end
  end
end

-- =============================================================================
-- PERSISTENCE (via REAPER ExtState)
-- =============================================================================

local EXTSTATE_KEY = "theme_mode"

--- Get ExtState section name for an app
--- @param app_name string|nil App name (nil = global)
--- @return string ExtState section name
--- @private
local function get_extstate_section(app_name)
  if app_name then
    return EXTSTATE_SECTION .. "_" .. app_name  -- "ARKITEKT_TemplateBrowser"
  end
  return EXTSTATE_SECTION  -- "ARKITEKT"
end

--- Notify other apps that theme changed (write timestamp)
--- @private
local function notify_theme_change()
  local timestamp = tostring(reaper.time_precise())
  reaper.SetExtState(EXTSTATE_SECTION, EXTSTATE_TIMESTAMP_KEY, timestamp, false)
  -- false = not persistent (resets on REAPER restart)
end

--- Save theme mode to REAPER ExtState (persistent across sessions)
--- @param mode string Theme mode to save
--- @param app_name string|nil App name (nil = global)
function M.save_mode(mode, app_name)
  if not mode then return end

  local section = get_extstate_section(app_name)
  reaper.SetExtState(section, EXTSTATE_KEY, mode, true)

  -- Only notify on GLOBAL changes (not app-specific overrides)
  if not app_name then
    notify_theme_change()
  end
end

--- Load saved theme mode from REAPER ExtState
--- @param app_name string|nil App name (nil = global only)
--- @return string|nil Saved theme mode or nil if not set
function M.load_mode(app_name)
  -- Try app-specific override first
  if app_name then
    local section = get_extstate_section(app_name)
    local app_mode = reaper.GetExtState(section, EXTSTATE_KEY)
    if app_mode and app_mode ~= "" then
      return app_mode  -- App override exists
    end
  end

  -- Fallback to global
  local global_mode = reaper.GetExtState(EXTSTATE_SECTION, EXTSTATE_KEY)
  if global_mode and global_mode ~= "" then
    return global_mode
  end

  return nil
end

--- Clear saved theme mode
function M.clear_mode()
  reaper.DeleteExtState(EXTSTATE_SECTION, EXTSTATE_KEY, true)
end

--- Clear app-specific override (fall back to global)
--- @param app_name string App name
function M.clear_app_override(app_name)
  if not app_name then return end
  local section = get_extstate_section(app_name)
  reaper.DeleteExtState(section, EXTSTATE_KEY, true)
  -- Don't notify globally - this is app-specific action
end

--- Check if app has a theme override
--- @param app_name string App name
--- @return boolean Has override
function M.has_app_override(app_name)
  if not app_name then return false end
  local section = get_extstate_section(app_name)
  local mode = reaper.GetExtState(section, EXTSTATE_KEY)
  return mode and mode ~= ""
end

-- =============================================================================
-- CUSTOM COLOR
-- =============================================================================

local CUSTOM_COLOR_KEY = "theme_custom_color"

--- Get saved custom theme color
--- @return number|nil ImGui color in RGBA format, or nil if not set
function M.get_custom_color()
  local saved = reaper.GetExtState(EXTSTATE_SECTION, CUSTOM_COLOR_KEY)
  if saved and saved ~= "" then
    local color = tonumber(saved)
    if color then return color end
  end
  return nil
end

--- Save custom theme color
--- @param color number ImGui color in RGBA format
function M.set_custom_color(color)
  if color then
    reaper.SetExtState(EXTSTATE_SECTION, CUSTOM_COLOR_KEY, tostring(color), true)
  end
end

--- Apply custom color as theme
--- @param color number|nil ImGui color in RGBA format (uses saved if nil)
--- @return boolean Success
function M.apply_custom_color(color)
  color = color or M.get_custom_color()
  if not color then
    return false
  end

  -- Clamp to safe range (guardrail for user-provided colors)
  local range_l = Palette.value_ranges.BG_LIGHTNESS
  local range_s = Palette.value_ranges.BG_SATURATION
  local clamped_color, was_clamped = Colors.clamp_bg_color(
    color,
    range_l.min,
    range_l.max,
    range_s.max
  )

  -- Optional: Warn user if clamping occurred
  if was_clamped then
    reaper.ShowConsoleMsg("[ARKITEKT] Custom color adjusted for visual clarity\n")
  end

  get_theme().generate_and_apply(clamped_color)
  return true
end

-- =============================================================================
-- ANIMATED TRANSITIONS
-- =============================================================================

--- Smooth transition between current colors and a new palette
--- @param target_palette table Target color palette
--- @param duration number Transition duration in seconds
--- @param on_complete function|nil Optional callback when complete
function M.transition_to_palette(target_palette, duration, on_complete)
  local Theme = get_theme()
  local start_colors = Theme.get_current_colors()
  local start_time = reaper.time_precise()

  local function animate()
    local elapsed = reaper.time_precise() - start_time
    local t = math.min(elapsed / duration, 1.0)

    -- Lerp each color
    for key, target_color in pairs(target_palette) do
      local start_color = start_colors[key]
      if start_color and type(target_color) == "number" and type(start_color) == "number" then
        Theme.COLORS[key] = Colors.lerp(start_color, target_color, t)
      elseif target_color then
        Theme.COLORS[key] = target_color
      end
    end

    -- Continue animating or finish
    if t < 1.0 then
      reaper.defer(animate)
    else
      -- Ensure final values are exact
      for key, value in pairs(target_palette) do
        Theme.COLORS[key] = value
      end
      if on_complete then
        on_complete()
      end
    end
  end

  animate()
end

--- Transition to a theme by name with smooth animation
--- @param name string Theme name
--- @param duration number|nil Transition duration in seconds (default: 0.3)
--- @param on_complete function|nil Optional callback
--- @return boolean Success (true if theme exists)
function M.transition_to_theme(name, duration, on_complete)
  local Presets = require('arkitekt.core.theme_manager.presets')
  local palette = Presets.get_palette(name)

  if not palette then
    return false
  end

  duration = duration or 0.3
  M.transition_to_palette(palette, duration, on_complete)
  return true
end

return M
