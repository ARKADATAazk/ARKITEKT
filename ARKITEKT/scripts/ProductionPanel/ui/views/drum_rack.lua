-- @noindex
-- ProductionPanel/ui/views/drum_rack.lua
-- Drum rack view with 16 sample pads

local M = {}

-- DEPENDENCIES
local Ark = require('arkitekt')
local Defaults = require('scripts.ProductionPanel.config.defaults')
local ImGui = Ark.ImGui
local Colors = Ark.Colors
local Theme = require('arkitekt.core.theme')

-- MOCK DATA
local mock_pads = {
  { name = 'Kick', note = 36, color = Colors.Hexrgb('#D94A4A'), has_sample = true },
  { name = 'Snare', note = 38, color = Colors.Hexrgb('#D9884A'), has_sample = true },
  { name = 'Clap', note = 39, color = Colors.Hexrgb('#D9C84A'), has_sample = true },
  { name = 'Hat Closed', note = 42, color = Colors.Hexrgb('#88D94A'), has_sample = true },
  { name = 'Tom Low', note = 43, color = Colors.Hexrgb('#4AD988'), has_sample = false },
  { name = 'Hat Open', note = 46, color = Colors.Hexrgb('#4AD9D9'), has_sample = true },
  { name = 'Tom Mid', note = 47, color = Colors.Hexrgb('#4A88D9'), has_sample = false },
  { name = 'Tom High', note = 48, color = Colors.Hexrgb('#884AD9'), has_sample = false },
  { name = 'Crash', note = 49, color = Colors.Hexrgb('#D94AD9'), has_sample = true },
  { name = 'Ride', note = 51, color = Colors.Hexrgb('#D94A88'), has_sample = false },
  { name = '', note = 52, color = Colors.Hexrgb('#505050'), has_sample = false },
  { name = '', note = 53, color = Colors.Hexrgb('#505050'), has_sample = false },
  { name = '', note = 54, color = Colors.Hexrgb('#505050'), has_sample = false },
  { name = '', note = 55, color = Colors.Hexrgb('#505050'), has_sample = false },
  { name = '', note = 56, color = Colors.Hexrgb('#505050'), has_sample = false },
  { name = '', note = 57, color = Colors.Hexrgb('#505050'), has_sample = false },
}

-- STATE
local state = {
  pads = {},
  selected_pad = nil,
}

-- HELPER FUNCTIONS
local function adjust_brightness(color, factor)
  -- Extract RGBA
  local r = ((color >> 0) & 0xFF) / 255
  local g = ((color >> 8) & 0xFF) / 255
  local b = ((color >> 16) & 0xFF) / 255
  local a = ((color >> 24) & 0xFF) / 255

  -- Adjust brightness
  r = math.min(1, r * factor)
  g = math.min(1, g * factor)
  b = math.min(1, b * factor)

  -- Pack back to RGBA
  local ri = math.floor(r * 255 + 0.5)
  local gi = math.floor(g * 255 + 0.5)
  local bi = math.floor(b * 255 + 0.5)
  local ai = math.floor(a * 255 + 0.5)

  return (ai << 24) | (bi << 16) | (gi << 8) | ri
end

local function lerp_color(color1, color2, t)
  -- Extract RGBA from both colors
  local r1 = ((color1 >> 0) & 0xFF) / 255
  local g1 = ((color1 >> 8) & 0xFF) / 255
  local b1 = ((color1 >> 16) & 0xFF) / 255
  local a1 = ((color1 >> 24) & 0xFF) / 255

  local r2 = ((color2 >> 0) & 0xFF) / 255
  local g2 = ((color2 >> 8) & 0xFF) / 255
  local b2 = ((color2 >> 16) & 0xFF) / 255
  local a2 = ((color2 >> 24) & 0xFF) / 255

  -- Lerp each component
  local r = r1 + (r2 - r1) * t
  local g = g1 + (g2 - g1) * t
  local b = b1 + (b2 - b1) * t
  local a = a1 + (a2 - a1) * t

  -- Pack back to RGBA
  local ri = math.floor(r * 255 + 0.5)
  local gi = math.floor(g * 255 + 0.5)
  local bi = math.floor(b * 255 + 0.5)
  local ai = math.floor(a * 255 + 0.5)

  return (ai << 24) | (bi << 16) | (gi << 8) | ri
