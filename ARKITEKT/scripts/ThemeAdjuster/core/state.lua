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

  -- Configurations system - multiple named assembler presets
  configurations = {
    active = "Default",
    items = {
      ["Default"] = {
        active_packages = {},
        package_order = {},
        package_exclusions = {},
        package_pins = {},
      }
    }
  },

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

    -- Load configurations
    local saved_configs = settings:get('configurations', nil)
    if saved_configs and saved_configs.items and saved_configs.active then
      state.configurations = saved_configs
      -- Ensure Default always exists
      if not state.configurations.items["Default"] then
        state.configurations.items["Default"] = {
          active_packages = {},
          package_order = {},
          package_exclusions = {},
          package_pins = {},
        }
      end
      -- Ensure active config exists
      if not state.configurations.items[state.configurations.active] then
        state.configurations.active = "Default"
      end
    end
  end
end

-- Helper to get current active configuration
local function get_active_config()
  local name = state.configurations.active
  local config = state.configurations.items[name]
  if not config then
    -- Create if missing
    config = {
      active_packages = {},
      package_order = {},
      package_exclusions = {},
      package_pins = {},
    }
    state.configurations.items[name] = config
  end
  return config
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
function M.get_theme_status() return state.theme_status end
function M.get_theme_name() return state.theme_name end
function M.get_cache_status() return state.cache_status end

-- Configuration-aware getters
function M.get_active_packages() return get_active_config().active_packages end
function M.get_package_order() return get_active_config().package_order end
function M.get_package_exclusions() return get_active_config().package_exclusions end
function M.get_package_pins() return get_active_config().package_pins end

-- Configuration management getters
function M.get_configurations() return state.configurations end
function M.get_active_configuration_name() return state.configurations.active end

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

-- Helper to save configurations
local function save_configurations()
  if state.settings then
    state.settings:set('configurations', state.configurations)
  end
end

function M.set_active_packages(packages)
  get_active_config().active_packages = packages
  save_configurations()
  M.update_resolution()
end

function M.set_package_order(order)
  get_active_config().package_order = order
  save_configurations()
  M.update_resolution()
end

function M.set_packages(packages)
  state.packages = packages

  -- Initialize order for new packages in active config
  local config = get_active_config()
  if #config.package_order == 0 then
    for _, pkg in ipairs(packages) do
      config.package_order[#config.package_order + 1] = pkg.id
    end
    save_configurations()
  end

  -- Try to load saved state for this theme (if not in demo mode)
  if not state.demo_mode then
    M.load_assembler_state()
  end

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
  local config = get_active_config()
  config.active_packages[package_id] = not config.active_packages[package_id]
  save_configurations()
  M.update_resolution()
end

function M.set_package_exclusions(exclusions)
  get_active_config().package_exclusions = exclusions
  save_configurations()
  M.update_resolution()
end

function M.set_package_pins(pins)
  get_active_config().package_pins = pins
  save_configurations()
  M.update_resolution()
end

-- ============================================================================
-- CONFIGURATION MANAGEMENT
-- ============================================================================

function M.switch_configuration(name)
  if not state.configurations.items[name] then return false end
  state.configurations.active = name
  save_configurations()
  M.update_resolution()
  return true
end

function M.add_configuration(name, clone_from_current)
  if state.configurations.items[name] then return false end  -- Already exists

  if clone_from_current then
    -- Deep copy current config
    local current = get_active_config()
    local new_config = {
      active_packages = {},
      package_order = {},
      package_exclusions = {},
      package_pins = {},
    }
    for k, v in pairs(current.active_packages) do new_config.active_packages[k] = v end
    for i, v in ipairs(current.package_order) do new_config.package_order[i] = v end
    for pkg_id, keys in pairs(current.package_exclusions) do
      new_config.package_exclusions[pkg_id] = {}
      for k, v in pairs(keys) do new_config.package_exclusions[pkg_id][k] = v end
    end
    for k, v in pairs(current.package_pins) do new_config.package_pins[k] = v end
    state.configurations.items[name] = new_config
  else
    state.configurations.items[name] = {
      active_packages = {},
      package_order = {},
      package_exclusions = {},
      package_pins = {},
    }
  end

  save_configurations()
  return true
end

function M.delete_configuration(name)
  if name == "Default" then return false end  -- Can't delete default
  if not state.configurations.items[name] then return false end

  state.configurations.items[name] = nil

  -- Switch to Default if we deleted the active one
  if state.configurations.active == name then
    state.configurations.active = "Default"
    M.update_resolution()
  end

  save_configurations()
  return true
end

function M.rename_configuration(old_name, new_name)
  if old_name == "Default" then return false end  -- Can't rename default
  if not state.configurations.items[old_name] then return false end
  if state.configurations.items[new_name] then return false end  -- Name taken

  state.configurations.items[new_name] = state.configurations.items[old_name]
  state.configurations.items[old_name] = nil

  if state.configurations.active == old_name then
    state.configurations.active = new_name
  end

  save_configurations()
  return true
end

-- ============================================================================
-- PACKAGE RESOLUTION
-- ============================================================================

function M.update_resolution()
  -- Resolve packages and update ImageMap
  local PackageManager = require('ThemeAdjuster.packages.manager')
  local ImageMap = require('ThemeAdjuster.packages.image_map')

  local config = get_active_config()
  local resolved = PackageManager.resolve_packages(
    state.packages,
    config.active_packages,
    config.package_order,
    config.package_exclusions,
    config.package_pins
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

  local config = get_active_config()

  -- Build active_order from active packages in order
  local active_order = {}
  for _, pkg_id in ipairs(config.package_order) do
    if config.active_packages[pkg_id] then
      active_order[#active_order + 1] = pkg_id
    end
  end

  -- Convert exclusions from {pkg_id = {key = true}} to {pkg_id = [keys]}
  local exclusions = {}
  for pkg_id, keys in pairs(config.package_exclusions) do
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
    pins = config.package_pins,
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

  local config = get_active_config()

  -- Restore active packages from active_order
  config.active_packages = {}
  config.package_order = {}
  for _, pkg_id in ipairs(saved_state.active_order) do
    config.active_packages[pkg_id] = true
    config.package_order[#config.package_order + 1] = pkg_id
  end

  -- Add inactive packages to order (maintain full list)
  for _, pkg in ipairs(state.packages) do
    local found = false
    for _, id in ipairs(config.package_order) do
      if id == pkg.id then
        found = true
        break
      end
    end
    if not found then
      config.package_order[#config.package_order + 1] = pkg.id
    end
  end

  -- Restore pins
  config.package_pins = saved_state.pins or {}

  -- Convert exclusions from {pkg_id = [keys]} to {pkg_id = {key = true}}
  config.package_exclusions = {}
  for pkg_id, key_list in pairs(saved_state.exclusions or {}) do
    config.package_exclusions[pkg_id] = {}
    for _, key in ipairs(key_list) do
      config.package_exclusions[pkg_id][key] = true
    end
  end

  save_configurations()
  M.update_resolution()
  return true
end

return M
