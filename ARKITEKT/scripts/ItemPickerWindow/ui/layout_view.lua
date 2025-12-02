-- @noindex
-- ItemPickerWindow/ui/layout_view.lua
-- Simple layout view for window mode (like RegionPlaylist)

local ImGui = require('arkitekt.platform.imgui')
local Ark = require('arkitekt')
local max = math.max
local min = math.min

local M = {}

local LayoutView = {}
LayoutView.__index = LayoutView

function M.new(config, state)
  return setmetatable({
    config = config,
    state = state,
  }, LayoutView)
end

function LayoutView:draw(ctx, coordinator, shell_state)
  local layout_mode = self.state.settings.layout_mode or 'vertical'

  if layout_mode == 'horizontal' then
    self:draw_horizontal(ctx, coordinator, shell_state)
  else
    self:draw_vertical(ctx, coordinator, shell_state)
  end
end

function LayoutView:draw_vertical(ctx, coordinator, shell_state)
  local content_w, content_h = ImGui.GetContentRegionAvail(ctx)

  local separator_config = self.config.SEPARATOR or {
    gap = 8,
    thickness = 4,
  }
  local min_midi_height = 150
  local min_audio_height = 150
  local separator_gap = separator_config.gap or 8

  local min_total_height = min_midi_height + min_audio_height + separator_gap

  local midi_height, audio_height

  if content_h < min_total_height then
    local ratio = content_h / min_total_height
    midi_height = (min_midi_height * ratio) // 1
    audio_height = content_h - midi_height - separator_gap

    if midi_height < 50 then midi_height = 50 end
    if audio_height < 50 then audio_height = 50 end

    audio_height = max(1, content_h - midi_height - separator_gap)
  else
    midi_height = self.state.get_separator_position()
    midi_height = max(min_midi_height, min(midi_height, content_h - min_audio_height - separator_gap))
    audio_height = content_h - midi_height - separator_gap
  end

  midi_height = max(1, midi_height)
  audio_height = max(1, audio_height)

  local start_x, start_y = ImGui.GetCursorScreenPos(ctx)

  -- Draw MIDI panel
  coordinator:draw_midi(ctx, midi_height, shell_state)

  -- Draw separator
  local separator_y = start_y + midi_height + separator_gap / 2
  local sep_result = Ark.Splitter(ctx, {
    id = 'midi_audio_separator_h',
    x = start_x,
    y = separator_y,
    width = content_w,
    orientation = 'horizontal',
    thickness = separator_config.thickness or 4,
  })

  -- Block grid input during separator drag
  if coordinator.midi_grid then coordinator.midi_grid.block_all_input = sep_result.dragging end
  if coordinator.audio_grid then coordinator.audio_grid.block_all_input = sep_result.dragging end

  if sep_result.action == 'reset' then
    self.state.set_separator_position(self.config.SEPARATOR.default_midi_height or 250)
  elseif sep_result.action == 'drag' and content_h >= min_total_height then
    local new_midi_height = sep_result.position - start_y - separator_gap / 2
    new_midi_height = max(min_midi_height, min(new_midi_height, content_h - min_audio_height - separator_gap))
    self.state.set_separator_position(new_midi_height)
  end

  -- Position for Audio panel
  ImGui.SetCursorScreenPos(ctx, start_x, start_y + midi_height + separator_gap)

  -- Draw Audio panel
  coordinator:draw_audio(ctx, audio_height, shell_state)
end

function LayoutView:draw_horizontal(ctx, coordinator, shell_state)
  local content_w, content_h = ImGui.GetContentRegionAvail(ctx)

  local separator_config = self.config.SEPARATOR or {
    gap = 8,
    thickness = 4,
  }
  local min_midi_width = 200
  local min_audio_width = 200
  local separator_gap = separator_config.gap or 8

  local min_total_width = min_midi_width + min_audio_width + separator_gap

  local midi_width, audio_width

  if content_w < min_total_width then
    local ratio = content_w / min_total_width
    midi_width = (min_midi_width * ratio) // 1
    audio_width = content_w - midi_width - separator_gap

    if midi_width < 100 then midi_width = 100 end
    if audio_width < 100 then audio_width = 100 end

    audio_width = max(1, content_w - midi_width - separator_gap)
  else
    midi_width = self.state.settings.separator_position_horizontal or 400
    midi_width = max(min_midi_width, min(midi_width, content_w - min_audio_width - separator_gap))
    audio_width = content_w - midi_width - separator_gap
  end

  midi_width = max(1, midi_width)
  audio_width = max(1, audio_width)

  local start_x, start_y = ImGui.GetCursorScreenPos(ctx)

  -- Use child windows for side-by-side layout
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0)

  -- MIDI panel (left)
  if ImGui.BeginChild(ctx, '##left_column', midi_width, content_h, ImGui.ChildFlags_None, 0) then
    coordinator:draw_midi(ctx, content_h, shell_state)
  end
  ImGui.EndChild(ctx)

  ImGui.PopStyleVar(ctx)

  -- Draw vertical separator
  local separator_x = start_x + midi_width + separator_gap / 2
  local sep_result = Ark.Splitter(ctx, {
    id = 'midi_audio_separator_v',
    x = separator_x,
    y = start_y,
    height = content_h,
    orientation = 'vertical',
    thickness = separator_config.thickness or 4,
  })

  -- Block grid input during separator drag
  if coordinator.midi_grid then coordinator.midi_grid.block_all_input = sep_result.dragging end
  if coordinator.audio_grid then coordinator.audio_grid.block_all_input = sep_result.dragging end

  if sep_result.action == 'reset' then
    self.state.set_setting('separator_position_horizontal', 400)
  elseif sep_result.action == 'drag' and content_w >= min_total_width then
    local new_midi_width = sep_result.position - start_x - separator_gap / 2
    new_midi_width = max(min_midi_width, min(new_midi_width, content_w - min_audio_width - separator_gap))
    self.state.set_setting('separator_position_horizontal', new_midi_width)
  end

  -- Position for Audio panel (right)
  ImGui.SetCursorScreenPos(ctx, start_x + midi_width + separator_gap, start_y)

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0)

  -- Audio panel (right)
  if ImGui.BeginChild(ctx, '##right_column', audio_width, content_h, ImGui.ChildFlags_None, 0) then
    coordinator:draw_audio(ctx, content_h, shell_state)
  end
  ImGui.EndChild(ctx)

  ImGui.PopStyleVar(ctx)
end

return M