end

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

  -- Invisible button for interaction (must be first)
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, 'pad_' .. index, size, size)

  local hovered = ImGui.IsItemHovered(ctx)
  local clicked = ImGui.IsItemClicked(ctx, 0)
  local active = ImGui.IsItemActive(ctx)

  -- Determine colors based on state
  local bg_color, border_color, text_color

  if pad.has_sample then
    -- Use pad's custom color
    bg_color = pad.color

    -- Add brightness boost on hover/active
    if active then
      bg_color = adjust_brightness(bg_color, 1.3)
    elseif hovered then
      bg_color = adjust_brightness(bg_color, 1.15)
    end

    text_color = Theme.COLORS.TEXT_BRIGHT
  else
    -- Empty pad
    bg_color = hovered and Theme.COLORS.BG_HOVER or Theme.COLORS.BG_PANEL
    text_color = Theme.COLORS.TEXT_DARK
  end

  -- Border color
  if is_selected then
    border_color = Theme.COLORS.TEXT_BRIGHT
  elseif hovered then
    border_color = Theme.COLORS.BORDER_HOVER
  else
    border_color = Theme.COLORS.BORDER_INNER
  end

  -- Draw pad background
  local dl = ImGui.GetWindowDrawList(ctx)
  local rounding = 6

  -- Shadow (if pad has sample)
  if pad.has_sample and not active then
    local shadow_offset = 2
    local shadow_color = Colors.WithOpacity(Colors.Hexrgb('#000000'), 0.3)
    ImGui.DrawList_AddRectFilled(dl,
      x + shadow_offset, y + shadow_offset,
      x + size + shadow_offset, y + size + shadow_offset,
      shadow_color, rounding)
  end

  -- Main pad background with subtle gradient
  if pad.has_sample then
    -- Top-to-bottom gradient for depth
    local top_color = bg_color
    local bottom_color = adjust_brightness(bg_color, 0.85)

    -- Manual gradient (ImGui doesn't have native gradient, so we approximate)
    local steps = 4
    local step_height = size / steps
    for i = 0, steps - 1 do
      local t = i / steps
      local step_color = lerp_color(top_color, bottom_color, t)
      local y1 = y + (i * step_height)
      local y2 = y + ((i + 1) * step_height)

      -- Only round corners on first/last steps
      local step_rounding = 0
      if i == 0 then step_rounding = rounding end
      if i == steps - 1 then step_rounding = rounding end

      ImGui.DrawList_AddRectFilled(dl, x, y1, x + size, y2, step_color, step_rounding)
    end
  else
    -- Simple fill for empty pads
    ImGui.DrawList_AddRectFilled(dl, x, y, x + size, y + size, bg_color, rounding)
  end

  -- Border (thicker if selected)
  local border_thickness = is_selected and 3 or 1.5
  ImGui.DrawList_AddRect(dl, x, y, x + size, y + size, border_color, rounding, 0, border_thickness)

  -- Velocity indicator (subtle bar at bottom if has sample)
  if pad.has_sample then
    local bar_height = 4
    local bar_y = y + size - bar_height - 3
    local bar_width = (size - 6) * (pad.volume or 1.0)

    -- Background track
    ImGui.DrawList_AddRectFilled(dl,
      x + 3, bar_y,
      x + size - 3, bar_y + bar_height,
      Colors.WithOpacity(Colors.Hexrgb('#000000'), 0.3), 2)

    -- Volume level
    local vol_color = adjust_brightness(bg_color, 1.4)
    ImGui.DrawList_AddRectFilled(dl,
      x + 3, bar_y,
      x + 3 + bar_width, bar_y + bar_height,
      vol_color, 2)
  end

  -- Pad label (with shadow for better readability)
  if pad.name and pad.name ~= '' then
    local label_x = x + 8
    local label_y = y + 8

    -- Shadow
    ImGui.DrawList_AddText(dl, label_x + 1, label_y + 1,
      Colors.WithOpacity(Colors.Hexrgb('#000000'), 0.6), pad.name)

    -- Main text
    ImGui.DrawList_AddText(dl, label_x, label_y, text_color, pad.name)
  end

  -- MIDI note number (badge style)
  local note_text = tostring(pad.note)
  local note_w, note_h = ImGui.CalcTextSize(ctx, note_text)
  local badge_padding = 4
  local badge_x = x + size - note_w - badge_padding * 2 - 3
  local badge_y = y + 3
  local badge_w = note_w + badge_padding * 2
  local badge_h = note_h + badge_padding

  -- Note badge background
  local badge_bg = Colors.WithOpacity(Colors.Hexrgb('#000000'), 0.5)
  ImGui.DrawList_AddRectFilled(dl,
    badge_x, badge_y,
    badge_x + badge_w, badge_y + badge_h,
    badge_bg, 3)

  -- Note number text
  ImGui.DrawList_AddText(dl,
    badge_x + badge_padding, badge_y + badge_padding / 2,
    Colors.WithOpacity(text_color, 0.9), note_text)

  -- Handle interaction (button was drawn first)
  if clicked then
    state.selected_pad = index
    -- TODO: Trigger sample preview
  end

  -- Right-click menu
  if hovered and ImGui.IsMouseClicked(ctx, 1) then
    ImGui.OpenPopup(ctx, 'pad_menu_' .. index)
  end

  if ImGui.BeginPopup(ctx, 'pad_menu_' .. index) then
    if ImGui.MenuItem(ctx, 'Load Sample...') then
      -- TODO: Open sample browser
    end
    if ImGui.MenuItem(ctx, 'Clear Sample', nil, false, pad.has_sample) then
      pad.has_sample = false
      pad.name = ''
    end
    ImGui.Separator(ctx)
    if ImGui.MenuItem(ctx, 'Edit FX Chain...') then
      -- TODO: Open FX chain editor
    end
    ImGui.EndPopup(ctx)
  end

  -- Hover tooltip
  if hovered and pad.name ~= '' then
    ImGui.SetTooltip(ctx, string.format('%s (MIDI Note %d)', pad.name, pad.note))
  end
end

---Draw drum rack view
---@param ctx userdata ImGui context
function M.Draw(ctx)
  if #state.pads == 0 then
    M.init()
  end

  local pad_size = Defaults.DRUM_RACK.PAD_SIZE
  local spacing = Defaults.DRUM_RACK.PAD_SPACING
  local rows = Defaults.DRUM_RACK.ROWS
  local cols = Defaults.DRUM_RACK.COLS

  -- Header
  -- ImGui.PushFont(ctx, 'font_title' or 0)  -- Font API requires font object + size, disabled for now
  ImGui.Text(ctx, 'Drum Rack')
  -- ImGui.PopFont(ctx)

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Controls
  ImGui.Text(ctx, 'MIDI Input: All Channels')
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, '  |  ')
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, 'Load Kit...', 100, 0) then
    -- TODO: Load drum kit
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, 'Save Kit...', 100, 0) then
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
    ImGui.Text(ctx, string.format('Selected: Pad %d - %s (Note %d)',
      state.selected_pad, pad.name ~= '' and pad.name or 'Empty', pad.note))

    if pad.has_sample then
      ImGui.Spacing(ctx)
      ImGui.Text(ctx, 'Volume:')
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 200)
      local changed, new_vol = ImGui.SliderDouble(ctx, '##volume', pad.volume, 0.0, 1.0, '%.2f')
      if changed then
        pad.volume = new_vol
      end

      ImGui.SameLine(ctx)
      ImGui.Text(ctx, 'Pan:')
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 200)
      local changed_pan, new_pan = ImGui.SliderDouble(ctx, '##pan', pad.pan, 0.0, 1.0, '%.2f')
      if changed_pan then
        pad.pan = new_pan
      end
    end
  else
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, Theme.COLORS.TEXT_DARK)
    ImGui.Text(ctx, '📝 Mockup: Click a pad to select, right-click for options')
    ImGui.PopStyleColor(ctx)
  end
end

return M
