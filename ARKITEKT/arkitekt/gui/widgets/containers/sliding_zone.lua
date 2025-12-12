-- @noindex
-- arkitekt/gui/widgets/containers/sliding_zone.lua
-- Reusable sliding zone/panel component with multi-track animation
-- Supports all 4 edges, hover zones, delayed retraction, and content callbacks
-- Uses existing Track system for consistent animation behavior

local ImGui = require('arkitekt.core.imgui')
local Base = require('arkitekt.gui.widgets.base')
local Tracks = require('arkitekt.gui.animation.tracks')
local Anim = require('arkitekt.config.animation')
local Math = require('arkitekt.core.math')
local Logger = require('arkitekt.debug.logger')
local Cursor = require('arkitekt.gui.interaction.cursor')

local M = {}

-- ============================================================================
-- DEFAULTS (uses library animation constants)
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = 'sliding_zone',

  -- Group coordination (for multiple zones)
  group = nil,              -- Group name - zones in same group coordinate
  exclusive = false,        -- If true, expanding this collapses others in group

  -- Edge positioning
  edge = 'right',           -- 'top', 'bottom', 'left', 'right'

  -- Bounds (required - defines the container area)
  bounds = nil,             -- {x, y, w, h} or {x1, y1, x2, y2}

  -- Size & Visibility
  size = 40,                -- Expanded panel width (left/right) or height (top/bottom)
  collapsed_ratio = 0.0,    -- Collapsed size as ratio of full size (0.0-1.0)
                            -- 0.0 = fully hidden, 0.08 = 8% visible (e.g., 12px of 150px)

  -- Animation
  fade_speed = 5.0,         -- Visibility fade in/out speed
  slide_speed = 6.0,        -- Slide animation speed (panel movement)
  expand_speed = 6.0,       -- Scale expansion speed (if expand_scale > 1.0)
  snap_epsilon = 0.001,     -- Threshold for considering animation settled

  -- Retract delays
  retract_delay = 0.3,      -- Base delay (used when directional_delay = false)
  directional_delay = false, -- Enable direction-aware retract delays
  retract_delay_toward = 1.0, -- Delay when cursor exits toward panel edge (longer)
  retract_delay_away = 0.1, -- Delay when cursor exits away from panel edge (shorter)

  -- Trigger Zone
  trigger_extension = 8,      -- Pixels beyond collapsed bar to extend trigger zone
                              -- Can be number (uniform) or table {up=100, down=20, left=8, right=8}
                              -- When collapsed_ratio=0 (fully hidden), this IS the trigger zone
                              -- When collapsed_ratio>0, this extends the visible collapsed bar
                              -- Directional extensions allow panels to respond to hover above/below/beside them

  trigger_extension_expanded = nil, -- Optional: Different trigger extension when expanded
                              -- If nil, uses trigger_extension for both states
                              -- If set, uses this when panel is expanded (is_expanded=true)
                              -- Useful for keeping panel open while hovering below it

  hover_padding = 30,         -- Y-axis padding for hover detection (advanced use)

  -- Custom Retraction
  retract_when = nil,         -- Optional: function(ctx, mx, my, state) -> boolean
                              -- Return true to force panel retraction
                              -- Use for custom close conditions (e.g., 'close when hovering below')

  -- Expansion on hover
  expand_scale = 1.0,       -- Scale multiplier on hover (1.3 = 30% bigger)

  -- Trigger mode
  trigger = 'hover',        -- 'hover', 'button', 'always'

  -- Style
  bg_color = nil,           -- Optional background color
  rounding = 0,             -- Corner rounding
  clip_content = true,      -- Clip content to bounds

  -- Content
  content_bounds = nil,     -- Optional: specific area for content (for hover calc)

  -- Window bounds (for reliable cursor tracking when cursor leaves window)
  window_bounds = nil,      -- {x, y, w, h} - if provided, enables 'exited toward edge' detection

  -- Callbacks
  draw = nil,               -- function(ctx, dl, bounds, visibility) - content drawing
  on_expand = nil,          -- function(state) - called when expanding
  on_collapse = nil,        -- function(state) - called when collapsing

  -- Draw list
  draw_list = nil,

  -- Debug
  debug_mouse_tracking = false,  -- Enable debug logging for mouse position tracking
}

