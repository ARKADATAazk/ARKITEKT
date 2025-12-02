-- @noindex
-- WalterBuilder/infra/settings.lua
-- Persistent settings for WalterBuilder

local Settings = require('arkitekt.core.settings')

local M = {}

-- Singleton instance
local instance = nil

-- Default values
local DEFAULTS = {
  -- UI state
  active_tab = 'rtconfig',  -- Default to rtconfig tab
  splitter_pos = 0.7,       -- Canvas/panel split (70% canvas)

  -- Conversion options
  force_visible = false,    -- Force all elements to be visible (ignore conditionals)
  filter_non_visual = true, -- Filter out .color/.font/.margin elements

  -- Context defaults
  default_context = 'tcp',  -- Default context filter

  -- Canvas
  zoom = 1.0,
  scroll_x = 0,
  scroll_y = 0,
}

-- Get or create the settings instance
function M.get()
  if not instance then
    -- Get the script path to determine cache directory
    local info = debug.getinfo(1, 'S')
    local script_path = info.source:match('@?(.*)')
    local sep = package.config:sub(1, 1)

    -- Go up from infra/ to WalterBuilder/ then to cache/
    local walter_dir = script_path:match('(.*' .. sep .. ')') or ''
    walter_dir = walter_dir:match('(.*' .. sep .. ')') or ''  -- Up one more level

    local cache_dir = walter_dir .. 'cache'

    instance = Settings.new(cache_dir, 'walter_settings.json')
  end
  return instance
end

-- Get a setting with default fallback
function M.get_value(key, default)
  local settings = M.get()
  local value = settings:get(key)
  if value == nil then
    return default ~= nil and default or DEFAULTS[key]
  end
  return value
end

-- Set a setting
function M.set_value(key, value)
  local settings = M.get()
  settings:set(key, value)
end

-- Flush pending writes
function M.flush()
  if instance then
    instance:flush()
  end
end

-- Maybe flush (debounced)
function M.maybe_flush()
  if instance then
    instance:maybe_flush()
  end
end

-- Convenience accessors
function M.get_force_visible()
  return M.get_value('force_visible', DEFAULTS.force_visible)
end

function M.set_force_visible(value)
  M.set_value('force_visible', value)
end

function M.get_active_tab()
  return M.get_value('active_tab', DEFAULTS.active_tab)
end

function M.set_active_tab(value)
  M.set_value('active_tab', value)
end

function M.get_splitter_pos()
  return M.get_value('splitter_pos', DEFAULTS.splitter_pos)
end

function M.set_splitter_pos(value)
  M.set_value('splitter_pos', value)
end

function M.get_filter_non_visual()
  return M.get_value('filter_non_visual', DEFAULTS.filter_non_visual)
end

function M.set_filter_non_visual(value)
  M.set_value('filter_non_visual', value)
end

return M
