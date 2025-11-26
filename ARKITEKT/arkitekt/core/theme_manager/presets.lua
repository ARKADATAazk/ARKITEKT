-- @noindex
-- arkitekt/core/theme_manager/presets.lua
-- Built-in theme presets
--
-- Provides dark and light presets plus legacy presets for backward compatibility.
-- Note: "grey" preset was removed - use "adapt" mode with a grey REAPER theme
-- or call generate_and_apply() directly with grey base colors.

local Colors = require('arkitekt.core.colors')
local Engine = require('arkitekt.core.theme_manager.engine')

local M = {}

-- =============================================================================
-- THEME DEFINITIONS
-- =============================================================================

M.themes = {
  -- DARK: Deep, high-contrast theme (~14% lightness)
  -- Best for: Low-light environments, OLED screens
  dark = function()
    return Engine.generate_palette(
      Colors.hexrgb("#242424FF"),  -- 36,36,36 RGB (~14% lightness)
      Colors.hexrgb("#CCCCCCFF"),  -- Light gray text (~80%)
      nil                          -- No accent (neutral grayscale)
    )
  end,

  -- LIGHT: Bright, paper-like theme (~88% lightness)
  -- Best for: Bright environments, printable mockups
  light = function()
    return Engine.generate_palette(
      Colors.hexrgb("#E0E0E0FF"),  -- Light gray (~88% lightness)
      Colors.hexrgb("#2A2A2AFF"),  -- Dark text (~16%)
      nil                          -- No accent (neutral grayscale)
    )
  end,

  -- ===== Legacy presets (kept for backward compatibility) =====

  -- Midnight (very dark)
  midnight = function()
    return Engine.generate_palette(
      Colors.hexrgb("#0A0A0AFF"),  -- Almost black
      Colors.hexrgb("#AAAAAAFF"),  -- Medium gray text
      nil
    )
  end,

  -- Pro Tools inspired
  pro_tools = function()
    return Engine.generate_palette(
      Colors.hexrgb("#3D3D3DFF"),  -- Medium dark gray (PT background)
      Colors.hexrgb("#D4D4D4FF"),  -- Off-white text
      nil
    )
  end,

  -- Ableton inspired
  ableton = function()
    return Engine.generate_palette(
      Colors.hexrgb("#1A1A1AFF"),  -- Very dark gray
      Colors.hexrgb("#CCCCCCFF"),  -- Light text
      nil
    )
  end,

  -- FL Studio inspired
  fl_studio = function()
    return Engine.generate_palette(
      Colors.hexrgb("#2B2B2BFF"),  -- Dark gray
      Colors.hexrgb("#E0E0E0FF"),  -- Light text
      nil
    )
  end,
}

-- =============================================================================
-- PUBLIC API
-- =============================================================================

--- Get list of available theme names
--- @return table Array of theme names (sorted)
function M.get_names()
  local names = {}
  for name in pairs(M.themes) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

--- Get primary preset names (for UI selectors)
--- @return table Array of primary theme names
function M.get_primary()
  return { "dark", "light" }
end

--- Check if a theme name exists
--- @param name string Theme name to check
--- @return boolean True if theme exists
function M.exists(name)
  return M.themes[name] ~= nil
end

--- Apply a preset theme by name
--- @param name string Theme name from M.themes
--- @return boolean Success (true if theme exists and was applied)
function M.apply(name)
  local generator = M.themes[name]
  if not generator then
    return false
  end

  local palette = generator()
  Engine.apply_palette(palette)
  return true
end

--- Get palette for a theme without applying it
--- @param name string Theme name
--- @return table|nil Palette or nil if theme doesn't exist
function M.get_palette(name)
  local generator = M.themes[name]
  if not generator then
    return nil
  end
  return generator()
end

return M