-- ============================================================================
-- INSTANCE & GROUP MANAGEMENT
-- ============================================================================

local instances = Base.create_instance_registry()

-- Group registry: tracks which zone IDs belong to which group
-- groups[group_name] = { zone_id1 = true, zone_id2 = true, ... }
local groups = {}

local function register_in_group(group_name, zone_id)
  if not group_name then return end
  if not groups[group_name] then
    groups[group_name] = {}
  end
  groups[group_name][zone_id] = true
end

local function get_group_members(group_name)
  if not group_name or not groups[group_name] then return {} end
  local members = {}
  local registry = instances._instances or instances
  for zone_id in pairs(groups[group_name]) do
    if registry[zone_id] then
      members[zone_id] = registry[zone_id]
    end
  end
  return members
end

local function collapse_others_in_group(group_name, except_id)
  if not group_name then return end
  local members = get_group_members(group_name)
  for zone_id, state in pairs(members) do
    if zone_id ~= except_id and state.is_expanded then
      state.is_expanded = false
      state.is_in_hover_zone = false
      state.hover_leave_time = nil
    end
  end
end

local SlidingZone = {}
SlidingZone.__index = SlidingZone

function SlidingZone.new(id)
  local self = setmetatable({
    id = id,

    -- Animation tracks (using library Track class)
    -- Original used 0.15 lerp per frame @ 60fps
    -- With dt-based lerp: speed * 0.016 ≈ 0.15, so speed ≈ 9.0
    visibility_track = Tracks.Track.new(0, 9.0, true),
    slide_track = Tracks.Track.new(0, 9.0, true),
    scale_track = Tracks.Track.new(1.0, 9.0, true),

    -- State
    is_expanded = false,    -- For button trigger mode
    is_in_hover_zone = false,
    hover_leave_time = nil,

    -- Cursor tracking (for direction-aware retract)
    last_mouse_x = nil,
    last_mouse_y = nil,
    exit_direction = nil,   -- 'toward' or 'away'

    -- Window bounds tracking (for reliable edge detection)
    last_mouse_in_window = false,

    -- Reusable tables (avoid per-frame allocations)
    _trigger_ext = {},
    _trigger_ext_expanded = {},
    _content_bounds = {},
    _result = { expanded = false, visibility = 0, bounds = nil, hovered = false, settled = true },
  }, SlidingZone)

  return self
end

function SlidingZone:configure_speeds(opts)
  -- Allow per-instance speed overrides
  if opts.fade_speed then
    self.visibility_track:set_speed(opts.fade_speed)
  end
  if opts.slide_speed then
    self.slide_track:set_speed(opts.slide_speed)
  end
  if opts.expand_speed then
    self.scale_track:set_speed(opts.expand_speed)
  end
end

function SlidingZone:set_targets(visibility, slide, scale)
  self.visibility_track:to(visibility)
  self.slide_track:to(slide)
  self.scale_track:to(scale)
end

function SlidingZone:update(dt)
  self.visibility_track:update(dt)
  self.slide_track:update(dt)
  self.scale_track:update(dt)
end

function SlidingZone:get_values()
  return self.visibility_track:get(),
         self.slide_track:get(),
         self.scale_track:get()
end

function SlidingZone:is_settled(epsilon)
  epsilon = epsilon or 0.001
  return not self.visibility_track:is_animating(epsilon) and
         not self.slide_track:is_animating(epsilon) and
         not self.scale_track:is_animating(epsilon)
end

function SlidingZone:teleport(visibility, slide, scale)
  self.visibility_track:teleport(visibility)
  self.slide_track:teleport(slide)
  self.scale_track:teleport(scale)
end

-- ============================================================================
-- MOUSE POSITION TRACKING
-- ============================================================================

