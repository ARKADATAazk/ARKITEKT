-- @noindex
-- arkitekt/gui/widgets/containers/sliding_zone.lua
-- Reusable sliding zone/panel component with multi-track animation
-- Supports all 4 edges, hover zones, delayed retraction, and content callbacks
-- Uses existing Track system for consistent animation behavior

local ImGui = require('arkitekt.platform.imgui')
local Base = require('arkitekt.gui.widgets.base')
local Tracks = require('arkitekt.gui.animation.tracks')
local Anim = require('arkitekt.core.animation')
local Math = require('arkitekt.core.math')
local Logger = require('arkitekt.debug.logger')

local M = {}

-- ============================================================================
-- DEFAULTS (uses library animation constants)
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = "sliding_zone",

  -- Group coordination (for multiple zones)
  group = nil,              -- Group name - zones in same group coordinate
  exclusive = false,        -- If true, expanding this collapses others in group

  -- Edge positioning
  edge = "right",           -- "top", "bottom", "left", "right"

  -- Bounds (required - defines the container area)
  bounds = nil,             -- {x, y, w, h} or {x1, y1, x2, y2}

  -- Size & Visibility
  size = 40,                -- Expanded panel width (left/right) or height (top/bottom)
  collapsed_ratio = 0.0,    -- Collapsed size as ratio of full size (0.0-1.0)
                            -- 0.0 = fully hidden, 0.08 = 8% visible (e.g., 12px of 150px)

  -- Deprecated (backward compat)
  min_visible = nil,        -- DEPRECATED: Use collapsed_ratio instead

  -- Animation
  fade_speed = 5.0,         -- Visibility fade in/out speed
  slide_speed = 6.0,        -- Slide animation speed (panel movement)
  expand_speed = 6.0,       -- Scale expansion speed (if expand_scale > 1.0)
  snap_epsilon = 0.001,     -- Threshold for considering animation settled

  -- Deprecated (backward compat)
  animation_speed = nil,    -- DEPRECATED: Use fade_speed instead
  scale_speed = nil,        -- DEPRECATED: Use expand_speed instead
  slide_distance = nil,     -- DEPRECATED: Auto-calculated from collapsed_ratio

  -- Retract delays
  retract_delay = 0.3,      -- Base delay (used when directional_delay = false)
  directional_delay = false, -- Enable direction-aware retract delays
  retract_delay_toward = 1.0, -- Delay when cursor exits toward panel edge (longer)
  retract_delay_away = 0.1, -- Delay when cursor exits away from panel edge (shorter)

  -- Trigger Zone
  trigger_extension = 8,      -- Pixels beyond collapsed bar to extend trigger zone
                              -- When collapsed_ratio=0 (fully hidden), this IS the trigger zone
                              -- When collapsed_ratio>0, this extends the visible collapsed bar

  -- Deprecated (backward compat)
  hover_extend_outside = nil, -- DEPRECATED: Use trigger_extension instead
  hover_extend_inside = nil,  -- DEPRECATED: Removed (dead code)
  hover_padding = 30,         -- Y-axis padding for hover detection (advanced use)

  -- Expansion on hover
  expand_scale = 1.0,       -- Scale multiplier on hover (1.3 = 30% bigger)

  -- Trigger mode
  trigger = "hover",        -- "hover", "button", "always"

  -- Style
  bg_color = nil,           -- Optional background color
  rounding = 0,             -- Corner rounding
  clip_content = true,      -- Clip content to bounds

  -- Content
  content_bounds = nil,     -- Optional: specific area for content (for hover calc)

  -- Window bounds (for reliable cursor tracking when cursor leaves window)
  window_bounds = nil,      -- {x, y, w, h} - if provided, enables "exited toward edge" detection

  -- Callbacks
  draw = nil,               -- function(ctx, dl, bounds, visibility) - NEW: preferred name
  on_draw = nil,            -- function(ctx, dl, bounds, visibility, state) - DEPRECATED: use 'draw'
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
    visibility_track = Tracks.Track.new(0, Anim.FADE_SPEED),
    slide_track = Tracks.Track.new(0, Anim.SMOOTH_SPEED),
    scale_track = Tracks.Track.new(1.0, Anim.SMOOTH_SPEED),

    -- State
    is_expanded = false,    -- For button trigger mode
    is_in_hover_zone = false,
    hover_leave_time = nil,

    -- Cursor tracking (for direction-aware retract)
    last_mouse_x = nil,
    last_mouse_y = nil,
    exit_direction = nil,   -- "toward" or "away"

    -- Window bounds tracking (for reliable edge detection)
    last_mouse_in_window = false,
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
        Logger.debug("SlidingZone", "Mouse pos: REAPER(%.1f, %.1f) vs ImGui(%.1f, %.1f) delta=%.1f",
          reaper_mx, reaper_my, imgui_mx, imgui_my, delta_mag)
      end
    else
      Logger.debug("SlidingZone", "Mouse pos: ImGui(%.1f, %.1f) [reaper API N/A]", imgui_mx, imgui_my)
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

