-- @noindex
-- Arkitekt/gui/style/defaults.lua
-- Centralized colors, presets, and styling utilities for all Arkitekt components
--
-- This is the SINGLE SOURCE OF TRUTH for all colors and component style presets.
-- Colors are organized by component for easy modification and theming.
--
-- For ImGui native widgets, see imgui_defaults.lua instead.

local ImGui = require('arkitekt.core.imgui')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb
local ConfigUtil = require('arkitekt.core.config')

local M = {}

-- ============================================================================
-- SHARED PRIMITIVES (Used across multiple components)
-- ============================================================================
-- These are foundational colors that multiple components reference.
-- Modify these to change the overall theme of the application.
-- ============================================================================

M.COLORS = {
  -- Backgrounds
  BG_BASE = hexrgb("#242424FF"),        -- 36,36,36 RGB - main content background
  BG_HOVER = hexrgb("#2A2A2AFF"),       -- Hovered control background
  BG_ACTIVE = hexrgb("#303030FF"),      -- Active/pressed control background
  BG_HEADER = hexrgb("#1E1E1EFF"),      -- 30,30,30 RGB - header/toolbar background
  BG_PANEL = hexrgb("#1A1A1AFF"),       -- 26,26,26 RGB - panel content background (darker)
  BG_CHROME = hexrgb("#0F0F0FFF"),      -- 15,15,15 RGB - titlebar/statusbar
  BG_TRANSPARENT = hexrgb("#00000000"), -- Transparent background

  -- Borders
  BORDER_OUTER = hexrgb("#000000DD"),   -- Black outer border (strong contrast)
  BORDER_INNER = hexrgb("#2f2f2fff"),   -- Gray inner highlight border
  BORDER_HOVER = hexrgb("#505050FF"),   -- Lighter border on hover
  BORDER_ACTIVE = hexrgb("#B0B0B077"),  -- Active state border (semi-transparent)
  BORDER_FOCUS = hexrgb("#7B7B7BFF"),   -- Focus state border

  -- Text
  TEXT_NORMAL = hexrgb("#CCCCCCFF"),    -- Standard text color
  TEXT_HOVER = hexrgb("#FFFFFFFF"),     -- Bright text on hover
  TEXT_ACTIVE = hexrgb("#FFFFFFFF"),    -- Bright text when active
  TEXT_DIMMED = hexrgb("#AAAAAAFF"),    -- Dimmed/secondary text
  TEXT_DARK = hexrgb("#707070FF"),      -- Dark text for high-contrast areas
  TEXT_BRIGHT = hexrgb("#EEEEEEFF"),    -- Extra bright text

  -- Accents (themed - used for toggle buttons, highlights)
  ACCENT_PRIMARY = hexrgb("#4A9EFF"),   -- Primary accent (blue)
  ACCENT_TEAL = hexrgb("#295650FF"),    -- Teal accent (for toggle buttons)
  ACCENT_TEAL_BRIGHT = hexrgb("#41E0A3FF"), -- Bright teal (for text on teal bg)
  ACCENT_WHITE = hexrgb("#2f2f2fff"),   -- White/gray accent (desaturated)
  ACCENT_WHITE_BRIGHT = hexrgb("#585858ff"), -- Bright white accent
  ACCENT_TRANSPARENT = hexrgb("#43434388"), -- Semi-transparent accent (overlays)

  -- Semantic colors (status indicators)
  ACCENT_SUCCESS = hexrgb("#4CAF50"),   -- Success/confirmation (green)
  ACCENT_WARNING = hexrgb("#FFA726"),   -- Warning state (orange)
  ACCENT_DANGER = hexrgb("#EF5350"),    -- Error/danger state (red)

  -- Background patterns (decorative grid/dot patterns)
  PATTERN_PRIMARY = hexrgb("#30303060"),   -- Primary pattern color (semi-transparent)
  PATTERN_SECONDARY = hexrgb("#30303020"), -- Secondary pattern color (more transparent)
}

-- ============================================================================
-- PANEL COLORS (All panel widget colors)
-- ============================================================================
-- Controls colors for panel containers, headers, tabs, and decorative elements.
--
-- When to modify:
-- - Want to change panel background darkness
-- - Adjust header bar styling
-- - Modify tab appearance
-- - Change separator line visibility
-- - Adjust background pattern colors
-- ============================================================================

