-- @noindex
-- ItemPicker/app/gui.lua

local ImGui = require 'imgui' '0.10'
local Grid = require('rearkitekt.gui.widgets.grid.core')
local Colors = require('rearkitekt.core.colors')
local MarchingAnts = require('rearkitekt.gui.fx.marching_ants')
local Draw = require('rearkitekt.gui.draw')
local TileFX = require('rearkitekt.gui.fx.tile_fx')
local TileAnim = require('rearkitekt.gui.fx.tile_motion')

local M = {}
local GUI = {}
GUI.__index = GUI

function M.create(state_module, config_module, settings_module, SCRIPT_DIRECTORY)
  local self = setmetatable({
    state = state_module,
    config = config_module,
    settings = settings_module,
    SCRIPT_DIRECTORY = SCRIPT_DIRECTORY,
    
    cache_manager = nil,
    reaper_interface = nil,
    visualization = nil,
    grid_adapter = nil,
    drag_drop = nil,
    main_ui = nil,
    shortcuts = nil,
    disabled_items = nil,
    utils = nil,
    tile_rendering = nil,
    job_queue = nil,
    
    initialized = false,
  }, GUI)
  
  local utils = dofile(SCRIPT_DIRECTORY .. 'app/utils.lua')
  local disabled_items = dofile(SCRIPT_DIRECTORY .. 'app/disabled_items.lua')
  local tile_rendering = dofile(SCRIPT_DIRECTORY .. 'app/tile_rendering.lua')
  local shortcuts = dofile(SCRIPT_DIRECTORY .. 'app/shortcuts.lua')
  local cache_manager = dofile(SCRIPT_DIRECTORY .. 'app/cache_manager.lua')
  local reaper_interface = dofile(SCRIPT_DIRECTORY .. 'app/reaper_interface.lua')
  local visualization = dofile(SCRIPT_DIRECTORY .. 'app/visualization.lua')
  local grid_adapter = dofile(SCRIPT_DIRECTORY .. 'app/grid_adapter.lua')
  local drag_drop = dofile(SCRIPT_DIRECTORY .. 'app/drag_drop.lua')
  local main_ui = dofile(SCRIPT_DIRECTORY .. 'app/main_ui.lua')
  local job_queue = dofile(SCRIPT_DIRECTORY .. 'app/job_queue.lua')
  
  self.utils = utils
  self.disabled_items = disabled_items
  self.tile_rendering = tile_rendering
  self.shortcuts = shortcuts
  self.cache_manager = cache_manager
  self.reaper_interface = reaper_interface
  self.visualization = visualization
  self.grid_adapter = grid_adapter
  self.drag_drop = drag_drop
  self.main_ui = main_ui
  self.job_queue = job_queue
  
  return self
end

function GUI:initialize_once(ctx)
  if self.initialized then return end
  
  self.state.cache = self.cache_manager.new(self.config.CACHE.MAX_ENTRIES)
  self.state.cache_manager = self.cache_manager
  self.state.disabled = self.disabled_items.new()
  self.state.job_queue = self.job_queue.new(3)
  
  self.reaper_interface.init(self.utils)
  self.shortcuts.init(self.config)
  self.tile_rendering.init(self.config, Colors, MarchingAnts, Draw, TileFX)
  self.visualization.init(self.utils, self.SCRIPT_DIRECTORY, self.cache_manager)
  self.grid_adapter.init(Grid, self.visualization, self.cache_manager, self.config, self.shortcuts, self.tile_rendering, self.disabled_items, TileAnim)
  self.drag_drop.init(self.visualization)
  self.main_ui.init(self.utils, self.grid_adapter, self.reaper_interface, self.config, self.shortcuts, self.disabled_items)
  
  self.state.track_chunks = self.reaper_interface.GetAllTrackStateChunks()
  self.state.item_chunks = self.reaper_interface.GetAllCleanedItemChunks()
  
  self.initialized = true
end

function GUI:draw(ctx, shell_state)
  self:initialize_once(ctx)
  
  if not self.state.draw_list then
    self.state.draw_list = ImGui.GetWindowDrawList(ctx)
  end
  
  local viewport = ImGui.GetMainViewport(ctx)
  local SCREEN_W, SCREEN_H = ImGui.Viewport_GetSize(viewport)
  
  local is_overlay_mode = shell_state.is_overlay_mode == true
  local overlay = shell_state.overlay
  
  local overlay_alpha = 1.0
  if is_overlay_mode and overlay and overlay.alpha then
    overlay_alpha = overlay.alpha:value()
  end
  self.state.overlay_alpha = overlay_alpha
  
  local mini_font = shell_state.fonts.default
  local mini_font_size = shell_state.fonts.default_size or 14
  local big_font = shell_state.fonts.title
  local big_font_size = shell_state.fonts.title_size or 24
  
  ImGui.PushFont(ctx, mini_font, mini_font_size)
  reaper.PreventUIRefresh(1)
  
  if self.state.job_queue and self.job_queue.process_jobs then
    self.job_queue.process_jobs(
      self.state.job_queue,
      self.visualization,
      self.cache_manager,
      ctx
    )
  end
  
  self.grid_adapter.update_animations(self.state, 0.016)
  
  if not self.state.dragging then
    self.main_ui.MainWindow(ctx, self.state, self.settings, big_font, "Item Picker", SCREEN_W, SCREEN_H)
  else
    local should_insert = self.drag_drop.DragDropLogic(ctx, self.state, mini_font)
    if should_insert then
      self.reaper_interface.InsertItemAtMousePos(self.state.item_to_add, self.state)
      self.state.exit = true
      self.state.dragging = nil
    end
    self.drag_drop.DraggingThumbnailWindow(ctx, self.state, mini_font)
  end
  
  reaper.PreventUIRefresh(-1)
  ImGui.PopFont(ctx)
  
  if self.state.exit or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    if is_overlay_mode then
      if overlay and overlay.close then
        overlay:close()
      end
    else
      if shell_state.window and shell_state.window.request_close then
        shell_state.window:request_close()
      end
    end
  end
end

return M