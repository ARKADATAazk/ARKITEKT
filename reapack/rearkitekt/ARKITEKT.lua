-- @description ARKITEKT Toolkit
-- @author ARKADATA
-- @donation https://www.paypal.com/donate/?hosted_button_id=2FP22TUPGFPSJ
-- @website https://www.arkadata.com
-- @version 0.1.5
-- @changelog Initial beta release
-- @provides
--   ../apps/**/*.lua
--   **/*.lua

-- Package path setup for relocated script
local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path

-- Ensure root_path ends with a slash
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end

-- Add both module search paths
local reapack_path = root_path .. "reapack/"
local scripts_path = root_path .. "reapack/scripts/"
package.path = reapack_path .. "?.lua;" .. reapack_path .. "?/init.lua;" .. 
               scripts_path .. "?.lua;" .. scripts_path .. "?/init.lua;" .. 
               package.path

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.9'

local Shell = require('rearkitekt.app.shell')
local Settings = nil
local Style = nil

-- Attempt to load optional modules
do
  local ok, mod = pcall(require, 'rearkitekt.app.settings')
  if ok then Settings = mod end
end

do
  local ok, mod = pcall(require, 'rearkitekt.app.style')
  if ok then Style = mod end
end

-- App State
local app_state = {
  counter = 0,
  input_text = "",
  slider_value = 0.5,
  checkbox_value = false,
  selected_tab = "Home",
  color = {r = 0.4, g = 0.7, b = 0.9, a = 1.0},
  last_status_update = 0,
  status_messages = {
    {text = "READY", color = 0x41E0A3FF},
    {text = "PROCESSING", color = 0xFFA500FF},
    {text = "WARNING", color = 0xFFFF00FF},
    {text = "ERROR", color = 0xFF4444FF},
  },
  current_status_index = 1,
}

-- Settings persistence
local settings = nil
if Settings then
  settings = Settings.new({
    name = 'ARKITEKT_DefaultApp',
    defaults = {
      counter = 0,
      slider_value = 0.5,
      checkbox_value = false,
      input_text = "",
    }
  })
  
  if settings then
    app_state.counter = settings:get('counter', app_state.counter)
    app_state.slider_value = settings:get('slider_value', app_state.slider_value)
    app_state.checkbox_value = settings:get('checkbox_value', app_state.checkbox_value)
    app_state.input_text = settings:get('input_text', app_state.input_text)
  end
end

-- Style configuration
local style = nil
if Style then
  style = Style.new()
end

-- Status bar function
local function get_status()
  local current_time = reaper.time_precise()
  
  if current_time - app_state.last_status_update > 5.0 then
    app_state.current_status_index = app_state.current_status_index + 1
    if app_state.current_status_index > #app_state.status_messages then
      app_state.current_status_index = 1
    end
    app_state.last_status_update = current_time
  end
  
  return app_state.status_messages[app_state.current_status_index]
end

-- Tab configuration
local tabs_config = {
  tabs = {
    {id = "home", label = "Home", icon = "🏠"},
    {id = "controls", label = "Controls", icon = "🎛️"},
    {id = "settings", label = "Settings", icon = "⚙️"},
    {id = "about", label = "About", icon = "ℹ️"},
  },
  active = "home",
}

-- Draw function for Home tab
local function draw_home_tab(ctx)
  ImGui.PushFont(ctx, ImGui.GetFont(ctx))
  
  ImGui.TextColored(ctx, 0x41E0A3FF, "Welcome to ARKITEKT Default App")
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  ImGui.Text(ctx, "This is a demonstration of the ARKITEKT framework.")
  ImGui.Text(ctx, string.format("Counter: %d", app_state.counter))
  
  ImGui.Spacing(ctx)
  
  if ImGui.Button(ctx, "Increment Counter", 150, 30) then
    app_state.counter = app_state.counter + 1
    if settings then
      settings:set('counter', app_state.counter)
    end
  end
  
  ImGui.SameLine(ctx)
  
  if ImGui.Button(ctx, "Reset Counter", 150, 30) then
    app_state.counter = 0
    if settings then
      settings:set('counter', app_state.counter)
    end
  end
  
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  ImGui.Text(ctx, "Project Information:")
  ImGui.BulletText(ctx, string.format("Project Path: %s", reaper.GetProjectPath("")))
  ImGui.BulletText(ctx, string.format("Time: %.2f seconds", reaper.GetPlayPosition()))
  ImGui.BulletText(ctx, string.format("BPM: %.2f", reaper.TimeMap_GetDividedBpmAtTime(0)))
  
  ImGui.PopFont(ctx)
end

-- Draw function for Controls tab
local function draw_controls_tab(ctx)
  ImGui.Text(ctx, "Interactive Controls")
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  local rv, new_text = ImGui.InputText(ctx, "Text Input", app_state.input_text, 256)
  if rv then
    app_state.input_text = new_text
    if settings then
      settings:set('input_text', app_state.input_text)
    end
  end
  
  ImGui.Spacing(ctx)
  
  local rv, new_value = ImGui.SliderDouble(ctx, "Slider", app_state.slider_value, 0.0, 1.0, "%.3f")
  if rv then
    app_state.slider_value = new_value
    if settings then
      settings:set('slider_value', app_state.slider_value)
    end
  end
  
  ImGui.Spacing(ctx)
  
  local rv, new_checked = ImGui.Checkbox(ctx, "Checkbox Option", app_state.checkbox_value)
  if rv then
    app_state.checkbox_value = new_checked
    if settings then
      settings:set('checkbox_value', app_state.checkbox_value)
    end
  end
  
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  ImGui.Text(ctx, "Color Picker")
  local color_u32 = ImGui.ColorConvertDouble4ToU32(
    app_state.color.r,
    app_state.color.g,
    app_state.color.b,
    app_state.color.a
  )
  
  local rv, new_color = ImGui.ColorEdit4(ctx, "Color", color_u32, ImGui.ColorEditFlags_None)
  if rv then
    app_state.color.r, app_state.color.g, app_state.color.b, app_state.color.a = 
      ImGui.ColorConvertU32ToDouble4(new_color)
  end
  
  ImGui.Spacing(ctx)
  
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, cursor_x, cursor_y, cursor_x + 200, cursor_y + 50, color_u32, 4)
  ImGui.Dummy(ctx, 200, 50)
end

-- Draw function for Settings tab
local function draw_settings_tab(ctx)
  ImGui.Text(ctx, "Application Settings")
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  ImGui.Text(ctx, "Persisted Values:")
  ImGui.BulletText(ctx, string.format("Counter: %d", app_state.counter))
  ImGui.BulletText(ctx, string.format("Slider: %.3f", app_state.slider_value))
  ImGui.BulletText(ctx, string.format("Checkbox: %s", app_state.checkbox_value and "true" or "false"))
  ImGui.BulletText(ctx, string.format("Text: %s", app_state.input_text ~= "" and app_state.input_text or "(empty)"))
  
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  if ImGui.Button(ctx, "Reset All Settings", 200, 30) then
    app_state.counter = 0
    app_state.slider_value = 0.5
    app_state.checkbox_value = false
    app_state.input_text = ""
    
    if settings then
      settings:set('counter', 0)
      settings:set('slider_value', 0.5)
      settings:set('checkbox_value', false)
      settings:set('input_text', "")
      settings:flush()
    end
  end
  
  ImGui.Spacing(ctx)
  
  if settings then
    ImGui.Text(ctx, string.format("Settings File: %s", settings.name))
  else
    ImGui.TextColored(ctx, 0xFF4444FF, "Settings module not available")
  end
end

-- Draw function for About tab
local function draw_about_tab(ctx)
  ImGui.TextColored(ctx, 0x41E0A3FF, "ARKITEKT Toolkit")
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  ImGui.Text(ctx, "Version: 0.1.0")
  ImGui.Text(ctx, "Author: ARKADATA")
  ImGui.Spacing(ctx)
  
  ImGui.Text(ctx, "Features:")
  ImGui.BulletText(ctx, "Custom window management with titlebar")
  ImGui.BulletText(ctx, "Integrated status bar")
  ImGui.BulletText(ctx, "Tab navigation system")
  ImGui.BulletText(ctx, "Settings persistence")
  ImGui.BulletText(ctx, "Profiling support (double-click icon)")
  ImGui.BulletText(ctx, "Custom styling system")
  ImGui.BulletText(ctx, "Maximize/restore functionality")
  
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
  
  ImGui.TextWrapped(ctx, "Double-click the application icon in the titlebar to toggle profiling metrics.")
end

-- Main draw function with tab routing
local function draw_main(ctx, state)
  local active_tab = state.window:get_active_tab()
  
  if not active_tab then
    active_tab = tabs_config.active
  end
  
  if active_tab == "home" then
    draw_home_tab(ctx)
  elseif active_tab == "controls" then
    draw_controls_tab(ctx)
  elseif active_tab == "settings" then
    draw_settings_tab(ctx)
  elseif active_tab == "about" then
    draw_about_tab(ctx)
  else
    draw_home_tab(ctx)
  end
end

-- On close callback
local function on_close()
  if settings then
    settings:flush()
  end
end

-- Start the application
local runtime = Shell.run({
  title = "ARKITEKT Default App",
  settings = settings,
  style = style,
  
  initial_size = {w = 900, h = 600},
  initial_pos = {x = 100, y = 100},
  min_size = {w = 600, h = 400},
  
  show_status_bar = true,
  show_titlebar = true,
  get_status_func = get_status,
  
  tabs = tabs_config,
  
  content_padding = 16,
  
  draw = draw_main,
  on_close = on_close,
  
  enable_profiling = true,
})

if runtime then
  reaper.defer(function() end)
end