M.PANEL_COLORS = {
  -- Panel container
  bg_panel = hexrgb("#1A1A1AFF"),       -- Main panel container background (darker than controls)
  border_panel = M.COLORS.BORDER_OUTER, -- Panel outer border (reuse shared)

  -- Header bar
  bg_header = hexrgb("#1E1E1EFF"),      -- Header bar background
  border_header = hexrgb("#00000066"),  -- Subtle header border

  -- Tab strip
  bg_tab = M.COLORS.BG_BASE,            -- Tab background (inactive)
  bg_tab_hover = M.COLORS.BG_HOVER,     -- Tab background (hovered)
  bg_tab_active = M.COLORS.BG_ACTIVE,   -- Tab background (active/selected)
  text_tab = M.COLORS.TEXT_DIMMED,      -- Tab text (inactive)
  text_tab_hover = M.COLORS.TEXT_HOVER, -- Tab text (hovered)
  text_tab_active = M.COLORS.TEXT_ACTIVE, -- Tab text (active)
  border_tab_inner = M.COLORS.BORDER_INNER,  -- Tab inner border
  border_tab_hover = M.COLORS.BORDER_HOVER,  -- Tab border on hover
  border_tab_focus = M.COLORS.BORDER_FOCUS,  -- Tab border when focused

  -- Tab track (background behind tabs)
  bg_tab_track = hexrgb("#1A1A1AFF"),   -- Track background
  border_tab_track = M.COLORS.BORDER_OUTER, -- Track border

  -- Separator
  separator_line = hexrgb("#30303080"),  -- Separator line color (semi-transparent)

  -- Scrollbar
  bg_scrollbar = M.COLORS.BG_TRANSPARENT, -- Scrollbar background

  -- Background pattern (decorative grid/dot pattern)
  -- References M.COLORS for dynamic theming
  pattern_primary = M.COLORS.PATTERN_PRIMARY,
  pattern_secondary = M.COLORS.PATTERN_SECONDARY,
}


-- ============================================================================
-- TOOLTIP COLORS
-- ============================================================================

M.TOOLTIP_COLORS = {
  bg = hexrgb("#2A2A2AFF"),
  border = M.COLORS.BORDER_INNER,
  text = hexrgb("#EEEEEEFF"),
}

-- ============================================================================
-- COMPONENT STYLE PRESETS
-- ============================================================================
-- Note: For dynamic theming, use the build_*_config() functions instead.
-- Static presets below are for backward compatibility only.
-- ============================================================================

-- Action chip presets - colored rectangles with dark text
M.ACTION_CHIP_WILDCARD = {
  bg_color = hexrgb("#5B8FB9"),  -- Muted blue for technical wildcards
  text_color = hexrgb("#1a1a1a"),  -- Dark text
  border_color = Colors.with_alpha(hexrgb("#000000"), 100),
  rounding = 2,
  padding_h = 8,
}

M.ACTION_CHIP_TAG = {
  bg_color = hexrgb("#8B7355"),  -- Warm amber for tags/names
  text_color = hexrgb("#1a1a1a"),  -- Dark text
  border_color = Colors.with_alpha(hexrgb("#000000"), 100),
  rounding = 2,
  padding_h = 8,
}

M.TOOLTIP = {
  bg_color = M.TOOLTIP_COLORS.bg,
  border_color = M.TOOLTIP_COLORS.border,
  text_color = M.TOOLTIP_COLORS.text,
  padding_x = 8,
  padding_y = 6,
  rounding = 4,
  border_thickness = 1,
  delay = 0.5,
}

-- ============================================================================
-- RENDERING UTILITIES
-- ============================================================================

M.RENDER = {}

