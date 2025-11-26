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
  retract_delay = 0.3,      -- Seconds to wait before retracting
  snap_epsilon = 0.001,     -- Threshold for considering animation settled

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
-- HOVER ZONE DETECTION
-- ============================================================================

local function is_in_hover_zone(ctx, opts, state, bounds)
  local mx, my = ImGui.GetMousePos(ctx)
  local edge = opts.edge or "right"

  -- Get content bounds for hover calculation
  local content = opts.content_bounds or bounds

  -- Calculate hover zone based on edge
  local hover_outside = opts.hover_extend_outside or 30
  local hover_inside = opts.hover_extend_inside or 50
  local padding = opts.hover_padding or 30

  if edge == "left" then
    local zone_x1 = bounds.x - hover_outside
    local zone_x2 = bounds.x + hover_inside
    local zone_y1 = content.y - padding
    local zone_y2 = content.y + content.h + padding
    return mx >= zone_x1 and mx <= zone_x2 and my >= zone_y1 and my <= zone_y2

  elseif edge == "right" then
    local zone_x1 = bounds.x + bounds.w - hover_inside
    local zone_x2 = bounds.x + bounds.w + hover_outside
    local zone_y1 = content.y - padding
    local zone_y2 = content.y + content.h + padding
    return mx >= zone_x1 and mx <= zone_x2 and my >= zone_y1 and my <= zone_y2

  elseif edge == "top" then
    local zone_x1 = content.x - padding
    local zone_x2 = content.x + content.w + padding
    local zone_y1 = bounds.y - hover_outside
    local zone_y2 = bounds.y + hover_inside
    return mx >= zone_x1 and mx <= zone_x2 and my >= zone_y1 and my <= zone_y2

  else -- bottom
    local zone_x1 = content.x - padding
    local zone_x2 = content.x + content.w + padding
    local zone_y1 = bounds.y + bounds.h - hover_inside
    local zone_y2 = bounds.y + bounds.h + hover_outside
    return mx >= zone_x1 and mx <= zone_x2 and my >= zone_y1 and my <= zone_y2
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
    -- Check hover zone
    local in_zone = is_in_hover_zone(ctx, opts, state, bounds)

    if in_zone then
      -- Expand immediately
      state:set_targets(1.0, slide_distance, opts.expand_scale or 1.0)
      state.hover_leave_time = nil
      state.is_in_hover_zone = true

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
      end

      -- Check if delay has passed
      local delay = opts.retract_delay or 0.3
      if state.hover_leave_time and (current_time - state.hover_leave_time) >= delay then
        -- Retract
        state:set_targets(opts.min_visible or 0.0, 0, 1.0)
        state.is_in_hover_zone = false
        state.hover_leave_time = nil

        -- Fire collapse callback on transition
        if state.is_expanded and opts.on_collapse then
          opts.on_collapse(state)
        end
        state.is_expanded = false
      end
    end

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
    return Base.create_result({
      expanded = state.is_expanded,
      visibility = visibility,
      bounds = content_bounds,
      hovered = false,
      settled = true,
    })
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

  -- Check if mouse is over content bounds
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= content_bounds.x and mx <= content_bounds.x + content_bounds.w and
                     my >= content_bounds.y and my <= content_bounds.y + content_bounds.h

  return Base.create_result({
    expanded = state.is_expanded,
    visibility = visibility,
    bounds = content_bounds,
    hovered = is_hovered,
    settled = is_settled,
  })
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
