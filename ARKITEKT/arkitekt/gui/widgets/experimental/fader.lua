-- @noindex
-- arkitekt/gui/widgets/experimental/fader.lua
-- EXPERIMENTAL: Vertical fader widget with dB scaling
-- Common in audio mixers - vertical slider with logarithmic (dB) scale

local ImGui = require('arkitekt.platform.imgui')
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Common dB scale ranges
local DB_RANGES = {
  mixer = { min = -60, max = 12, default = 0 },      -- Typical mixer channel
  master = { min = -60, max = 6, default = 0 },      -- Master fader
  send = { min = -100, max = 0, default = -100 },    -- Send/aux (off to 0dB)
}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = nil,
  label = "",

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  width = 30,
  height = 200,
  cap_height = 8,   -- Height of fader cap/handle

  -- Value (in dB)
  value = 0,
  min = -60,
  max = 12,
  default = 0,      -- Double-click reset value

  -- State
  disabled = false,
  scale_type = "db",  -- "db" or "linear"

  -- Style
  bg_color = nil,
  track_color = nil,
  fill_color = nil,
  cap_color = nil,
  cap_hover_color = nil,
  cap_active_color = nil,
  border_color = nil,
  scale_color = nil,
  label_color = nil,

  -- Display
  show_scale = true,     -- Show dB markings
  show_value = true,     -- Show numeric value
  show_label = true,     -- Show label below

  -- Callbacks
  on_change = nil,
  tooltip = nil,

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local fader_locks = {}  -- Prevents double-click interference with drag

-- ============================================================================
-- DB CONVERSION
-- ============================================================================

-- Convert linear (0-1) to dB
local function linear_to_db(linear, min_db, max_db)
  if linear <= 0 then return min_db end
  if linear >= 1 then return max_db end

  -- Logarithmic mapping
  local db_range = max_db - min_db
  return min_db + (math.log(linear) / math.log(10) * 20 + 60) * (db_range / 60)
end

-- Convert dB to linear (0-1) for positioning
local function db_to_linear(db, min_db, max_db)
  if db <= min_db then return 0 end
  if db >= max_db then return 1 end

  -- Inverse logarithmic mapping
  local db_range = max_db - min_db
  local normalized = (db - min_db) / db_range
  return math.pow(10, (normalized * 60 - 60) / 20)
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_fader_track(dl, x, y, w, h, opts)
  local bg_color = opts.bg_color or Theme.COLORS.BG_BASE
  local track_color = opts.track_color or Theme.COLORS.BG_HOVER
  local border_color = opts.border_color or Theme.COLORS.BORDER_OUTER

  -- Background track
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color)

  -- Track groove (centered, narrower)
  local groove_w = math.max(4, w / 3)
  local groove_x = x + (w - groove_w) / 2
  ImGui.DrawList_AddRectFilled(dl, groove_x, y, groove_x + groove_w, y + h, track_color)

  -- Border
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, border_color, 0, 0, 1)
end

local function render_fader_fill(dl, x, y, w, h, cap_y, cap_h, opts)
  local fill_color = opts.fill_color or Colors.with_opacity(Theme.COLORS.ACCENT_PRIMARY, 0.3)

  -- Fill from bottom to cap
  local fill_top = cap_y + cap_h / 2
  local fill_bottom = y + h
  local groove_w = math.max(4, w / 3)
  local groove_x = x + (w - groove_w) / 2

  if fill_bottom > fill_top then
    ImGui.DrawList_AddRectFilled(dl, groove_x, fill_top, groove_x + groove_w, fill_bottom, fill_color)
  end
end

local function render_fader_cap(dl, x, y, w, cap_y, cap_h, hovered, active, disabled, opts)
  local cap_color
  if disabled then
    cap_color = Colors.with_opacity(Colors.desaturate(opts.cap_color or Theme.COLORS.BG_ACTIVE, 0.5), 0.5)
  elseif active then
    cap_color = opts.cap_active_color or Colors.adjust_brightness(Theme.COLORS.BG_ACTIVE, 1.2)
  elseif hovered then
    cap_color = opts.cap_hover_color or Colors.adjust_brightness(Theme.COLORS.BG_ACTIVE, 1.1)
  else
    cap_color = opts.cap_color or Theme.COLORS.BG_ACTIVE
  end

  -- Shadow
  if not disabled then
    ImGui.DrawList_AddRectFilled(dl, x + 1, cap_y + 1, x + w + 1, cap_y + cap_h + 1,
      Colors.hexrgb("#00000050"), 2)
  end

  -- Cap body
  ImGui.DrawList_AddRectFilled(dl, x, cap_y, x + w, cap_y + cap_h, cap_color, 2)

  -- Border
  local border_color = Colors.adjust_brightness(cap_color, 0.7)
  ImGui.DrawList_AddRect(dl, x, cap_y, x + w, cap_y + cap_h, border_color, 2, 0, 1)

  -- Center line indicator
  local line_color = Colors.adjust_brightness(cap_color, 1.3)
  local line_y = cap_y + cap_h / 2
  ImGui.DrawList_AddLine(dl, x + 2, line_y, x + w - 2, line_y, line_color, 1)
end

