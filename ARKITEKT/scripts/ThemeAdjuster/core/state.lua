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
end

function M.set_package_order(order)
  state.package_order = order
  if state.settings then state.settings:set('package_order', order) end
end

function M.set_packages(packages)
  state.packages = packages
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
end

return M
