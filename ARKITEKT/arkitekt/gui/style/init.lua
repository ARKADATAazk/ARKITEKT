-- @noindex
-- Arkitekt/gui/style/defaults.lua
-- Centralized colors, presets, and styling utilities for all Arkitekt components
--
-- This is the SINGLE SOURCE OF TRUTH for all colors and component style presets.
-- Colors are organized by component for easy modification and theming.
--
-- For ImGui native widgets, see imgui_defaults.lua instead.

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
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
  BG_BASE = hexrgb("#252525FF"),        -- Standard control background
  BG_HOVER = hexrgb("#2A2A2AFF"),       -- Hovered control background
  BG_ACTIVE = hexrgb("#303030FF"),      -- Active/pressed control background
  BG_PANEL = hexrgb("#1A1A1AFF"),       -- Panel/container background (darker)
  BG_CHROME = hexrgb("#141414FF"),      -- Chrome (titlebar/statusbar) - significantly darker
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
  pattern_primary = hexrgb("#14141490"),   -- Primary grid/dot color
  pattern_secondary = hexrgb("#14141420"), -- Secondary grid/dot color
}

-- ============================================================================
-- BUTTON COLORS (All button-related colors including toggle variants)
-- ============================================================================
-- Controls colors for standard buttons and toggle button variants.
--
-- When to modify:
-- - Change button color scheme
-- - Add new toggle button color variants (e.g., BLUE, RED, PURPLE)
-- - Adjust toggle button ON state colors
-- - Modify button state transitions (hover, active)
-- ============================================================================

M.BUTTON_COLORS = {
  -- Base button (non-toggle)
  bg = M.COLORS.BG_BASE,
  bg_hover = M.COLORS.BG_HOVER,
  bg_active = M.COLORS.BG_ACTIVE,
  border_outer = M.COLORS.BORDER_OUTER,
  border_inner = M.COLORS.BORDER_INNER,
  border_hover = M.COLORS.BORDER_HOVER,
  border_active = M.COLORS.BORDER_ACTIVE,
  text = M.COLORS.TEXT_NORMAL,
  text_hover = M.COLORS.TEXT_HOVER,
  text_active = M.COLORS.TEXT_ACTIVE,

  -- Toggle button variants (ON state colors)
  -- Each variant defines colors for when the toggle is ON

  -- WHITE variant: Classic white/gray toggle (high contrast)
  toggle_white = {
    bg_on = hexrgb("#2f2f2fff"),
    bg_on_hover = hexrgb("#373737ff"),
    bg_on_active = hexrgb("#343434ff"),
    border_inner_on = hexrgb("#585858ff"),
    border_inner_on_hover = hexrgb("#8b8b8bff"),
    border_inner_on_active = hexrgb("#737373ff"),
    text_on = hexrgb("#FFFFFFFF"),
  },

  -- TEAL variant: Teal/green accent toggle (softer, colorful)
  toggle_teal = {
    bg_on = hexrgb("#295650FF"),        -- Teal background when ON
    bg_on_hover = hexrgb("#2E6459FF"),  -- Slightly lighter on hover
    bg_on_active = hexrgb("#234B46FF"), -- Slightly darker when pressed
    border_inner_on = hexrgb("#37775FFF"),        -- Teal inner border
    border_inner_on_hover = hexrgb("#42866DFF"),  -- Lighter teal on hover
    border_inner_on_active = hexrgb("#2D6851FF"), -- Darker teal when pressed
    text_on = hexrgb("#41E0A3FF"),      -- Bright teal/green text
  },

  -- TRANSPARENT variant: Semi-transparent overlay style (for corner buttons over content)
  toggle_transparent = {
    bg_on = hexrgb("#434343AA"),        -- Semi-transparent gray when ON (67% opacity)
    bg_on_hover = hexrgb("#484848BB"),  -- Slightly lighter on hover (73% opacity)
    bg_on_active = hexrgb("#3E3E3E99"), -- Slightly darker when pressed (60% opacity)
    border_inner_on = hexrgb("#898989AA"),        -- Semi-transparent border
    border_inner_on_hover = hexrgb("#9A9A9ABB"),  -- Lighter on hover
    border_inner_on_active = hexrgb("#7E7E7E99"), -- Darker when pressed
    text_on = hexrgb("#FFFFFFDD"),      -- Bright white text (87% opacity)
  },
}