--- Get mouse position using reaper.GetMousePosition() for reliable tracking
--- even when cursor is outside the ImGui window.
--- Both reaper and ImGui use the same screen coordinate system (proven by drag_handler).
--- @param ctx ImGui_Context
--- @param opts table Options (for debug flag)
--- @return number mx Mouse X
--- @return number my Mouse Y
local function get_mouse_position(ctx, opts)
  local reaper_mx, reaper_my = nil, nil
  local imgui_mx, imgui_my = ImGui.GetMousePos(ctx)

  -- Use reaper.GetMousePosition() for reliable global tracking
  -- This works even when cursor is outside window (unlike ImGui.GetMousePos)
  if reaper.GetMousePosition then
    reaper_mx, reaper_my = reaper.GetMousePosition()
  end

  -- Debug logging to compare both methods
  if opts and opts.debug_mouse_tracking then
    if reaper_mx and reaper_my then
      local delta_x = reaper_mx - imgui_mx
      local delta_y = reaper_my - imgui_my
      local delta_mag = math.sqrt(delta_x * delta_x + delta_y * delta_y)

      -- Only log when there's a difference (to avoid spam)
      if delta_mag > 1 then
        Logger.debug('SlidingZone', 'Mouse pos: REAPER(%.1f, %.1f) vs ImGui(%.1f, %.1f) delta=%.1f',
          reaper_mx, reaper_my, imgui_mx, imgui_my, delta_mag)
      end
    else
      Logger.debug('SlidingZone', 'Mouse pos: ImGui(%.1f, %.1f) [reaper API N/A]', imgui_mx, imgui_my)
    end
  end

  -- Return REAPER position if available, otherwise ImGui
  if reaper_mx and reaper_my then
    return reaper_mx, reaper_my
  else
    return imgui_mx, imgui_my
  end
end

-- ============================================================================
-- EXIT DIRECTION CALCULATION
-- ============================================================================

--- Determine if cursor exit direction is 'toward' or 'away' from panel edge
--- @param edge string Panel edge ('left', 'right', 'top', 'bottom')
--- @param prev_x number Previous cursor X
--- @param prev_y number Previous cursor Y
--- @param curr_x number Current cursor X
--- @param curr_y number Current cursor Y
--- @return string 'toward' if moving toward edge, 'away' otherwise
local function calculate_exit_direction(edge, prev_x, prev_y, curr_x, curr_y)
  if not prev_x or not prev_y then
    return 'away'  -- Default to shorter delay if no previous position
  end

  local dx = curr_x - prev_x
  local dy = curr_y - prev_y

  -- Primary axis movement determines direction
  if edge == 'left' then
    -- Moving left (negative X) = toward left edge
    return dx < 0 and 'toward' or 'away'
  elseif edge == 'right' then
    -- Moving right (positive X) = toward right edge
    return dx > 0 and 'toward' or 'away'
  elseif edge == 'top' then
    -- Moving up (negative Y) = toward top edge
    return dy < 0 and 'toward' or 'away'
  else -- bottom
    -- Moving down (positive Y) = toward bottom edge
    return dy > 0 and 'toward' or 'away'
  end
end

-- ============================================================================
-- HOVER ZONE DETECTION
-- ============================================================================

