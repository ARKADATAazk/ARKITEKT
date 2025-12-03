-- ARKITEKT Namespace
-- Provides ImGui-style access to all widgets via lazy loading
-- Auto-loads ImGui and bootstraps the framework
-- Usage: local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT[/\\])') .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')
--        local ctx = Ark.ImGui.CreateContext('My Script')
--        Ark.Button(ctx, 'Click')
--        Ark.Shell.run({ title = 'My App', draw = function(ctx) end })

-- ============================================================================
-- SINGLETON PATTERN
-- ============================================================================
-- CRITICAL: Return cached namespace if already loaded to prevent module corruption
-- when multiple scripts use require('arkitekt')
-- Entry points use dofile() to get fresh bootstrap, but sub-modules use require()
if package.loaded['arkitekt'] then
  return package.loaded['arkitekt']
end

-- CRITICAL: Clear all arkitekt.* modules from cache to prevent stale modules
-- when multiple scripts run in same process (e.g., DevKit launches ItemPicker)
for key in pairs(package.loaded) do
  if key:match('^arkitekt%.') then
    package.loaded[key] = nil
  end
end

-- ============================================================================
-- BOOTSTRAP
-- ============================================================================

local sep = package.config:sub(1,1)
local src = debug.getinfo(1,'S').source:sub(2)

-- Get the directory containing this init.lua (arkitekt/)
local arkitekt_dir = src:match('(.*)[/\\]init%.lua$')
if not arkitekt_dir then
  error('ARKITEKT init.lua: Cannot determine arkitekt directory from: ' .. tostring(src))
end

-- Get root path (parent of arkitekt/)
local root_path = arkitekt_dir:match('(.*)[/\\]arkitekt$') or arkitekt_dir:match('(.*)[/\\]')
if not root_path then
  error('ARKITEKT init.lua: Cannot determine root path from: ' .. tostring(arkitekt_dir))
end
root_path = root_path .. sep

-- ============================================================================
-- PACKAGE PATH SETUP
-- ============================================================================

package.path =
    root_path .. '?.lua;' ..
    root_path .. '?' .. sep .. 'init.lua;' ..
    root_path .. 'scripts' .. sep .. '?.lua;' ..
    root_path .. 'scripts' .. sep .. '?' .. sep .. 'init.lua;' ..
    package.path

-- Add ReaImGui builtin path (required for extension to be found)
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

-- ============================================================================
-- REAIMGUI SHIM LOADING
-- ============================================================================

local shim_path = reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua'
if reaper.file_exists(shim_path) then
  dofile(shim_path)('0.10')
end

-- ============================================================================
-- DEPENDENCY VALIDATION
-- ============================================================================

-- ImGui
local has_imgui, imgui_result = pcall(require, 'imgui')
if not has_imgui then
  reaper.MB(
    'Missing dependency: ReaImGui extension.\n\n' ..
    'Install via ReaPack:\n' ..
    'Extensions > ReaPack > Browse packages\n' ..
    'Search: ReaImGui',
    'ARKITEKT Bootstrap Error',
    0
  )
  return nil
end

-- SWS Extension
local has_sws = reaper.BR_GetMediaItemGUID and
                reaper.BR_GetMouseCursorContext and
                reaper.SNM_GetIntConfigVar

if not has_sws then
  reaper.MB(
    'Missing dependency: SWS Extension.\n\n' ..
    'ARKITEKT requires SWS for:\n' ..
    '- Media item tracking (BR_GetMediaItemGUID)\n' ..
    '- Mouse cursor detection (BR_GetMouseCursorContext)\n' ..
    '- Configuration management (SNM_GetIntConfigVar)\n\n' ..
    'Install from: https://www.sws-extension.org/\n' ..
    'Or via ReaPack: Extensions > ReaPack > Browse packages',
    'ARKITEKT Bootstrap Error',
    0
  )
  return nil
end

-- JS_ReaScriptAPI
local has_js_api = reaper.JS_Mouse_GetState and
                   reaper.JS_Window_Find and
                   reaper.JS_Window_GetRect

if not has_js_api then
  reaper.MB(
    'Missing dependency: js_ReaScriptAPI extension.\n\n' ..
    'ARKITEKT requires JS API for:\n' ..
    '- Mouse state detection outside ImGui\n' ..
    '- Window positioning and multi-monitor support\n' ..
    '- Drag & drop functionality in Item Picker\n\n' ..
    'Install via ReaPack:\n' ..
    'Extensions > ReaPack > Browse packages\n' ..
    'Search: js_ReaScriptAPI',
    'ARKITEKT Bootstrap Error',
    0
  )
  return nil
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function dirname(p)
  return p:match('^(.*)[/\\]')
end

local function join(a, b)
  return (a:sub(-1) == sep) and (a .. b) or (a .. sep .. b)
end

-- Get REAPER Data directory for ARKITEKT app storage
-- Returns: REAPER_RESOURCE_PATH/Data/ARKITEKT/{app_name}/
-- Creates the directory if it doesn't exist
local function get_data_dir(app_name)
  if not app_name or app_name == '' then
    error('get_data_dir: app_name is required')
  end

  local resource_path = reaper.GetResourcePath()
  local data_dir = resource_path .. sep .. 'Data' .. sep .. 'ARKITEKT' .. sep .. app_name

  -- Create directory if it doesn't exist
  if reaper.RecursiveCreateDirectory then
    reaper.RecursiveCreateDirectory(data_dir, 0)
  end

  return data_dir