--- Determine if cursor exit direction is "toward" or "away" from panel edge
--- @param edge string Panel edge ("left", "right", "top", "bottom")
--- @param prev_x number Previous cursor X
--- @param prev_y number Previous cursor Y
--- @param curr_x number Current cursor X
--- @param curr_y number Current cursor Y
--- @return string "toward" if moving toward edge, "away" otherwise
local function calculate_exit_direction(edge, prev_x, prev_y, curr_x, curr_y)
  if not prev_x or not prev_y then
    return "away"  -- Default to shorter delay if no previous position
  end

  local dx = curr_x - prev_x
  local dy = curr_y - prev_y

  -- Primary axis movement determines direction
  if edge == "left" then
    -- Moving left (negative X) = toward left edge
    return dx < 0 and "toward" or "away"
  elseif edge == "right" then
    -- Moving right (positive X) = toward right edge
    return dx > 0 and "toward" or "away"
  elseif edge == "top" then
    -- Moving up (negative Y) = toward top edge
    return dy < 0 and "toward" or "away"
  else -- bottom
    -- Moving down (positive Y) = toward bottom edge
    return dy > 0 and "toward" or "away"
  end
end

-- ============================================================================
-- HOVER ZONE DETECTION
-- ============================================================================

local function is_in_hover_zone(ctx, opts, state, bounds)
  local mx, my = get_mouse_position(ctx, opts)  -- Pass opts for debug logging
  local edge = opts.edge or "right"

  -- Get content bounds for hover calculation
  local content = opts.content_bounds or bounds

  -- Calculate hover zone based on edge
  local padding = opts.hover_padding or 30

  -- TRIGGER ZONE CALCULATION
  -- When collapsed: trigger only at the collapsed bar edge (narrow)
  -- When expanded: trigger covers the full expanded panel (wide)

  local trigger_threshold
  if state.is_expanded or state.is_in_hover_zone then
    -- Expanded: trigger covers the full panel size
    local size = opts.size or DEFAULTS.size
    trigger_threshold = size
  else
    -- Collapsed: trigger at the VISIBLE collapsed bar edge
    -- Calculate visible collapsed width (collapsed_ratio * size)
    local size = opts.size or DEFAULTS.size
    local collapsed_ratio = opts.collapsed_ratio
    local collapsed_width = size * collapsed_ratio

    -- Trigger zone = collapsed bar + extension for easier activation
    local extension = opts.trigger_extension
    trigger_threshold = collapsed_width + extension
  end

  local in_zone = false
  local trigger_line = nil  -- For debug logging

  -- Maximum distance outside bounds before trigger stops working
  -- Prevents triggering from another monitor
  local max_outside = opts.hover_extend_outside or 50

  if edge == "left" then
    -- Trigger zone: BETWEEN (bounds.x - max_outside) and (bounds.x + trigger_threshold)
    -- NOT infinite - stops at max_outside distance
    trigger_line = bounds.x + trigger_threshold
    local min_x = bounds.x - max_outside
    local zone_y1 = content.y - padding
    local zone_y2 = content.y + content.h + padding
    in_zone = mx >= min_x and mx < trigger_line and my >= zone_y1 and my <= zone_y2

  elseif edge == "right" then
    -- Trigger zone: BETWEEN (bounds.x + bounds.w - trigger_threshold) and (bounds.x + bounds.w + max_outside)
    trigger_line = bounds.x + bounds.w - trigger_threshold
    local max_x = bounds.x + bounds.w + max_outside
    local zone_y1 = content.y - padding
    local zone_y2 = content.y + content.h + padding
    in_zone = mx > trigger_line and mx <= max_x and my >= zone_y1 and my <= zone_y2

  elseif edge == "top" then
    -- Trigger zone: BETWEEN (bounds.y - max_outside) and (bounds.y + trigger_threshold)
    trigger_line = bounds.y + trigger_threshold
    local min_y = bounds.y - max_outside
    local zone_x1 = content.x - padding
    local zone_x2 = content.x + content.w + padding
    in_zone = my >= min_y and my < trigger_line and mx >= zone_x1 and mx <= zone_x2

  else -- bottom
    -- Trigger zone: BETWEEN (bounds.y + bounds.h - trigger_threshold) and (bounds.y + bounds.h + max_outside)
    trigger_line = bounds.y + bounds.h - trigger_threshold
    local max_y = bounds.y + bounds.h + max_outside
    local zone_x1 = content.x - padding
    local zone_x2 = content.x + content.w + padding
    in_zone = my > trigger_line and my <= max_y and mx >= zone_x1 and mx <= zone_x2
  end

  -- Debug logging for trigger zone
  if opts.debug_mouse_tracking then
    local state_str = state.is_expanded and "expanded" or "collapsed"
    Logger.debug("SlidingZone", "Trigger zone [%s edge, %s]: threshold=%.1f, trigger_line=%.1f, in_zone=%s",
      edge, state_str, trigger_threshold, trigger_line or 0, tostring(in_zone))
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
  local edge = opts.edge or "right"
  local content = opts.content_bounds or bounds
  local padding = opts.hover_padding or 30

  -- Check if cursor was in window last frame but not this frame
  if not state.last_mouse_in_window or mouse_in_window then
    return false
  end

  -- Cursor just left the window - check if it exited toward the panel edge
  if edge == "left" then
    -- Left edge panel: trigger if cursor exited to the LEFT of window
    local exited_left = mx < win.x
    local in_y_range = my >= (content.y - padding) and my <= (content.y + content.h + padding)
    return exited_left and in_y_range

  elseif edge == "right" then
    -- Right edge panel: trigger if cursor exited to the RIGHT of window
    local exited_right = mx > (win.x + win.w)
    local in_y_range = my >= (content.y - padding) and my <= (content.y + content.h + padding)
    return exited_right and in_y_range

  elseif edge == "top" then
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