local function is_in_hover_zone(ctx, opts, state, bounds)
  local mx, my = get_mouse_position(ctx, opts)  -- Pass opts for debug logging
  local edge = opts.edge or 'right'

  -- Get content bounds for hover calculation
  local content = opts.content_bounds or bounds

  -- Calculate hover zone based on edge
  local padding = opts.hover_padding or 30

  -- TRIGGER ZONE CALCULATION (with directional extensions)
  -- When collapsed: trigger at collapsed bar + directional extensions
  -- When expanded: trigger covers full panel + directional extensions

  local size = opts.size or DEFAULTS.size

  -- Use trigger_extension_expanded when panel is expanded, otherwise use trigger_extension
  local ext_to_use = opts.trigger_extension
  if state.is_expanded and opts.trigger_extension_expanded then
    ext_to_use = opts.trigger_extension_expanded
  end

  local ext = ext_to_use  -- Table {up, down, left, right}

  local in_zone = false
  local trigger_line = nil  -- For debug logging

  if edge == 'left' then
    -- Left edge: panel extends from left boundary
    local collapsed_ratio = opts.collapsed_ratio
    local collapsed_width = size * collapsed_ratio
    local panel_width = state.is_expanded and size or collapsed_width
    local base_trigger = panel_width + ext.right  -- Extension always applies

    -- X bounds: left edge + trigger threshold
    local x1 = bounds.x - ext.left  -- Extend left (outside panel)
    local x2 = bounds.x + base_trigger  -- Extend right (into content)
    trigger_line = x2

    -- Y bounds: panel height + up/down extensions
    local y1 = bounds.y - ext.up
    local y2 = bounds.y + bounds.h + ext.down

    in_zone = mx >= x1 and mx < x2 and my >= y1 and my <= y2

  elseif edge == 'right' then
    -- Right edge: panel extends from right boundary
    local collapsed_ratio = opts.collapsed_ratio
    local collapsed_width = size * collapsed_ratio
    local panel_width = state.is_expanded and size or collapsed_width
    local base_trigger = panel_width + ext.left  -- Extension always applies

    -- X bounds: right edge - trigger threshold
    local x1 = bounds.x + bounds.w - base_trigger  -- Extend left (into content)
    local x2 = bounds.x + bounds.w + ext.right  -- Extend right (outside panel)
    trigger_line = x1

    -- Y bounds: panel height + up/down extensions
    local y1 = bounds.y - ext.up
    local y2 = bounds.y + bounds.h + ext.down

    in_zone = mx > x1 and mx <= x2 and my >= y1 and my <= y2

  elseif edge == 'top' then
    -- Top edge: panel extends from top boundary
    local collapsed_ratio = opts.collapsed_ratio
    local collapsed_height = size * collapsed_ratio
    local panel_height = state.is_expanded and size or collapsed_height
    local base_trigger = panel_height + ext.down  -- Extension always applies

    -- Y bounds: top edge + trigger threshold
    local y1 = bounds.y - ext.up  -- Extend up (outside panel)
    local y2 = bounds.y + base_trigger  -- Extend down (into content)
    trigger_line = y2

    -- X bounds: panel width + left/right extensions
    local x1 = bounds.x - ext.left
    local x2 = bounds.x + bounds.w + ext.right

    in_zone = my >= y1 and my < y2 and mx >= x1 and mx <= x2

  else -- bottom
    -- Bottom edge: panel extends from bottom boundary
    local collapsed_ratio = opts.collapsed_ratio
    local collapsed_height = size * collapsed_ratio
    local panel_height = state.is_expanded and size or collapsed_height
    local base_trigger = panel_height + ext.up  -- Extension always applies

    -- Y bounds: bottom edge - trigger threshold
    local y1 = bounds.y + bounds.h - base_trigger  -- Extend up (into content)
    local y2 = bounds.y + bounds.h + ext.down  -- Extend down (outside panel)
    trigger_line = y1

    -- X bounds: panel width + left/right extensions
    local x1 = bounds.x - ext.left
    local x2 = bounds.x + bounds.w + ext.right

    in_zone = my > y1 and my <= y2 and mx >= x1 and mx <= x2
  end

  -- Debug logging for trigger zone
  if opts.debug_mouse_tracking then
    local state_str = state.is_expanded and 'expanded' or 'collapsed'
    local ext = opts.trigger_extension
    Logger.debug('SlidingZone', 'Trigger zone [%s edge, %s]: ext={%d,%d,%d,%d}, in_zone=%s',
      edge, state_str, ext.up or 0, ext.down or 0, ext.left or 0, ext.right or 0, tostring(in_zone))
  end

  return in_zone
end

-- DEAD CODE REMOVED: crossed_toward_edge() function
-- This function was never called and used the deprecated hover_extend_inside parameter
-- If fast cursor movement detection is needed in the future, implement it differently

