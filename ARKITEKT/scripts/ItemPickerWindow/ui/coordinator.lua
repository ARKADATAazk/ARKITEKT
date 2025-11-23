-- @noindex
-- ItemPickerWindow/ui/coordinator.lua
-- Coordinator using TilesContainer panels for Audio and MIDI grids

local ImGui = require 'imgui' '0.10'
local TileAnim = require('arkitekt.gui.rendering.tile.animator')
local TilesContainer = require('arkitekt.gui.widgets.containers.panel')
local AudioGridFactory = require('ItemPicker.ui.grids.factories.audio_grid_factory')
local MidiGridFactory = require('ItemPicker.ui.grids.factories.midi_grid_factory')

local M = {}
local Coordinator = {}
Coordinator.__index = Coordinator

-- Get container config for Audio panel
local function get_audio_container_config(opts)
  return {
    title = "Audio Items",
    show_tabs = false,
    show_search = true,
    show_sort = true,
    header = {
      height = 36,
      padding = 8,
      bg_color = 0x1A1A1AFF,
      border_color = 0x2A2A2AFF,
    },
    sort_modes = {
      { id = "none", label = "None" },
      { id = "name", label = "Name" },
      { id = "length", label = "Length" },
      { id = "color", label = "Color" },
      { id = "pool", label = "Pool" },
    },
    on_search = opts.on_audio_search,
    on_sort = opts.on_audio_sort,
    on_sort_direction = opts.on_audio_sort_direction,
  }
end

-- Get container config for MIDI panel
local function get_midi_container_config(opts)
  return {
    title = "MIDI Items",
    show_tabs = false,
    show_search = true,
    show_sort = true,
    header = {
      height = 36,
      padding = 8,
      bg_color = 0x1A1A1AFF,
      border_color = 0x2A2A2AFF,
    },
    sort_modes = {
      { id = "none", label = "None" },
      { id = "name", label = "Name" },
      { id = "length", label = "Length" },
      { id = "color", label = "Color" },
      { id = "pool", label = "Pool" },
    },
    on_search = opts.on_midi_search,
    on_sort = opts.on_midi_sort,
    on_sort_direction = opts.on_midi_sort_direction,
  }
end

function M.new(ctx, config, state, visualization)
  local self = setmetatable({
    config = config,
    state = state,
    visualization = visualization,

    animator = nil,
    audio_grid = nil,
    midi_grid = nil,
    audio_container = nil,
    midi_container = nil,
  }, Coordinator)

  -- Create animator
  self.animator = TileAnim.new(12.0)

  -- Create grids using ItemPicker's factories
  self.audio_grid = AudioGridFactory.create(ctx, config, state, visualization, self.animator)
  self.midi_grid = MidiGridFactory.create(ctx, config, state, visualization, self.animator)

  -- Create TilesContainer for Audio panel
  self.audio_container = TilesContainer.new({
    id = "audio_tiles_container",
    config = get_audio_container_config({
      on_audio_search = function(text)
        state.set_search_filter(text)
      end,
      on_audio_sort = function(mode)
        state.set_setting('sort_mode', mode)
      end,
      on_audio_sort_direction = function(direction)
        state.set_setting('sort_reverse', direction == "desc")
      end,
    }),
  })

  -- Create TilesContainer for MIDI panel
  self.midi_container = TilesContainer.new({
    id = "midi_tiles_container",
    config = get_midi_container_config({
      on_midi_search = function(text)
        state.set_search_filter(text)
      end,
      on_midi_sort = function(mode)
        state.set_setting('sort_mode', mode)
      end,
      on_midi_sort_direction = function(direction)
        state.set_setting('sort_reverse', direction == "desc")
      end,
    }),
  })

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

function Coordinator:draw_audio(ctx, height, shell_state)
  if not self.audio_container then return end

  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Set container dimensions
  self.audio_container.width = avail_w
  self.audio_container.height = height

  -- Begin container draw (handles header, search, etc.)
  if not self.audio_container:begin_draw(ctx) then
    return
  end

  -- Draw the actual grid inside the container
  if self.audio_grid then
    self.audio_grid:draw(ctx)
  end

  -- End container draw
  self.audio_container:end_draw(ctx)
end

function Coordinator:draw_midi(ctx, height, shell_state)
  if not self.midi_container then return end

  local avail_w = ImGui.GetContentRegionAvail(ctx)

  -- Set container dimensions
  self.midi_container.width = avail_w
  self.midi_container.height = height

  -- Begin container draw (handles header, search, etc.)
  if not self.midi_container:begin_draw(ctx) then
    return
  end

  -- Draw the actual grid inside the container
  if self.midi_grid then
    self.midi_grid:draw(ctx)
  end

  -- End container draw
  self.midi_container:end_draw(ctx)
end

-- Clear internal drag state from both grids
function Coordinator:clear_grid_drag_states()
  if self.audio_grid and self.audio_grid.drag then
    self.audio_grid.drag:release()
  end
  if self.midi_grid and self.midi_grid.drag then
    self.midi_grid.drag:release()
  end
end

return M
