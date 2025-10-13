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
local State = require("Region_Playlist.app.state")
local GUI = require("Region_Playlist.app.gui")
local StatusBarConfig = require("Region_Playlist.app.status")

local SettingsOK, Settings = pcall(require, "rearkitekt.core.settings")
local StyleOK, Style = pcall(require, "rearkitekt.gui.style")

local settings = nil
if SettingsOK and type(Settings.new) == "function" then
  local ok, inst = pcall(Settings.new, join(HERE, "cache"), "region_playlist.json")
  if ok then settings = inst end
end

State.initialize(settings)

local status_bar = StatusBarConfig.create(State, StyleOK and Style)
local gui = GUI.create(State, Config, settings)

Shell.run({
  title        = "Region Playlist",
  version      = "v2.0.0-beta",
  version_color = 0xFF9800FF,
  draw         = function(ctx, shell_state) gui:draw(ctx, shell_state.window) end,
  settings     = settings,
  style        = StyleOK and Style or nil,
  initial_pos  = { x = 120, y = 120 },
  initial_size = { w = 1000, h = 700 },
  icon_color   = 0x41E0A3FF,
  icon_size    = 18,
  min_size     = { w = 700, h = 500 },
  status_bar   = status_bar,
})