--- Converts corner_rounding config to ImGui corner flags.
--- Logic:
---   - nil corner_rounding = standalone element, return 0 (caller handles default)
---   - corner_rounding exists with flags = specific corners rounded
---   - corner_rounding exists with no flags = middle element, explicitly no rounding
--- @param corner_rounding table|nil Corner rounding configuration from layout engine
--- @return integer ImGui DrawFlags for corner rounding
function M.RENDER.get_corner_flags(corner_rounding)
  -- No corner_rounding config = standalone element (not in panel header)
  -- Return 0 so caller can apply default behavior
  if not corner_rounding then
    return 0
  end

  -- Panel context: build flags from individual corner settings
  local flags = 0
  if corner_rounding.round_top_left then
    flags = flags | ImGui.DrawFlags_RoundCornersTopLeft
  end
  if corner_rounding.round_top_right then
    flags = flags | ImGui.DrawFlags_RoundCornersTopRight
  end
  if corner_rounding.round_bottom_left then
    flags = flags | ImGui.DrawFlags_RoundCornersBottomLeft
  end
  if corner_rounding.round_bottom_right then
    flags = flags | ImGui.DrawFlags_RoundCornersBottomRight
  end

  -- If flags == 0 here, it means we're in panel context but no corners should round
  -- (middle element in a group). Return RoundCornersNone to explicitly disable rounding.
  if flags == 0 then
    return ImGui.DrawFlags_RoundCornersNone
  end

  return flags
end

-- Draw standard double-border control background
function M.RENDER.draw_control_background(dl, x, y, w, h, bg_color, border_inner, border_outer, rounding, corner_flags)
  corner_flags = corner_flags or 0
  local inner_rounding = math.max(0, rounding - 2)

  -- Background
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color, inner_rounding, corner_flags)

  -- Inner border
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + w - 1, y + h - 1, border_inner, inner_rounding, corner_flags, 1)

  -- Outer border
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_outer, inner_rounding, corner_flags, 1)
end

-- Get state-based colors for a control
function M.RENDER.get_state_colors(config, is_hovered, is_active)
  local colors = {
    bg = config.bg_color,
    border_inner = config.border_inner_color,
    border_outer = config.border_outer_color,
    text = config.text_color,
  }

  if is_active then
    colors.bg = config.bg_active_color or colors.bg
    colors.border_inner = config.border_active_color or colors.border_inner
    colors.text = config.text_active_color or colors.text
  elseif is_hovered then
    colors.bg = config.bg_hover_color or colors.bg
    colors.border_inner = config.border_hover_color or colors.border_inner
    colors.text = config.text_hover_color or colors.text
  end

  return colors
end

-- ============================================================================
-- DYNAMIC CONFIG BUILDERS (Option 3: Direct M.COLORS Access)
-- ============================================================================
-- These functions build widget configs from M.COLORS every time they're called.
-- This enables truly dynamic theming - changing M.COLORS updates all widgets
-- on the next frame with zero rebuild needed.
--
-- Usage in widgets:
--   local config = Style.build_button_config()
--   apply_preset(config, opts.preset_name)
--   merge_user_opts(config, opts)
-- ============================================================================

--- Build button config from current M.COLORS
--- @return table Button configuration with all color properties
function M.build_button_config()
  return {
    -- Backgrounds
    bg_color = M.COLORS.BG_BASE,
    bg_hover_color = M.COLORS.BG_HOVER,
    bg_active_color = M.COLORS.BG_ACTIVE,
    bg_disabled_color = Colors.adjust_lightness(M.COLORS.BG_BASE, -0.05),

    -- Borders
    border_outer_color = M.COLORS.BORDER_OUTER,
    border_inner_color = M.COLORS.BORDER_INNER,
    border_hover_color = M.COLORS.BORDER_HOVER,
    border_active_color = M.COLORS.BORDER_ACTIVE,
    border_inner_disabled_color = Colors.adjust_lightness(M.COLORS.BORDER_INNER, -0.05),
    border_outer_disabled_color = M.COLORS.BORDER_OUTER,

    -- Text
    text_color = M.COLORS.TEXT_NORMAL,
    text_hover_color = M.COLORS.TEXT_HOVER,
    text_active_color = M.COLORS.TEXT_ACTIVE,
    text_disabled_color = M.COLORS.TEXT_DIMMED,

    -- Geometry (non-color properties)
    padding_x = 10,
    padding_y = 6,
    rounding = 0,
  }
end