local function calculate_content_bounds(opts, visibility, slide_offset, scale)
  local bounds = normalize_bounds(opts.bounds)
  local edge = opts.edge or "right"
  local size = opts.size or 40

  -- Apply scale
  local scaled_size = size * scale

  -- Apply visibility to size
  local visible_size = scaled_size * math.max(opts.collapsed_ratio or 0, visibility)

  if edge == "left" then
    -- Starts clipped outside left edge, slides right
    local reveal_offset = opts._reveal_offset
    local base_x = bounds.x - reveal_offset
    return {
      x = base_x + slide_offset,
      y = bounds.y,
      w = visible_size,
      h = bounds.h
    }

  elseif edge == "right" then
    -- Starts clipped outside right edge, slides left
    local reveal_offset = opts._reveal_offset
    local base_x = bounds.x + bounds.w + reveal_offset - visible_size
    return {
      x = base_x - slide_offset,
      y = bounds.y,
      w = visible_size,
      h = bounds.h
    }

  elseif edge == "top" then
    -- Starts clipped outside top edge, slides down
    local reveal_offset = opts._reveal_offset
    local base_y = bounds.y - reveal_offset
    return {
      x = bounds.x,
      y = base_y + slide_offset,
      w = bounds.w,
      h = visible_size
    }

  else -- bottom
    -- Starts clipped outside bottom edge, slides up
    local reveal_offset = opts._reveal_offset
    local base_y = bounds.y + bounds.h + reveal_offset - visible_size
    return {
      x = bounds.x,
      y = base_y - slide_offset,
      w = bounds.w,
      h = visible_size
    }
  end
end

-- ============================================================================
-- CORNER FLAGS FOR POSITION
-- ============================================================================

local function get_corner_flags(edge)
  -- Round corners opposite to the edge
  if edge == "top" then
    return 0xC  -- Bottom corners only
  elseif edge == "bottom" then
    return 0x3  -- Top corners only
  elseif edge == "left" then
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

  local corner_flags = get_corner_flags(opts.edge or "right")
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

