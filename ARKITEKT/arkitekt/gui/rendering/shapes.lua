-- @noindex
-- Arkitekt/gui/rendering/shapes.lua
-- Shape rendering utilities for UI elements

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Badge = require('arkitekt.gui.widgets.primitives.badge')

local M = {}

-- Draw a favorite star indicator using modular badge system
-- @param ctx ImGui context
-- @param dl DrawList
-- @param x X position (top-left of bounds)
-- @param y Y position (top-left of bounds)
-- @param size Size of the badge
-- @param alpha Overall alpha multiplier (0.0-1.0)
-- @param is_favorite Whether the item is favorited
-- @param icon_font Optional icon font to use (remixicon), falls back to Unicode star
-- @param icon_font_size Optional icon font size
-- @param base_color Optional base tile color for border derivation (defaults to neutral gray)
-- @param config Optional badge config overrides
function M.draw_favorite_star(ctx, dl, x, y, size, alpha, is_favorite, icon_font, icon_font_size, base_color, config)
  if not is_favorite then
    return  -- Only draw if favorited
  end

  -- Convert alpha from 0.0-1.0 to 0-255 for badge system
  local alpha_255 = (alpha * 255)//1

  -- Use remixicon star-fill if available, otherwise fallback to Unicode star
  local star_char
  if icon_font then
    -- Remixicon star-fill: U+F186
    star_char = utf8.char(0xF186)
  else
    -- Fallback to Unicode star character for cleaner rendering (no aliasing)
    star_char = "★"  -- U+2605 BLACK STAR
  end

  -- Default base color if not provided
  base_color = base_color or Colors.hexrgb("#555555")

  -- Render using modular badge system
  Badge.render_icon_badge(ctx, dl, x, y, size, star_char, base_color, alpha_255, icon_font, icon_font_size, config)
end

return M