--- Build colored button config (danger, success, warning, info)
--- @param variant string "danger", "success", "warning", or "info"
--- @return table Button configuration with colored theme
function M.build_colored_button_config(variant)
  local prefix = "BUTTON_" .. string.upper(variant) .. "_"
  local bg = M.COLORS[prefix .. "BG"]
  local hover = M.COLORS[prefix .. "HOVER"]
  local active = M.COLORS[prefix .. "ACTIVE"]
  local text = M.COLORS[prefix .. "TEXT"]

  -- Fallback to default button if variant not found
  if not bg then return M.build_button_config() end

  return {
    -- Backgrounds
    bg_color = bg,
    bg_hover_color = hover,
    bg_active_color = active,
    bg_disabled_color = Colors.adjust_saturation(Colors.adjust_lightness(bg, -0.1), -0.4),

    -- Borders (derived from bg)
    border_outer_color = Colors.adjust_lightness(bg, -0.18),
    border_inner_color = Colors.adjust_lightness(bg, 0.12),
    border_hover_color = Colors.adjust_lightness(hover, 0.10),
    border_active_color = Colors.adjust_lightness(active, -0.10),
    border_inner_disabled_color = Colors.adjust_lightness(bg, -0.15),
    border_outer_disabled_color = Colors.adjust_lightness(bg, -0.20),

    -- Text
    text_color = text,
    text_hover_color = text,
    text_active_color = text,
    text_disabled_color = Colors.adjust_lightness(text, -0.3),

    -- Geometry
    padding_x = 10,
    padding_y = 6,
    rounding = 0,
  }
end

--- Build dropdown config from current M.COLORS
--- @return table Dropdown configuration with all color properties
function M.build_dropdown_config()
  return {
    -- Button (closed state)
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

    -- Arrow
    arrow_color = M.COLORS.TEXT_NORMAL,
    arrow_hover_color = M.COLORS.TEXT_HOVER,

    -- Geometry
    rounding = 0,
    padding_x = 10,
    padding_y = 6,
    arrow_size = 6,
    enable_mousewheel = true,
    tooltip_delay = 0.5,

    -- Popup menu
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

--- Build search input config from current M.COLORS
--- @return table Search input configuration
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

--- Build tooltip config from current M.COLORS
--- @return table Tooltip configuration
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

-- ============================================================================
-- PRESET DEFINITIONS (Option 3: Key Mappings)
-- ============================================================================
-- Presets map config keys to M.COLORS keys (strings) or direct values.
-- At application time, string keys are resolved to actual colors.
--
-- This allows presets to stay dynamic - they reference M.COLORS keys
-- instead of copying color values.
-- ============================================================================

M.DYNAMIC_PRESETS = {
  -- Toggle button variants (ON state colors)
  BUTTON_TOGGLE_TEAL = {
    -- ON state (key mappings to M.COLORS)
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

  -- Action chips (colored rectangles with dark text)
  ACTION_CHIP_WILDCARD = {
    bg_color = hexrgb("#5B8FB9"),  -- Direct value (not theme-dependent)
    text_color = hexrgb("#1a1a1a"),
    border_color = Colors.with_alpha(hexrgb("#000000"), 100),
    rounding = 2,
    padding_h = 8,
  },

  ACTION_CHIP_TAG = {
    bg_color = hexrgb("#8B7355"),
    text_color = hexrgb("#1a1a1a"),
    border_color = Colors.with_alpha(hexrgb("#000000"), 100),
    rounding = 2,
    padding_h = 8,
  },
}

-- Legacy alias
M.DYNAMIC_PRESETS.BUTTON_TOGGLE_ACCENT = M.DYNAMIC_PRESETS.BUTTON_TOGGLE_TEAL

--- Apply a dynamic preset to a config
--- Resolves string keys (e.g., "ACCENT_TEAL") to actual colors from M.COLORS
--- @param config table Config to modify
--- @param preset_name string Preset name from M.DYNAMIC_PRESETS
function M.apply_dynamic_preset(config, preset_name)
  local preset = M.DYNAMIC_PRESETS[preset_name]
  if not preset then return end

  for key, value in pairs(preset) do
    if type(value) == "string" then
      -- String value = key into M.COLORS
      config[key] = M.COLORS[value]
    else
      -- Direct value (number, boolean, etc.)
      config[key] = value
    end
  end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Get state-based color (normal, hover, active)
function M.get_state_color(colors, is_hovered, is_active, color_key)
  local active_key = color_key .. "_active"
  local hover_key = color_key .. "_hover"

  if is_active and colors[active_key] then
    return colors[active_key]
  elseif is_hovered and colors[hover_key] then
    return colors[hover_key]
  else
    return colors[color_key]
  end
end

return M
