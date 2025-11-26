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
  dark = function()
    return Engine.generate_palette(Colors.hexrgb("#242424FF"))
  end,

  -- LIGHT: Bright, paper-like theme (~88% lightness)
  light = function()
    return Engine.generate_palette(Colors.hexrgb("#E0E0E0FF"))
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
