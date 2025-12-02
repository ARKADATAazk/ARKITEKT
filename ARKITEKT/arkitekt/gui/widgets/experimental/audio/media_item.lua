-- @noindex
-- arkitekt/gui/widgets/experimental/audio/media_item.lua
-- EXPERIMENTAL: Media item tile widget - audio/MIDI representation
-- Extracted from ItemPicker tile renderer system
-- Complete media item display with header, waveform, badges, and states

local ImGui = require('arkitekt.platform.imgui')
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')
local Waveform = require('arkitekt.gui.widgets.experimental.audio.waveform')
local MIDIPianoRoll = require('arkitekt.gui.widgets.experimental.audio.midi_piano_roll')

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = nil,
  name = "Unnamed",

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  width = 200,
  height = 80,

  -- Data
  peaks = nil,          -- Waveform peak data (optional, for audio items)
  midi_notes = nil,     -- MIDI note data (optional, for MIDI items) - format: {{x1, y1, x2, y2}, ...}
  midi_cache_width = 400,   -- Width MIDI notes are normalized to
  midi_cache_height = 200,  -- Height MIDI notes are normalized to
  duration = 0,         -- Duration in seconds
  color = nil,          -- Item/track color
  pool_count = nil,     -- Number of pool instances (optional badge)

  -- State
  disabled = false,
  is_selected = false,
  is_muted = false,

  -- Style
  bg_color = nil,
  header_color = nil,
  waveform_color = nil,
  text_color = nil,
  border_color = nil,
  selection_color = nil,
  rounding = 4,

  -- Display
  is_waveform_filled = true,
  show_header = true,
  show_duration = true,
  show_pool_badge = true,
  header_height = 20,

  -- Callbacks
  on_click = nil,
  on_right_click = nil,
  on_double_click = nil,
  tooltip = nil,

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- RENDERING HELPERS
-- ============================================================================

local function render_base_tile(dl, x, y, w, h, color, rounding)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, color, rounding)
end

local function render_header(ctx, dl, x, y, w, h, name, text_color, header_color, rounding)
  -- Header background (semi-transparent)
  local header_alpha = Colors.opacity(header_color)
  if header_alpha > 0 then
    ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, header_color, rounding, ImGui.DrawFlags_RoundCornersTop)
  end

  -- Name text (truncated if too long)
  local padding = 4
  local available_width = w - padding * 2
  local name_text = Base.truncate_text(ctx, name, available_width)
  local text_w = ImGui.CalcTextSize(ctx, name_text)

  ImGui.SetCursorScreenPos(ctx, x + padding, y + (h - ImGui.GetTextLineHeight(ctx)) / 2)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
  ImGui.Text(ctx, name_text)
  ImGui.PopStyleColor(ctx)
end

local function render_duration_badge(ctx, dl, x, y, duration, text_color, bg_color)
  -- Format duration
  local minutes = duration // 60
  local seconds = duration % 60
  local duration_text = string.format("%d:%02d", minutes, seconds)

  local padding_x = 6
  local padding_y = 2
  local text_w = ImGui.CalcTextSize(ctx, duration_text)
  local badge_w = text_w + padding_x * 2
  local badge_h = ImGui.GetTextLineHeight(ctx) + padding_y * 2

  local badge_x = x - badge_w - 4
  local badge_y = y + 4

  -- Badge background
  ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x + badge_w, badge_y + badge_h, bg_color, 2)

  -- Badge text
  ImGui.SetCursorScreenPos(ctx, badge_x + padding_x, badge_y + padding_y)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
  ImGui.Text(ctx, duration_text)
  ImGui.PopStyleColor(ctx)

  return badge_w + 4, badge_h
end

local function render_pool_badge(ctx, dl, x, y, count, text_color, bg_color)
  local pool_text = string.format("×%d", count)

  local padding_x = 6
  local padding_y = 2
  local text_w = ImGui.CalcTextSize(ctx, pool_text)
  local badge_w = text_w + padding_x * 2
  local badge_h = ImGui.GetTextLineHeight(ctx) + padding_y * 2

  local badge_x = x - badge_w - 4
  local badge_y = y + 4

  -- Badge background
  ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x + badge_w, badge_y + badge_h, bg_color, 2)

  -- Badge text
  ImGui.SetCursorScreenPos(ctx, badge_x + padding_x, badge_y + padding_y)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
  ImGui.Text(ctx, pool_text)
  ImGui.PopStyleColor(ctx)

  return badge_w + 4, badge_h
end

local function render_selection_border(dl, x, y, w, h, color, rounding)
  -- Selection border (2px)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, color, rounding, 0, 2)
end