-- ============================================================================
-- DROPDOWN COLORS (All dropdown menu colors)
-- ============================================================================
-- Controls colors for dropdown menus including button, popup, and items.
--
-- When to modify:
-- - Change dropdown button appearance
-- - Adjust popup menu styling
-- - Modify item hover/selection colors
-- - Change arrow indicator color
-- ============================================================================

M.DROPDOWN_COLORS = {
  -- Dropdown button (closed state)
  bg = M.COLORS.BG_BASE,
  bg_hover = M.COLORS.BG_HOVER,
  bg_active = M.COLORS.BG_ACTIVE,
  border_outer = M.COLORS.BORDER_OUTER,
  border_inner = M.COLORS.BORDER_INNER,
  border_hover = M.COLORS.BORDER_HOVER,
  border_active = M.COLORS.BORDER_ACTIVE,
  text = M.COLORS.TEXT_NORMAL,
  text_hover = M.COLORS.TEXT_HOVER,
  text_active = M.COLORS.TEXT_ACTIVE,

  -- Arrow indicator
  arrow = M.COLORS.TEXT_NORMAL,
  arrow_hover = M.COLORS.TEXT_HOVER,

  -- Popup menu (lighter grey with much darker borders)
  popup_bg = hexrgb("#222222FF"),         -- Popup background (lighter grey)
  popup_border = hexrgb("#0F0F0FFF"),     -- Popup border (much darker, almost black)

  -- Menu items (enhanced styling)
  item_bg = hexrgb("#00000000"),          -- Item background (transparent)
  item_hover = hexrgb("#2E2E2EFF"),       -- Item background on hover (subtle highlight)
  item_active = hexrgb("#353535FF"),      -- Item background when active (more visible)
  item_selected = hexrgb("#303030FF"),    -- Item background when selected
  item_text = M.COLORS.TEXT_NORMAL,       -- Item text
  item_text_hover = M.COLORS.TEXT_HOVER,  -- Item text on hover
  item_text_selected = M.COLORS.TEXT_BRIGHT, -- Item text when selected (brighter)
}

-- ============================================================================
-- SEARCH INPUT COLORS
-- ============================================================================
-- Darker than buttons/combobox for clear visual distinction
-- Input fields are recessed/inset elements, so darker background emphasizes depth