--- Detect if cursor exited the window toward the panel edge (like Settings panel)
--- This is the most reliable detection - doesn't depend on exact cursor position outside window
--- @param opts table Widget options (needs window_bounds)
--- @param state table Instance state with last_mouse_in_window
--- @param bounds table Panel bounds
--- @param mx number Current mouse X
--- @param my number Current mouse Y
--- @param mouse_in_window boolean Is cursor currently in window
--- @return boolean True if cursor exited window toward the panel edge
local function exited_toward_edge(opts, state, bounds, mx, my, mouse_in_window)
  -- Requires window_bounds to be set
  if not opts.window_bounds then return false end

  local win = opts.window_bounds
  local edge = opts.edge or 'right'
  local content = opts.content_bounds or bounds
  local padding = opts.hover_padding or 30

  -- Check if cursor was in window last frame but not this frame
  if not state.last_mouse_in_window or mouse_in_window then
    return false
  end

  -- Cursor just left the window - check if it exited toward the panel edge
  if edge == 'left' then
    -- Left edge panel: trigger if cursor exited to the LEFT of window
    local exited_left = mx < win.x
    local in_y_range = my >= (content.y - padding) and my <= (content.y + content.h + padding)
    return exited_left and in_y_range

  elseif edge == 'right' then
    -- Right edge panel: trigger if cursor exited to the RIGHT of window
    local exited_right = mx > (win.x + win.w)
    local in_y_range = my >= (content.y - padding) and my <= (content.y + content.h + padding)
    return exited_right and in_y_range

  elseif edge == 'top' then
    -- Top edge panel: trigger if cursor exited ABOVE window
    local exited_top = my < win.y
    local in_x_range = mx >= (content.x - padding) and mx <= (content.x + content.w + padding)
    return exited_top and in_x_range

  else -- bottom
    -- Bottom edge panel: trigger if cursor exited BELOW window
    local exited_bottom = my > (win.y + win.h)
    local in_x_range = mx >= (content.x - padding) and mx <= (content.x + content.w + padding)
    return exited_bottom and in_x_range
  end
end

-- ============================================================================
-- BOUNDS CALCULATION
-- ============================================================================

local function normalize_bounds(bounds)
  -- Accept both {x, y, w, h} and {x1, y1, x2, y2} formats
  if bounds.w then
    return bounds
  elseif bounds[3] and bounds[4] then
    -- Array format {x1, y1, x2, y2}
    return {
      x = bounds[1],
      y = bounds[2],
      w = bounds[3] - bounds[1],
      h = bounds[4] - bounds[2]
    }
  end
  return bounds
end

local function calculate_content_bounds(opts, visibility, slide_offset, scale, out)
  local bounds = normalize_bounds(opts.bounds)
  local edge = opts.edge or 'right'
  local size = opts.size or 40

  -- Apply scale
  local scaled_size = size * scale

  -- Apply visibility to size
  local collapsed_ratio = opts.collapsed_ratio or 0
  local visible_size = scaled_size * math.max(collapsed_ratio, visibility)

  -- IMPORTANT: Couple slide_offset to visibility to prevent jitter
  local reveal_offset = opts._reveal_offset
  local coupled_slide = reveal_offset * visibility

  -- Reuse output table to avoid allocations
  out = out or {}

  if edge == 'left' then
    local base_x = bounds.x - reveal_offset
    out.x, out.y = base_x + coupled_slide, bounds.y
    out.w, out.h = visible_size, bounds.h

  elseif edge == 'right' then
    local base_x = bounds.x + bounds.w + reveal_offset - visible_size
    out.x, out.y = base_x - coupled_slide, bounds.y
    out.w, out.h = visible_size, bounds.h

  elseif edge == 'top' then
    local base_y = bounds.y - reveal_offset
    out.x, out.y = bounds.x, base_y + coupled_slide
    out.w, out.h = bounds.w, visible_size

  else -- bottom
    local base_y = bounds.y + bounds.h + reveal_offset - visible_size
    out.x, out.y = bounds.x, base_y - coupled_slide
    out.w, out.h = bounds.w, visible_size
  end

  return out
end

-- ============================================================================
-- CORNER FLAGS FOR POSITION
-- ============================================================================

