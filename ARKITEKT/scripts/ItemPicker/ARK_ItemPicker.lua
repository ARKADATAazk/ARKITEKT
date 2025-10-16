-- @noindex
-- ItemPicker main launcher with clean overlay support
local _, script_filename, _, _, _, _, _ = reaper.get_action_context()
local SCRIPT_DIRECTORY = script_filename:match('(.*)[%\\/]') .. "\\"

local ARKITEKT_PATH = SCRIPT_DIRECTORY:match("(.*/ARKITEKT/)") or SCRIPT_DIRECTORY:match("(.*\\ARKITEKT\\)")
package.path = ARKITEKT_PATH .. '?.lua;' .. ARKITEKT_PATH .. '?/init.lua;' .. package.path
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
package.path = SCRIPT_DIRECTORY .. '?.lua;' .. SCRIPT_DIRECTORY .. '?/init.lua;' .. package.path

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
local Overlay = require('rearkitekt.app.overlay')
local GUI = dofile(SCRIPT_DIRECTORY .. 'app/gui.lua')
local pickle = dofile(SCRIPT_DIRECTORY .. 'app/pickle.lua')
local config = dofile(SCRIPT_DIRECTORY .. 'app/config.lua')

if not config then error("config failed to load") end

-- Configuration
local USE_OVERLAY = true  -- Set to false for normal window mode

local function SetButtonState(set)
  local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  reaper.SetToggleCommandState(sec, cmd, set or 0)
  reaper.RefreshToolbar2(sec, cmd)
end

-- Settings management
local settings = {
  play_item_through_track = false,
  show_muted_tracks = false,
  show_muted_items = false,
  show_disabled_items = false,
  focus_keyboard_on_init = true,
  search_string = 0,
}

local rv, pickled_settings = reaper.GetProjExtState(0, "ItemPicker", "settings")
if rv == 1 then
  settings = pickle.Unpickle(pickled_settings)
end

-- State management
local state = {
  item_waveforms = {},
  midi_thumbnails = {},
  box_current_sample = {},
  box_current_item = {},
  scroll_y = {},
  previewing = 0,
  cache = nil,
  cache_manager = nil,
  disabled = nil,
  dragging = nil,
  exit = false,
}

function table.getn(tab)
  local i = 0
  for _ in pairs(tab) do
    i = i + 1
  end
  return i
end

local function cleanup()
  SetButtonState()
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_STOPPREVIEW"), 0)
  reaper.SetProjExtState(0, "ItemPicker", "settings", pickle.Pickle(settings))
end

SetButtonState(1)

-- Create GUI
local gui = GUI.create(state, config, settings, SCRIPT_DIRECTORY)

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
  local ctx = ImGui.CreateContext("Item Picker")
  local fonts = load_fonts(ctx)
  
  -- Create overlay
  local overlay = Overlay.new({
    enabled = true,
    use_viewport = true,
    fade_duration = 10.3,
    fade_speed = 10.0,
    scrim_enabled = true,
    scrim_color = 0x000000FF,
    scrim_opacity = 0.85,
    show_close_button = true,
    close_on_background_click = false,
    close_on_background_right_click = true,
    close_on_escape = false,  -- We'll handle ESC in the GUI
    close_button_size = 32,
    close_button_margin = 16,
    close_button_proximity = 150,
    content_padding = 20,
    
    draw = function(ctx, overlay_state)
      -- Push font for content with size
      ImGui.PushFont(ctx, fonts.default, fonts.default_size)
      
      -- Create a child window for the actual content
      local child_flags = ImGui.WindowFlags_NoScrollbar | 
                         ImGui.WindowFlags_NoScrollWithMouse |
                         ImGui.WindowFlags_NoBackground
      
      if ImGui.BeginChild(ctx, "##ItemPickerContent", 
                          overlay_state.width, 
                          overlay_state.height, 
                          ImGui.ChildFlags_None, 
                          child_flags) then
        
        -- Let the GUI handle its own drawing
        if gui and gui.draw then
          -- Pass a state that includes both fonts and overlay reference
          gui:draw(ctx, {
            fonts = fonts,
            overlay_state = overlay_state,
            overlay = overlay_state.overlay,  -- Pass the overlay reference
            is_overlay_mode = true,
          })
        end
        
        ImGui.EndChild(ctx)
      end
      
      ImGui.PopFont(ctx)
    end,
    
    on_close = function()
      cleanup()
    end,
  })
  
  -- Open overlay immediately
  overlay:open()
  
  -- Create runtime
  local runtime = Runtime.new({
    title = "Item Picker",
    ctx = ctx,
    
    on_frame = function(ctx)
      local keep_open = overlay:render(ctx)
      return keep_open
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
    title = "Item Picker",
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
      gui:draw(ctx, shell_state)
    end,
    
    on_close = function()
      cleanup()
    end,
  })
end