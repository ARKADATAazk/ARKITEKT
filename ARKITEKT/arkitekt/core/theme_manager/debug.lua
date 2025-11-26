-- @noindex
-- arkitekt/core/theme_manager/debug.lua
-- Debug overlay, validation, and script registration
--
-- Provides visual debugging tools for tuning theme values,
-- validation utilities for catching config errors,
-- and a registry system for script-specific colors and rules.

local Colors = require('arkitekt.core.colors')
local Style = require('arkitekt.gui.style')
local Rules = require('arkitekt.core.theme_manager.rules')
local Engine = require('arkitekt.core.theme_manager.engine')

local M = {}

-- =============================================================================
-- DEBUG OVERLAY STATE
-- =============================================================================

M.debug_enabled = false

function M.toggle_debug()
  M.debug_enabled = not M.debug_enabled
end

function M.enable_debug()
  M.debug_enabled = true
end

function M.disable_debug()
  M.debug_enabled = false
end

-- =============================================================================
-- SCRIPT COLOR REGISTRATION
-- =============================================================================
-- Scripts can register their color modules for display in the debug overlay.

--- Registered script color modules
--- @type table<string, table<string, any>>
M.registered_script_colors = {}

--- Register a script's color table for debug display
--- @param script_name string Name of the script (e.g., "RegionPlaylist")
--- @param colors table Color table with key-value pairs
function M.register_script_colors(script_name, colors)
  if type(script_name) ~= "string" or type(colors) ~= "table" then
    return
  end
  M.registered_script_colors[script_name] = colors
end

--- Unregister a script's colors
--- @param script_name string Name of the script to unregister
function M.unregister_script_colors(script_name)
  M.registered_script_colors[script_name] = nil
end

--- Get all registered script colors
--- @return table<string, table<string, any>>
function M.get_registered_script_colors()
  return M.registered_script_colors
end

-- =============================================================================
-- SCRIPT RULES REGISTRATION
-- =============================================================================
-- Scripts can register their own theme-reactive rules using the same wrappers.

--- Registered script rule definitions
--- @type table<string, table<string, table>>
M.registered_script_rules = {}

--- Cache for computed script rules
local script_rules_cache = {}

--- Clear the script rules cache (called when theme changes)
function M.clear_script_rules_cache()
  script_rules_cache = {}
end

--- Register a script's theme-reactive rules
--- @param script_name string Name of the script
--- @param rules table Rules table using wrappers
function M.register_script_rules(script_name, rules)
  if type(script_name) ~= "string" or type(rules) ~= "table" then
    return
  end
  M.registered_script_rules[script_name] = rules
  script_rules_cache[script_name] = nil  -- Invalidate cache
end

--- Unregister a script's rules
--- @param script_name string Name of the script to unregister
function M.unregister_script_rules(script_name)
  M.registered_script_rules[script_name] = nil
  script_rules_cache[script_name] = nil
end

--- Get computed rules for a script (computed for current theme)
--- @param script_name string Name of the script
--- @param current_t number Current interpolation factor
--- @return table|nil Computed rules table, or nil if not registered
function M.get_script_rules(script_name, current_t)
  local rule_defs = M.registered_script_rules[script_name]
  if not rule_defs then
    return nil
  end

  -- Check cache
  local cached = script_rules_cache[script_name]
  if cached and cached._t == current_t then
    return cached
  end

  -- Compute rules for current theme
  local computed = { _t = current_t }
  for key, rule in pairs(rule_defs) do
    computed[key] = Engine.compute_rule_value(rule, current_t)
  end

  script_rules_cache[script_name] = computed
  return computed
end

--- Get all registered script rules (definitions, not computed)
--- @return table<string, table<string, table>>
function M.get_registered_script_rules()
  return M.registered_script_rules
end

-- =============================================================================
-- VALIDATION
-- =============================================================================

