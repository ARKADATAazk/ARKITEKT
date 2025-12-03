-- @noindex
-- arkitekt/gui/widgets/experimental/step_sequencer.lua
-- EXPERIMENTAL: Step sequencer grid for pattern editing
-- Interactive grid where each cell represents a note/trigger at a time step

local ImGui = require('arkitekt.platform.imgui')
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Performance: Cache ImGui functions
local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled
local DrawList_AddRect = ImGui.DrawList_AddRect
local IsItemHovered = ImGui.IsItemHovered
local IsItemClicked = ImGui.IsItemClicked

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

  -- Grid configuration
  steps = 16,         -- Number of steps (columns)
  tracks = 4,         -- Number of tracks/lanes (rows)

  -- Data (2D array: pattern[track][step] = velocity (0-1, or nil/false for off))
  pattern = nil,

  -- Playback state
  current_step = nil,  -- Highlighted playback position (1-indexed, nil = none)

  -- State
  disabled = false,

  -- Style
  cell_spacing = 2,           -- Spacing between cells
  cell_rounding = 2,          -- Cell corner rounding

  -- Colors
  color_empty = nil,          -- Empty cell color
  color_filled = nil,         -- Filled cell color
  color_current = nil,        -- Current step indicator color
  color_hover = nil,          -- Hover state color
  bg_color = nil,             -- Background color (optional)
  grid_color = nil,           -- Grid line color (optional)

  -- Accent colors (for velocity visualization)
  is_velocity_colors = false,  -- Use velocity to modulate color
  color_accent_low = nil,      -- Low velocity color
  color_accent_high = nil,     -- High velocity color

  -- Labels
  track_labels = nil,         -- Array of track names (optional)
  show_step_numbers = false,  -- Show step numbers at top

  -- Interaction
  is_interactive = true,      -- Allow editing

  -- Callbacks
  on_change = nil,            -- function(track, step, velocity) - called when cell changes
  tooltip = nil,

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Get color for cell based on velocity
local function get_cell_color(velocity, opts)
  if not velocity or velocity <= 0 then
    return opts.color_empty or Colors.with_opacity(Theme.COLORS.BG_BASE, 0.3)
  end

  local base_color = opts.color_filled or Theme.COLORS.ACCENT_PRIMARY

  -- Velocity-based color modulation
  if opts.is_velocity_colors then
    local color_low = opts.color_accent_low or Colors.hexrgb("#4466FF")
    local color_high = opts.color_accent_high or Colors.hexrgb("#FF4466")
    return Colors.lerp_color(color_low, color_high, velocity)
  end

  -- Simple opacity modulation
  return Colors.with_opacity(base_color, 0.3 + velocity * 0.7)
end

--- Initialize empty pattern if needed
local function ensure_pattern(opts)
  if opts.pattern then return opts.pattern end

  local pattern = {}
  for track = 1, opts.tracks do
    pattern[track] = {}
    for step = 1, opts.steps do
      pattern[track][step] = false
    end
  end
  return pattern
end

-- ============================================================================
-- RENDERING
-- ============================================================================

