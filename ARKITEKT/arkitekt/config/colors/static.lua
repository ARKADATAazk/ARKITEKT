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
  {id = 26, name = 'Light Gray',    hex = 0x878787FF,},
  {id = 0,  name = 'Indigo',        hex = 0x373EC8FF,},
  {id = 1,  name = 'Royal Blue',    hex = 0x1A55CBFF,},
  {id = 2,  name = 'Dark Teal',     hex = 0x086868FF,},
  {id = 3,  name = 'Forest Green',  hex = 0x186D18FF,},
  {id = 4,  name = 'Olive Green',   hex = 0x56730DFF,},
  {id = 5,  name = 'Olive',         hex = 0x787211FF,},
  -- Row 2: Dark Gray + light colors
  {id = 27, name = 'Dark Gray',     hex = 0x646464FF,},
  {id = 13, name = 'Light Indigo',  hex = 0x6B6FC2FF,},
  {id = 14, name = 'Periwinkle',    hex = 0x6383C5FF,},
  {id = 15, name = 'Teal',          hex = 0x438989FF,},
  {id = 16, name = 'Green',         hex = 0x539353FF,},
  {id = 17, name = 'Light Olive',   hex = 0x80983EFF,},
  {id = 18, name = 'Gold',          hex = 0xA09827FF,},
  -- Row 3: Warm dark colors
  {id = 6,  name = 'Bronze',        hex = 0x795815FF,},
  {id = 7,  name = 'Brown',         hex = 0x78440DFF,},
  {id = 8,  name = 'Mahogany',      hex = 0x72392CFF,},
  {id = 9,  name = 'Maroon',        hex = 0x892424FF,},
  {id = 10, name = 'Purple',        hex = 0x7D267DFF,},
  {id = 11, name = 'Lavender',      hex = 0x732B97FF,},
  {id = 12, name = 'Violet',        hex = 0x5937AEFF,},
  -- Row 4: Warm light colors
  {id = 19, name = 'Amber',         hex = 0xAB873FFF,},
  {id = 20, name = 'Light Brown',   hex = 0xAE7A42FF,},
  {id = 21, name = 'Terra Cotta',   hex = 0xAE6656FF,},
  {id = 22, name = 'Rose',          hex = 0xB95B5BFF,},
  {id = 23, name = 'Pink',          hex = 0xAA50AAFF,},
  {id = 24, name = 'Light Lavender', hex = 0x9B56BDFF,},
  {id = 25, name = 'Light Violet',  hex = 0x8760E2FF,},
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
