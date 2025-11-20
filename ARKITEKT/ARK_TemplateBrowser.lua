-- @noindex
-- TemplateBrowser main launcher with overlay support
-- Three-panel UI: Folders | Templates | Tags

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local ARK
do
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local path = src:match("(.*"..sep..")")
  while path and #path > 3 do
    local init = path .. "rearkitekt" .. sep .. "app" .. sep .. "init" .. sep .. "init.lua"
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

-- Load required modules
local ImGui = ARK.ImGui
local Runtime = require('rearkitekt.app.runtime.runtime')
local Fonts = require('rearkitekt.app.assets.fonts')
local OverlayManager = require('rearkitekt.gui.widgets.overlays.overlay.manager')
local OverlayDefaults = require('rearkitekt.gui.widgets.overlays.overlay.defaults')
local ImGuiStyle = require('rearkitekt.gui.style.imgui_defaults')

-- Load TemplateBrowser modules
local Config = require('TemplateBrowser.core.config')
local State = require('TemplateBrowser.core.state')
local GUI = require('TemplateBrowser.ui.gui')
local MainWindow = require('TemplateBrowser.ui.main_window')
local Scanner = require('TemplateBrowser.domain.scanner')

-- Configuration
local USE_OVERLAY = true  -- Set to false for normal window mode
local USE_REFACTORED_UI = true  -- Set to false to use original monolithic GUI

local function SetButtonState(set)
  local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  reaper.SetToggleCommandState(sec, cmd, set or 0)
  reaper.RefreshToolbar2(sec, cmd)
end

-- Initialize state
State.initialize(Config)

-- Initialize scanner and load templates
Scanner.scan_templates(State)

-- Create GUI (always needed for template_container)
local gui_instance = GUI.new(Config, State, Scanner)

-- Create main window (refactored or original)
local gui = USE_REFACTORED_UI
  and MainWindow.new(Config, State, Scanner, gui_instance)
  or gui_instance

local function cleanup()
  SetButtonState()
  State.cleanup()
end

SetButtonState(1)

-- Run based on mode
if USE_OVERLAY then
  -- OVERLAY MODE
  local ctx = ImGui.CreateContext("Template Browser")
  local fonts = Fonts.load(ImGui, ctx)  -- Uses framework defaults from constants.lua

  -- Create overlay manager
  local overlay_mgr = OverlayManager.new()

  -- Push overlay onto stack using centralized defaults
  overlay_mgr:push(OverlayDefaults.create_overlay_config({
    id = "template_browser_main",
    -- All other settings use framework defaults from constants.lua
    -- Only override if truly app-specific

    render = function(ctx, alpha_val, bounds)
      ImGuiStyle.PushMyStyle(ctx, { window_bg = false, modal_dim_bg = false })
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
      ImGuiStyle.PopMyStyle(ctx)
    end,

    on_close = cleanup,
  }))

  -- Create runtime
  local runtime = Runtime.new({
    title = "Template Browser",
    ctx = ctx,

    on_frame = function(ctx)
      overlay_mgr:render(ctx)
      return overlay_mgr:is_active()
    end,

    on_destroy = function()
      cleanup()
    end,
  })

  runtime:start()

else
  -- NORMAL WINDOW MODE
  local Shell = require('rearkitekt.app.runtime.shell')

  Shell.run({
    title = "Template Browser",
    version = "1.0.0",

    show_titlebar = true,
    show_status_bar = false,

    initial_size = { w = 1400, h = 800 },
    min_size = { w = 1000, h = 600 },

    fonts = {
      default = 14,
      title = 20,
      monospace = 12,
    },

    draw = function(ctx, shell_state)
      gui:draw(ctx, shell_state)
    end,

    on_close = function()
      cleanup()
    end,
  })
end
