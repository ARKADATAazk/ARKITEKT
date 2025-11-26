-- @noindex
-- arkitekt/gui/widgets/containers/sliding_zone.lua
-- Reusable sliding zone/panel component with multi-track animation
-- Supports all 4 edges, hover zones, delayed retraction, and content callbacks
-- Uses existing Track system for consistent animation behavior

local ImGui = require('arkitekt.core.imgui')
local Base = require('arkitekt.gui.widgets.base')
local Tracks = require('arkitekt.gui.fx.animation.tracks')
local Anim = require('arkitekt.core.animation')
local Math = require('arkitekt.core.math')

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

  -- Size
  size = 40,                -- Width (for left/right) or height (for top/bottom)
  min_visible = 0.0,        -- Minimum visibility when hidden (0.0 = fully hidden)

  -- Animation (uses library defaults)
  slide_distance = 20,      -- How far to slide when revealing
  animation_speed = nil,    -- nil = use Anim.FADE_SPEED
  slide_speed = nil,        -- nil = use Anim.SMOOTH_SPEED
  scale_speed = nil,        -- nil = use Anim.SMOOTH_SPEED
  snap_epsilon = 0.001,     -- Threshold for considering animation settled

  -- Retract delays
  retract_delay = 0.3,      -- Base delay (used when directional_delay = false)
  directional_delay = false, -- Enable direction-aware retract delays
  retract_delay_toward = 1.0, -- Delay when cursor exits toward panel edge (longer)
  retract_delay_away = 0.1, -- Delay when cursor exits away from panel edge (shorter)

  -- Hover zone
  hover_extend_outside = 30,  -- Extend hover zone outside bounds
  hover_extend_inside = 50,   -- Extend hover zone inside bounds
  hover_padding = 30,         -- Padding around content area for hover

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
  on_draw = nil,            -- function(ctx, dl, bounds, visibility, state)
  on_expand = nil,          -- function(state) - called when expanding
  on_collapse = nil,        -- function(state) - called when collapsing

  -- Draw list
  draw_list = nil,
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
  if opts.animation_speed then
    self.visibility_track:set_speed(opts.animation_speed)
  end
  if opts.slide_speed then
    self.slide_track:set_speed(opts.slide_speed)
  end
  if opts.scale_speed then
    self.scale_track:set_speed(opts.scale_speed)
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
--- @return number mx Mouse X
--- @return number my Mouse Y
local function get_mouse_position(ctx)
  -- Use reaper.GetMousePosition() for reliable global tracking
  -- This works even when cursor is outside window (unlike ImGui.GetMousePos)
  if reaper.GetMousePosition then
    return reaper.GetMousePosition()
  else
    -- Fallback to ImGui if REAPER API not available
    return ImGui.GetMousePos(ctx)
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
  local mx, my = get_mouse_position(ctx)
  local edge = opts.edge or "right"

  -- Get content bounds for hover calculation
  local content = opts.content_bounds or bounds

  -- Calculate hover zone based on edge
  local padding = opts.hover_padding or 30

  -- MASSIVE TRIGGER ZONE (like Settings panel's "everything ABOVE Y")
  -- This is more reliable than trying to detect crossing through a thin strip
  -- For left/right edges: trigger extends far into content area
  -- For top/bottom edges: trigger extends far into content area

  -- When expanded, extend trigger to cover full panel
  local trigger_threshold
  if state.is_expanded or state.is_in_hover_zone then
    -- Expanded: trigger covers the full panel size
    local size = opts.size or 40
    trigger_threshold = size
  else
    -- Collapsed: MASSIVE trigger zone extends into content
    -- This makes it easy to trigger even with fast mouse movement
    trigger_threshold = opts.hover_extend_inside or 200  -- Was 50, now 200 (massive)
  end

  if edge == "left" then
    -- Trigger zone: everything LEFT of (bounds.x + trigger_threshold)
    -- This is like Settings panel's "everything ABOVE Y"
    local trigger_x = bounds.x + trigger_threshold
    local zone_y1 = content.y - padding
    local zone_y2 = content.y + content.h + padding
    return mx < trigger_x and my >= zone_y1 and my <= zone_y2

  elseif edge == "right" then
    -- Trigger zone: everything RIGHT of (bounds.x + bounds.w - trigger_threshold)
    local trigger_x = bounds.x + bounds.w - trigger_threshold
    local zone_y1 = content.y - padding
    local zone_y2 = content.y + content.h + padding
    return mx > trigger_x and my >= zone_y1 and my <= zone_y2

  elseif edge == "top" then
    -- Trigger zone: everything ABOVE (bounds.y + trigger_threshold)
    local trigger_y = bounds.y + trigger_threshold
    local zone_x1 = content.x - padding
    local zone_x2 = content.x + content.w + padding
    return my < trigger_y and mx >= zone_x1 and mx <= zone_x2

  else -- bottom
    -- Trigger zone: everything BELOW (bounds.y + bounds.h - trigger_threshold)
    local trigger_y = bounds.y + bounds.h - trigger_threshold
    local zone_x1 = content.x - padding
    local zone_x2 = content.x + content.w + padding
    return my > trigger_y and mx >= zone_x1 and mx <= zone_x2
  end
end

--- Detect if cursor moved from content area toward the panel edge (fast movement)
--- This matches the pattern used by ItemPicker's Settings panel - tracks if cursor
--- was in the "content area" (away from edge) and moved toward/past the edge.
--- @param opts table Widget options
--- @param state table Instance state with last_mouse_x/y
--- @param bounds table Normalized bounds
--- @param mx number Current mouse X
--- @param my number Current mouse Y
--- @return boolean True if cursor moved from content toward edge
local function crossed_toward_edge(opts, state, bounds, mx, my)
  local prev_x, prev_y = state.last_mouse_x, state.last_mouse_y
  if not prev_x or not prev_y then return false end

  local edge = opts.edge or "right"
  local content = opts.content_bounds or bounds
  local padding = opts.hover_padding or 30
  local hover_inside = opts.hover_extend_inside or 50

  -- Define "content area" as the area AWAY from the panel edge
  -- If cursor was in content and moved toward edge, trigger the panel
  if edge == "left" then
    -- Content area = right of the trigger zone
    local content_threshold = bounds.x + hover_inside
    local edge_threshold = bounds.x
    -- Was in content area (right of trigger), now at or past edge (left of bounds)
    local was_in_content = prev_x > content_threshold
    local now_at_edge = mx <= edge_threshold
    local in_y_range = my >= (content.y - padding) and my <= (content.y + content.h + padding)
    return was_in_content and now_at_edge and in_y_range

  elseif edge == "right" then
    -- Content area = left of the trigger zone
    local content_threshold = bounds.x + bounds.w - hover_inside
    local edge_threshold = bounds.x + bounds.w
    -- Was in content area (left of trigger), now at or past edge (right of bounds)
    local was_in_content = prev_x < content_threshold
    local now_at_edge = mx >= edge_threshold
    local in_y_range = my >= (content.y - padding) and my <= (content.y + content.h + padding)
    return was_in_content and now_at_edge and in_y_range

  elseif edge == "top" then
    -- Content area = below the trigger zone
    local content_threshold = bounds.y + hover_inside
    local edge_threshold = bounds.y
    -- Was in content area (below trigger), now at or past edge (above bounds)
    local was_in_content = prev_y > content_threshold
    local now_at_edge = my <= edge_threshold
    local in_x_range = mx >= (content.x - padding) and mx <= (content.x + content.w + padding)
    return was_in_content and now_at_edge and in_x_range

  else -- bottom
    -- Content area = above the trigger zone
    local content_threshold = bounds.y + bounds.h - hover_inside
    local edge_threshold = bounds.y + bounds.h
    -- Was in content area (above trigger), now at or past edge (below bounds)
    local was_in_content = prev_y < content_threshold
    local now_at_edge = my >= edge_threshold
    local in_x_range = mx >= (content.x - padding) and mx <= (content.x + content.w + padding)
    return was_in_content and now_at_edge and in_x_range
  end
end

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
  local visible_size = scaled_size * math.max(opts.min_visible or 0, visibility)

  if edge == "left" then
    -- Starts clipped outside left edge, slides right
    local slide_distance = opts.slide_distance or 20
    local base_x = bounds.x - slide_distance
    return {
      x = base_x + slide_offset,
      y = bounds.y,
      w = visible_size,
      h = bounds.h
    }

  elseif edge == "right" then
    -- Starts clipped outside right edge, slides left
    local slide_distance = opts.slide_distance or 20
    local base_x = bounds.x + bounds.w + slide_distance - visible_size
    return {
      x = base_x - slide_offset,
      y = bounds.y,
      w = visible_size,
      h = bounds.h
    }

  elseif edge == "top" then
    -- Starts clipped outside top edge, slides down
    local slide_distance = opts.slide_distance or 20
    local base_y = bounds.y - slide_distance
    return {
      x = bounds.x,
      y = base_y + slide_offset,
      w = bounds.w,
      h = visible_size
    }

  else -- bottom
    -- Starts clipped outside bottom edge, slides up
    local slide_distance = opts.slide_distance or 20
    local base_y = bounds.y + bounds.h + slide_distance - visible_size
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

  -- Validate required opts
  if not opts.bounds then
    error("SlidingZone requires 'bounds' option", 2)
  end

  -- Resolve unique ID
  local unique_id = Base.resolve_id(opts, "sliding_zone")

  -- Get or create instance
  local state = Base.get_or_create_instance(instances, unique_id, SlidingZone.new)

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
  local slide_distance = opts.slide_distance or 20

  if trigger == "always" then
    -- Always visible
    state:set_targets(1.0, slide_distance, opts.expand_scale or 1.0)

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
      state:set_targets(1.0, slide_distance, opts.expand_scale or 1.0)
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
      state:set_targets(1.0, slide_distance, opts.expand_scale or 1.0)
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
  if opts.on_draw then
    opts.on_draw(ctx, dl, content_bounds, visibility, state)
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
  local unique_id = Base.resolve_id(opts, "sliding_zone")
  local state = Base.get_or_create_instance(instances, unique_id, SlidingZone.new)

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
  local unique_id = Base.resolve_id(opts, "sliding_zone")
  local state = Base.get_or_create_instance(instances, unique_id, SlidingZone.new)

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
  local unique_id = Base.resolve_id(opts, "sliding_zone")
  local state = Base.get_or_create_instance(instances, unique_id, SlidingZone.new)

  state.is_expanded = expanded
  local slide_distance = opts.slide_distance or 20

  if expanded then
    state:teleport(1.0, slide_distance, opts.expand_scale or 1.0)
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
  local unique_id = Base.resolve_id(opts, "sliding_zone")
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

return M
