-- @noindex
-- ItemPicker/ui/grids/coordinator.lua
-- Coordinator for managing audio and MIDI grids

local ImGui = require('arkitekt.platform.imgui')
local Ark = require('arkitekt')
local TileAnim = require('arkitekt.gui.animation.tile_animator')
local Lifecycle = require('arkitekt.gui.animation.lifecycle')
local AudioGridFactory = require('ItemPicker.ui.grids.factories.audio')
local MidiGridFactory = require('ItemPicker.ui.grids.factories.midi')
local AudioRenderer = require('ItemPicker.ui.grids.renderers.audio')
local MidiRenderer = require('ItemPicker.ui.grids.renderers.midi')

local M = {}
local Coordinator = {}
Coordinator.__index = Coordinator

function M.new(ctx, config, state, visualization)
  local self = setmetatable({
    config = config,
    state = state,
    visualization = visualization,

    animator = nil,
    disable_animator = nil,

    -- Grid options and result references (new callable API)
    audio_grid_opts = nil,
    audio_grid_result_ref = nil,
    midi_grid_opts = nil,
    midi_grid_result_ref = nil,

    -- PERF: Badge click handlers (called after grid render, replaces per-tile InvisibleButtons)
    audio_badge_click_handler = nil,
    midi_badge_click_handler = nil,
  }, Coordinator)

  -- Create animator
  self.animator = TileAnim.new(12.0)

  -- Create disable animator (for when items are disabled AND show_disabled_items = false)
  self.disable_animator = Lifecycle.DisableAnim.new({duration = 0.10})

  -- Create grid options (factories now return badge click handler as 3rd value)
  self.audio_grid_opts, self.audio_grid_result_ref, self.audio_badge_click_handler = AudioGridFactory.create_options(config, state, visualization, self.animator, self.disable_animator)
  self.midi_grid_opts, self.midi_grid_result_ref, self.midi_badge_click_handler = MidiGridFactory.create_options(config, state, visualization, self.animator, self.disable_animator)

  return self
end

function Coordinator:update_animations(dt)
  if self.animator then
    self.animator:update(dt)
  end
  if self.disable_animator then
    self.disable_animator:update(dt)
  end
end

-- Returns true if any grid tiles are actively animating (resizing/repositioning)
-- Used to throttle expensive operations like waveform/MIDI regeneration during resize
function Coordinator:is_animating()
  local audio_result = self.audio_grid_result_ref and self.audio_grid_result_ref.current
  local midi_result = self.midi_grid_result_ref and self.midi_grid_result_ref.current

  local audio_animating = audio_result and audio_result.is_animating
  local midi_animating = midi_result and midi_result.is_animating

  return audio_animating or midi_animating
end

function Coordinator:render_disable_animations(ctx)
  if not self.disable_animator then return end

  local dl = ImGui.GetWindowDrawList(ctx)

  -- Render all active disable animations (like grid/animation.lua does)
  for key, anim_data in pairs(self.disable_animator.disabling) do
    self.disable_animator:render(ctx, dl, key, anim_data.rect,
                                  nil, -- Color is stored in anim_data
                                  self.config.TILE.ROUNDING,
                                  self.state.icon_font,
                                  self.state.icon_font_size)
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

  -- Update grid options with new size (functions are already reactive)
  if self.midi_grid_opts then
    self.midi_grid_opts.fixed_tile_h = self.state.get_tile_height()
  end

  if self.audio_grid_opts then
    self.audio_grid_opts.fixed_tile_h = self.state.get_tile_height()
  end

  return true
end

function Coordinator:render_audio_grid(ctx, avail_w, avail_h, header_offset)
  if not self.audio_grid_opts then return end
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
      self.audio_grid_opts.panel_clip_bounds = {
        window_x,
        origin_y + header_offset,  -- Start below header
        window_x + avail_w,
        window_y + avail_h
      }
      self.audio_grid_opts.clip_rendering = true  -- Enable actual rendering clipping
      ImGui.SetCursorScreenPos(ctx, origin_x, origin_y + header_offset)
    else
      self.audio_grid_opts.panel_clip_bounds = nil
      self.audio_grid_opts.clip_rendering = false
    end

    -- PERF: Init renderer cache before drawing tiles
    AudioRenderer.begin_frame(ctx, self.config)

    -- Call Grid with options and store result
    local result = Ark.Grid(ctx, self.audio_grid_opts)
    self.audio_grid_result_ref.current = result

    -- PERF: Handle badge clicks via single hit-test (replaces ~5000 InvisibleButtons)
    if self.audio_badge_click_handler then
      self.audio_badge_click_handler(ctx)
    end

    -- Render disable animations on top (after items are drawn)
    self:render_disable_animations(ctx)

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
  if not self.midi_grid_opts then return end
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
      self.midi_grid_opts.panel_clip_bounds = {
        window_x,
        origin_y + header_offset,  -- Start below header
        window_x + avail_w,
        window_y + avail_h
      }
      self.midi_grid_opts.clip_rendering = true  -- Enable actual rendering clipping
      ImGui.SetCursorScreenPos(ctx, origin_x, origin_y + header_offset)
    else
      self.midi_grid_opts.panel_clip_bounds = nil
      self.midi_grid_opts.clip_rendering = false
    end

    -- PERF: Init renderer cache before drawing tiles
    MidiRenderer.begin_frame(ctx, self.config)

    -- Call Grid with options and store result
    local result = Ark.Grid(ctx, self.midi_grid_opts)
    self.midi_grid_result_ref.current = result

    -- PERF: Handle badge clicks via single hit-test (replaces ~5000 InvisibleButtons)
    if self.midi_badge_click_handler then
      self.midi_badge_click_handler(ctx)
    end

    -- Render disable animations on top (after items are drawn)
    self:render_disable_animations(ctx)

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
  if self.audio_grid_result_ref and self.audio_grid_result_ref.current and self.audio_grid_result_ref.current.drag then
    self.audio_grid_result_ref.current.drag:release()
  end
  if self.midi_grid_result_ref and self.midi_grid_result_ref.current and self.midi_grid_result_ref.current.drag then
    self.midi_grid_result_ref.current.drag:release()
  end
end

return M