end

-- ============================================================================
-- LAUNCH ARGUMENTS (from DevKit or other launchers)
-- ============================================================================

local function get_launch_args()
  local args = {
    debug = reaper.GetExtState('ARKITEKT_LAUNCH', 'debug') == '1',
    profiler = reaper.GetExtState('ARKITEKT_LAUNCH', 'profiler') == '1',
    script_path = reaper.GetExtState('ARKITEKT_LAUNCH', 'script_path'),
  }

  -- Clear the ExtState after reading (consume once)
  reaper.DeleteExtState('ARKITEKT_LAUNCH', 'debug', false)
  reaper.DeleteExtState('ARKITEKT_LAUNCH', 'profiler', false)
  reaper.DeleteExtState('ARKITEKT_LAUNCH', 'script_path', false)

  return args
end

-- ============================================================================
-- BOOTSTRAP CONTEXT (for backward compat and advanced use)
-- ============================================================================

local bootstrap_context = {
  root_path = root_path,
  sep = sep,
  dirname = dirname,
  join = join,
  get_data_dir = get_data_dir,
  ImGui = require('arkitekt.core.imgui'),
  launch_args = get_launch_args(),
  require_framework = function(module_name)
    return require(module_name)
  end,
}

-- ============================================================================
-- ARK NAMESPACE
-- ============================================================================

local Ark = {}

-- Expose ImGui directly (no need to require in every script)
Ark.ImGui = bootstrap_context.ImGui

-- Store full bootstrap context for advanced use cases
Ark._bootstrap = bootstrap_context

-- Expose launch arguments (from DevKit or other launchers)
Ark.launch_args = bootstrap_context.launch_args

-- ID Stack for ImGui-style PushID/PopID (loaded eagerly for performance)
local IdStack = require('arkitekt.core.id_stack')
Ark.PushID = IdStack.push
Ark.PopID = IdStack.pop

-- Module registry - maps names to module paths
-- Lazy loaded on first access to minimize startup overhead
local MODULES = {
  -- Runtime (app shell)
  Shell = 'arkitekt.runtime.shell',

  -- Primitives (alphabetically sorted)
  Badge = 'arkitekt.gui.widgets.primitives.badge',
  Button = 'arkitekt.gui.widgets.primitives.button',
  Checkbox = 'arkitekt.gui.widgets.primitives.checkbox',
  CloseButton = 'arkitekt.gui.widgets.primitives.close_button',
  Combo = 'arkitekt.gui.widgets.primitives.combo',
  CornerButton = 'arkitekt.gui.widgets.primitives.corner_button',
  HueSlider = 'arkitekt.gui.widgets.primitives.hue_slider',
  InputText = 'arkitekt.gui.widgets.primitives.inputtext',
  LoadingSpinner = 'arkitekt.gui.widgets.primitives.loading_spinner',
  MarkdownField = 'arkitekt.gui.widgets.primitives.markdown_field',
  ProgressBar = 'arkitekt.gui.widgets.primitives.progress_bar',
  RadioButton = 'arkitekt.gui.widgets.primitives.radio_button',
  Scrollbar = 'arkitekt.gui.widgets.primitives.scrollbar',
  Slider = 'arkitekt.gui.widgets.primitives.slider',
  Spinner = 'arkitekt.gui.widgets.primitives.spinner',
  Splitter = 'arkitekt.gui.widgets.primitives.splitter',

  -- Containers
  Grid = 'arkitekt.gui.widgets.containers.grid.core',
  Panel = 'arkitekt.gui.widgets.containers.panel',
  SlidingZone = 'arkitekt.gui.widgets.containers.sliding_zone',
  TileGroup = 'arkitekt.gui.widgets.containers.tile_group',

  -- Navigation
  Tree = 'arkitekt.gui.widgets.navigation.tree_view',

  -- Utilities (commonly used modules)
  Anim = 'arkitekt.config.animation',
  Colors = 'arkitekt.core.colors',
  Cursor = 'arkitekt.gui.interaction.cursor',
  Style = 'arkitekt.gui.style',
  Draw = 'arkitekt.gui.draw.primitives',
  Pattern = 'arkitekt.gui.draw.patterns',
  Easing = 'arkitekt.gui.animation.easing',
  Features = 'arkitekt.config.features',
  Lookup = 'arkitekt.core.lookup',
  Math = 'arkitekt.core.math',
  Notification = 'arkitekt.core.notification',
  UUID = 'arkitekt.core.uuid',

  -- Platform (REAPER + ImGui specific utilities)
  Images = 'arkitekt.core.images',
}

-- Lazy loading with metatable
-- Widgets are only loaded when first accessed (like ImGui namespace)
setmetatable(Ark, {
  __index = function(t, key)
    local module_path = MODULES[key]
    if module_path then
      -- Load and cache the module
      local success, module = pcall(require, module_path)
      if success then
        t[key] = module  -- Cache to avoid future requires
        return module
      else
        error(string.format("Ark.%s: Failed to load module '%s'\n%s",
                          key, module_path, module), 2)
      end
    end
    error(string.format('Ark.%s is not a valid widget. See MODULES table in arkitekt/init.lua', key), 2)
  end
})

-- Cache this namespace so require('arkitekt') from sub-modules returns the same instance
-- This prevents module corruption when multiple scripts run in the same process
package.loaded['arkitekt'] = Ark

return Ark
