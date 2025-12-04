-- @noindex
-- arkitekt/gui/widgets/experimental/audio/midi_piano_roll.lua
-- EXPERIMENTAL: MIDI piano roll visualization from note data
-- Extracted from ItemPicker MIDI visualization system
-- Displays MIDI notes as rectangles (piano roll view)

local ImGui = require('arkitekt.core.imgui')
local Theme = require('arkitekt.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Default cache resolution (coordinates are normalized to this, then scaled)
local DEFAULT_CACHE_WIDTH = 400
local DEFAULT_CACHE_HEIGHT = 200

-- Minimum note size (pixels) - smaller notes are culled for performance
local MIN_NOTE_WIDTH = 1.0
local MIN_NOTE_HEIGHT = 1.0

-- Performance: Cache ImGui functions
local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled
local DrawList_PushClipRect = ImGui.DrawList_PushClipRect
local DrawList_PopClipRect = ImGui.DrawList_PopClipRect

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = nil,

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size
  width = 400,
  height = 200,

  -- Data
  notes = nil,          -- MIDI note data array (required) - format: {{x1, y1, x2, y2}, ...}
  cache_width = 400,    -- Width notes are normalized to
  cache_height = 200,   -- Height notes are normalized to

  -- State
  disabled = false,

  -- Style
  color = nil,          -- Note color
  bg_color = nil,       -- Background color (optional)

  -- Performance
  is_culling_enabled = true,  -- Skip notes below MIN_NOTE_WIDTH/HEIGHT

  -- Callbacks
  tooltip = nil,

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- RENDERING
-- ============================================================================

--- Render MIDI piano roll with LOD culling
local function render_piano_roll(dl, x, y, w, h, notes, cache_w, cache_h, color, is_culling)
  -- Push clip rect to prevent notes from overflowing bounds
  DrawList_PushClipRect(dl, x, y, x + w, y + h, true)

  -- Calculate scale factors from cache resolution to display resolution
  local scale_x = w / cache_w
  local scale_y = h / cache_h

  -- LOD: Calculate minimum note size thresholds in cache coordinates
  local min_width_cache = is_culling and (MIN_NOTE_WIDTH / scale_x) or 0
  local min_height_cache = is_culling and (MIN_NOTE_HEIGHT / scale_y) or 0

  -- Render notes (indexed loop for performance)
  local num_notes = #notes
  for i = 1, num_notes do
    local note = notes[i]

    -- LOD: Skip notes that are too small to see
    local note_w = note.x2 - note.x1
    local note_h = note.y2 - note.y1

    if note_w >= min_width_cache and note_h >= min_height_cache then
      -- Scale note coordinates from cache resolution to display resolution
      local note_x1 = x + (note.x1 * scale_x)
      local note_x2 = x + (note.x2 * scale_x)
      local note_y1 = y + (note.y1 * scale_y)
      local note_y2 = y + (note.y2 * scale_y)

      DrawList_AddRectFilled(dl, note_x1, note_y1, note_x2, note_y2, color)
    end
  end

  -- Pop clip rect
  DrawList_PopClipRect(dl)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a MIDI piano roll widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { width, height, hovered }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "midi_piano_roll")

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local w = opts.width or 400
  local h = opts.height or 200

  -- Validate note data
  local notes = opts.notes
  if not notes or #notes == 0 then
    -- No data - draw placeholder
    local bg_color = Colors.WithOpacity(Theme.COLORS.BG_BASE, 0.3)
    ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color)

    -- Advance cursor
    Base.advance_cursor(ctx, x, y, w, h, opts.advance)

    return Base.create_result({
      width = w,
      height = h,
      hovered = false,
    })
  end

  -- Background (optional)
  if opts.bg_color then
    ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, opts.bg_color)
  end

  -- Get cache dimensions
  local cache_w = opts.cache_width or DEFAULT_CACHE_WIDTH
  local cache_h = opts.cache_height or DEFAULT_CACHE_HEIGHT

  -- Get color
  local color = opts.color or Theme.COLORS.ACCENT_PRIMARY

  -- Render piano roll
  render_piano_roll(dl, x, y, w, h, notes, cache_w, cache_h, color, opts.is_culling_enabled)

  -- Create invisible button for interaction/tooltip
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, w, h)
  local hovered = ImGui.IsItemHovered(ctx)

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
    width = w,
    height = h,
    hovered = hovered,
  })
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.MIDIPianoRoll(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