--- Draw a sliding zone
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { expanded, visibility, bounds, hovered, settled }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- ============================================================================
  -- BACKWARD COMPATIBILITY SHIMS
  -- ============================================================================

  -- Callback rename: on_draw → draw
  opts.draw = opts.draw or opts.on_draw

  -- Parameter renames with fallbacks
  opts.collapsed_ratio = opts.collapsed_ratio or opts.min_visible or DEFAULTS.collapsed_ratio
  opts.trigger_extension = opts.trigger_extension or opts.hover_extend_outside or DEFAULTS.trigger_extension
  opts.fade_speed = opts.fade_speed or opts.animation_speed or DEFAULTS.fade_speed
  opts.expand_speed = opts.expand_speed or opts.scale_speed or DEFAULTS.expand_speed

  -- Auto-calculate reveal offset from collapsed_ratio
  -- Panel slides from collapsed size to full size during reveal
  local size = opts.size or DEFAULTS.size
  local collapsed_ratio = opts.collapsed_ratio
  local reveal_offset = opts.slide_distance or (size * (1 - collapsed_ratio))
  opts._reveal_offset = reveal_offset  -- Store calculated value

  -- Validate required opts
  if not opts.bounds then
    error("SlidingZone requires 'bounds' option", 2)
  end

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "sliding_zone")

  -- Get or create instance
  local state = Base.get_or_create_instance(instances, unique_id, SlidingZone.new, ctx)

  -- Register in group if specified
  register_in_group(opts.group, unique_id)

  -- Configure speeds (allows runtime changes)
  state:configure_speeds(opts)

  -- Get draw list and delta time
  local dl = Base.get_draw_list(ctx, opts)
  local dt = ImGui.GetDeltaTime(ctx)

  -- Normalize bounds
  local bounds = normalize_bounds(opts.bounds)

  -- Handle trigger modes
  local trigger = opts.trigger or "hover"
  local current_time = ImGui.GetTime(ctx)
  local reveal_offset = opts._reveal_offset

  if trigger == "always" then
    -- Always visible
    state:set_targets(1.0, reveal_offset, opts.expand_scale or 1.0)

  elseif trigger == "hover" then
    -- Get current mouse position (using reaper API for reliability outside window)
    local mx, my = get_mouse_position(ctx)

    -- Calculate mouse_in_window if window_bounds provided
    local mouse_in_window = true  -- Default to true if no window bounds
    if opts.window_bounds then
      local win = opts.window_bounds
      mouse_in_window = mx >= win.x and mx <= (win.x + win.w) and
                        my >= win.y and my <= (win.y + win.h)
    end

    -- Check massive trigger zone (like Settings panel's "everything ABOVE Y")
    -- No need for complex crossing detection - the massive zone catches everything
    local in_zone = is_in_hover_zone(ctx, opts, state, bounds)

    if in_zone then
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
            opts.edge or "right",
            state.last_mouse_x, state.last_mouse_y,
            mx, my
          )
        end
      end

      -- Determine delay based on direction
      local delay
      if opts.directional_delay and state.exit_direction then
        if state.exit_direction == "toward" then
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
        state:set_targets(opts.min_visible or 0.0, 0, 1.0)
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

  elseif trigger == "button" then
    -- Toggle state managed externally or via click
    if state.is_expanded then
      state:set_targets(1.0, reveal_offset, opts.expand_scale or 1.0)
    else
      state:set_targets(opts.min_visible or 0.0, 0, 1.0)
    end
  end

  -- Update animation tracks
  state:update(dt)

  -- Get current animation values
  local visibility, slide_offset, scale = state:get_values()

  -- Calculate content bounds
  local content_bounds = calculate_content_bounds(opts, visibility, slide_offset, scale)

  -- Check if completely hidden (skip drawing)
  local is_settled = state:is_settled(opts.snap_epsilon or 0.001)
  if visibility < 0.001 and slide_offset < 0.5 and is_settled then
    return {
      expanded = state.is_expanded,
      visibility = visibility,
      bounds = content_bounds,
      hovered = false,
      settled = true,
    }
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

  -- Check if mouse is over content bounds (using reaper API for reliability)
  local mx, my = get_mouse_position(ctx)
  local is_hovered = mx >= content_bounds.x and mx <= content_bounds.x + content_bounds.w and
                     my >= content_bounds.y and my <= content_bounds.y + content_bounds.h

  return {
    expanded = state.is_expanded,
    visibility = visibility,
    bounds = content_bounds,
    hovered = is_hovered,
    settled = is_settled,
  }
end

--- Toggle expanded state (for button trigger mode)
--- @param ctx userdata ImGui context
--- @param opts table Widget options (must include id)
function M.toggle(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)
  local unique_id = Base.resolve_id(ctx, opts, "sliding_zone")
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
  local unique_id = Base.resolve_id(ctx, opts, "sliding_zone")
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
  local unique_id = Base.resolve_id(ctx, opts, "sliding_zone")
  local state = Base.get_or_create_instance(instances, unique_id, SlidingZone.new, ctx)

  state.is_expanded = expanded
  local reveal_offset = opts._reveal_offset

  if expanded then
    state:teleport(1.0, reveal_offset, opts.expand_scale or 1.0)
  else
    state:teleport(opts.min_visible or 0.0, 0, 1.0)
  end
end

--- Get current state (for external state inspection)
--- @param ctx userdata ImGui context
--- @param opts table Widget options (must include id)
--- @return table|nil State or nil if not created
function M.get_state(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)
  local unique_id = Base.resolve_id(ctx, opts, "sliding_zone")
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

--- Clean up sliding zone instances
function M.cleanup()
  Base.cleanup_registry(instances)
  -- Also clear groups
  for k in pairs(groups) do
    groups[k] = nil
  end
end

-- ============================================================================
-- CALLABLE PATTERN
-- ============================================================================

return setmetatable(M, {
  __call = function(_, ctx, opts)
    return M.draw(ctx, opts)
  end
})
