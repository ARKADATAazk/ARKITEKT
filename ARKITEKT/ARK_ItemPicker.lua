-- @noindex
-- ItemPicker main launcher with clean overlay support

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local ARK
do
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local path = src:match("(.*"..sep..")")
  while path and #path > 3 do
    local init = path .. "arkitekt" .. sep .. "app" .. sep .. "init" .. sep .. "init.lua"
    local f = io.open(init, "r")
    if f then
      f:close()
      local Init = dofile(init)
      ARK = Init.bootstrap()
      break
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end
  if not ARK then
    reaper.MB("ARKITEKT framework not found!", "FATAL ERROR", 0)
    return
  end
end

-- ============================================================================
-- PROFILER INITIALIZATION (Controlled by ARKITEKT/config.lua)
-- ============================================================================
local ProfilerInit = require('arkitekt.debug.profiler_init')
local profiler_enabled = ProfilerInit.init()

if profiler_enabled then
  reaper.ShowConsoleMsg("[ItemPicker] ✓ Profiler enabled and initialized\n")
else
  reaper.ShowConsoleMsg("[ItemPicker] ✗ Profiler disabled or not found\n")
  reaper.ShowConsoleMsg("[ItemPicker]   To enable: Set PROFILER_ENABLED=true in arkitekt/app/app_defaults.lua\n")
  reaper.ShowConsoleMsg("[ItemPicker]   Install profiler: ReaPack > Browse > Search 'cfillion Lua profiler'\n")
end

-- Load required modules
local ImGui = ARK.ImGui
local Shell = require('arkitekt.app.runtime.shell')
local Fonts = require('arkitekt.app.assets.fonts')
local OverlayManager = require('arkitekt.gui.widgets.overlays.overlay.manager')
local OverlayDefaults = require('arkitekt.gui.widgets.overlays.overlay.defaults')

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

-- Run based on mode
if USE_OVERLAY then
  -- OVERLAY MODE
  local ctx = ImGui.CreateContext("Item Picker" .. (profiler_enabled and " [Profiling]" or ""))
  local fonts = Fonts.load(ImGui, ctx, { title_size = 24, monospace_size = 14 })  -- App-specific overrides

  -- Create overlay manager
  local overlay_mgr = OverlayManager.new()

  -- Push overlay onto stack using centralized defaults
  overlay_mgr:push(OverlayDefaults.create_overlay_config({
    id = "item_picker_main",
    esc_to_close = false,  -- App-specific: GUI handles ESC for special behavior
    -- All other settings use framework defaults

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

    on_close = cleanup,
  }))

  -- Use Shell.run_loop for defer loop
  Shell.run_loop({
    ctx = ctx,
    on_frame = function(ctx)
      -- Show ImGui debug window when profiling
      if profiler_enabled then
        ImGui.ShowMetricsWindow(ctx, true)
      end

      -- Check if should close after drop
      if State.should_close_after_drop then
        return false
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

        -- Check again after draw in case flag was set during draw
        if State.should_close_after_drop then
          return false
        end
        return true
      else
        -- Normal mode: let overlay manager handle everything
        overlay_mgr:render(ctx)
        return overlay_mgr:is_active()
      end
    end,
    on_close = cleanup,
  })

else
  -- NORMAL WINDOW MODE (using Shell)
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
