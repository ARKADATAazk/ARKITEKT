-- @noindex
-- ItemPickerWindow/ui/coordinator.lua
-- Coordinator for managing audio and MIDI grids (mirrors ItemPicker/ui/grids/coordinator.lua)

local ImGui = require('arkitekt.core.imgui')
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

    -- Grid options and result references
    audio_grid_opts = nil,
    audio_grid_result_ref = nil,
    midi_grid_opts = nil,
    midi_grid_result_ref = nil,

    -- Badge click handlers
    audio_badge_click_handler = nil,
    midi_badge_click_handler = nil,
  }, Coordinator)

  -- Create animator
  self.animator = TileAnim.new(12.0)

  -- Create disable animator
  self.disable_animator = Lifecycle.DisableAnim.new({duration = 0.10})

  -- Create grid options using factories
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

function Coordinator:render_disable_animations(ctx)
  if not self.disable_animator then return end

  local dl = ImGui.GetWindowDrawList(ctx)

  for key, anim_data in pairs(self.disable_animator.disabling) do
    self.disable_animator:render(ctx, dl, key, anim_data.rect,
                                  nil,
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

  -- Update grid options with new size
  if self.midi_grid_opts then
    self.midi_grid_opts.fixed_tile_h = self.state.get_tile_height()
  end

  if self.audio_grid_opts then
    self.audio_grid_opts.fixed_tile_h = self.state.get_tile_height()
  end

  return true
end

function Coordinator:draw_audio(ctx, height, shell_state)
  if not self.audio_grid_opts then
    ImGui.Text(ctx, '[DEBUG] audio_grid_opts is nil')
    return
  end

  local avail_w = ImGui.GetContentRegionAvail(ctx)
  if avail_w <= 0 or height <= 0 then
    ImGui.Text(ctx, string.format('[DEBUG] Invalid size: w=%d h=%d', avail_w, height))
    return
  end

  local visible = ImGui.BeginChild(ctx, 'audio_grid', avail_w, height, ImGui.ChildFlags_None, ImGui.WindowFlags_NoScrollbar)
  if visible then
    -- Check for CTRL/ALT+wheel BEFORE grid draws (prevents scroll)
    local saved_scroll = nil
    local wheel_y = ImGui.GetMouseWheel(ctx)

    if wheel_y ~= 0 then
      local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
      local alt = ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) or ImGui.IsKeyDown(ctx, ImGui.Key_RightAlt)

      if ctrl or alt then
        saved_scroll = ImGui.GetScrollY(ctx)
      end
    end

    -- Cache renderer config once per frame
    AudioRenderer.begin_frame(ctx, self.config, self.state)

    -- Call Grid with options and store result
    local result = Ark.Grid(ctx, self.audio_grid_opts)
    self.audio_grid_result_ref.current = result

    -- Add Dummy to extend child bounds (required when Grid uses SetCursorScreenPos)
    ImGui.Dummy(ctx, 0, 0)

    -- Handle badge clicks
    if self.audio_badge_click_handler then
      self.audio_badge_click_handler(ctx)
    end

    -- Render disable animations on top
    self:render_disable_animations(ctx)

    -- Restore scroll if we consumed wheel for resize
    if saved_scroll then
      ImGui.SetScrollY(ctx, saved_scroll)
    end
  end
  ImGui.EndChild(ctx)
end

function Coordinator:draw_midi(ctx, height, shell_state)
  if not self.midi_grid_opts then
    ImGui.Text(ctx, '[DEBUG] midi_grid_opts is nil')
    return
  end

  local avail_w = ImGui.GetContentRegionAvail(ctx)
  if avail_w <= 0 or height <= 0 then
    ImGui.Text(ctx, string.format('[DEBUG] Invalid size: w=%d h=%d', avail_w, height))
    return
  end

  local visible = ImGui.BeginChild(ctx, 'midi_grid', avail_w, height, ImGui.ChildFlags_None, ImGui.WindowFlags_NoScrollbar)
  if visible then
    -- Check for CTRL/ALT+wheel BEFORE grid draws (prevents scroll)
    local saved_scroll = nil
    local wheel_y = ImGui.GetMouseWheel(ctx)

    if wheel_y ~= 0 then
      local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
      local alt = ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) or ImGui.IsKeyDown(ctx, ImGui.Key_RightAlt)

      if ctrl or alt then
        saved_scroll = ImGui.GetScrollY(ctx)
      end
    end

    -- Cache renderer config once per frame
    MidiRenderer.begin_frame(ctx, self.config, self.state)

    -- Call Grid with options and store result
    local result = Ark.Grid(ctx, self.midi_grid_opts)
    self.midi_grid_result_ref.current = result

    -- Add Dummy to extend child bounds (required when Grid uses SetCursorScreenPos)
    ImGui.Dummy(ctx, 0, 0)

    -- Handle badge clicks
    if self.midi_badge_click_handler then
      self.midi_badge_click_handler(ctx)
    end

    -- Render disable animations on top
    self:render_disable_animations(ctx)

    -- Restore scroll if we consumed wheel for resize
    if saved_scroll then
      ImGui.SetScrollY(ctx, saved_scroll)
    end
  end
  ImGui.EndChild(ctx)
end

-- Clear internal drag state from both grids
function Coordinator:clear_grid_drag_states()
  if self.audio_grid_result_ref and self.audio_grid_result_ref.current and self.audio_grid_result_ref.current.drag then
    self.audio_grid_result_ref.current.drag:release()
  end
  if self.midi_grid_result_ref and self.midi_grid_result_ref.current and self.midi_grid_result_ref.current.drag then
    self.midi_grid_result_ref.current.drag:release()
  end
end

return M
