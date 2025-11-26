-- @noindex
-- arkitekt/core/theme_manager/presets.lua
-- Theme preset application
--
-- Thin wrapper around Palette.presets for applying themes.

local Colors = require('arkitekt.core.colors')
local Engine = require('arkitekt.core.theme_manager.engine')
local Palette = require('arkitekt.defs.palette')

local M = {}

-- Re-export presets from palette (single source of truth)
M.presets = Palette.presets

--- Get list of available preset names
function M.get_names()
  local names = {}
  for name in pairs(M.presets) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

--- Get primary preset names (for UI selectors)
function M.get_primary()
  return { "dark", "light" }
end

--- Check if a preset exists
function M.exists(name)
  return M.presets[name] ~= nil
end

--- Apply a preset by name
function M.apply(name)
  local hex = M.presets[name]
  if not hex then return false end

  local bg = Colors.hexrgb(hex .. "FF")
  Engine.generate_and_apply(bg)
  return true
end

--- Get palette for a preset without applying
function M.get_palette(name)
  local hex = M.presets[name]
  if not hex then return nil end

  local bg = Colors.hexrgb(hex .. "FF")
  return Engine.generate_palette(bg)
end

return M
