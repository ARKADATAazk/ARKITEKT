-- @noindex
-- ItemPicker/ui/tiles/coordinator.lua
-- Coordinator for managing audio and MIDI grids

local ImGui = require 'imgui' '0.10'
local TileAnim = require('arkitekt.gui.rendering.tile.animator')
local AudioGridFactory = require('ItemPicker.ui.grids.factories.audio_grid_factory')
local MidiGridFactory = require('ItemPicker.ui.grids.factories.midi_grid_factory')

local M = {}
local Coordinator = {}
Coordinator.__index = Coordinator

function M.new(ctx, config, state, visualization)
  local self = setmetatable({
    config = config,
    state = state,
    visualization = visualization,

    animator = nil,
    audio_grid = nil,
    midi_grid = nil,
  }, Coordinator)

  -- Create animator
  self.animator = TileAnim.new(12.0)

  -- Create grids
  self.audio_grid = AudioGridFactory.create(ctx, config, state, visualization, self.animator)
  self.midi_grid = MidiGridFactory.create(ctx, config, state, visualization, self.animator)

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
  local current_w = self.state.get_tile_width()
  local current_h = self.state.get_tile_height()

  if ctrl then
    local new_height = current_h + (delta * self.config.TILE.HEIGHT_STEP)
    self.state.set_tile_size(current_w, new_height)
  elseif alt then
    local new_width = current_w + (delta * self.config.TILE.WIDTH_STEP)
    self.state.set_tile_size(new_width, current_h)
  end

  -- Update grids with new size
  if self.midi_grid then
    self.midi_grid.min_col_w_fn = function() return self.state.get_tile_width() end
    self.midi_grid.fixed_tile_h = self.state.get_tile_height()
  end

  if self.audio_grid then
    self.audio_grid.min_col_w_fn = function() return self.state.get_tile_width() end
    self.audio_grid.fixed_tile_h = self.state.get_tile_height()
  end

  return true
end

function Coordinator:render_audio_grid(ctx, avail_w, avail_h, header_offset)
  if not self.audio_grid then return end
  header_offset = header_offset or 0

  if ImGui.BeginChild(ctx, "audio_grid", avail_w, avail_h, ImGui.ChildFlags_None, ImGui.WindowFlags_NoScrollbar) then
    -- Check for CTRL/ALT+wheel BEFORE grid draws (prevents scroll)
    local saved_scroll = nil
    local wheel_y = ImGui.GetMouseWheel(ctx)

    if wheel_y ~= 0 then
      local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
      local alt = ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) or ImGui.IsKeyDown(ctx, ImGui.Key_RightAlt)

      if ctrl or alt then
        -- Save scroll position to restore after grid processes wheel
        saved_scroll = ImGui.GetScrollY(ctx)
      end
    end

    -- Set clip bounds to limit grid rendering below header
    if header_offset > 0 then
      local origin_x, origin_y = ImGui.GetCursorScreenPos(ctx)
      local window_x, window_y = ImGui.GetWindowPos(ctx)
      -- Set panel_clip_bounds to constrain grid below header
      self.audio_grid.panel_clip_bounds = {
        window_x,
        origin_y + header_offset,  -- Start below header
        window_x + avail_w,
        window_y + avail_h
      }
      self.audio_grid.clip_rendering = true  -- Enable actual rendering clipping
      ImGui.SetCursorScreenPos(ctx, origin_x, origin_y + header_offset)
    else
      self.audio_grid.panel_clip_bounds = nil
      self.audio_grid.clip_rendering = false
    end

    self.audio_grid:draw(ctx)

    -- Add Dummy to extend child bounds when using SetCursorScreenPos
    if header_offset > 0 then
      ImGui.Dummy(ctx, 0, 0)
    end

    -- Restore scroll if we consumed wheel for resize
    if saved_scroll then
      ImGui.SetScrollY(ctx, saved_scroll)
    end

    ImGui.EndChild(ctx)
  end
end

function Coordinator:render_midi_grid(ctx, avail_w, avail_h, header_offset)
  if not self.midi_grid then return end
  header_offset = header_offset or 0

  if ImGui.BeginChild(ctx, "midi_grid", avail_w, avail_h, ImGui.ChildFlags_None, ImGui.WindowFlags_NoScrollbar) then
    -- Check for CTRL/ALT+wheel BEFORE grid draws (prevents scroll)
    local saved_scroll = nil
    local wheel_y = ImGui.GetMouseWheel(ctx)

    if wheel_y ~= 0 then
      local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
      local alt = ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) or ImGui.IsKeyDown(ctx, ImGui.Key_RightAlt)

      if ctrl or alt then
        -- Save scroll position to restore after grid processes wheel
        saved_scroll = ImGui.GetScrollY(ctx)
      end
    end

    -- Set clip bounds to limit grid rendering below header
    if header_offset > 0 then
      local origin_x, origin_y = ImGui.GetCursorScreenPos(ctx)
      local window_x, window_y = ImGui.GetWindowPos(ctx)
      -- Set panel_clip_bounds to constrain grid below header
      self.midi_grid.panel_clip_bounds = {
        window_x,
        origin_y + header_offset,  -- Start below header
        window_x + avail_w,
        window_y + avail_h
      }
      self.midi_grid.clip_rendering = true  -- Enable actual rendering clipping
      ImGui.SetCursorScreenPos(ctx, origin_x, origin_y + header_offset)
    else
      self.midi_grid.panel_clip_bounds = nil
      self.midi_grid.clip_rendering = false
    end

    self.midi_grid:draw(ctx)

    -- Add Dummy to extend child bounds when using SetCursorScreenPos
    if header_offset > 0 then
      ImGui.Dummy(ctx, 0, 0)
    end

    -- Restore scroll if we consumed wheel for resize
    if saved_scroll then
      ImGui.SetScrollY(ctx, saved_scroll)
    end

    ImGui.EndChild(ctx)
  end
end

-- Clear internal drag state from both grids (called after external drop completes)
function Coordinator:clear_grid_drag_states()
  if self.audio_grid and self.audio_grid.drag then
    self.audio_grid.drag:release()
  end
  if self.midi_grid and self.midi_grid.drag then
    self.midi_grid.drag:release()
  end
end

return M
