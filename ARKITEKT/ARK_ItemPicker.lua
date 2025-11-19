-- @noindex
-- ItemPicker main launcher with clean overlay support

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

-- ============================================================================
-- PROFILER INITIALIZATION (Controlled by ARKITEKT/config.lua)
-- ============================================================================
local ProfilerInit = require('rearkitekt.debug.profiler_init')
local profiler_enabled = ProfilerInit.init()

if profiler_enabled then
  reaper.ShowConsoleMsg("[ItemPicker] ✓ Profiler enabled and initialized\n")
else
  reaper.ShowConsoleMsg("[ItemPicker] ✗ Profiler disabled or not found\n")
  reaper.ShowConsoleMsg("[ItemPicker]   To enable: Set PROFILER_ENABLED=true in rearkitekt/app/app_defaults.lua\n")
  reaper.ShowConsoleMsg("[ItemPicker]   Install profiler: ReaPack > Browse > Search 'cfillion Lua profiler'\n")
end

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

-- Load required modules
local ImGui = require 'imgui' '0.10'
local Runtime = require('rearkitekt.app.runtime')
local OverlayManager = require('rearkitekt.gui.widgets.overlays.overlay.manager')

-- Load new refactored modules
local Config = require('ItemPicker.core.config')
local State = require('ItemPicker.core.app_state')
local Controller = require('ItemPicker.core.controller')
local GUI = require('ItemPicker.ui.main_window')

-- Data and service modules
local visualization = require('ItemPicker.services.visualization')
local reaper_interface = require('ItemPicker.data.reaper_api')
local utils = require('ItemPicker.services.utils')
local drag_handler = require('ItemPicker.ui.components.drag_handler')

-- Configuration
local USE_OVERLAY = true  -- Set to false for normal window mode

local function SetButtonState(set)
  local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  reaper.SetToggleCommandState(sec, cmd, set or 0)
  reaper.RefreshToolbar2(sec, cmd)
end

-- Initialize state
State.initialize(Config)

-- Initialize domain modules
reaper_interface.init(utils)
visualization.init(utils, SCRIPT_DIRECTORY, Config)

-- Initialize controller
Controller.init(reaper_interface, utils)

-- Create GUI
local gui = GUI.new(Config, State, Controller, visualization, drag_handler)

-- ============================================================================
-- PROFILER INSTRUMENTATION (After modules loaded)
-- ============================================================================
if profiler_enabled then
  ProfilerInit.attach_locals()
  ProfilerInit.launch_window()
end

local function cleanup()
  SetButtonState()
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_STOPPREVIEW"), 0)
  State.cleanup()
end

SetButtonState(1)

-- Font loading
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

-- Run based on mode
if USE_OVERLAY then
  -- OVERLAY MODE
  local ctx = ImGui.CreateContext("Item Picker" .. (profiler_enabled and " [Profiling]" or ""))
  local fonts = load_fonts(ctx)

  -- Create overlay manager
  local overlay_mgr = OverlayManager.new()

  -- Push overlay onto stack
  local Colors = require('rearkitekt.core.colors')
  overlay_mgr:push({
    id = "item_picker_main",
    use_viewport = true,
    show_close_button = true,
    close_on_background_click = false,
    close_on_background_right_click = true,
    close_on_scrim = false,
    esc_to_close = false,  -- We'll handle ESC in the GUI
    close_button_size = 32,
    close_button_margin = 16,
    close_button_proximity = 150,
    content_padding = 20,

    render = function(ctx, alpha_val, bounds)
      -- Push font for content with size
      ImGui.PushFont(ctx, fonts.default, fonts.default_size)

      local overlay_state = {
        x = bounds.x,
        y = bounds.y,
        width = bounds.w,
        height = bounds.h,
        alpha = alpha_val,
      }

      -- In overlay mode, don't create child window - draw directly
      -- The overlay manager's window is the container
      if gui and gui.draw then
        gui:draw(ctx, {
          fonts = fonts,
          overlay_state = overlay_state,
          overlay = { alpha = { value = function() return alpha_val end } },  -- Provide alpha accessor for animations
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
    title = "Item Picker" .. (profiler_enabled and " [Profiling]" or ""),
    ctx = ctx,

    on_frame = function(ctx)
      -- Show ImGui debug window when profiling
      if profiler_enabled then
        ImGui.ShowMetricsWindow(ctx, true)
      end

      -- When dragging, skip overlay entirely and just render drag handlers
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

  runtime:start()

else
  -- NORMAL WINDOW MODE (using Shell)
  local Shell = require('rearkitekt.app.shell')

  Shell.run({
    title = "Item Picker" .. (profiler_enabled and " [Profiling]" or ""),
    version = "1.0.0",

    show_titlebar = true,
    show_status_bar = false,

    initial_size = { w = 1200, h = 800 },
    min_size = { w = 800, h = 600 },

    fonts = {
      default = 14,
      title = 24,
      monospace = 14,
    },

    draw = function(ctx, shell_state)
      -- Show ImGui debug window when profiling
      if profiler_enabled then
        ImGui.ShowMetricsWindow(ctx, true)
      end

      gui:draw(ctx, shell_state)
    end,

    on_close = function()
      cleanup()
    end,
  })
end