--- Render step sequencer grid
local function render_grid(ctx, dl, x, y, w, h, pattern, opts, unique_id)
  local steps = opts.steps or 16
  local tracks = opts.tracks or 4
  local cell_spacing = opts.cell_spacing or 2
  local cell_rounding = opts.cell_rounding or 2

  -- Calculate cell dimensions
  local total_spacing_x = cell_spacing * (steps - 1)
  local total_spacing_y = cell_spacing * (tracks - 1)
  local cell_w = (w - total_spacing_x) / steps
  local cell_h = (h - total_spacing_y) / tracks

  local changed = false
  local changed_track, changed_step, changed_velocity

  -- Render background (optional)
  if opts.bg_color then
    DrawList_AddRectFilled(dl, x, y, x + w, y + h, opts.bg_color, 0)
  end

  -- Render cells
  for track = 1, tracks do
    for step = 1, steps do
      local cell_x = x + (step - 1) * (cell_w + cell_spacing)
      local cell_y = y + (track - 1) * (cell_h + cell_spacing)

      local velocity = pattern[track][step] or 0
      local is_active = velocity and velocity > 0

      -- Get cell color
      local cell_color = get_cell_color(velocity, opts)

      -- Highlight current step
      if opts.current_step == step then
        local current_color = opts.color_current or Colors.hexrgb("#FFFF44")
        cell_color = Colors.lerp_color(cell_color, current_color, 0.4)
      end

      -- Draw cell
      DrawList_AddRectFilled(dl, cell_x, cell_y, cell_x + cell_w, cell_y + cell_h, cell_color, cell_rounding)

      -- Interaction (if enabled)
      if opts.is_interactive and not opts.disabled then
        ImGui.SetCursorScreenPos(ctx, cell_x, cell_y)
        ImGui.InvisibleButton(ctx, "##cell_" .. unique_id .. "_" .. track .. "_" .. step, cell_w, cell_h)

        local hovered = IsItemHovered(ctx)

        -- Hover highlight
        if hovered then
          local hover_color = opts.color_hover or Colors.with_opacity(Theme.COLORS.TEXT_NORMAL, 0.2)
          DrawList_AddRect(dl, cell_x, cell_y, cell_x + cell_w, cell_y + cell_h, hover_color, cell_rounding, 0, 2)
        end

        -- Click to toggle
        if IsItemClicked(ctx, ImGui.MouseButton_Left) then
          -- Toggle: if off, set to full velocity; if on, turn off
          local new_velocity = is_active and 0 or 1
          pattern[track][step] = new_velocity

          changed = true
          changed_track = track
          changed_step = step
          changed_velocity = new_velocity
        end

        -- Right-click for velocity adjustment (if active)
        if is_active and IsItemClicked(ctx, ImGui.MouseButton_Right) then
          -- Cycle through velocity levels: 0.33, 0.66, 1.0
          local new_velocity
          if velocity >= 0.9 then
            new_velocity = 0.33
          elseif velocity >= 0.6 then
            new_velocity = 1.0
          else
            new_velocity = 0.66
          end

          pattern[track][step] = new_velocity

          changed = true
          changed_track = track
          changed_step = step
          changed_velocity = new_velocity
        end
      end
    end
  end

  -- Fire callback
  if changed and opts.on_change then
    opts.on_change(changed_track, changed_step, changed_velocity)
  end

  return changed
end

--- Render track labels (optional)
local function render_track_labels(ctx, x, y, h, tracks, labels)
  local track_h = h / tracks
  for track = 1, tracks do
    local label = labels[track] or ("Track " .. track)
    local label_y = y + (track - 1) * track_h + track_h / 2 - 8
    ImGui.SetCursorScreenPos(ctx, x, label_y)
    ImGui.Text(ctx, label)
  end
end

--- Render step numbers (optional)
local function render_step_numbers(ctx, x, y, w, steps)
  local step_w = w / steps
  for step = 1, steps do
    -- Show every 4th step number
    if step % 4 == 1 then
      local label_x = x + (step - 1) * step_w
      ImGui.SetCursorScreenPos(ctx, label_x, y - 15)
      ImGui.Text(ctx, tostring(step))
    end
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a step sequencer widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { changed, pattern, track, step, velocity, width, height }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "step_sequencer")

  -- Ensure pattern exists
  local pattern = ensure_pattern(opts)

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local w = opts.width or 400
  local h = opts.height or 200

  -- Optional: render step numbers
  if opts.show_step_numbers then
    render_step_numbers(ctx, x, y, w, opts.steps)
  end

  -- Optional: render track labels (to the left of grid)
  local label_width = 0
  if opts.track_labels then
    label_width = 60
    render_track_labels(ctx, x - label_width, y, h, opts.tracks, opts.track_labels)
  end

  -- Render grid
  local changed = render_grid(ctx, dl, x, y, w, h, pattern, opts, unique_id)

  -- Tooltip (global)
  if opts.tooltip then
    ImGui.SetCursorScreenPos(ctx, x, y)
    ImGui.InvisibleButton(ctx, "##" .. unique_id .. "_tooltip", w, h)
    if IsItemHovered(ctx) then
      if ImGui.BeginTooltip(ctx) then
        ImGui.Text(ctx, opts.tooltip)
        ImGui.EndTooltip(ctx)
      end
    end
  end

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, w, h, opts.advance)

  -- Return standardized result
  return Base.create_result({
    changed = changed,
    pattern = pattern,
    width = w,
    height = h,
  })
end

-- ============================================================================
-- CONVENIENCE CONSTRUCTORS
-- ============================================================================

--- Standard 16-step, 4-track sequencer
function M.standard(ctx, opts)
  opts = opts or {}
  opts.steps = 16
  opts.tracks = 4
  return M.draw(ctx, opts)
end

--- 8-step mini sequencer
function M.mini(ctx, opts)
  opts = opts or {}
  opts.steps = 8
  opts.tracks = 4
  opts.width = 200
  opts.height = 120
  return M.draw(ctx, opts)
end

--- 32-step extended sequencer
function M.extended(ctx, opts)
  opts = opts or {}
  opts.steps = 32
  opts.tracks = 8
  opts.width = 600
  opts.height = 240
  return M.draw(ctx, opts)
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.StepSequencer(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
