local _, script_filename, _, _, _, _, _ = reaper.get_action_context()
SCRIPT_DIRECTORY = script_filename:match('(.*)[%\\/]') .. "\\"

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local imgui = require 'imgui' '0.9.0'  -- ADD THIS LINE

SCRIPT_TITLE = "Item Picker"

local ARKITEKT_PATH = SCRIPT_DIRECTORY:match("(.*/ARKITEKT/)") or SCRIPT_DIRECTORY:match("(.*\\ARKITEKT\\)")
package.path = ARKITEKT_PATH .. '?.lua;' .. ARKITEKT_PATH .. '?/init.lua;' .. package.path

local Shell = require('rearkitekt.app.shell')
local Grid = require('rearkitekt.gui.widgets.grid.core')
local Colors = require('rearkitekt.core.colors')
local MarchingAnts = require('rearkitekt.gui.fx.marching_ants')
local Draw = require('rearkitekt.gui.draw')
local TileFX = require('rearkitekt.gui.fx.tile_fx')
local TileAnim = require('rearkitekt.gui.fx.tile_motion')

local profiler = dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua')
reaper.defer = profiler.defer

dofile(reaper.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua")
local ultraschall = ultraschall

if not package.loaded['imgui'] then
  reaper.MB("Missing dependency: ReaImGui extension.\nDownload it via Reapack ReaTeam extension repository.", "Error", 0)
  return false
end

reaimgui_shim_file_path = reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua'
if reaper.file_exists(reaimgui_shim_file_path) then
  dofile(reaimgui_shim_file_path)('0.8.6')
end

package.path = SCRIPT_DIRECTORY .. '?.lua;' .. SCRIPT_DIRECTORY .. '?/init.lua;' .. package.path

local pickle = dofile(SCRIPT_DIRECTORY .. 'app/pickle.lua')
local utils = dofile(SCRIPT_DIRECTORY .. 'app/utils.lua')
local config = dofile(SCRIPT_DIRECTORY .. 'app/config.lua')
local shortcuts = dofile(SCRIPT_DIRECTORY .. 'app/shortcuts.lua')
local disabled_items = dofile(SCRIPT_DIRECTORY .. 'app/disabled_items.lua')
local tile_rendering = dofile(SCRIPT_DIRECTORY .. 'app/tile_rendering.lua')

if not config then error("config failed to load") end
if not shortcuts then error("shortcuts failed to load") end
if not disabled_items then error("disabled_items failed to load") end
if not tile_rendering then error("tile_rendering failed to load") end

local cache_manager = dofile(SCRIPT_DIRECTORY .. 'app/cache_manager.lua')
local reaper_interface = dofile(SCRIPT_DIRECTORY .. 'app/reaper_interface.lua')
local visualization = dofile(SCRIPT_DIRECTORY .. 'app/visualization.lua')
local grid_adapter = dofile(SCRIPT_DIRECTORY .. 'app/grid_adapter.lua')
local drag_drop = dofile(SCRIPT_DIRECTORY .. 'app/drag_drop.lua')
local main_ui = dofile(SCRIPT_DIRECTORY .. 'app/main_ui.lua')

local function SetButtonState(set)
  local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  reaper.SetToggleCommandState(sec, cmd, set or 0)
  reaper.RefreshToolbar2(sec, cmd)
end

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

Shell.run({
  title = SCRIPT_TITLE,
  version = "1.0.0",
  
  fullscreen = {
    enabled = true,
    use_viewport = true,
    fade_in_duration = 0.3,
    fade_out_duration = 0.3,
    fade_speed = 10.0,
    scrim_enabled = true,
    scrim_color = 0x000000FF,
    scrim_opacity = 0.85,
    
    show_close_button = true,
    close_on_background_click = true,
    close_on_background_left_click = false,
    close_button_proximity = 150,
    
    close_button = {
      size = 32,
      margin = 16,
      bg_color = 0x000000FF,
      bg_opacity = 0.6,
      bg_opacity_hover = 0.8,
      icon_color = 0xFFFFFFFF,
      hover_color = 0xFF4444FF,
      active_color = 0xFF0000FF,
    },
  },
  
  show_titlebar = false,
  show_status_bar = false,
  
  fonts = {
    default = 14,
    title = 24,
    monospace = 14,
  },
  
  draw = function(ctx, shell_state)
    
    if not state.cache then
      state.cache = cache_manager.new(config.CACHE.MAX_ENTRIES)
      state.cache_manager = cache_manager
      state.disabled = disabled_items.new()
      
      reaper_interface.init(utils)
      shortcuts.init(imgui, ctx, config)
      tile_rendering.init(imgui, ctx, config, Colors, MarchingAnts, Draw, TileFX)
      visualization.init(utils, imgui, ctx, SCRIPT_DIRECTORY, cache_manager)
      grid_adapter.init(imgui, ctx, Grid, visualization, cache_manager, config, shortcuts, tile_rendering, disabled_items, TileAnim)
      drag_drop.init(imgui, ctx, visualization)
      main_ui.init(imgui, ctx, utils, grid_adapter, reaper_interface, config, shortcuts, disabled_items)
      
      state.track_chunks = reaper_interface.GetAllTrackStateChunks()
      state.item_chunks = reaper_interface.GetAllCleanedItemChunks()
    end
    
    if not state.draw_list then
      state.draw_list = imgui.GetWindowDrawList(ctx)
    end
    
    local viewport = imgui.GetMainViewport(ctx)
    local SCREEN_W, SCREEN_H = imgui.Viewport_GetSize(viewport)
    
    local mini_font = shell_state.fonts.default
    local big_font = shell_state.fonts.title
    
    imgui.PushFont(ctx, mini_font)
    reaper.PreventUIRefresh(1)
    
    grid_adapter.update_animations(state, 0.016)
    
    if not state.dragging then
      main_ui.MainWindow(state, settings, big_font, SCRIPT_TITLE, SCREEN_W, SCREEN_H)
    else
      local should_insert = drag_drop.DragDropLogic(state, mini_font)
      if should_insert then
        reaper_interface.InsertItemAtMousePos(state.item_to_add, state)
        state.exit = true
        state.dragging = nil
      end
      drag_drop.DraggingThumbnailWindow(state, mini_font)
    end
    
    reaper.PreventUIRefresh(-1)
    imgui.PopFont(ctx)
    
    if state.exit or imgui.IsKeyPressed(ctx, imgui.Key_Escape) then
      shell_state.window:request_close()
    end
  end,
  
  on_close = function()
    cleanup()
  end,
})