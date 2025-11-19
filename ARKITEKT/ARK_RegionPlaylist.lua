-- @noindex

-- ============================================================================
-- UNIVERSAL PATH RESOLUTION - Find ARKITEKT root automatically
-- ============================================================================
local sep = package.config:sub(1,1)
local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("(.*"..sep..")")

-- Find ARKITEKT root by scanning upward until folder "rearkitekt" exists
local function find_root(path)
  while path and #path > 3 do
    local test = path .. "rearkitekt" .. sep
    local f = io.open(test .. "app" .. sep .. "shell.lua", "r")
    if f then f:close(); return path end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end
end

local root_path = find_root(script_dir)
if not root_path then
  reaper.MB("ARKITEKT root not found! Cannot locate rearkitekt/app/shell.lua", "FATAL ERROR", 0)
  return
end

-- Build module search paths
package.path =
    root_path .. "?.lua;" ..
    root_path .. "?" .. sep .. "init.lua;" ..
    root_path .. "scripts" .. sep .. "?.lua;" ..
    root_path .. "scripts" .. sep .. "?" .. sep .. "init.lua;" ..
    package.path

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

-- Utility functions
local function dirname(p) return p:match("^(.*)[/\\]") end
local function join(a,b) local s=package.config:sub(1,1); return (a:sub(-1)==s) and (a..b) or (a..s..b) end

local SRC = debug.getinfo(1,"S").source:sub(2)
local HERE = dirname(SRC) or "."

-- ============================================================================
-- PROFILER INITIALIZATION (Controlled by ARKITEKT/config.lua)
-- ============================================================================
local ProfilerInit = require('rearkitekt.debug.profiler_init')
local profiler_enabled = ProfilerInit.init()

-- ============================================================================
-- LOAD MODULES
-- ============================================================================

local Shell = require("rearkitekt.app.shell")
local Config = require("Region_Playlist.core.config")
local State = require("Region_Playlist.core.app_state")
local GUI = require("Region_Playlist.ui.gui")
local StatusConfig = require("Region_Playlist.ui.status")
local Colors = require("rearkitekt.core.colors")

local hexrgb = Colors.hexrgb

local SettingsOK, Settings = pcall(require, "rearkitekt.core.settings")
local StyleOK, Style = pcall(require, "rearkitekt.gui.style.imgui_defaults")

local settings = nil
if SettingsOK and type(Settings.new) == "function" then
  local ok, inst = pcall(Settings.new, join(HERE, "cache"), "region_playlist.json")
  if ok then settings = inst end
end

State.initialize(settings)

local gui = GUI.create(State, Config, settings)

-- ============================================================================
-- PROFILER INSTRUMENTATION (After modules loaded)
-- ============================================================================
if profiler_enabled then
  ProfilerInit.attach_locals()
  ProfilerInit.launch_window()
end

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================

Shell.run({
  title        = "Region Playlist" .. (profiler_enabled and " [Profiling]" or ""),
  version      = "v0.1.0",
  draw         = function(ctx, shell_state) gui:draw(ctx, shell_state.window, shell_state) end,
  settings     = settings,
  style        = StyleOK and Style or nil,
  initial_pos  = { x = 120, y = 120 },
  initial_size = { w = 1000, h = 700 },
  icon_color   = hexrgb("#41E0A3"),
  icon_size    = 18,
  min_size     = { w = 700, h = 500 },
  get_status_func = StatusConfig.get_status_func and StatusConfig.get_status_func(State) or nil,
  fonts        = {
    time_display = 20,  -- Transport time display font
    icons = 20,         -- Icon font (remixicon) for corner buttons
  },
})