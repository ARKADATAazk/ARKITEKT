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
local EventBus = require("rearkitekt.core.events")
local State = require("Region_Playlist.core.state")
local MainView = require("Region_Playlist.views.main")
local PlaybackCoordinator = require("Region_Playlist.playback.coordinator")
local Sequencer = require("Region_Playlist.playlists.sequencer")

local hexrgb = Colors.hexrgb

local SettingsOK, Settings = pcall(require, "rearkitekt.core.settings")
local StyleOK, Style = pcall(require, "rearkitekt.gui.style")

local function build_settings()
  if not SettingsOK or type(Settings.new) ~= "function" then
    return nil
  end
  local ok, inst = pcall(Settings.new, join(HERE, "cache"), "region_playlist.json")
  if ok then
    return inst
  end
  return nil
end

local function ensure_project_state(project_id)
  if type(State.initialize) == "function" then
    return State.initialize(project_id)
  end
  return State.for_project(project_id)
end

local function ensure_selection_defaults(state)
  if not state then
    return
  end
  local selection = state:get('ui.selection')
  local has_active = type(selection) == 'table' and type(selection.active) == 'table'
  local has_pool = type(selection) == 'table' and type(selection.pool) == 'table'
  if not (has_active and has_pool) then
    state:set('ui.selection', {
      active = { keys = {}, last_clicked = nil },
      pool = { keys = {}, last_clicked = nil },
    })
  end
end

local function create_shell_options(settings, status_bar)
  return {
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
end

local settings = build_settings()
AppState.initialize(settings)

local project_state = ensure_project_state(0)
local active_playlist = AppState.get_active_playlist and AppState.get_active_playlist()
if active_playlist and active_playlist.id then
  project_state:set('playlists.active_id', active_playlist.id)
end
ensure_selection_defaults(project_state)

local status_bar = StatusBarConfig.create(AppState, StyleOK and Style)
local gui = GUI.create(AppState, Config, settings)

local shell_options = create_shell_options(settings, status_bar)

local events = EventBus.new()
local coordinator = AppState.state and AppState.state.bridge or nil
if coordinator then
  local existing_events = coordinator.get_events and coordinator:get_events()
  if existing_events then
    events = existing_events
  end
else
  local sequencer = Sequencer.new({
    proj = 0,
    get_playlist_by_id = AppState.get_playlist_by_id,
  })
  coordinator = PlaybackCoordinator.new({
    proj = 0,
    sequencer = sequencer,
    events = events,
    get_playlist_by_id = AppState.get_playlist_by_id,
    get_active_playlist = AppState.get_active_playlist,
    on_repeat_cycle = function() end,
  })
end

_G.ARK_COMPAT_MODE = _G.ARK_COMPAT_MODE or 'warn'
local Compat = require('Region_Playlist.core.compat')
if Compat and Compat.install then
  Compat.install()
end

local main_view = MainView.new(project_state, coordinator, events, {
  gui = gui,
  status_bar = status_bar,
  app_state = AppState,
  settings = settings,
})

shell_options.status_bar = nil
shell_options.draw = function(ctx, shell_state)
  return main_view:draw(ctx, shell_state and shell_state.window or nil)
end

Shell.run(shell_options)
