-- @noindex
-- arkitekt/core/theme/manager/presets.lua
-- Theme preset application
--
-- Thin wrapper around Palette.presets for applying themes.

local Colors = require('arkitekt.core.colors')
local Engine = require('arkitekt.core.theme.manager.engine')
local Palette = require('arkitekt.config.colors')

local M = {}

-- Lazy load Theme to avoid circular dependency
local _Theme
local function get_theme()
  if not _Theme then
    _Theme = require('arkitekt.core.theme')
  end
  return _Theme
end

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
  return { 'dark', 'grey', 'light_grey', 'light' }
end

--- Check if a preset exists
function M.exists(name)
  return M.presets[name] ~= nil
end

--- Apply a preset by name
function M.apply(name)
  local hex = M.presets[name]
  if not hex then return false end

  local bg = Colors.Hexrgb(hex .. 'FF')
  get_theme().generate_and_apply(bg)
  return true
end

--- Get palette for a preset without applying
function M.get_palette(name)
  local hex = M.presets[name]
  if not hex then return nil end

  local bg = Colors.Hexrgb(hex .. 'FF')
  return Engine.generate_palette(bg)
end

return M
