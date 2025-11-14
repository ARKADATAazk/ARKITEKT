-- @noindex
-- ItemPicker/ui/views/status_bar.lua
-- Status bar showing selection info and tips

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local hexrgb = Colors.hexrgb

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

  -- Left side: Selection info
  local status_text = ""

  if selected_audio > 0 or selected_midi > 0 then
    local parts = {}
    if selected_audio > 0 then
      table.insert(parts, string.format("%d Audio", selected_audio))
    end
    if selected_midi > 0 then
      table.insert(parts, string.format("%d MIDI", selected_midi))
    end
    status_text = string.format("Selected: %s", table.concat(parts, ", "))
  else
    status_text = string.format("Items: %d Audio, %d MIDI", total_audio, total_midi)
  end

  ImGui.Text(ctx, status_text)

  -- Right side: Keyboard shortcuts hint
  ImGui.SameLine(ctx)

  local hints = "Ctrl+F: Search | Right-click: Toggle | Delete: Disable | Alt+Click: Quick Disable"
  local hints_w = ImGui.CalcTextSize(ctx, hints)
  ImGui.SetCursorPosX(ctx, avail_w - hints_w - 10)

  local hint_color = hexrgb("#888888")
  ImGui.TextColored(ctx, hint_color, hints)

  ImGui.Spacing(ctx)
end

return M
