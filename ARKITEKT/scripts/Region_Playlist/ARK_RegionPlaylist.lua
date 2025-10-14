-- @noindex


-- Auto-injected package path setup for relocated script

-- Package path setup for relocated script
local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path

-- Ensure root_path ends with a slash
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end

-- Add both module search paths
local arkitekt_path= root_path .. "ARKITEKT/"
local scripts_path = root_path .. "ARKITEKT/scripts/"
package.path = arkitekt_path.. "?.lua;" .. arkitekt_path.. "?/init.lua;" .. 
               scripts_path .. "?.lua;" .. scripts_path .. "?/init.lua;" .. 
               package.path

local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end
package.path = root_path .. "?.lua;" .. root_path .. "?/init.lua;" .. package.path

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

local function dirname(p) return p:match("^(.*)[/\\]") end
local function join(a,b) local s=package.config:sub(1,1); return (a:sub(-1)==s) and (a..b) or (a..s..b) end
local function addpath(p) if p and p~="" and not package.path:find(p,1,true) then package.path = p .. ";" .. package.path end end

local SRC   = debug.getinfo(1,"S").source:sub(2)
local HERE  = dirname(SRC) or "."
local REARKITEKT_ROOT = dirname(HERE or ".") or "."
local SCRIPTS_ROOT = dirname(REARKITEKT_ROOT or ".") or "."

addpath(join(SCRIPTS_ROOT, "?.lua"))
addpath(join(SCRIPTS_ROOT, "?/init.lua"))
addpath(join(REARKITEKT_ROOT, "?.lua"))
addpath(join(REARKITEKT_ROOT, "?/init.lua"))

local Shell = require("rearkitekt.app.shell")
local Config = require("Region_Playlist.app.config")
local AppState = require("Region_Playlist.app.state")
local GUI = require("Region_Playlist.app.gui")
local StatusBarConfig = require("Region_Playlist.app.status")
local Colors = require("rearkitekt.core.colors")
local State = require("Region_Playlist.core.state")

local hexrgb = Colors.hexrgb

local SettingsOK, Settings = pcall(require, "rearkitekt.core.settings")
local StyleOK, Style = pcall(require, "rearkitekt.gui.style")

local settings = nil
if SettingsOK and type(Settings.new) == "function" then
  local ok, inst = pcall(Settings.new, join(HERE, "cache"), "region_playlist.json")
  if ok then settings = inst end
end

local function S()
  return State.for_project(0)
end

AppState.initialize(settings)

local active_playlist = AppState.get_active_playlist and AppState.get_active_playlist()
local initial_active_id = active_playlist and active_playlist.id
if initial_active_id then S():set('playlists.active_id', initial_active_id) end

if not S():get('ui.selection') then
  S():set('ui.selection', {
    active = { keys = {}, last_clicked = nil },
    pool = { keys = {}, last_clicked = nil },
  })
end

local status_bar = StatusBarConfig.create(AppState, StyleOK and Style)
local gui = GUI.create(AppState, Config, settings)

local shell_options = {
  title        = "Region Playlist",
  version      = "v0.1.0",
  version_color = hexrgb("#4fffdfad"),
  settings     = settings,
  style        = StyleOK and Style or nil,
  initial_pos  = { x = 120, y = 120 },
  initial_size = { w = 1000, h = 700 },
  icon_color   = 0x41E0A3FF,
  icon_size    = 18,
  min_size     = { w = 700, h = 500 },
  status_bar   = status_bar,
}

local USE_VIEWS = true

if USE_VIEWS then
  local Main = require('Region_Playlist.views.main')
  local main_view = Main.new({
    gui = gui,
    status_bar = status_bar,
  })

  shell_options.status_bar = nil
  shell_options.draw = function(ctx, shell_state)
    return main_view:draw(ctx, shell_state and shell_state.window or nil)
  end
else
  shell_options.status_bar = status_bar
  shell_options.draw = function(ctx, shell_state)
    return gui:draw(ctx, shell_state and shell_state.window or nil)
  end
end

Shell.run(shell_options)
