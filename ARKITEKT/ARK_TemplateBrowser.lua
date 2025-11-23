-- @noindex
-- TemplateBrowser main launcher with overlay support
-- Three-panel UI: Folders | Templates | Tags

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local ARK = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt/app/init/init.lua").bootstrap()

-- Load required modules
local ImGui = ARK.ImGui
local Shell = require('arkitekt.app.runtime.shell')
local Fonts = require('arkitekt.app.assets.fonts')
local OverlayManager = require('arkitekt.gui.widgets.overlays.overlay.manager')
local OverlayDefaults = require('arkitekt.gui.widgets.overlays.overlay.defaults')
local ImGuiStyle = require('arkitekt.gui.style.imgui_defaults')
local Colors = require('arkitekt.core.colors')

-- Load TemplateBrowser modules
local Config = require('TemplateBrowser.core.config')
local State = require('TemplateBrowser.core.state')
local GUI = require('TemplateBrowser.ui.gui')
local Scanner = require('TemplateBrowser.domain.scanner')

local hexrgb = Colors.hexrgb

-- Configuration
local USE_OVERLAY = true  -- Set to false for normal window mode

-- Initialize state
State.initialize(Config)

-- Initialize scanner and load templates
Scanner.scan_templates(State)

-- Create GUI instance
local gui = GUI.new(Config, State, Scanner)

-- Run based on mode
if USE_OVERLAY then
  -- OVERLAY MODE - uses inline defer loop
  local ctx = ImGui.CreateContext("Template Browser")
  local fonts = Fonts.load(ImGui, ctx)

  -- Create overlay manager
  local overlay_mgr = OverlayManager.new()

  -- Push overlay onto stack using centralized defaults
  overlay_mgr:push(OverlayDefaults.create_overlay_config({
    id = "template_browser_main",
    close_on_scrim = false,
    close_on_background_right_click = false,

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

    on_close = function()
      State.cleanup()
    end,
  }))

  -- Use Shell.run_loop for defer loop
  Shell.run_loop({
    ctx = ctx,
    on_frame = function(ctx)
      overlay_mgr:render(ctx)
      return overlay_mgr:is_active()
    end,
    on_close = function()
      State.cleanup()
    end,
  })

else
  -- NORMAL WINDOW MODE
  Shell.run({
    title = "Template Browser",
    version = "1.0.0",
    toggle_button = true,
    initial_pos = { x = 100, y = 100 },
    initial_size = { w = 1400, h = 800 },
    min_size = { w = 1000, h = 600 },
    icon_color = hexrgb("#FF9F43"),
    icon_size = 18,
    fonts = {
      icons = 14,
    },
    draw = function(ctx, shell_state)
      gui:draw(ctx, shell_state)
    end,
    on_close = function()
      State.cleanup()
    end,
  })
end