local function get_corner_flags(edge)
  -- Round corners opposite to the edge
  if edge == 'top' then
    return 0xC  -- Bottom corners only
  elseif edge == 'bottom' then
    return 0x3  -- Top corners only
  elseif edge == 'left' then
    return 0xA  -- Right corners only
  else -- right
    return 0x5  -- Left corners only
  end
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function draw_background(dl, content_bounds, opts)
  if not opts.bg_color then return end

  local corner_flags = get_corner_flags(opts.edge or 'right')
  local rounding = opts.rounding or 0

  ImGui.DrawList_AddRectFilled(
    dl,
    content_bounds.x, content_bounds.y,
    content_bounds.x + content_bounds.w, content_bounds.y + content_bounds.h,
    opts.bg_color,
    rounding,
    corner_flags
  )
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Normalize trigger extension to directional table {up, down, left, right}
--- Reuses existing table if provided to avoid allocations
--- @param ext number|table|nil Input extension (number for uniform, table for directional)
--- @param default number Default value for missing directions
--- @param out table|nil Optional output table to reuse
--- @return table Normalized {up, down, left, right}
local function normalize_trigger_extension(ext, default, out)
  out = out or {}
  if type(ext) == 'number' then
    out.up, out.down, out.left, out.right = ext, ext, ext, ext
  elseif type(ext) == 'table' then
    out.up = ext.up or default
    out.down = ext.down or default
    out.left = ext.left or default
    out.right = ext.right or default
  else
    out.up, out.down, out.left, out.right = default, default, default, default
  end
  return out
end