--- Validate rules configuration
--- @return boolean valid True if configuration is valid
--- @return string|nil error_message Error details if invalid
function M.validate()
  local errors = {}

  for key, rule in pairs(Rules.definitions) do
    -- Check: Rule is properly wrapped
    if type(rule) ~= "table" or not rule.mode then
      errors[#errors + 1] = string.format(
        "Rule '%s' is not wrapped (use offsetFromBase, lerpDarkLight, snapAtMidpoint, or snapAt)",
        key
      )
    else
      -- Check: Has dark and light values
      if rule.dark == nil then
        errors[#errors + 1] = string.format("Rule '%s' missing 'dark' value", key)
      end
      if rule.light == nil then
        errors[#errors + 1] = string.format("Rule '%s' missing 'light' value", key)
      end

      -- Check: Valid mode
      local valid_modes = { offset = true, lerp = true, snap = true }
      if not valid_modes[rule.mode] then
        errors[#errors + 1] = string.format(
          "Rule '%s' has invalid mode '%s' (expected: offset, lerp, snap)",
          key, tostring(rule.mode)
        )
      end

      -- Check: Dark and light have same type
      if rule.dark ~= nil and rule.light ~= nil then
        local dark_type = type(rule.dark)
        local light_type = type(rule.light)
        if dark_type ~= light_type then
          errors[#errors + 1] = string.format(
            "Rule '%s' has type mismatch: dark=%s (%s), light=%s (%s)",
            key, tostring(rule.dark), dark_type, tostring(rule.light), light_type
          )
        end
      end

      -- Check: Threshold in valid range
      if rule.threshold ~= nil then
        if type(rule.threshold) ~= "number" or rule.threshold < 0 or rule.threshold > 1 then
          errors[#errors + 1] = string.format(
            "Rule '%s' has invalid threshold '%s' (expected: 0.0-1.0)",
            key, tostring(rule.threshold)
          )
        end
      end
    end
  end

  if #errors > 0 then
    return false, table.concat(errors, "\n")
  end

  return true, nil
end

--- Get validation status as a summary table
--- @return table Summary with counts and status
function M.get_validation_summary()
  local valid, err = M.validate()
  local rule_count = 0
  local mode_counts = { offset = 0, lerp = 0, snap = 0 }

  for _, rule in pairs(Rules.definitions) do
    rule_count = rule_count + 1
    if type(rule) == "table" and rule.mode then
      mode_counts[rule.mode] = (mode_counts[rule.mode] or 0) + 1
    end
  end

  return {
    valid = valid,
    error_message = err,
    rule_count = rule_count,
    mode_counts = mode_counts,
    error_count = err and select(2, err:gsub("\n", "\n")) + 1 or 0,
  }
end

-- =============================================================================
-- DEBUG OVERLAY RENDERING
-- =============================================================================

-- Mapping from rule keys to Style.COLORS keys (for debug display)
local RULE_TO_STYLE_MAP = {
  bg_hover_delta = "BG_HOVER",
  bg_active_delta = "BG_ACTIVE",
  bg_header_delta = "BG_HEADER",
  bg_panel_delta = "BG_PANEL",
  chrome_lightness_factor = "BG_CHROME",
  chrome_lightness_offset = "BG_CHROME",
  pattern_primary_delta = "PATTERN_PRIMARY",
  pattern_secondary_delta = "PATTERN_SECONDARY",
  border_outer_color = "BORDER_OUTER",
  border_outer_opacity = "BORDER_OUTER",
  border_inner_delta = "BORDER_INNER",
  border_hover_delta = "BORDER_HOVER",
  border_active_delta = "BORDER_ACTIVE",
  border_focus_delta = "BORDER_FOCUS",
  text_hover_delta = "TEXT_HOVER",
  text_dimmed_delta = "TEXT_DIMMED",
  text_dark_delta = "TEXT_DARK",
  text_bright_delta = "TEXT_BRIGHT",
  accent_bright_delta = "ACCENT_TEAL_BRIGHT",
  accent_white_lightness = "ACCENT_WHITE",
  accent_white_bright_lightness = "ACCENT_WHITE_BRIGHT",
  status_success = "ACCENT_SUCCESS",
  status_warning = "ACCENT_WARNING",
  status_danger = "ACCENT_DANGER",
  tile_fill_brightness = "TILE_FILL_BRIGHTNESS",
  tile_fill_saturation = "TILE_FILL_SATURATION",
  tile_fill_opacity = "TILE_FILL_OPACITY",
  tile_name_color = "TILE_NAME_COLOR",
  badge_bg_color = "BADGE_BG",
  badge_bg_opacity = "BADGE_BG",
  badge_text_color = "BADGE_TEXT",
  badge_border_opacity = "BADGE_BORDER_OPACITY",
  playlist_tile_color = "PLAYLIST_TILE_COLOR",
  playlist_name_color = "PLAYLIST_NAME_COLOR",
  playlist_badge_color = "PLAYLIST_BADGE_COLOR",
}

--- Render debug overlay showing current theme state
--- @param ctx userdata ImGui context
--- @param ImGui table ImGui library reference
--- @param state table State from init.lua (lightness, t, mode)
function M.render_debug_overlay(ctx, ImGui, state)
  if not M.debug_enabled then return end
  if not ctx or not ImGui then return end

  local lightness = state.lightness or 0.14
  local t = state.t or 0
  local current_mode = state.mode

  ImGui.SetNextWindowBgAlpha(ctx, 0.92)

  local window_flags = ImGui.WindowFlags_AlwaysAutoResize
  if ImGui.WindowFlags_NoSavedSettings then
    window_flags = window_flags | ImGui.WindowFlags_NoSavedSettings
  end

  local visible, open = ImGui.Begin(ctx, "Theme Debug", true, window_flags)
  if visible then
    -- Header info
    ImGui.Text(ctx, string.format("Lightness: %.3f", lightness))
    ImGui.Text(ctx, string.format("Interpolation t: %.3f", t))
    ImGui.Text(ctx, string.format("Mode: %s", current_mode or "nil"))

    -- Validation status
    local valid, err = M.validate()
    if valid then
      ImGui.TextColored(ctx, 0x4CAF50FF, "Validation: OK")
    else
      ImGui.TextColored(ctx, 0xEF5350FF, "Validation: ERRORS")
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, err)
      end
    end

    ImGui.Separator(ctx)

    -- Preset anchors
    ImGui.Text(ctx, string.format("Dark anchor: %.2f (t=0)", Rules.anchors.dark))
    ImGui.Text(ctx, string.format("Light anchor: %.2f (t=1)", Rules.anchors.light))
    ImGui.Separator(ctx)

    -- Computed rules
    ImGui.Text(ctx, "Rules -> Style.COLORS:")
    ImGui.Separator(ctx)

    local computed_rules = Engine.compute_rules(lightness, current_mode)

    -- Sort keys for consistent display
    local sorted_keys = {}
    for key in pairs(Rules.definitions) do
      sorted_keys[#sorted_keys + 1] = key
    end
    table.sort(sorted_keys)

    for _, key in ipairs(sorted_keys) do
      local rule = Rules.definitions[key]
      local value = computed_rules[key]
      local mode = rule.mode or "?"
      local style_key = RULE_TO_STYLE_MAP[key]

      -- Get final color from Style.COLORS
      local final_color = style_key and Style.COLORS[style_key]
      local has_final_color = final_color and type(final_color) == "number" and final_color == math.floor(final_color)

      -- Show final color swatch
      if has_final_color then
        ImGui.ColorButton(ctx, "final_" .. key, math.floor(final_color), 0, 12, 12)
        ImGui.SameLine(ctx)
      end

      -- Show computed value swatch for hex colors
      if type(value) == "string" and value:match("^#") then
        local hex_with_alpha = value
        if #value == 7 then hex_with_alpha = value .. "FF" end
        local color = Colors.hexrgb(hex_with_alpha)
        ImGui.ColorButton(ctx, "computed_" .. key, color, 0, 12, 12)
        ImGui.SameLine(ctx)
      end

      -- Value display
      local display_value = type(value) == "number" and string.format("%.3f", value) or tostring(value)
      local mode_char = mode:sub(1, 1):upper()
      local style_suffix = style_key and (" -> " .. style_key) or ""
      ImGui.Text(ctx, string.format("[%s] %s: %s%s", mode_char, key, display_value, style_suffix))

      -- Tooltip with details
      if ImGui.IsItemHovered(ctx) then
        local tooltip = string.format(
          "dark: %s\nlight: %s\nt=%.3f\nmode: %s",
          tostring(rule.dark), tostring(rule.light), t, mode
        )
        if rule.threshold and rule.threshold ~= 0.5 then
          tooltip = tooltip .. string.format("\nthreshold: %.2f", rule.threshold)
        end
        if style_key then
          tooltip = tooltip .. "\n\nStyle.COLORS." .. style_key
          if has_final_color then
            tooltip = tooltip .. string.format(" = 0x%08X", final_color)
          end
        end
        ImGui.SetTooltip(ctx, tooltip)
      end
    end

    ImGui.Separator(ctx)

    -- All Style.COLORS (collapsible)
    if ImGui.CollapsingHeader(ctx, "All Style.COLORS") then
      local color_keys = {}
      for k in pairs(Style.COLORS) do
        color_keys[#color_keys + 1] = k
      end
      table.sort(color_keys)

      for _, k in ipairs(color_keys) do
        local v = Style.COLORS[k]
        if type(v) == "number" and v == math.floor(v) then
          ImGui.ColorButton(ctx, "style_" .. k, math.floor(v), 0, 12, 12)
          ImGui.SameLine(ctx)
          ImGui.Text(ctx, string.format("%s: 0x%08X", k, math.floor(v)))
        elseif type(v) == "number" then
          ImGui.Text(ctx, string.format("%s: %.3f", k, v))
        else
          ImGui.Text(ctx, string.format("%s: %s", k, tostring(v)))
        end
      end
    end

    -- Registered script colors (collapsible per script)
    for script_name, script_colors in pairs(M.registered_script_colors) do
      if ImGui.CollapsingHeader(ctx, "Script: " .. script_name) then
        local script_keys = {}
        for k in pairs(script_colors) do
          script_keys[#script_keys + 1] = k
        end
        table.sort(script_keys)

        for _, k in ipairs(script_keys) do
          local v = script_colors[k]
          if type(v) == "number" and v == math.floor(v) then
            ImGui.ColorButton(ctx, script_name .. "_" .. k, math.floor(v), 0, 12, 12)
            ImGui.SameLine(ctx)
            ImGui.Text(ctx, string.format("%s: 0x%08X", k, math.floor(v)))
          elseif type(v) == "number" then
            ImGui.Text(ctx, string.format("%s: %.3f", k, v))
          elseif type(v) == "string" and v:match("^#") then
            local hex_with_alpha = v
            if #v == 7 then hex_with_alpha = v .. "FF" end
            local color = Colors.hexrgb(hex_with_alpha)
            ImGui.ColorButton(ctx, script_name .. "_" .. k, color, 0, 12, 12)
            ImGui.SameLine(ctx)
            ImGui.Text(ctx, string.format("%s: %s", k, v))
          else
            ImGui.Text(ctx, string.format("%s: %s", k, tostring(v)))
          end
        end
      end
    end

    ImGui.End(ctx)
  end

  if not open then
    M.debug_enabled = false
  end
end

--- Check for F12 key press to toggle debug overlay
--- @param ctx userdata ImGui context
--- @param ImGui table ImGui library reference
function M.check_debug_hotkey(ctx, ImGui)
  if not ctx or not ImGui then return end

  if ImGui.IsKeyPressed and ImGui.Key_F12 then
    if ImGui.IsKeyPressed(ctx, ImGui.Key_F12) then
      M.toggle_debug()
    end
  end
end

-- =============================================================================
-- AUTO-VALIDATION (Dev Mode)
-- =============================================================================

local function run_auto_validation()
  local is_dev_mode = false

  if os.getenv("ARKITEKT_DEV") then
    is_dev_mode = true
  end

  if reaper and reaper.GetExtState then
    local dev_state = reaper.GetExtState("ARKITEKT", "dev_mode")
    if dev_state == "1" or dev_state == "true" then
      is_dev_mode = true
    end
  end

  if is_dev_mode then
    local valid, err = M.validate()
    if not valid then
      local msg = "[ThemeManager] Validation errors:\n" .. err .. "\n"
      if reaper and reaper.ShowConsoleMsg then
        reaper.ShowConsoleMsg(msg)
      else
        print(msg)
      end
    end
  end
end

-- Run auto-validation on module load
run_auto_validation()

return M
