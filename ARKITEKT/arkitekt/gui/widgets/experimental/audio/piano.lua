-- @noindex
-- arkitekt/gui/widgets/experimental/audio/piano.lua
-- EXPERIMENTAL: Piano keyboard widget for note input and visualization
-- Interactive or display-only piano keyboard with horizontal/vertical orientation

local ImGui = require('arkitekt.platform.imgui')
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Black key positions (which white keys have a black key to their right)
-- Pattern: C# D# _ F# G# A# _ (repeats every octave)
local BLACK_KEY_PATTERN = {
  [0] = true,  -- C -> C#
  [1] = true,  -- D -> D#
  [2] = false, -- E (no black key)
  [3] = true,  -- F -> F#
  [4] = true,  -- G -> G#
  [5] = true,  -- A -> A#
  [6] = false, -- B (no black key)
}

local NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = nil,

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Range
  start_note = 60,      -- Middle C (MIDI note number)
  num_octaves = 2,      -- Number of octaves to display
  end_note = nil,       -- Alternative: specify end note instead of num_octaves

  -- Size
  orientation = "horizontal",  -- "horizontal" or "vertical"
  white_key_width = 20,        -- Width of each white key (or height if vertical)
  white_key_height = 80,       -- Height of each white key (or width if vertical)
  black_key_width_ratio = 0.6, -- Black key width as ratio of white key width
  black_key_height_ratio = 0.6,-- Black key height as ratio of white key height

  -- State
  disabled = false,
  is_interactive = true,    -- If false, display-only (no click handling)
  is_scrollable = false,    -- If true, adds scrollbar when content exceeds size
  active_notes = {},        -- Table of currently active notes {[60] = true, [64] = true}

  -- Style
  white_key_color = nil,
  white_key_hover_color = nil,
  white_key_active_color = nil,
  black_key_color = nil,
  black_key_hover_color = nil,
  black_key_active_color = nil,
  border_color = nil,

  -- Callbacks
  on_note_press = nil,      -- function(note_number)
  on_note_release = nil,    -- function(note_number)
  tooltip = nil,

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function get_note_name(note_num)
  local octave = (note_num // 12) - 1
  local note_idx = note_num % 12
  return NOTE_NAMES[note_idx + 1] .. octave
end

local function is_black_key(note_num)
  local note_in_octave = note_num % 12
  return NOTE_NAMES[note_in_octave + 1]:find("#") ~= nil
end

local function get_white_key_index(note_num)
  -- Returns the index of this note among white keys only (0-indexed from C)
  local note_in_octave = note_num % 12
  local white_keys_before = 0

  if note_in_octave >= 1 then white_keys_before = white_keys_before + 1 end -- C
  if note_in_octave >= 2 then white_keys_before = white_keys_before + 1 end -- D
  if note_in_octave >= 4 then white_keys_before = white_keys_before + 1 end -- E
  if note_in_octave >= 5 then white_keys_before = white_keys_before + 1 end -- F
  if note_in_octave >= 7 then white_keys_before = white_keys_before + 1 end -- G
  if note_in_octave >= 9 then white_keys_before = white_keys_before + 1 end -- A
  if note_in_octave >= 11 then white_keys_before = white_keys_before + 1 end -- B

  local octaves = note_num // 12
  return octaves * 7 + white_keys_before
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_horizontal_piano(ctx, dl, x, y, notes, opts)
  local white_w = opts.white_key_width
  local white_h = opts.white_key_height
  local black_w = white_w * opts.black_key_width_ratio
  local black_h = white_h * opts.black_key_height_ratio

  local white_color = opts.white_key_color or Colors.hexrgb("#FFFFFF")
  local white_hover = opts.white_key_hover_color or Colors.hexrgb("#F0F0F0")
  local white_active = opts.white_key_active_color or Colors.hexrgb("#4A90D9")
  local black_color = opts.black_key_color or Colors.hexrgb("#000000")
  local black_hover = opts.black_key_hover_color or Colors.hexrgb("#333333")
  local black_active = opts.black_key_active_color or Colors.hexrgb("#2A6099")
  local border_color = opts.border_color or Colors.hexrgb("#000000")

  local result = {
    note_pressed = nil,
    note_released = nil,
    hovered_note = nil,
  }

  -- Get mouse position
  local mx, my = ImGui.GetMousePos(ctx)
  local is_mouse_down = ImGui.IsMouseDown(ctx, 0)

  -- Draw white keys first
  for i, note in ipairs(notes) do
    if not is_black_key(note) then
      local white_idx = get_white_key_index(note)
      local key_x = x + white_idx * white_w
      local key_y = y

      -- Determine color
      local is_active = opts.active_notes[note]
      local is_hovered = mx >= key_x and mx < key_x + white_w and
                         my >= key_y and my < key_y + white_h

      local color = white_color
      if is_active then
        color = white_active
      elseif is_hovered then
        color = white_hover
        result.hovered_note = note
      end

      -- Draw key
      ImGui.DrawList_AddRectFilled(dl, key_x, key_y, key_x + white_w, key_y + white_h, color)
      ImGui.DrawList_AddRect(dl, key_x, key_y, key_x + white_w, key_y + white_h, border_color, 0, 0, 1)

      -- Handle click
      if opts.is_interactive and not opts.disabled and is_hovered and is_mouse_down then
        if not opts.active_notes[note] then
          result.note_pressed = note
        end
      end
    end
  end

  -- Draw black keys on top
  for i, note in ipairs(notes) do
    if is_black_key(note) then
      -- Black keys are positioned between white keys
      local prev_note = note - 1
      local white_idx = get_white_key_index(prev_note)
      local key_x = x + white_idx * white_w + white_w - black_w / 2
      local key_y = y

      -- Determine color
      local is_active = opts.active_notes[note]
      local is_hovered = mx >= key_x and mx < key_x + black_w and
                         my >= key_y and my < key_y + black_h

      local color = black_color
      if is_active then
        color = black_active
      elseif is_hovered then
        color = black_hover
        result.hovered_note = note
      end

      -- Draw key
      ImGui.DrawList_AddRectFilled(dl, key_x, key_y, key_x + black_w, key_y + black_h, color)
      ImGui.DrawList_AddRect(dl, key_x, key_y, key_x + black_w, key_y + black_h, border_color, 0, 0, 1)

      -- Handle click
      if opts.is_interactive and not opts.disabled and is_hovered and is_mouse_down then
        if not opts.active_notes[note] then
          result.note_pressed = note
        end
      end
    end
  end

  return result
end

local function render_vertical_piano(ctx, dl, x, y, notes, opts)
  local white_w = opts.white_key_height  -- Swapped for vertical
  local white_h = opts.white_key_width
  local black_w = white_w * opts.black_key_width_ratio
  local black_h = white_h * opts.black_key_height_ratio

  local white_color = opts.white_key_color or Colors.hexrgb("#FFFFFF")
  local white_hover = opts.white_key_hover_color or Colors.hexrgb("#F0F0F0")
  local white_active = opts.white_key_active_color or Colors.hexrgb("#4A90D9")
  local black_color = opts.black_key_color or Colors.hexrgb("#000000")
  local black_hover = opts.black_key_hover_color or Colors.hexrgb("#333333")
  local black_active = opts.black_key_active_color or Colors.hexrgb("#2A6099")
  local border_color = opts.border_color or Colors.hexrgb("#000000")

  local result = {
    note_pressed = nil,
    note_released = nil,
    hovered_note = nil,
  }

  local mx, my = ImGui.GetMousePos(ctx)
  local is_mouse_down = ImGui.IsMouseDown(ctx, 0)

  -- Draw white keys first (going downward, highest note at top)
  for i = #notes, 1, -1 do
    local note = notes[i]
    if not is_black_key(note) then
      local white_idx = get_white_key_index(note)
      local key_x = x
      local key_y = y + white_idx * white_h

      local is_active = opts.active_notes[note]
      local is_hovered = mx >= key_x and mx < key_x + white_w and
                         my >= key_y and my < key_y + white_h

      local color = white_color
      if is_active then
        color = white_active
      elseif is_hovered then
        color = white_hover
        result.hovered_note = note
      end

      ImGui.DrawList_AddRectFilled(dl, key_x, key_y, key_x + white_w, key_y + white_h, color)
      ImGui.DrawList_AddRect(dl, key_x, key_y, key_x + white_w, key_y + white_h, border_color, 0, 0, 1)

      if opts.is_interactive and not opts.disabled and is_hovered and is_mouse_down then
        if not opts.active_notes[note] then
          result.note_pressed = note
        end
      end
    end
  end

  -- Draw black keys on top
  for i = #notes, 1, -1 do
    local note = notes[i]
    if is_black_key(note) then
      local prev_note = note - 1
      local white_idx = get_white_key_index(prev_note)
      local key_x = x
      local key_y = y + white_idx * white_h + white_h - black_h / 2

      local is_active = opts.active_notes[note]
      local is_hovered = mx >= key_x and mx < key_x + black_w and
                         my >= key_y and my < key_y + black_h

      local color = black_color
      if is_active then
        color = black_active
      elseif is_hovered then
        color = black_hover
        result.hovered_note = note
      end

      ImGui.DrawList_AddRectFilled(dl, key_x, key_y, key_x + black_w, key_y + black_h, color)
      ImGui.DrawList_AddRect(dl, key_x, key_y, key_x + black_w, key_y + black_h, border_color, 0, 0, 1)

      if opts.is_interactive and not opts.disabled and is_hovered and is_mouse_down then
        if not opts.active_notes[note] then
          result.note_pressed = note
        end
      end
    end
  end

  return result
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a piano keyboard widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { note_pressed, note_released, hovered_note, width, height }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "piano")

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Calculate note range
  local start_note = opts.start_note or 60
  local end_note = opts.end_note
  if not end_note then
    local num_octaves = opts.num_octaves or 2
    end_note = start_note + (num_octaves * 12) - 1
  end

  -- Generate note list
  local notes = {}
  for note = start_note, end_note do
    notes[#notes + 1] = note
  end

  -- Calculate dimensions
  local white_key_count = 0
  for _, note in ipairs(notes) do
    if not is_black_key(note) then
      white_key_count = white_key_count + 1
    end
  end

  local w, h
  if opts.orientation == "vertical" then
    w = opts.white_key_height
    h = white_key_count * opts.white_key_width
  else
    w = white_key_count * opts.white_key_width
    h = opts.white_key_height
  end

  -- Render piano
  local render_result
  if opts.orientation == "vertical" then
    render_result = render_vertical_piano(ctx, dl, x, y, notes, opts)
  else
    render_result = render_horizontal_piano(ctx, dl, x, y, notes, opts)
  end

  -- Create invisible button for overall interaction area
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, w, h)
  local hovered = ImGui.IsItemHovered(ctx)

  -- Callbacks
  if render_result.note_pressed and opts.on_note_press then
    opts.on_note_press(render_result.note_pressed)
  end

  -- Tooltip
  if hovered and render_result.hovered_note then
    local note_name = get_note_name(render_result.hovered_note)
    local tooltip_text = opts.tooltip or note_name

    if ImGui.BeginTooltip(ctx) then
      ImGui.Text(ctx, tooltip_text)
      ImGui.EndTooltip(ctx)
    end
  end

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, w, h, opts.advance)

  -- Return standardized result
  return Base.create_result({
    note_pressed = render_result.note_pressed,
    note_released = render_result.note_released,
    hovered_note = render_result.hovered_note,
    width = w,
    height = h,
    hovered = hovered,
  })
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.Piano(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