local function render_disabled_overlay(dl, x, y, w, h, rounding)
  -- Dark overlay for disabled items
  local overlay_color = Colors.with_opacity(Colors.hexrgb("#000000"), 0.5)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, overlay_color, rounding)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a media item widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { clicked, right_clicked, double_clicked, width, height, hovered, active }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "media_item")

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local w = opts.width or 200
  local h = opts.height or 80

  -- Get colors
  local base_color = opts.color or Theme.COLORS.ACCENT_PRIMARY
  local bg_color = opts.bg_color or base_color
  local text_color = opts.text_color or Theme.COLORS.TEXT_NORMAL
  local border_color = opts.border_color or Theme.COLORS.BORDER_OUTER
  local selection_color = opts.selection_color or Colors.adjust_brightness(base_color, 1.3)

  -- Header colors (semi-transparent)
  local header_color = opts.header_color or Colors.with_opacity(Colors.adjust_brightness(base_color, 0.7), 0.6)

  -- Waveform color (darkened for contrast)
  local waveform_color = opts.waveform_color
  if not waveform_color then
    local r, g, b = ImGui.ColorConvertU32ToDouble4(base_color)
    local h_hsv, s, v = ImGui.ColorConvertRGBtoHSV(r, g, b)
    s = s * 0.64
    v = v * 0.35
    r, g, b = ImGui.ColorConvertHSVtoRGB(h_hsv, s, v)
    waveform_color = Colors.components_to_rgba(r * 255, g * 255, b * 255, 255)
  end

  -- Render base tile
  render_base_tile(dl, x, y, w, h, bg_color, opts.rounding or 4)

  -- Calculate content area (below header if shown)
  local header_height = opts.show_header and (opts.header_height or 20) or 0
  local content_y = y + header_height
  local content_h = h - header_height

  -- Render visualization in content area (waveform or MIDI)
  if content_h > 10 then
    if opts.peaks then
      -- Audio: Render waveform
      Waveform.draw(ctx, {
        x = x,
        y = content_y,
        width = w,
        height = content_h,
        peaks = opts.peaks,
        color = waveform_color,
        is_filled = opts.is_waveform_filled,
        advance = "none",
        draw_list = dl,
      })
    elseif opts.midi_notes then
      -- MIDI: Render piano roll
      MIDIPianoRoll.draw(ctx, {
        x = x,
        y = content_y,
        width = w,
        height = content_h,
        notes = opts.midi_notes,
        cache_width = opts.midi_cache_width or 400,
        cache_height = opts.midi_cache_height or 200,
        color = waveform_color,  -- Use same color logic
        advance = "none",
        draw_list = dl,
      })
    end
  end

  -- Render header with name
  if opts.show_header and header_height > 0 then
    render_header(ctx, dl, x, y, w, header_height, opts.name, text_color, header_color, opts.rounding or 4)
  end

  -- Render badges (top-right corner)
  local badge_x = x + w
  local badge_y = y

  -- Duration badge
  if opts.show_duration and opts.duration > 0 then
    local badge_color = Colors.with_opacity(Colors.hexrgb("#000000"), 0.6)
    local badge_w, badge_h = render_duration_badge(ctx, dl, badge_x, badge_y, opts.duration, text_color, badge_color)
    badge_y = badge_y + badge_h + 2
  end

  -- Pool badge
  if opts.show_pool_badge and opts.pool_count and opts.pool_count > 1 then
    local badge_color = Colors.with_opacity(Theme.COLORS.ACCENT_SECONDARY or Colors.hexrgb("#FF9933"), 0.8)
    render_pool_badge(ctx, dl, badge_x, badge_y, opts.pool_count, text_color, badge_color)
  end

  -- Selection border
  if opts.is_selected then
    render_selection_border(dl, x, y, w, h, selection_color, opts.rounding or 4)
  end

  -- Disabled overlay
  if opts.disabled then
    render_disabled_overlay(dl, x, y, w, h, opts.rounding or 4)
  end

  -- Border
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_color, opts.rounding or 4, 0, 1)

  -- Create invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, w, h)

  local hovered = not opts.disabled and ImGui.IsItemHovered(ctx)
  local active = not opts.disabled and ImGui.IsItemActive(ctx)
  local clicked = not opts.disabled and ImGui.IsItemClicked(ctx, 0)
  local right_clicked = not opts.disabled and ImGui.IsItemClicked(ctx, 1)
  local double_clicked = not opts.disabled and ImGui.IsMouseDoubleClicked(ctx, 0) and hovered

  -- Callbacks
  if clicked and opts.on_click then
    opts.on_click()
  end

  if right_clicked and opts.on_right_click then
    opts.on_right_click()
  end

  if double_clicked and opts.on_double_click then
    opts.on_double_click()
  end

  -- Tooltip
  if hovered and opts.tooltip then
    if ImGui.BeginTooltip(ctx) then
      ImGui.Text(ctx, opts.tooltip)
      ImGui.EndTooltip(ctx)
    end
  end

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, w, h, opts.advance)

  -- Return standardized result
  return Base.create_result({
    clicked = clicked,
    right_clicked = right_clicked,
    double_clicked = double_clicked,
    width = w,
    height = h,
    hovered = hovered,
    active = active,
  })
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.MediaItem(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