--- Draw a sliding zone
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { expanded, visibility, bounds, hovered, settled }
function M.Draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Validate required opts
  if not opts.bounds then
    error('SlidingZone requires \'bounds\' option', 2)
  end

  -- Resolve unique ID and get instance early (need cached tables)
  local unique_id = Base.resolve_id(ctx, opts, 'sliding_zone')
  local state = Base.get_or_create_instance(instances, unique_id, SlidingZone.new, ctx)

  -- Normalize trigger extensions into cached tables (avoid allocations)
  local default_ext = DEFAULTS.trigger_extension
  opts.trigger_extension = normalize_trigger_extension(opts.trigger_extension, default_ext, state._trigger_ext)
  if opts.trigger_extension_expanded then
    opts.trigger_extension_expanded = normalize_trigger_extension(opts.trigger_extension_expanded, default_ext, state._trigger_ext_expanded)
  end

  -- Auto-calculate reveal offset from collapsed_ratio
  local size = opts.size or DEFAULTS.size
  local collapsed_ratio = opts.collapsed_ratio or DEFAULTS.collapsed_ratio
  local reveal_offset = size * (1 - collapsed_ratio)
  opts._reveal_offset = reveal_offset

  -- Register in group if specified (quick hash lookup, minimal overhead)
  register_in_group(opts.group, unique_id)

  -- Configure speeds (allows runtime changes)
  state:configure_speeds(opts)

  -- Get draw list and delta time
  local dl = Base.get_draw_list(ctx, opts)
  local dt = ImGui.GetDeltaTime(ctx)

  -- Normalize bounds
  local bounds = normalize_bounds(opts.bounds)

  -- Handle trigger modes
  local trigger = opts.trigger or 'hover'
  local current_time = ImGui.GetTime(ctx)
  local reveal_offset = opts._reveal_offset

  if trigger == 'always' then
    -- Always visible
    state:set_targets(1.0, reveal_offset, opts.expand_scale or 1.0)

  elseif trigger == 'hover' then
    -- Get current mouse position (using reaper API for reliability outside window)
    local mx, my = get_mouse_position(ctx)

    -- Calculate mouse_in_window if window_bounds provided
    local mouse_in_window = true  -- Default to true if no window bounds
    if opts.window_bounds then
      local win = opts.window_bounds
      mouse_in_window = mx >= win.x and mx <= (win.x + win.w) and
                        my >= win.y and my <= (win.y + win.h)
    end

    -- Check trigger zone (current position)
    local in_zone = is_in_hover_zone(ctx, opts, state, bounds)

    -- Fast movement detection: only check when collapsed and not already in zone
    -- This catches cases where mouse moves so fast it skips the trigger zone in one frame
    if not in_zone and not state.is_expanded and state.last_mouse_x and state.last_mouse_y then
      local crossed = Cursor.crossed_edge(
        opts.edge or 'right',
        state.last_mouse_x,
        state.last_mouse_y,
        mx, my,
        bounds,
        opts.hover_padding or 30,  -- Y padding
        opts.hover_padding or 30   -- X padding
      )
      if crossed then
        in_zone = true  -- Treat crossing as being in zone
      end
    end

    -- Check custom retract condition
    local force_retract = false
    if opts.retract_when and type(opts.retract_when) == 'function' then
      force_retract = opts.retract_when(ctx, mx, my, state)
    end

    if force_retract then
      -- Force retract immediately
      state:set_targets(0.0, 0.0, 1.0)
      state.hover_leave_time = nil
      state.is_in_hover_zone = false
      state.is_expanded = false

    elseif in_zone then
      -- Expand immediately
      state:set_targets(1.0, reveal_offset, opts.expand_scale or 1.0)
      state.hover_leave_time = nil
      state.is_in_hover_zone = true
      state.exit_direction = nil

      -- Fire expand callback on transition
      if not state.is_expanded then
        -- Collapse others in group if exclusive
        if opts.exclusive then
          collapse_others_in_group(opts.group, unique_id)
        end
        if opts.on_expand then
          opts.on_expand(state)
        end
      end
      state.is_expanded = true
    else
      -- Start delay timer when leaving
      if state.is_in_hover_zone and not state.hover_leave_time then
        state.hover_leave_time = current_time

        -- Calculate exit direction for directional delays
        if opts.directional_delay then
          state.exit_direction = calculate_exit_direction(
            opts.edge or 'right',
            state.last_mouse_x, state.last_mouse_y,
            mx, my
          )
        end
      end

      -- Determine delay based on direction
      local delay
      if opts.directional_delay and state.exit_direction then
        if state.exit_direction == 'toward' then
          delay = opts.retract_delay_toward or 1.0
        else
          delay = opts.retract_delay_away or 0.1
        end
      else
        delay = opts.retract_delay or 0.3
      end

      -- Check if delay has passed
      if state.hover_leave_time and (current_time - state.hover_leave_time) >= delay then
        -- Retract
        state:set_targets(collapsed_ratio, 0, 1.0)
        state.is_in_hover_zone = false
        state.hover_leave_time = nil
        state.exit_direction = nil

        -- Fire collapse callback on transition
        if state.is_expanded and opts.on_collapse then
          opts.on_collapse(state)
        end
        state.is_expanded = false
      end
    end

    -- Update cursor tracking
    state.last_mouse_x = mx
    state.last_mouse_y = my
    state.last_mouse_in_window = mouse_in_window

  elseif trigger == 'button' then
    -- Toggle state managed externally or via click
    if state.is_expanded then
      state:set_targets(1.0, reveal_offset, opts.expand_scale or 1.0)
    else
      state:set_targets(collapsed_ratio, 0, 1.0)
    end
  end

  -- Update animation tracks
  state:update(dt)

  -- Get current animation values
  local visibility, slide_offset, scale = state:get_values()

  -- Calculate content bounds (reuse cached table)
  local content_bounds = calculate_content_bounds(opts, visibility, slide_offset, scale, state._content_bounds)

  -- Check if completely hidden (skip drawing)
  local is_settled = state:is_settled(opts.snap_epsilon or 0.001)
  if visibility < 0.001 and slide_offset < 0.5 and is_settled then
    -- Reuse cached result table
    local result = state._result
    result.expanded = state.is_expanded
    result.visibility = visibility
    result.bounds = content_bounds
    result.hovered = false
    result.settled = true
    return result
  end

  -- Apply clipping if enabled
  if opts.clip_content then
    ImGui.DrawList_PushClipRect(dl, bounds.x, bounds.y, bounds.x + bounds.w, bounds.y + bounds.h, true)
  end

  -- Draw background
  draw_background(dl, content_bounds, opts)

  -- Call content draw callback
  if opts.draw then
    opts.draw(ctx, dl, content_bounds, visibility)
  end

  -- Pop clipping
  if opts.clip_content then
    ImGui.DrawList_PopClipRect(dl)
  end

  -- Check if mouse is over content bounds (reuse mx/my from hover check if available)
  local mx, my = state.last_mouse_x or 0, state.last_mouse_y or 0
  local is_hovered = mx >= content_bounds.x and mx <= content_bounds.x + content_bounds.w and
                     my >= content_bounds.y and my <= content_bounds.y + content_bounds.h

  -- Reuse cached result table
  local result = state._result
  result.expanded = state.is_expanded
  result.visibility = visibility
  result.bounds = content_bounds
  result.hovered = is_hovered
  result.settled = is_settled
  return result
end

