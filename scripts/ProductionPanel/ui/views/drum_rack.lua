-- @noindex
-- ProductionPanel/ui/views/drum_rack.lua
-- Drum rack view with 16 sample pads

local M = {}

-- DEPENDENCIES
local Defaults = require('scripts.ProductionPanel.defs.defaults')
local ImGui = require('imgui')('0.10')
local Colors = require('arkitekt.core.colors')
local Theme = require('arkitekt.core.theme')

-- MOCK DATA
local mock_pads = {
  { name = "Kick", note = 36, color = Colors.hexrgb("#D94A4A"), has_sample = true },
  { name = "Snare", note = 38, color = Colors.hexrgb("#D9884A"), has_sample = true },
  { name = "Clap", note = 39, color = Colors.hexrgb("#D9C84A"), has_sample = true },
  { name = "Hat Closed", note = 42, color = Colors.hexrgb("#88D94A"), has_sample = true },
  { name = "Tom Low", note = 43, color = Colors.hexrgb("#4AD988"), has_sample = false },
  { name = "Hat Open", note = 46, color = Colors.hexrgb("#4AD9D9"), has_sample = true },
  { name = "Tom Mid", note = 47, color = Colors.hexrgb("#4A88D9"), has_sample = false },
  { name = "Tom High", note = 48, color = Colors.hexrgb("#884AD9"), has_sample = false },
  { name = "Crash", note = 49, color = Colors.hexrgb("#D94AD9"), has_sample = true },
  { name = "Ride", note = 51, color = Colors.hexrgb("#D94A88"), has_sample = false },
  { name = "", note = 52, color = Colors.hexrgb("#505050"), has_sample = false },
  { name = "", note = 53, color = Colors.hexrgb("#505050"), has_sample = false },
  { name = "", note = 54, color = Colors.hexrgb("#505050"), has_sample = false },
  { name = "", note = 55, color = Colors.hexrgb("#505050"), has_sample = false },
  { name = "", note = 56, color = Colors.hexrgb("#505050"), has_sample = false },
  { name = "", note = 57, color = Colors.hexrgb("#505050"), has_sample = false },
}

-- STATE
local state = {
  pads = {},
  selected_pad = nil,
}

---Initialize drum rack
function M.init()
  for i = 1, Defaults.DRUM_RACK.PADS do
    state.pads[i] = {
      name = mock_pads[i].name,
      note = mock_pads[i].note,
      color = mock_pads[i].color,
      has_sample = mock_pads[i].has_sample,
      volume = 1.0,
      pan = 0.5,
    }
  end
end

---Draw a single drum pad
---@param ctx userdata ImGui context
---@param index number Pad index
---@param x number X position
---@param y number Y position
---@param size number Pad size
local function draw_pad(ctx, index, x, y, size)
  local pad = state.pads[index]
  if not pad then return end

  local is_selected = state.selected_pad == index

  -- Background color
  local bg_color = pad.has_sample and pad.color or Colors.hexrgb("#1A1A1A")
  local border_color = is_selected and Colors.hexrgb("#FFFFFF") or Colors.hexrgb("#303030")
  local text_color = pad.has_sample and Colors.hexrgb("#FFFFFF") or Colors.hexrgb("#606060")

  -- Draw pad background
  local dl = ImGui.GetWindowDrawList(ctx)
  local rounding = 4

  ImGui.DrawList_AddRectFilled(dl, x, y, x + size, y + size, bg_color, rounding)

  -- Border (thicker if selected)
  local border_thickness = is_selected and 2 or 1
  ImGui.DrawList_AddRect(dl, x, y, x + size, y + size, border_color, rounding, 0, border_thickness)

  -- Sample indicator (small dot in corner if has sample)
  if pad.has_sample then
    local dot_size = 6
    local dot_x = x + size - dot_size - 4
    local dot_y = y + 4
    ImGui.DrawList_AddCircleFilled(dl, dot_x + dot_size/2, dot_y + dot_size/2, dot_size/2,
      Colors.hexrgb("#FFFFFF"), 12)
  end

  -- Pad label
  if pad.name and pad.name ~= "" then
    local label_x = x + 8
    local label_y = y + 8
    ImGui.DrawList_AddText(dl, label_x, label_y, text_color, pad.name)
  end

  -- MIDI note number at bottom
  local note_text = tostring(pad.note)
  local note_w, note_h = ImGui.CalcTextSize(ctx, note_text)
  local note_x = x + size - note_w - 6
  local note_y = y + size - note_h - 6
  ImGui.DrawList_AddText(dl, note_x, note_y, Colors.with_opacity(text_color, 0.6), note_text)

  -- Invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "pad_" .. index, size, size)

  local hovered = ImGui.IsItemHovered(ctx)
  local clicked = ImGui.IsItemClicked(ctx, 0)

  if clicked then
    state.selected_pad = index
    -- TODO: Trigger sample
  end

  -- Right-click menu
  if hovered and ImGui.IsMouseClicked(ctx, 1) then
    ImGui.OpenPopup(ctx, "pad_menu_" .. index)
  end

  if ImGui.BeginPopup(ctx, "pad_menu_" .. index) then
    if ImGui.MenuItem(ctx, "Load Sample...") then
      -- TODO: Open sample browser
    end
    if ImGui.MenuItem(ctx, "Clear Sample", nil, false, pad.has_sample) then
      pad.has_sample = false
      pad.name = ""
    end
    ImGui.Separator(ctx)
    if ImGui.MenuItem(ctx, "Edit FX Chain...") then
      -- TODO: Open FX chain editor
    end
    ImGui.EndPopup(ctx)
  end

  -- Hover tooltip
  if hovered and pad.name ~= "" then
    ImGui.SetTooltip(ctx, string.format("%s (MIDI Note %d)", pad.name, pad.note))
  end
