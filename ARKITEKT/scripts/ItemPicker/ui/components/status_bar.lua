-- @noindex
-- ItemPicker/ui/views/status_bar.lua
-- Status bar showing selection info and tips

local ImGui = require 'imgui' '0.10'
local Constants = require('ItemPicker.defs.constants')
local Strings = require('ItemPicker.defs.strings')
local Defaults = require('ItemPicker.defs.defaults')

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

  -- Left side: Selection info, loading progress, and preview status
  local status_text = ""

  -- Loading status (highest priority)
  if self.state.is_loading then
    local progress = self.state.loading_progress or 0
    local percent = math.floor(progress * 100)

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
    local item_name = take and reaper.GetTakeName(take) or "Item"
    status_text = string.format(Strings.STATUS.preview_format, item_name)
    ImGui.Text(ctx, status_text)
  elseif selected_audio > 0 or selected_midi > 0 then
    local parts = {}
    if selected_audio > 0 then
      table.insert(parts, string.format(Strings.STATUS.selection_audio, selected_audio))
    end
    if selected_midi > 0 then
      table.insert(parts, string.format(Strings.STATUS.selection_midi, selected_midi))
    end
    status_text = string.format(Strings.STATUS.selection_combined, table.concat(parts, ", "))
    ImGui.Text(ctx, status_text)
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
