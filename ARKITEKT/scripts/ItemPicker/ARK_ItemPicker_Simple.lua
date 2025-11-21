-- @noindex
-- ItemPicker with simple ExtState toggle

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

local ImGui = ARK.ImGui
local Runtime = require('rearkitekt.app.runtime.runtime')
local Fonts = require('rearkitekt.app.assets.fonts')
local OverlayManager = require('rearkitekt.gui.widgets.overlays.overlay.manager')
local OverlayDefaults = require('rearkitekt.gui.widgets.overlays.overlay.defaults')

local Config = require('ItemPicker.core.config')
local State = require('ItemPicker.core.app_state')
local Controller = require('ItemPicker.core.controller')
local GUI = require('ItemPicker.ui.main_window')

local visualization = require('ItemPicker.services.visualization')
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
visualization.init(utils, SCRIPT_DIRECTORY, Config)

-- Initialize controller
Controller.init(reaper_interface, utils)

-- Create GUI
local gui = GUI.new(Config, State, Controller, visualization, drag_handler)

local function cleanup()
  SetButtonState()
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_STOPPREVIEW"), 0)
  State.cleanup()

  -- Explicitly close any active overlays
  if overlay_mgr then
    while overlay_mgr:is_active() do
      overlay_mgr:pop()
    end
  end

  reaper.DeleteExtState(ext_section, ext_running, false)
  reaper.DeleteExtState(ext_section, "close_request", false)
end

SetButtonState(1)

-- ============================================================================
-- Main
-- ============================================================================

local ctx = ImGui.CreateContext("Item Picker")
local fonts = Fonts.load(ImGui, ctx, { title_size = 24, monospace_size = 14 })  -- App-specific overrides

-- Create overlay manager
local overlay_mgr = OverlayManager.new()

-- Push overlay onto stack using centralized defaults
local Colors = require('rearkitekt.core.colors')
overlay_mgr:push(OverlayDefaults.create_overlay_config({
  id = "item_picker_main",
  -- App-specific customizations only:
  scrim_color = Colors.hexrgb("#FF0000"),  -- Red scrim for this variant
  scrim_opacity = 0.92,
  esc_to_close = false,

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

  on_close = cleanup,
}))

-- Create runtime
local runtime = Runtime.new({
  title = "Item Picker",
  ctx = ctx,

  on_frame = function(ctx)
    -- Check for close request
    local close_req = reaper.GetExtState(ext_section, "close_request")
    if close_req == "1" then
      reaper.SetExtState(ext_section, "close_request", "", false)
      return false  -- Stop running, on_destroy will call cleanup
    end

    -- Check if should close after drop (before AND after rendering)
    if State.should_close_after_drop then
      return false  -- Stop running, on_destroy will call cleanup
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

      -- Check again after draw in case flag was set during draw
      if State.should_close_after_drop then
        return false  -- Stop running, on_destroy will call cleanup
      end

      return true  -- Keep running
    else
      -- Normal mode: let overlay manager handle everything
      -- Don't render if we should close
      if State.should_close_after_drop then
        return false  -- Stop running, on_destroy will call cleanup
      end

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
