-- @noindex
-- ItemPicker with simple ExtState toggle

-- Package path setup
local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path

if not root_path:match("[\\/]$") then root_path = root_path .. "/" end

local arkitekt_path = root_path .. "ARKITEKT/"
local scripts_path = root_path .. "ARKITEKT/scripts/"
package.path = arkitekt_path.. "?.lua;" .. arkitekt_path.. "?/init.lua;" ..
               scripts_path .. "?.lua;" .. scripts_path .. "?/init.lua;" ..
               package.path

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path

-- Check dependencies
local has_imgui, imgui_test = pcall(require, 'imgui')
if not has_imgui then
  reaper.MB("Missing dependency: ReaImGui extension.\nDownload it via Reapack ReaTeam extension repository.", "Error", 0)
  return false
end

local reaimgui_shim_file_path = reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua'
if reaper.file_exists(reaimgui_shim_file_path) then
  dofile(reaimgui_shim_file_path)('0.10')
end

-- ============================================================================
-- ExtState Toggle Detection
-- ============================================================================

local ext_section = "ARK_ItemPicker"
local ext_running = "running"

-- Check if already running
local already_running = reaper.GetExtState(ext_section, ext_running) == "1"

if already_running then
  -- Signal the running instance to close
  reaper.SetExtState(ext_section, "close_request", "1", false)
  return
end

-- Mark as running
reaper.SetExtState(ext_section, ext_running, "1", false)

-- ============================================================================
-- Load modules
-- ============================================================================

local ImGui = require 'imgui' '0.10'
local Runtime = require('rearkitekt.app.runtime')
local OverlayManager = require('rearkitekt.gui.widgets.overlays.overlay.manager')

local Config = require('ItemPicker.core.config')
local State = require('ItemPicker.core.app_state')
local Controller = require('ItemPicker.core.controller')
local GUI = require('ItemPicker.ui.main_window')

local visualization = require('ItemPicker.services.visualization')
local cache_mgr = require('ItemPicker.data.loaders.cache_manager')
local reaper_interface = require('ItemPicker.data.reaper_api')
local utils = require('ItemPicker.services.utils')
local drag_handler = require('ItemPicker.ui.components.drag_handler')

-- ============================================================================
-- Setup
-- ============================================================================

local function SetButtonState(set)
  local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  reaper.SetToggleCommandState(sec, cmd, set or 0)
  reaper.RefreshToolbar2(sec, cmd)
end

-- Initialize state
State.initialize(Config)

-- Initialize domain modules
reaper_interface.init(utils)
visualization.init(utils, SCRIPT_DIRECTORY, cache_mgr)

-- Initialize controller
Controller.init(reaper_interface, utils)

-- Create GUI
local gui = GUI.new(Config, State, Controller, visualization, cache_mgr, drag_handler)

local function cleanup()
  SetButtonState()
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_STOPPREVIEW"), 0)
  State.cleanup()
  reaper.DeleteExtState(ext_section, ext_running, false)
  reaper.DeleteExtState(ext_section, "close_request", false)
end

SetButtonState(1)

-- ============================================================================
-- Font loading
-- ============================================================================

local function load_fonts(ctx)
  local SEP = package.config:sub(1,1)
  local src = debug.getinfo(1, 'S').source:sub(2)
  local this_dir = src:match('(.*'..SEP..')') or ('.'..SEP)
  local parent = this_dir:match('^(.*'..SEP..')[^'..SEP..']*'..SEP..'$') or this_dir
  local fontsdir = parent .. 'rearkitekt' .. SEP .. 'fonts' .. SEP

  local regular = fontsdir .. 'Inter_18pt-Regular.ttf'
  local bold = fontsdir .. 'Inter_18pt-SemiBold.ttf'
  local mono = fontsdir .. 'JetBrainsMono-Regular.ttf'

  local function exists(p)
    local f = io.open(p, 'rb')
    if f then f:close(); return true end
  end

  local fonts = {
    default = exists(regular) and ImGui.CreateFont(regular, 14) or ImGui.CreateFont('sans-serif', 14),
    default_size = 14,
    title = exists(bold) and ImGui.CreateFont(bold, 24) or ImGui.CreateFont('sans-serif', 24),
    title_size = 24,
    monospace = exists(mono) and ImGui.CreateFont(mono, 14) or ImGui.CreateFont('sans-serif', 14),
    monospace_size = 14,
  }

  for _, font in pairs(fonts) do
    if font and type(font) ~= "number" then
      ImGui.Attach(ctx, font)
    end
  end

  return fonts
end

-- ============================================================================
-- Main
-- ============================================================================

local ctx = ImGui.CreateContext("Item Picker")
local fonts = load_fonts(ctx)

-- Create overlay manager
local overlay_mgr = OverlayManager.new()

-- Push overlay onto stack
local Colors = require('rearkitekt.core.colors')
overlay_mgr:push({
  id = "item_picker_main",
  use_viewport = true,
  fade_duration = 0.3,
  fade_curve = 'ease_out_quad',
  scrim_color = Colors.hexrgb("#101010"),
  scrim_opacity = 0.92,
  show_close_button = true,
  close_on_background_click = false,
  close_on_background_right_click = true,
  close_on_scrim = false,
  esc_to_close = false,
  close_button_size = 32,
  close_button_margin = 16,
  close_button_proximity = 150,
  content_padding = 20,

  render = function(ctx, alpha_val, bounds)
    ImGui.PushFont(ctx, fonts.default, fonts.default_size)

    local overlay_state = {
      x = bounds.x,
      y = bounds.y,
      width = bounds.w,
      height = bounds.h,
      alpha = alpha_val,
    }

    if gui and gui.draw then
      gui:draw(ctx, {
        fonts = fonts,
        overlay_state = overlay_state,
        overlay = { alpha = { value = function() return alpha_val end } },
        is_overlay_mode = true,
      })
    end

    ImGui.PopFont(ctx)
  end,

  on_close = function()
    cleanup()
  end,
})

-- Create runtime
local runtime = Runtime.new({
  title = "Item Picker",
  ctx = ctx,

  on_frame = function(ctx)
    -- Check for close request
    local close_req = reaper.GetExtState(ext_section, "close_request")
    if close_req == "1" then
      reaper.SetExtState(ext_section, "close_request", "", false)
      cleanup()
      return false  -- Stop running
    end

    -- When dragging, skip overlay and just render drag handlers
    if State.dragging then
      ImGui.PushFont(ctx, fonts.default, fonts.default_size)
      gui:draw(ctx, {
        fonts = fonts,
        overlay_state = {},
        overlay = overlay_mgr,
        is_overlay_mode = true,
      })
      ImGui.PopFont(ctx)
      return true  -- Keep running
    else
      -- Normal mode: let overlay manager handle everything
      overlay_mgr:render(ctx)
      return overlay_mgr:is_active()
    end
  end,

  on_destroy = function()
    cleanup()
  end,
})

-- Register cleanup
reaper.atexit(cleanup)

-- Start
runtime:start()
