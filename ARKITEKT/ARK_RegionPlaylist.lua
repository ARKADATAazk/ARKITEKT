-- @noindex

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local function init_arkitekt()
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local dir = src:match("(.*"..sep..")")

  -- Scan upward for bootstrap
  local path = dir
  while path and #path > 3 do
    local bootstrap = path .. "rearkitekt" .. sep .. "app" .. sep .. "bootstrap.lua"
    local f = io.open(bootstrap, "r")
    if f then
      f:close()
      return dofile(bootstrap)(path)
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end

  reaper.MB("ARKITEKT bootstrap not found!", "FATAL ERROR", 0)
  return nil
end

local ARK = init_arkitekt()
if not ARK then return end

-- Local references
local SRC = debug.getinfo(1,"S").source:sub(2)
local HERE = ARK.dirname(SRC) or "."

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
  local ok, inst = pcall(Settings.new, ARK.join(HERE, "cache"), "region_playlist.json")
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