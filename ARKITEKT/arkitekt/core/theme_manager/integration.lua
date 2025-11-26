-- @noindex
-- arkitekt/core/theme_manager/integration.lua
-- External system integration
--
-- Handles REAPER theme sync, persistence via ExtState,
-- animated transitions, and live sync polling.

local Colors = require('arkitekt.core.colors')
local Style = require('arkitekt.gui.style')
local Engine = require('arkitekt.core.theme_manager.engine')
local Rules = require('arkitekt.core.theme_manager.rules')

local M = {}

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
  local offset = Rules.definitions.reaper_sync_offset.dark
  local offset_bg = Colors.adjust_lightness(main_bg, offset)

  -- Generate and apply palette (text color derived automatically)
  Engine.generate_and_apply(offset_bg)

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

-- =============================================================================
-- PERSISTENCE (via REAPER ExtState)
-- =============================================================================

local EXTSTATE_SECTION = "ARKITEKT"
local EXTSTATE_KEY = "theme_mode"

--- Save theme mode to REAPER ExtState (persistent across sessions)
--- @param mode string Theme mode to save
function M.save_mode(mode)
  if mode then
    reaper.SetExtState(EXTSTATE_SECTION, EXTSTATE_KEY, mode, true)
  end
end

--- Load saved theme mode from REAPER ExtState
--- @return string|nil Saved theme mode or nil if not set
function M.load_mode()
  local saved = reaper.GetExtState(EXTSTATE_SECTION, EXTSTATE_KEY)
  if saved and saved ~= "" then
    return saved
  end
  return nil
end

--- Clear saved theme mode
function M.clear_mode()
  reaper.DeleteExtState(EXTSTATE_SECTION, EXTSTATE_KEY, true)
end

-- =============================================================================
-- ANIMATED TRANSITIONS
-- =============================================================================

--- Smooth transition between current colors and a new palette
--- @param target_palette table Target color palette
--- @param duration number Transition duration in seconds
--- @param on_complete function|nil Optional callback when complete
function M.transition_to_palette(target_palette, duration, on_complete)
  local start_colors = Engine.get_current_colors()
  local start_time = reaper.time_precise()

  local function animate()
    local elapsed = reaper.time_precise() - start_time
    local t = math.min(elapsed / duration, 1.0)

    -- Lerp each color
    for key, target_color in pairs(target_palette) do
      local start_color = start_colors[key]
      if start_color and type(target_color) == "number" and type(start_color) == "number" then
        Style.COLORS[key] = Colors.lerp(start_color, target_color, t)
      elseif target_color then
        Style.COLORS[key] = target_color
      end
    end

    -- Continue animating or finish
    if t < 1.0 then
      reaper.defer(animate)
    else
      -- Ensure final values are exact
      Engine.apply_palette(target_palette)
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
