-- @noindex
-- ThemeAdjuster v2 - Main Entry Point
-- Refactored to use ARKITEKT framework

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
-- LOAD MODULES
-- ============================================================================

local Shell = require("rearkitekt.app.shell")
local Config = require("ThemeAdjuster.core.config")
local State = require("ThemeAdjuster.core.state")
local ThemeParams = require("ThemeAdjuster.core.theme_params")
local GUI = require("ThemeAdjuster.ui.gui")
local StatusConfig = require("ThemeAdjuster.ui.status")
local Colors = require("rearkitekt.core.colors")

local hexrgb = Colors.hexrgb

local SettingsOK, Settings = pcall(require, "rearkitekt.core.settings")
local StyleOK, Style = pcall(require, "rearkitekt.gui.style.imgui_defaults")

-- ============================================================================
-- INITIALIZE SETTINGS
-- ============================================================================

local settings = nil
if SettingsOK and type(Settings.new) == "function" then
  local ok, inst = pcall(Settings.new, join(HERE, "cache"), "theme_adjuster.json")
  if ok then settings = inst end
end

State.initialize(settings)

-- Initialize theme parameter system (CRITICAL - must be before creating views)
ThemeParams.initialize()

local gui = GUI.create(State, Config, settings)

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================

Shell.run({
  title        = "Theme Adjuster",
  version      = "(1.0.0)",
  draw         = function(ctx, shell_state) gui:draw(ctx, shell_state.window, shell_state) end,
  settings     = settings,
  style        = StyleOK and Style or nil,
  initial_pos  = { x = 80, y = 80 },
  initial_size = { w = 1120, h = 820 },
  icon_color   = hexrgb("#00B88F"),
  icon_size    = 18,
  min_size     = { w = 700, h = 500 },
  get_status_func = StatusConfig.get_status_func and StatusConfig.get_status_func(State) or nil,
  content_padding = 12,
  tabs = {
    items = {
      { id = "GLOBAL", label = "Global" },
      { id = "ASSEMBLER", label = "Assembler" },
      { id = "TCP", label = "TCP" },
      { id = "MCP", label = "MCP" },
      { id = "COLORS", label = "Colors" },
      { id = "ENVELOPES", label = "Envelopes" },
      { id = "TRANSPORT", label = "Transport" },
      { id = "ADDITIONAL", label = "Additional" },
      { id = "DEBUG", label = "Debug" },
    },
    active = State.get_active_tab(),
    style = {
      active_indicator_height = 0,  -- Remove accent line below active tab
      spacing_after = 2,             -- Reduce spacing below tabs (was 4)
    },
    colors = {
      bg_active   = hexrgb("#242424"),
      bg_clicked  = hexrgb("#2A2A2A"),
      bg_hovered  = hexrgb("#202020"),
      bg_inactive = hexrgb("#1A1A1A"),
      border      = hexrgb("#000000"),
      text_active = hexrgb("#FFFFFF"),
      text_inact  = hexrgb("#BBBBBB"),
    },
  },
  fonts        = {},
})
