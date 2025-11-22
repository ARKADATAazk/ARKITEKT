-- @noindex
-- ThemeAdjuster/core/state.lua
-- Application state management

local M = {}

-- ============================================================================
-- STATE STORAGE
-- ============================================================================

local state = {
  settings = nil,

  -- Package management
  packages = {},
  active_packages = {},
  package_order = {},
  package_exclusions = {},
  package_pins = {},

  -- UI state
  active_tab = "ASSEMBLER",
  demo_mode = true,
  search_text = "",
  filters = {
    TCP = true,
    MCP = true,
    Transport = true,
    Global = true,
  },
  tile_size = 220,

  -- Theme info
  theme_status = "direct",  -- or "zip-ready", "needs-link", etc.
  theme_name = "Default Theme",
  cache_status = "ready",
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function M.initialize(settings)
  state.settings = settings

  if settings then
    state.active_tab = settings:get('active_tab', "ASSEMBLER")
    state.demo_mode = settings:get('demo_mode', true)
    state.search_text = settings:get('search_text', "")
    state.filters = settings:get('filters', state.filters)
    state.tile_size = settings:get('tile_size', 220)
    state.active_packages = settings:get('active_packages', {})
    state.package_order = settings:get('package_order', {})
    state.package_exclusions = settings:get('package_exclusions', {})
    state.package_pins = settings:get('package_pins', {})
  end
end

-- ============================================================================
-- GETTERS
-- ============================================================================

function M.get_active_tab() return state.active_tab end
function M.get_demo_mode() return state.demo_mode end
function M.get_search_text() return state.search_text end
function M.get_filters() return state.filters end
function M.get_tile_size() return state.tile_size end
function M.get_packages() return state.packages end
function M.get_active_packages() return state.active_packages end
function M.get_package_order() return state.package_order end
function M.get_theme_status() return state.theme_status end
function M.get_theme_name() return state.theme_name end
function M.get_cache_status() return state.cache_status end
function M.get_package_exclusions() return state.package_exclusions end
function M.get_package_pins() return state.package_pins end

-- ============================================================================
-- SETTERS
-- ============================================================================

function M.set_active_tab(value)
  state.active_tab = value
  if state.settings then state.settings:set('active_tab', value) end
end

function M.set_demo_mode(value)
  state.demo_mode = value
  if state.settings then state.settings:set('demo_mode', value) end
end

function M.set_search_text(value)
  state.search_text = value
  if state.settings then state.settings:set('search_text', value) end
end

function M.set_filters(filters)
  state.filters = filters
  if state.settings then state.settings:set('filters', filters) end
end

function M.set_tile_size(value)
  state.tile_size = value
  if state.settings then state.settings:set('tile_size', value) end
end

function M.set_active_packages(packages)
  state.active_packages = packages
  if state.settings then state.settings:set('active_packages', packages) end
  M.update_resolution()
end

function M.set_package_order(order)
  state.package_order = order
  if state.settings then state.settings:set('package_order', order) end
  M.update_resolution()
end

function M.set_packages(packages)
  state.packages = packages
  M.update_resolution()
end

function M.set_theme_status(status)
  state.theme_status = status
end

function M.set_cache_status(status)
  state.cache_status = status
end

-- ============================================================================
-- PACKAGE HELPERS
-- ============================================================================

function M.toggle_package(package_id)
  state.active_packages[package_id] = not state.active_packages[package_id]
  if state.settings then state.settings:set('active_packages', state.active_packages) end

  -- Trigger resolution update
  M.update_resolution()
end

function M.set_package_exclusions(exclusions)
  state.package_exclusions = exclusions
  if state.settings then state.settings:set('package_exclusions', exclusions) end
  M.update_resolution()
end

function M.set_package_pins(pins)
  state.package_pins = pins
  if state.settings then state.settings:set('package_pins', pins) end
  M.update_resolution()
end

-- ============================================================================
-- PACKAGE RESOLUTION
-- ============================================================================

function M.update_resolution()
  -- Resolve packages and update ImageMap
  local PackageManager = require('ThemeAdjuster.packages.manager')
  local ImageMap = require('ThemeAdjuster.packages.image_map')

  local resolved = PackageManager.resolve_packages(
    state.packages,
    state.active_packages,
    state.package_order,
    state.package_exclusions,
    state.package_pins
  )

  ImageMap.apply(resolved)
end

-- ============================================================================
-- THEME-SPECIFIC STATE PERSISTENCE
-- ============================================================================

-- Save assembler state for current theme
function M.save_assembler_state()
  local PackageManager = require('ThemeAdjuster.packages.manager')
  local Theme = require('ThemeAdjuster.core.theme')

  local theme_root = Theme.get_theme_root_path()
  if not theme_root then return false end

  -- Build active_order from active packages in order
  local active_order = {}
  for _, pkg_id in ipairs(state.package_order) do
    if state.active_packages[pkg_id] then
      active_order[#active_order + 1] = pkg_id
    end
  end

  -- Convert exclusions from {pkg_id = {key = true}} to {pkg_id = [keys]}
  local exclusions = {}
  for pkg_id, keys in pairs(state.package_exclusions) do
    local key_list = {}
    for key, _ in pairs(keys) do
      key_list[#key_list + 1] = key
    end
    if #key_list > 0 then
      exclusions[pkg_id] = key_list
    end
  end

  return PackageManager.save_state(theme_root, {
    active_order = active_order,
    pins = state.package_pins,
    exclusions = exclusions,
  })
end

-- Load assembler state for current theme
function M.load_assembler_state()
  local PackageManager = require('ThemeAdjuster.packages.manager')
  local Theme = require('ThemeAdjuster.core.theme')

  local theme_root = Theme.get_theme_root_path()
  if not theme_root then return false end

  local saved_state = PackageManager.load_state(theme_root)
  if not saved_state then return false end

  -- Restore active packages from active_order
  state.active_packages = {}
  state.package_order = {}
  for _, pkg_id in ipairs(saved_state.active_order) do
    state.active_packages[pkg_id] = true
    state.package_order[#state.package_order + 1] = pkg_id
  end

  -- Add inactive packages to order (maintain full list)
  for _, pkg in ipairs(state.packages) do
    local found = false
    for _, id in ipairs(state.package_order) do
      if id == pkg.id then
        found = true
        break
      end
    end
    if not found then
      state.package_order[#state.package_order + 1] = pkg.id
    end
  end

  -- Restore pins
  state.package_pins = saved_state.pins or {}

  -- Convert exclusions from {pkg_id = [keys]} to {pkg_id = {key = true}}
  state.package_exclusions = {}
  for pkg_id, key_list in pairs(saved_state.exclusions or {}) do
    state.package_exclusions[pkg_id] = {}
    for _, key in ipairs(key_list) do
      state.package_exclusions[pkg_id][key] = true
    end
  end

  -- Save to settings too
  if state.settings then
    state.settings:set('active_packages', state.active_packages)
    state.settings:set('package_order', state.package_order)
    state.settings:set('package_exclusions', state.package_exclusions)
    state.settings:set('package_pins', state.package_pins)
  end

  M.update_resolution()
  return true
end

-- Auto-save on state changes (debounced in practice by UI interactions)
local function auto_save()
  -- Only save if not in demo mode
  if not state.demo_mode then
    M.save_assembler_state()
  end
end

-- Override setters to auto-save
local original_set_active_packages = M.set_active_packages
function M.set_active_packages(packages)
  original_set_active_packages(packages)
  auto_save()
end

local original_set_package_order = M.set_package_order
function M.set_package_order(order)
  original_set_package_order(order)
  auto_save()
end

local original_set_package_exclusions = M.set_package_exclusions
function M.set_package_exclusions(exclusions)
  original_set_package_exclusions(exclusions)
  auto_save()
end

local original_set_package_pins = M.set_package_pins
function M.set_package_pins(pins)
  original_set_package_pins(pins)
  auto_save()
end

local original_toggle_package = M.toggle_package
function M.toggle_package(package_id)
  original_toggle_package(package_id)
  auto_save()
end

return M
