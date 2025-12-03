-- @noindex
-- ItemPicker/ui/components/status.lua
-- Status bar showing selection info and tips

local ImGui = require('arkitekt.core.imgui')
local Constants = require('ItemPicker.config.constants')
local Strings = require('ItemPicker.config.strings')
local Defaults = require('ItemPicker.config.defaults')

local M = {}
local StatusBar = {}
StatusBar.__index = StatusBar

function M.new(config, state)
  local self = setmetatable({
    config = config,
    state = state,
  }, StatusBar)

  return self
end

function StatusBar:render(ctx)
  local avail_w = ImGui.GetContentRegionAvail(ctx)

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Calculate totals
  local total_audio = #(self.state.sample_indexes or {})
  local total_midi = #(self.state.midi_indexes or {})
  local selected_audio = self.state.audio_selection_count or 0
  local selected_midi = self.state.midi_selection_count or 0

  -- Calculate filtered counts (if filters are active)
  local filtered_audio = nil
  local filtered_midi = nil
  local cache = self.state.runtime_cache
  if cache then
    if cache.audio_filtered then
      filtered_audio = #cache.audio_filtered
    end
    if cache.midi_filtered then
      filtered_midi = #cache.midi_filtered
    end
  end

  -- Check if any filtering is active
  local is_filtered = (filtered_audio and filtered_audio ~= total_audio) or
                      (filtered_midi and filtered_midi ~= total_midi)

  -- Left side: Selection info, loading progress, and preview status
  local status_text = ''

  -- Loading status (highest priority)
  if self.state.is_loading then
    local progress = self.state.loading_progress or 0
    local percent = (progress * 100) // 1

    -- Animated spinner
    local spinner_chars = Strings.STATUS.spinner_chars
    local spinner_idx = math.floor((reaper.time_precise() * Defaults.ANIMATION.spinner_speed) % #spinner_chars) + 1
    local spinner = spinner_chars[spinner_idx]

    status_text = string.format(Strings.STATUS.loading_format,
      spinner, percent, total_audio, total_midi)

    -- Show loading color
    ImGui.TextColored(ctx, Constants.COLORS.LOADING, status_text)
  -- Preview status
  elseif self.state.previewing and self.state.previewing ~= 0 and self.state.preview_item then
    local take = reaper.GetActiveTake(self.state.preview_item)
    local item_name = take and reaper.GetTakeName(take) or 'Item'
    status_text = string.format(Strings.STATUS.preview_format, item_name)
    ImGui.Text(ctx, status_text)
  elseif selected_audio > 0 or selected_midi > 0 then
    local parts = {}
    if selected_audio > 0 then
      parts[#parts + 1] = string.format(Strings.STATUS.selection_audio, selected_audio)
    end
    if selected_midi > 0 then
      parts[#parts + 1] = string.format(Strings.STATUS.selection_midi, selected_midi)
    end
    status_text = string.format(Strings.STATUS.selection_combined, table.concat(parts, ', '))
    ImGui.Text(ctx, status_text)
  elseif is_filtered then
    -- Show filtered count when filters are active
    local visible_audio = filtered_audio or total_audio
    local visible_midi = filtered_midi or total_midi
    status_text = string.format('%d/%d audio, %d/%d midi visible',
      visible_audio, total_audio, visible_midi, total_midi)
    ImGui.TextColored(ctx, Constants.COLORS.HINT, status_text)
  else
    status_text = string.format(Strings.STATUS.items_format, total_audio, total_midi)
    ImGui.Text(ctx, status_text)
  end

  -- Right side: Keyboard shortcuts hint
  ImGui.SameLine(ctx)

  local hints = Strings.STATUS.hints
  local hints_w = ImGui.CalcTextSize(ctx, hints)
  ImGui.SetCursorPosX(ctx, avail_w - hints_w - 10)

  ImGui.TextColored(ctx, Constants.COLORS.HINT, hints)

  ImGui.Spacing(ctx)
end

return M