local function render_scale(ctx, dl, x, y, w, h, min_db, max_db, opts)
  if not opts.show_scale then return end

  local scale_color = opts.scale_color or Theme.COLORS.TEXT_DIMMED
  local marks = {12, 6, 0, -6, -12, -18, -24, -36, -48, -60}

  for _, db in ipairs(marks) do
    if db >= min_db and db <= max_db then
      -- Convert dB to Y position
      local t = db_to_linear(db, min_db, max_db)
      local mark_y = y + (1 - t) * h

      -- Tick mark
      ImGui.DrawList_AddLine(dl, x - 3, mark_y, x, mark_y, scale_color, 1)

      -- Label (left of track)
      local label = tostring(db)
      local label_w = ImGui.CalcTextSize(ctx, label)
      ImGui.SetCursorScreenPos(ctx, x - label_w - 6, mark_y - 6)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, scale_color)
      ImGui.Text(ctx, label)
      ImGui.PopStyleColor(ctx)
    end
  end
end

local function render_value_display(ctx, x, y, w, value_db, opts)
  if not opts.show_value then return end

  local value_color = opts.label_color or Theme.COLORS.TEXT_NORMAL
  local value_text

  if value_db <= -90 then
    value_text = "-∞"
  else
    value_text = string.format("%.1f", value_db)
  end

  local text_w = ImGui.CalcTextSize(ctx, value_text)
  ImGui.SetCursorScreenPos(ctx, x + (w - text_w) / 2, y - 20)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, value_color)
  ImGui.Text(ctx, value_text)
  ImGui.PopStyleColor(ctx)
end

local function render_label(ctx, x, y, w, label, opts)
  if not opts.show_label or not label or label == "" then return 0 end

  local label_color = opts.label_color or Theme.COLORS.TEXT_NORMAL
  local label_w = ImGui.CalcTextSize(ctx, label)
  ImGui.SetCursorScreenPos(ctx, x + (w - label_w) / 2, y + 4)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, label_color)
  ImGui.Text(ctx, label)
  ImGui.PopStyleColor(ctx)

  return ImGui.GetTextLineHeight(ctx) + 4
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a fader widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { changed, value, width, height, hovered, active }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "fader")

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local w = opts.width or 30
  local h = opts.height or 200
  local cap_h = opts.cap_height or 8

  -- Get value range
  local min_db = opts.min or -60
  local max_db = opts.max or 12
  local default_db = opts.default or 0
  local value_db = Base.clamp(opts.value or default_db, min_db, max_db)

  -- State
  local disabled = opts.disabled or false
  local changed = false

  -- Render track
  render_fader_track(dl, x, y, w, h, opts)

  -- Render scale
  local scale_width = opts.show_scale and 30 or 0
  render_scale(ctx, dl, x, y, w, h, min_db, max_db, opts)

  -- Calculate cap position
  local t = db_to_linear(value_db, min_db, max_db)
  local cap_y = y + (1 - t) * (h - cap_h)

  -- Create invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, w, h)

  local hovered = not disabled and ImGui.IsItemHovered(ctx)
  local active = not disabled and ImGui.IsItemActive(ctx)

  -- Check for lock
  local now = ImGui.GetTime(ctx)
  local locked = (fader_locks[unique_id] or 0) > now

  -- Double-click to reset
  if hovered and not locked and ImGui.IsMouseDoubleClicked(ctx, 0) then
    value_db = default_db
    changed = true
    fader_locks[unique_id] = now + 0.3
  end

  -- Drag to adjust
  if not locked and active and not ImGui.IsMouseDoubleClicked(ctx, 0) then
    local _, my = ImGui.GetMousePos(ctx)
    my = Base.clamp(my, y, y + h)

    -- Convert Y position to linear (0-1)
    local linear = 1.0 - ((my - y) / h)

    -- Convert to dB
    local new_db = linear_to_db(linear, min_db, max_db)
    new_db = Base.clamp(new_db, min_db, max_db)

    if math.abs(new_db - value_db) > 0.1 then
      value_db = new_db
      changed = true
    end
  end

  -- Render fill
  render_fader_fill(dl, x, y, w, h, cap_y, cap_h, opts)

  -- Render cap
  render_fader_cap(dl, x, y, w, cap_y, cap_h, hovered, active, disabled, opts)

  -- Render value display
  render_value_display(ctx, x, y, w, value_db, opts)

  -- Render label
  local bottom_y = y + h
  local label_height = render_label(ctx, x, bottom_y, w, opts.label, opts)

  -- Tooltip
  if hovered or active then
    local tooltip_text
    if opts.tooltip then
      tooltip_text = opts.tooltip
    else
      if value_db <= -90 then
        tooltip_text = "-∞ dB"
      else
        tooltip_text = string.format("%.1f dB", value_db)
      end
    end

    if ImGui.BeginTooltip(ctx) then
      ImGui.Text(ctx, tooltip_text)
      ImGui.EndTooltip(ctx)
    end
  end

  -- Call change callback
  if changed and opts.on_change then
    opts.on_change(value_db)
  end

  -- Calculate total dimensions
  local value_height = opts.show_value and 20 or 0
  local total_height = value_height + h + label_height

  -- Advance cursor
  Base.advance_cursor(ctx, x, y - value_height, w + scale_width, total_height, opts.advance)

  -- Return standardized result
  return Base.create_result({
    changed = changed,
    value = value_db,
    width = w + scale_width,
    height = total_height,
    hovered = hovered,
    active = active,
  })
end

--- Convenience constructor for mixer channel fader
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result
function M.mixer(ctx, opts)
  opts = opts or {}
  local range = DB_RANGES.mixer
  opts.min = opts.min or range.min
  opts.max = opts.max or range.max
  opts.default = opts.default or range.default
  return M.draw(ctx, opts)
end

--- Convenience constructor for master fader
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result
function M.master(ctx, opts)
  opts = opts or {}
  local range = DB_RANGES.master
  opts.min = opts.min or range.min
  opts.max = opts.max or range.max
  opts.default = opts.default or range.default
  return M.draw(ctx, opts)
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.Fader(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
