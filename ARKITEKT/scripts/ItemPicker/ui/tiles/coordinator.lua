-- @noindex
-- ItemPicker/ui/tiles/coordinator.lua
-- Coordinator for managing audio and MIDI grids

local ImGui = require 'imgui' '0.10'
local TileAnim = require('rearkitekt.gui.fx.tile_motion')
local AudioGridFactory = require('ItemPicker.ui.tiles.factories.audio_grid_factory')
local MidiGridFactory = require('ItemPicker.ui.tiles.factories.midi_grid_factory')

local M = {}
local Coordinator = {}
Coordinator.__index = Coordinator

function M.new(ctx, config, state, visualization, cache_mgr)
  local self = setmetatable({
    config = config,
    state = state,
    visualization = visualization,
    cache_mgr = cache_mgr,

    animator = nil,
    audio_grid = nil,
    midi_grid = nil,
  }, Coordinator)

  -- Create animator
  self.animator = TileAnim.new(12.0)

  -- Create grids
  self.audio_grid = AudioGridFactory.create(ctx, config, state, visualization, cache_mgr, self.animator)
  self.midi_grid = MidiGridFactory.create(ctx, config, state, visualization, cache_mgr, self.animator)

  return self
end

function Coordinator:update_animations(dt)
  if self.animator then
    self.animator:update(dt)
  end
end

function Coordinator:handle_tile_size_shortcuts(ctx)
  local wheel = ImGui.GetMouseWheel(ctx)
  if wheel == 0 then return false end

  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
  local alt = ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) or ImGui.IsKeyDown(ctx, ImGui.Key_RightAlt)

  if not ctrl and not alt then return false end

  local delta = wheel > 0 and 1 or -1
  local current_w = self.state:get_tile_width()
  local current_h = self.state:get_tile_height()

  if ctrl then
    local new_height = current_h + (delta * self.config.TILE.HEIGHT_STEP)
    self.state:set_tile_size(current_w, new_height)
  elseif alt then
    local new_width = current_w + (delta * self.config.TILE.WIDTH_STEP)
    self.state:set_tile_size(new_width, current_h)
  end

  -- Update grids with new size
  if self.midi_grid then
    self.midi_grid.min_col_w_fn = function() return self.state:get_tile_width() end
    self.midi_grid.fixed_tile_h = self.state:get_tile_height()
  end

  if self.audio_grid then
    self.audio_grid.min_col_w_fn = function() return self.state:get_tile_width() end
    self.audio_grid.fixed_tile_h = self.state:get_tile_height()
  end

  return true
end

function Coordinator:render_audio_grid(ctx, avail_w, avail_h)
  if not self.audio_grid then return end

  if ImGui.BeginChild(ctx, "audio_grid", avail_w, avail_h, ImGui.ChildFlags_None, ImGui.WindowFlags_NoScrollbar) then
    self.audio_grid:render(ctx, avail_w, avail_h)
    ImGui.EndChild(ctx)
  end
end

function Coordinator:render_midi_grid(ctx, avail_w, avail_h)
  if not self.midi_grid then return end

  if ImGui.BeginChild(ctx, "midi_grid", avail_w, avail_h, ImGui.ChildFlags_None, ImGui.WindowFlags_NoScrollbar) then
    self.midi_grid:render(ctx, avail_w, avail_h)
    ImGui.EndChild(ctx)
  end
end

return M
