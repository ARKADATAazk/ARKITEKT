-- @noindex
-- ThemeAdjuster main_panel_test.lua
-- Test version using Panel tab_strip instead of Shell menutabs

-- ============================================================================
-- PACKAGE PATH SETUP
-- ============================================================================
local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path

if not root_path:match("[\\/]$") then root_path = root_path .. "/" end

local arkitekt_path = root_path .. "ARKITEKT/"
local scripts_path = root_path .. "ARKITEKT/scripts/"
package.path = arkitekt_path .. "?.lua;" .. arkitekt_path .. "?/init.lua;" ..
               scripts_path .. "?.lua;" .. scripts_path .. "?/init.lua;" ..
               package.path

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

local function dirname(p) return p:match("^(.*)[/\\]") end
local function join(a,b) local s=package.config:sub(1,1); return (a:sub(-1)==s) and (a..b) or (a..s..b) end
local function addpath(p) if p and p~="" and not package.path:find(p,1,true) then package.path = p .. ";" .. package.path end end

local SRC = debug.getinfo(1,"S").source:sub(2)
local HERE = dirname(SRC) or "."
local ARKITEKT_ROOT = dirname(HERE or ".") or "."
local SCRIPTS_ROOT = dirname(ARKITEKT_ROOT or ".") or "."

addpath(join(SCRIPTS_ROOT, "?.lua"))
addpath(join(SCRIPTS_ROOT, "?/init.lua"))
addpath(join(ARKITEKT_ROOT, "?.lua"))
addpath(join(ARKITEKT_ROOT, "?/init.lua"))

-- ============================================================================
-- LOAD MODULES
-- ============================================================================

local Shell = require("arkitekt.app.runtime.shell")
local Config = require("ThemeAdjuster.core.config")
local State = require("ThemeAdjuster.core.state")
local GUI = require("ThemeAdjuster.ui.gui_panel_test")  -- Use test version
local StatusConfig = require("ThemeAdjuster.ui.status")
local Colors = require("arkitekt.core.colors")

local hexrgb = Colors.hexrgb

local SettingsOK, Settings = pcall(require, "arkitekt.core.settings")
local StyleOK, Style = pcall(require, "arkitekt.gui.style.imgui_defaults")

-- ============================================================================
-- INITIALIZE SETTINGS
-- ============================================================================

local settings = nil
if SettingsOK and type(Settings.new) == "function" then
  local data_dir = ARK.get_data_dir("ThemeAdjuster")
  local ok, inst = pcall(Settings.new, data_dir, "main_panel_test.json")
  if ok then settings = inst end
end

State.initialize(settings)

local gui = GUI.create(State, Config, settings)

-- ============================================================================
-- RUN APPLICATION (NO MENUTABS)
-- ============================================================================

Shell.run({
  title        = "Enhanced 6.0 Theme Adjuster (Panel Tab Test)",
  version      = "v2.0.0-test",
  draw         = function(ctx, shell_state) gui:draw(ctx, shell_state.window, shell_state) end,
  settings     = settings,
  style        = StyleOK and Style or nil,
  initial_pos  = { x = 80, y = 80 },
  initial_size = { w = 980, h = 600 },
  icon_color   = hexrgb("#00B88F"),
  icon_size    = 18,
  min_size     = { w = 700, h = 500 },
  get_status_func = StatusConfig.get_status_func and StatusConfig.get_status_func(State) or nil,
  content_padding = 12,
  -- NO tabs config - using Panel tab_strip instead
  fonts        = {},
})