M.SEARCH_INPUT_COLORS = {
  bg = M.COLORS.BG_BASE,
  bg_hover = M.COLORS.BG_HOVER,
  bg_active = M.COLORS.BG_ACTIVE,
  border_outer = M.COLORS.BORDER_OUTER,
  border_inner = M.COLORS.BORDER_INNER,
  border_hover = M.COLORS.BORDER_HOVER,
  border_active = M.COLORS.BORDER_ACTIVE,
  text = M.COLORS.TEXT_NORMAL,         -- More transparent/dimmed text
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
-- TOGGLE BUTTON STYLE BUILDER
-- ============================================================================
-- Creates complete toggle button configurations from color variants.
-- This combines base button colors (OFF state) with variant colors (ON state).
-- ============================================================================

--- Creates a toggle button style from a variant
--- @param variant table Color variant from M.BUTTON_COLORS.toggle_*
--- @return table Complete toggle button style configuration
local function create_toggle_style(variant)
  local BC = M.BUTTON_COLORS
  return {
    -- Normal/OFF state (inherit from base button colors)
    bg_color = BC.bg,
    bg_hover_color = BC.bg_hover,
    bg_active_color = BC.bg_active,
    border_outer_color = BC.border_outer,
    border_inner_color = BC.border_inner,
    border_hover_color = BC.border_hover,
    border_active_color = BC.border_active,
    text_color = BC.text,
    text_hover_color = BC.text_hover,
    text_active_color = BC.text_active,

    -- ON state (from variant)
    bg_on_color = variant.bg_on,
    bg_on_hover_color = variant.bg_on_hover,
    bg_on_active_color = variant.bg_on_active,
    border_outer_on_color = M.COLORS.BORDER_OUTER, -- Always black outer border
    border_inner_on_color = variant.border_inner_on,
    border_on_hover_color = variant.border_inner_on_hover,
    border_on_active_color = variant.border_inner_on_active,
    text_on_color = variant.text_on,
    text_on_hover_color = variant.text_on,
    text_on_active_color = variant.text_on,

    padding_x = 10,
    padding_y = 6,
    rounding = 0,
  }
end

-- ============================================================================
-- COMPONENT STYLE PRESETS
-- ============================================================================
-- Pre-built complete style configurations for each component type.
-- These combine colors with geometry settings (padding, rounding, etc.).
--
-- Usage: Pass preset_name to component config, e.g.:
--   config = { preset_name = "BUTTON_TOGGLE_TEAL" }
-- ============================================================================

M.BUTTON = {
  bg_color = M.BUTTON_COLORS.bg,
  bg_hover_color = M.BUTTON_COLORS.bg_hover,
  bg_active_color = M.BUTTON_COLORS.bg_active,
  border_outer_color = M.BUTTON_COLORS.border_outer,
  border_inner_color = M.BUTTON_COLORS.border_inner,
  border_hover_color = M.BUTTON_COLORS.border_hover,
  border_active_color = M.BUTTON_COLORS.border_active,
  text_color = M.BUTTON_COLORS.text,
  text_hover_color = M.BUTTON_COLORS.text_hover,
  text_active_color = M.BUTTON_COLORS.text_active,
  -- Disabled state colors
  bg_disabled_color = hexrgb("#1a1a1a"),  -- Darker, dimmed background
  border_inner_disabled_color = hexrgb("#202020"),  -- Very dark inner border
  border_outer_disabled_color = hexrgb("#000000DD"),  -- Same outer border as normal
  text_disabled_color = hexrgb("#555555"),  -- Dimmed text
  padding_x = 10,
  padding_y = 6,
  rounding = 0,
}

-- Toggle button presets - built from color variants
M.BUTTON_TOGGLE = create_toggle_style(M.BUTTON_COLORS.toggle_white)
M.BUTTON_TOGGLE_WHITE = create_toggle_style(M.BUTTON_COLORS.toggle_white)
M.BUTTON_TOGGLE_TEAL = create_toggle_style(M.BUTTON_COLORS.toggle_teal)
M.BUTTON_TOGGLE_TRANSPARENT = create_toggle_style(M.BUTTON_COLORS.toggle_transparent)

-- Legacy alias for backward compatibility
M.BUTTON_TOGGLE_ACCENT = M.BUTTON_TOGGLE_TEAL

M.SEARCH_INPUT = {
  placeholder = "Search...",
  fade_speed = 8.0,
  bg_color = M.SEARCH_INPUT_COLORS.bg,
  bg_hover_color = M.SEARCH_INPUT_COLORS.bg_hover,
  bg_active_color = M.SEARCH_INPUT_COLORS.bg_active,
  border_outer_color = M.SEARCH_INPUT_COLORS.border_outer,
  border_inner_color = M.SEARCH_INPUT_COLORS.border_inner,
  border_hover_color = M.SEARCH_INPUT_COLORS.border_hover,
  border_active_color = M.SEARCH_INPUT_COLORS.border_active,
  text_color = M.SEARCH_INPUT_COLORS.text,
  padding_x = 6,
  rounding = 0,
  tooltip_delay = 0.5,
}

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

M.DROPDOWN = {
  bg_color = M.DROPDOWN_COLORS.bg,
  bg_hover_color = M.DROPDOWN_COLORS.bg_hover,
  bg_active_color = M.DROPDOWN_COLORS.bg_active,
  border_outer_color = M.DROPDOWN_COLORS.border_outer,
  border_inner_color = M.DROPDOWN_COLORS.border_inner,
  border_hover_color = M.DROPDOWN_COLORS.border_hover,
  border_active_color = M.DROPDOWN_COLORS.border_active,
  text_color = M.DROPDOWN_COLORS.text,
  text_hover_color = M.DROPDOWN_COLORS.text_hover,
  text_active_color = M.DROPDOWN_COLORS.text_active,
  rounding = 0,
  padding_x = 10,
  padding_y = 6,
  arrow_size = 6,
  arrow_color = M.DROPDOWN_COLORS.arrow,
  arrow_hover_color = M.DROPDOWN_COLORS.arrow_hover,
  enable_mousewheel = true,
  tooltip_delay = 0.5,
  popup = {
    bg_color = M.DROPDOWN_COLORS.popup_bg,
    border_color = M.DROPDOWN_COLORS.popup_border,
    item_bg_color = M.DROPDOWN_COLORS.item_bg,
    item_hover_color = M.DROPDOWN_COLORS.item_hover,
    item_active_color = M.DROPDOWN_COLORS.item_active,
    item_text_color = M.DROPDOWN_COLORS.item_text,
    item_text_hover_color = M.DROPDOWN_COLORS.item_text_hover,
    item_selected_color = M.DROPDOWN_COLORS.item_selected,
    item_selected_text_color = M.DROPDOWN_COLORS.item_text_selected,
    rounding = 2,             -- Slight rounding for modern look
    padding = 6,              -- More padding for breathing room
    item_height = 26,         -- Taller items for better touch targets
    item_padding_x = 12,      -- More horizontal padding
    border_thickness = 1,
  },
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

-- Lerp between two colors
function M.RENDER.lerp_color(a, b, t)
  local ar = (a >> 24) & 0xFF
  local ag = (a >> 16) & 0xFF
  local ab = (a >> 8) & 0xFF
  local aa = a & 0xFF

  local br = (b >> 24) & 0xFF
  local bg = (b >> 16) & 0xFF
  local bb = (b >> 8) & 0xFF
  local ba = b & 0xFF

  local r = (ar + (br - ar) * t)//1
  local g = (ag + (bg - ag) * t)//1
  local b = (ab + (bb - ab) * t)//1
  local a = (aa + (ba - aa) * t)//1

  return (r << 24) | (g << 16) | (b << 8) | a
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
-- COLORED BUTTON PRESET GENERATOR (Algorithmic Hue Variations)
-- ============================================================================
-- Generate colored button presets from HSL values for visual consistency.
-- All variants maintain the same saturation/lightness relationships,
-- differing only in hue. This ensures mathematical harmony and allows
-- buttons to adapt to theme changes.
--
-- Examples:
--   Red button:    create_colored_button_preset(0.0)      -- 0° hue
--   Green button:  create_colored_button_preset(0.33)     -- 120° hue
--   Blue button:   create_colored_button_preset(0.66)     -- 240° hue
--   Theme accent:  create_colored_button_preset(nil)      -- Uses theme's accent hue
-- ============================================================================

--- Create a colored button preset from HSL values
--- @param hue number|nil Hue (0-1): 0=red, 0.33=green, 0.66=blue, nil=theme accent
--- @param saturation number|nil Saturation intensity (0-1, default: 0.65)
--- @param lightness number|nil Brightness (0-1, default: 0.48)
--- @return table Button preset configuration with derived colors
function M.create_colored_button_preset(hue, saturation, lightness)
  -- Use theme accent hue if not specified
  if hue == nil then
    local h, s, l = Colors.rgb_to_hsl(M.COLORS.ACCENT_PRIMARY)
    hue = h
  end

  -- Default to vibrant, balanced colors
  saturation = saturation or 0.65
  lightness = lightness or 0.48

  -- Generate base color from HSL
  local r, g, b = Colors.hsl_to_rgb(hue, saturation, lightness)
  local base_color = Colors.components_to_rgba(r, g, b, 0xFF)

  -- Derive all button states with consistent relationships
  return {
    -- Base states
    bg_color = base_color,
    bg_hover_color = Colors.adjust_lightness(base_color, 0.08),   -- +8% lighter
    bg_active_color = Colors.adjust_lightness(base_color, -0.08), -- -8% darker
    bg_disabled_color = Colors.adjust_saturation(
      Colors.adjust_lightness(base_color, -0.1),
      -0.4
    ), -- Desaturated & darker

    -- Borders (darker/lighter variations)
    border_outer_color = Colors.adjust_lightness(base_color, -0.18),  -- Much darker
    border_inner_color = Colors.adjust_lightness(base_color, 0.15),   -- Lighter highlight
    border_hover_color = Colors.adjust_lightness(base_color, 0.22),   -- Even lighter
    border_active_color = Colors.adjust_lightness(base_color, -0.12), -- Darker when pressed
    border_inner_disabled_color = Colors.adjust_lightness(base_color, -0.15),
    border_outer_disabled_color = Colors.adjust_lightness(base_color, -0.20),

    -- Text (auto white/black based on background luminance)
    text_color = Colors.auto_text_color(base_color),
    text_hover_color = Colors.auto_text_color(base_color),
    text_active_color = Colors.auto_text_color(base_color),
    text_disabled_color = Colors.adjust_lightness(Colors.auto_text_color(base_color), -0.3),

    -- Geometry
    padding_x = 10,
    padding_y = 6,
    rounding = 0,
  }
end

--- Generate a full set of colored button presets with consistent HSL
--- @param base_hue number|nil Base hue (0-1), nil for theme accent
--- @return table Table of button presets (primary, secondary, tertiary)
function M.create_colored_button_set(base_hue)
  base_hue = base_hue or 0.55  -- Default blue

  return {
    primary = M.create_colored_button_preset(base_hue, 0.70, 0.50),        -- Vibrant
    secondary = M.create_colored_button_preset(base_hue, 0.45, 0.52),      -- Muted
    tertiary = M.create_colored_button_preset(base_hue, 0.30, 0.55),       -- Very muted
    danger = M.create_colored_button_preset(0.0, 0.70, 0.55),              -- Red (fixed)
    success = M.create_colored_button_preset(0.33, 0.65, 0.50),            -- Green (fixed)
    warning = M.create_colored_button_preset(0.08, 0.80, 0.60),            -- Orange (fixed)
    info = M.create_colored_button_preset(base_hue, 0.70, 0.50),           -- Theme hue
  }
end

--- Generate analogous colored buttons (adjacent hues on color wheel)
--- @param base_hue number Base hue (0-1)
--- @param angle number|nil Hue angle offset (0-1, default: 0.083 = 30°)
--- @return table Table with main, left, right button presets
function M.create_analogous_button_set(base_hue, angle)
  angle = angle or 0.083  -- 30° default

  return {
    main = M.create_colored_button_preset(base_hue, 0.70, 0.50),
    left = M.create_colored_button_preset((base_hue - angle) % 1, 0.70, 0.50),  -- -30°
    right = M.create_colored_button_preset((base_hue + angle) % 1, 0.70, 0.50), -- +30°
  }
end

--- Generate complementary colored button (opposite hue)
--- @param base_hue number Base hue (0-1)
--- @return table Button preset for complementary color
function M.create_complementary_button(base_hue)
  return M.create_colored_button_preset((base_hue + 0.5) % 1, 0.70, 0.50)  -- +180°
end

--- Generate triadic colored buttons (120° apart on color wheel)
--- @param base_hue number Base hue (0-1)
--- @return table Array of 3 button presets
function M.create_triadic_button_set(base_hue)
  return {
    M.create_colored_button_preset(base_hue, 0.70, 0.50),
    M.create_colored_button_preset((base_hue + 0.333) % 1, 0.70, 0.50),  -- +120°
    M.create_colored_button_preset((base_hue + 0.666) % 1, 0.70, 0.50),  -- +240°
  }
end

--- Generate saturation variants of same hue (muted to vivid)
--- @param base_hue number Base hue (0-1)
--- @param base_lightness number|nil Lightness (0-1, default: 0.48)
--- @return table Table with muted, normal, vivid variants
function M.create_saturation_variants(base_hue, base_lightness)
  base_lightness = base_lightness or 0.48

  return {
    muted = M.create_colored_button_preset(base_hue, 0.30, base_lightness),   -- Low saturation
    normal = M.create_colored_button_preset(base_hue, 0.65, base_lightness),  -- Default
    vivid = M.create_colored_button_preset(base_hue, 0.85, base_lightness),   -- High saturation
  }
end

--- Generate lightness variants of same hue (dark to light)
--- @param base_hue number Base hue (0-1)
--- @param base_saturation number|nil Saturation (0-1, default: 0.65)
--- @return table Table with dark, normal, light variants
function M.create_lightness_variants(base_hue, base_saturation)
  base_saturation = base_saturation or 0.65

  return {
    dark = M.create_colored_button_preset(base_hue, base_saturation, 0.35),   -- Dark
    normal = M.create_colored_button_preset(base_hue, base_saturation, 0.48), -- Default
    light = M.create_colored_button_preset(base_hue, base_saturation, 0.62),  -- Light
  }
end

--- Generate full matrix of saturation × lightness variants
--- Creates 9 button presets covering the full range
--- @param base_hue number Base hue (0-1)
--- @return table 2D table: variants[saturation][lightness]
function M.create_button_matrix(base_hue)
  return {
    muted = {
      dark = M.create_colored_button_preset(base_hue, 0.30, 0.35),
      normal = M.create_colored_button_preset(base_hue, 0.30, 0.48),
      light = M.create_colored_button_preset(base_hue, 0.30, 0.62),
    },
    normal = {
      dark = M.create_colored_button_preset(base_hue, 0.65, 0.35),
      normal = M.create_colored_button_preset(base_hue, 0.65, 0.48),
      light = M.create_colored_button_preset(base_hue, 0.65, 0.62),
    },
    vivid = {
      dark = M.create_colored_button_preset(base_hue, 0.85, 0.35),
      normal = M.create_colored_button_preset(base_hue, 0.85, 0.48),
      light = M.create_colored_button_preset(base_hue, 0.85, 0.62),
    },
  }
end

--- Generate monochromatic palette (same hue, varying saturation/lightness)
--- Creates a harmonious set of buttons from a single hue
--- @param base_hue number Base hue (0-1)
--- @return table Named preset variants
function M.create_monochromatic_set(base_hue)
  return {
    primary = M.create_colored_button_preset(base_hue, 0.70, 0.50),      -- Vibrant
    secondary = M.create_colored_button_preset(base_hue, 0.45, 0.52),    -- Muted
    subtle = M.create_colored_button_preset(base_hue, 0.25, 0.58),       -- Very muted, lighter
    bold = M.create_colored_button_preset(base_hue, 0.85, 0.42),         -- Very vivid, darker
    accent = M.create_colored_button_preset(base_hue, 0.75, 0.60),       -- Bright accent
  }
end

-- Pre-generate semantic colored button presets
-- These use fixed hues for consistent meaning (red=danger, green=success, etc.)
M.DYNAMIC_PRESETS.BUTTON_DANGER = M.create_colored_button_preset(0.0, 0.68, 0.55)     -- Red
M.DYNAMIC_PRESETS.BUTTON_SUCCESS = M.create_colored_button_preset(0.33, 0.60, 0.50)   -- Green
M.DYNAMIC_PRESETS.BUTTON_WARNING = M.create_colored_button_preset(0.08, 0.78, 0.62)   -- Orange
M.DYNAMIC_PRESETS.BUTTON_INFO = M.create_colored_button_preset(0.55, 0.68, 0.52)      -- Blue
M.DYNAMIC_PRESETS.BUTTON_PRIMARY = M.create_colored_button_preset(nil, 0.70, 0.50)    -- Theme accent

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Apply defaults to user config
-- Delegates to centralized Config utility for consistency
function M.apply_defaults(defaults, user_config)
  return ConfigUtil.apply_defaults(defaults, user_config)
end

-- Apply alpha to color
function M.apply_alpha(color, alpha_factor)
  local a = color & 0xFF
  local new_a = (a * alpha_factor)//1
  return (color & 0xFFFFFF00) | new_a
end

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