--- Toggle expanded state (for button trigger mode)
--- @param ctx userdata ImGui context
--- @param opts table Widget options (must include id)
function M.toggle(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)
  local unique_id = Base.resolve_id(ctx, opts, 'sliding_zone')
  local state = Base.get_or_create_instance(instances, unique_id, SlidingZone.new, ctx)

  state.is_expanded = not state.is_expanded

  if state.is_expanded and opts.on_expand then
    opts.on_expand(state)
  elseif not state.is_expanded and opts.on_collapse then
    opts.on_collapse(state)
  end
end

--- Set expanded state (for button trigger mode)
--- @param ctx userdata ImGui context
--- @param opts table Widget options (must include id)
--- @param expanded boolean New expanded state
function M.set_expanded(ctx, opts, expanded)
  opts = Base.parse_opts(opts, DEFAULTS)
  local unique_id = Base.resolve_id(ctx, opts, 'sliding_zone')
  local state = Base.get_or_create_instance(instances, unique_id, SlidingZone.new, ctx)

  local was_expanded = state.is_expanded
  state.is_expanded = expanded

  if expanded and not was_expanded and opts.on_expand then
    opts.on_expand(state)
  elseif not expanded and was_expanded and opts.on_collapse then
    opts.on_collapse(state)
  end
end

--- Teleport to a state immediately (skip animation)
--- @param ctx userdata ImGui context
--- @param opts table Widget options (must include id)
--- @param expanded boolean Target expanded state
function M.teleport(ctx, opts, expanded)
  opts = Base.parse_opts(opts, DEFAULTS)
  local unique_id = Base.resolve_id(ctx, opts, 'sliding_zone')
  local state = Base.get_or_create_instance(instances, unique_id, SlidingZone.new, ctx)

  state.is_expanded = expanded

  -- Calculate reveal_offset (same as in Draw)
  local size = opts.size or DEFAULTS.size
  local collapsed_ratio = opts.collapsed_ratio or DEFAULTS.collapsed_ratio
  local reveal_offset = size * (1 - collapsed_ratio)

  if expanded then
    state:teleport(1.0, reveal_offset, opts.expand_scale or 1.0)
  else
    state:teleport(collapsed_ratio, 0, 1.0)
  end
end

--- Get current state (for external state inspection)
--- @param ctx userdata ImGui context
--- @param opts table Widget options (must include id)
--- @return table|nil State or nil if not created
function M.get_state(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)
  local unique_id = Base.resolve_id(ctx, opts, 'sliding_zone')
  local registry = instances._instances or instances
  return registry[unique_id]
end

--- Check if a sliding zone is settled (animations complete)
--- @param ctx userdata ImGui context
--- @param opts table Widget options (must include id)
--- @return boolean True if all animations are settled
function M.is_settled(ctx, opts)
  local state = M.get_state(ctx, opts)
  return state and state:is_settled() or true
end

-- ============================================================================
-- GROUP MANAGEMENT
-- ============================================================================

--- Collapse all zones in a group
--- @param group_name string Group name
function M.collapse_group(group_name)
  if not group_name then return end
  local members = get_group_members(group_name)
  for _, state in pairs(members) do
    state.is_expanded = false
    state.is_in_hover_zone = false
    state.hover_leave_time = nil
  end
end

--- Get all expanded zones in a group
--- @param group_name string Group name
--- @return table Array of zone IDs that are expanded
function M.get_expanded_in_group(group_name)
  if not group_name then return {} end
  local expanded = {}
  local members = get_group_members(group_name)
  for zone_id, state in pairs(members) do
    if state.is_expanded then
      expanded[#expanded + 1] = zone_id
    end
  end
  return expanded
end

--- Check if any zone in group is expanded
--- @param group_name string Group name
--- @return boolean True if any zone in group is expanded
function M.is_group_active(group_name)
  if not group_name then return false end
  local members = get_group_members(group_name)
  for _, state in pairs(members) do
    if state.is_expanded then
      return true
    end
  end
  return false
end

-- ============================================================================
-- CALLABLE PATTERN
-- ============================================================================

return setmetatable(M, {
  __call = function(_, ctx, opts)
    return M.Draw(ctx, opts)
  end
})