end

---Draw drum rack view
---@param ctx userdata ImGui context
function M.draw(ctx)
  if #state.pads == 0 then
    M.init()
  end

  local pad_size = Defaults.DRUM_RACK.PAD_SIZE
  local spacing = Defaults.DRUM_RACK.PAD_SPACING
  local rows = Defaults.DRUM_RACK.ROWS
  local cols = Defaults.DRUM_RACK.COLS

  -- Header
  ImGui.PushFont(ctx, "font_title" or 0)
  ImGui.Text(ctx, "Drum Rack")
  ImGui.PopFont(ctx)

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Controls
  ImGui.Text(ctx, "MIDI Input: All Channels")
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, "  |  ")
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Load Kit...", 100, 0) then
    -- TODO: Load drum kit
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Save Kit...", 100, 0) then
    -- TODO: Save drum kit
  end

  ImGui.Spacing(ctx)
  ImGui.Spacing(ctx)

  -- Pad grid
  local start_x, start_y = ImGui.GetCursorScreenPos(ctx)

  for row = 0, rows - 1 do
    for col = 0, cols - 1 do
      local index = (row * cols) + col + 1
      local x = start_x + col * (pad_size + spacing)
      local y = start_y + row * (pad_size + spacing)

      draw_pad(ctx, index, x, y, pad_size)
    end
  end

  -- Advance cursor past grid
  ImGui.SetCursorScreenPos(ctx, start_x, start_y + (rows * (pad_size + spacing)) + 20)

  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Selected pad info
  if state.selected_pad then
    local pad = state.pads[state.selected_pad]
    ImGui.Text(ctx, string.format("Selected: Pad %d - %s (Note %d)",
      state.selected_pad, pad.name ~= "" and pad.name or "Empty", pad.note))

    if pad.has_sample then
      ImGui.Spacing(ctx)
      ImGui.Text(ctx, "Volume:")
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 200)
      local changed, new_vol = ImGui.SliderDouble(ctx, "##volume", pad.volume, 0.0, 1.0, "%.2f")
      if changed then
        pad.volume = new_vol
      end

      ImGui.SameLine(ctx)
      ImGui.Text(ctx, "Pan:")
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 200)
      local changed_pan, new_pan = ImGui.SliderDouble(ctx, "##pan", pad.pan, 0.0, 1.0, "%.2f")
      if changed_pan then
        pad.pan = new_pan
      end
    end
  else
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, Colors.hexrgb("#808080"))
    ImGui.Text(ctx, "📝 Mockup: Click a pad to select, right-click for options")
    ImGui.PopStyleColor(ctx)
  end
end

return M
