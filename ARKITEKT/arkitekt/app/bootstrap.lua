-- @noindex
-- arkitekt/app/bootstrap.lua
-- ARKITEKT Framework Bootstrap
-- Finds itself, sets up package paths, validates dependencies, returns ARK context

local M = {}

-- Internal bootstrap function that sets up the ARKITEKT environment
-- @param root_path: Absolute path to ARKITEKT root (containing arkitekt/ and scripts/)
-- @return: Context table with utilities and common modules, or nil on error
local function setup(root_path)
  if not root_path then
    reaper.MB("Bootstrap called without root_path", "ARKITEKT Bootstrap Error", 0)
    return nil
  end

  local sep = package.config:sub(1,1)

  -- ============================================================================
  -- PACKAGE PATH SETUP
  -- ============================================================================

  -- Build module search paths
  package.path =
      root_path .. "?.lua;" ..
      root_path .. "?" .. sep .. "init.lua;" ..
      root_path .. "scripts" .. sep .. "?.lua;" ..
      root_path .. "scripts" .. sep .. "?" .. sep .. "init.lua;" ..
      package.path

  -- Add ReaImGui path
  package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

  -- ============================================================================
  -- REAIMGUI SHIM LOADING
  -- ============================================================================

  local shim_path = reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua'
  if reaper.file_exists(shim_path) then
    dofile(shim_path)('0.10')
  end

  -- ============================================================================
  -- IMGUI VALIDATION
  -- ============================================================================

  local has_imgui, imgui_result = pcall(require, 'imgui')
  if not has_imgui then
    reaper.MB(
      "Missing dependency: ReaImGui extension.\n\n" ..
      "Install via ReaPack:\n" ..
      "Extensions > ReaPack > Browse packages\n" ..
      "Search: ReaImGui",
      "ARKITEKT Bootstrap Error",
      0
    )
    return nil
  end

  -- Load ImGui with version
  local ImGui = require('imgui')('0.10')

  -- ============================================================================
  -- SWS EXTENSION VALIDATION
  -- ============================================================================

  -- Check for critical SWS functions used throughout ARKITEKT
  local has_sws = reaper.BR_GetMediaItemGUID and
                  reaper.BR_GetMouseCursorContext and
                  reaper.SNM_GetIntConfigVar

  if not has_sws then
    reaper.MB(
      "Missing dependency: SWS Extension.\n\n" ..
      "ARKITEKT requires SWS for:\n" ..
      "- Media item tracking (BR_GetMediaItemGUID)\n" ..
      "- Mouse cursor detection (BR_GetMouseCursorContext)\n" ..
      "- Configuration management (SNM_GetIntConfigVar)\n\n" ..
      "Install from: https://www.sws-extension.org/\n" ..
      "Or via ReaPack: Extensions > ReaPack > Browse packages",
      "ARKITEKT Bootstrap Error",
      0
    )
    return nil
  end

  -- ============================================================================
  -- JS_REASCRIPTAPI VALIDATION
  -- ============================================================================

  -- Check for critical JS API functions used in Item Picker and Media Container
  local has_js_api = reaper.JS_Mouse_GetState and
                     reaper.JS_Window_Find and
                     reaper.JS_Window_GetRect

  if not has_js_api then
    reaper.MB(
      "Missing dependency: js_ReaScriptAPI extension.\n\n" ..
      "ARKITEKT requires JS API for:\n" ..
      "- Mouse state detection outside ImGui\n" ..
      "- Window positioning and multi-monitor support\n" ..
      "- Drag & drop functionality in Item Picker\n\n" ..
      "Install via ReaPack:\n" ..
      "Extensions > ReaPack > Browse packages\n" ..
      "Search: js_ReaScriptAPI",
      "ARKITEKT Bootstrap Error",
      0
    )
    return nil
  end

  -- ============================================================================
  -- UTILITY FUNCTIONS
  -- ============================================================================

  local function dirname(p)
    return p:match("^(.*)[/\\]")
  end

  local function join(a, b)
    local s = package.config:sub(1,1)
    return (a:sub(-1) == s) and (a .. b) or (a .. s .. b)
  end

  -- Get REAPER Data directory for ARKITEKT app storage
  -- Returns: REAPER_RESOURCE_PATH/Data/ARKITEKT/{app_name}/
  -- Creates the directory if it doesn't exist
  local function get_data_dir(app_name)
    if not app_name or app_name == "" then
      error("get_data_dir: app_name is required")
    end

    local resource_path = reaper.GetResourcePath()
    local data_dir = resource_path .. sep .. "Data" .. sep .. "ARKITEKT" .. sep .. app_name

    -- Create directory if it doesn't exist
    if reaper.RecursiveCreateDirectory then
      reaper.RecursiveCreateDirectory(data_dir, 0)
    end

    return data_dir
  end

  -- ============================================================================
  -- RETURN CONTEXT
  -- ============================================================================

  return {
    -- Path information
    root_path = root_path,
    sep = sep,

    -- Utility functions
    dirname = dirname,
    join = join,
    get_data_dir = get_data_dir,

    -- Pre-loaded ImGui
    ImGui = ImGui,

    -- Common module loader helper
    require_framework = function(module_name)
      return require(module_name)
    end,
  }
end

-- Find and load the ARKITEKT bootstrap
-- Scans upward from the calling script's location until it finds this file
-- @return ARK context table with framework utilities, or nil on failure
function M.init()
  local sep = package.config:sub(1,1)

  -- Get the path of the script that called this function (level 2)
  local src = debug.getinfo(2, "S").source:sub(2)
  local dir = src:match("(.*"..sep..")")

  -- Scan upward for bootstrap.lua
  local path = dir
  while path and #path > 3 do
    local bootstrap = path .. "arkitekt" .. sep .. "app" .. sep .. "bootstrap.lua"
    local f = io.open(bootstrap, "r")
    if f then
      f:close()
      -- Found it! Call setup with the root path
      return setup(path)
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end

  -- Bootstrap not found - show error and return nil
  reaper.MB("ARKITEKT bootstrap not found!", "FATAL ERROR", 0)
  return nil
end

return M
