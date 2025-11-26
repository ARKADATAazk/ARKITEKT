-- @noindex
-- arkitekt/defs/colors/static.lua
-- Static color palettes (API-bound, never change with theme)
--
-- Contains:
--   PALETTE - 28 Wwise-compatible user-assignable colors
--
-- These colors are fixed for external API compatibility.
-- For theme-reactive colors, see theme.lua

local M = {}

-- =============================================================================
-- WWISE COLOR PALETTE (28 colors)
-- =============================================================================
-- User-assignable colors for tags, items, regions, etc.
-- Organized as 4 rows of 7, with id for Wwise API compatibility.
-- These must remain static to match exported audio metadata.

M.PALETTE = {
  -- Row 1: Light Gray + dark blues/greens
  {id = 26, name = "Light Gray",    hex = "#878787"},
  {id = 0,  name = "Indigo",        hex = "#373EC8"},
  {id = 1,  name = "Royal Blue",    hex = "#1A55CB"},
  {id = 2,  name = "Dark Teal",     hex = "#086868"},
  {id = 3,  name = "Forest Green",  hex = "#186D18"},
  {id = 4,  name = "Olive Green",   hex = "#56730D"},
  {id = 5,  name = "Olive",         hex = "#787211"},
  -- Row 2: Dark Gray + light colors
  {id = 27, name = "Dark Gray",     hex = "#646464"},
  {id = 13, name = "Light Indigo",  hex = "#6B6FC2"},
  {id = 14, name = "Periwinkle",    hex = "#6383C5"},
  {id = 15, name = "Teal",          hex = "#438989"},
  {id = 16, name = "Green",         hex = "#539353"},
  {id = 17, name = "Light Olive",   hex = "#80983E"},
  {id = 18, name = "Gold",          hex = "#A09827"},
  -- Row 3: Warm dark colors
  {id = 6,  name = "Bronze",        hex = "#795815"},
  {id = 7,  name = "Brown",         hex = "#78440D"},
  {id = 8,  name = "Mahogany",      hex = "#72392C"},
  {id = 9,  name = "Maroon",        hex = "#892424"},
  {id = 10, name = "Purple",        hex = "#7D267D"},
  {id = 11, name = "Lavender",      hex = "#732B97"},
  {id = 12, name = "Violet",        hex = "#5937AE"},
  -- Row 4: Warm light colors
  {id = 19, name = "Amber",         hex = "#AB873F"},
  {id = 20, name = "Light Brown",   hex = "#AE7A42"},
  {id = 21, name = "Terra Cotta",   hex = "#AE6656"},
  {id = 22, name = "Rose",          hex = "#B95B5B"},
  {id = 23, name = "Pink",          hex = "#AA50AA"},
  {id = 24, name = "Light Lavender", hex = "#9B56BD"},
  {id = 25, name = "Light Violet",  hex = "#8760E2"},
}

-- =============================================================================
-- HELPERS
-- =============================================================================

--- Get palette color by Wwise ID
--- @param wwise_id number Wwise color index
--- @return string|nil Hex color string
function M.get_color_by_id(wwise_id)
  for _, color in ipairs(M.PALETTE) do
    if color.id == wwise_id then
      return color.hex
    end
  end
  return nil
end

--- Get palette as flat array of hex values
--- @return string[] Array of hex color strings
function M.get_palette_colors()
  local colors = {}
  for i, color in ipairs(M.PALETTE) do
    colors[i] = color.hex
  end
  return colors
end

--- Get palette color by name
--- @param name string Color name
--- @return string|nil Hex color string
function M.get_color_by_name(name)
  for _, color in ipairs(M.PALETTE) do
    if color.name == name then
      return color.hex
    end
  end
  return nil
end

return M
