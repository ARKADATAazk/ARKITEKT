local Colors = require('rearkitekt.core.colors')

local M = {}

local function hsl_to_rgba(h, s, l)
  local r, g, b = Colors.hsl_to_rgb(h, s, l)
  return Colors.components_to_rgba(r, g, b, 0xFF)
end

function M.generate_chip_color(random_fn)
  local rng = random_fn or math.random

  local hue = rng()
  local saturation = 0.65 + rng() * 0.25
  local lightness = 0.50 + rng() * 0.15

  return hsl_to_rgba(hue % 1, math.min(math.max(saturation, 0), 1), math.min(math.max(lightness, 0), 1))
end

return M
