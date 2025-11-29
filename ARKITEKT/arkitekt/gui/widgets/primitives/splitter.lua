-- @noindex
-- arkitekt/gui/widgets/primitives/splitter.lua
-- Draggable splitter for resizing panels
-- Uses unified opts-based API

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
  -- Identity
  id = "splitter",

  -- Position (nil = use cursor)
  x = nil,
  y = nil,

  -- Size (depends on orientation)
  width = nil,   -- Required for vertical, ignored for horizontal (uses provided width)
  height = nil,  -- Required for horizontal, ignored for vertical (uses provided height)

  -- Orientation
  orientation = "horizontal",  -- "horizontal" or "vertical"

  -- Interaction
  thickness = 8,  -- Hit area thickness for dragging
  disabled = false,

  -- Callbacks
  on_drag = nil,       -- Called while dragging: function(new_pos)
  on_reset = nil,      -- Called on double-click: function()
  tooltip = nil,

  -- Cursor control
  advance = "none",  -- Usually managed by parent layout

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- INSTANCE MANAGEMENT (strong tables with access tracking for cleanup)
-- ============================================================================

local instances = Base.create_instance_registry()

local Splitter = {}
Splitter.__index = Splitter

function Splitter.new(id)
  return setmetatable({
    id = id,
    is_dragging = false,
    drag_offset = 0,
  }, Splitter)
end

-- ============================================================================
-- RENDERING
-- ============================================================================

local function render_horizontal(ctx, instance, x, y, width, thickness, disabled)
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = not disabled and
                     mx >= x and mx < x + width and
                     my >= y - thickness/2 and my < y + thickness/2

  if is_hovered or instance.is_dragging then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS)
  end

  -- Create invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x, y - thickness/2)
  ImGui.InvisibleButton(ctx, "##hsplit_" .. instance.id, width, thickness)

  -- Check for reset (double-click)
  if not disabled and ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
    instance.is_dragging = false
    return "reset", 0
  end

  -- Check for drag
  if not disabled and ImGui.IsItemActive(ctx) then
    if not instance.is_dragging then
      instance.is_dragging = true
      instance.drag_offset = my - y
    end

    local new_pos = my - instance.drag_offset
    return "drag", new_pos
  elseif instance.is_dragging and not ImGui.IsMouseDown(ctx, 0) then
    instance.is_dragging = false
  end

  return "none", y
end

local function render_vertical(ctx, instance, x, y, height, thickness, disabled)
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = not disabled and
                     mx >= x - thickness/2 and mx < x + thickness/2 and
                     my >= y and my < y + height

  if is_hovered or instance.is_dragging then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
  end

  -- Create invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, x - thickness/2, y)
  ImGui.InvisibleButton(ctx, "##vsplit_" .. instance.id, thickness, height)

  -- Check for reset (double-click)
  if not disabled and ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
    instance.is_dragging = false
    return "reset", 0
  end

  -- Check for drag
  if not disabled and ImGui.IsItemActive(ctx) then
    if not instance.is_dragging then
      instance.is_dragging = true
      instance.drag_offset = mx - x
    end

    local new_pos = mx - instance.drag_offset
    return "drag", new_pos
  elseif instance.is_dragging and not ImGui.IsMouseDown(ctx, 0) then
    instance.is_dragging = false
  end

  return "none", x
end

-- ============================================================================
-- PUBLIC API (Standardized)
-- ============================================================================

--- Draw a splitter widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { action, position, dragging, width, height }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(opts, "splitter")

  -- Get or create instance
  local instance = Base.get_or_create_instance(instances, unique_id, Splitter.new)

  -- Get position
  local x, y = Base.get_position(ctx, opts)

  -- Render based on orientation
  local action, position
  if opts.orientation == "vertical" then
    local height = opts.height
    if not height then
      error("splitter: height required for vertical orientation")
    end
    action, position = render_vertical(ctx, instance, x, y, height, opts.thickness, opts.disabled)
  else
    -- Horizontal (default)
    local width = opts.width
    if not width then
      error("splitter: width required for horizontal orientation")
    end
    action, position = render_horizontal(ctx, instance, x, y, width, opts.thickness, opts.disabled)
  end

  -- Handle callbacks
  if action == "drag" and opts.on_drag then
    opts.on_drag(position)
  elseif action == "reset" and opts.on_reset then
    opts.on_reset()
  end

  -- Handle tooltip
  Base.handle_tooltip(ctx, opts)

  -- Calculate result dimensions
  local result_width = opts.orientation == "vertical" and opts.thickness or opts.width
  local result_height = opts.orientation == "horizontal" and opts.thickness or opts.height

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, result_width, result_height, opts.advance)

  -- Return standardized result
  return Base.create_result({
    action = action,        -- "none", "drag", or "reset"
    position = position,    -- New position (or current if not dragging)
    dragging = instance.is_dragging,
    width = result_width,
    height = result_height,
  })
end

--- Check if splitter is currently being dragged
--- @param ctx userdata ImGui context
--- @param opts table Widget options (must have same id as draw call)
--- @return boolean True if dragging
function M.is_dragging(ctx, opts)
  opts = opts or {}
  local unique_id = Base.resolve_id(opts, "splitter")
  local instance = instances[unique_id]
  return instance and instance.is_dragging or false
end

-- ============================================================================
-- DEPRECATED / REMOVED FUNCTIONS
-- ============================================================================

-- M.cleanup() - REMOVED (automatic via Base.cleanup_registry, no manual call needed)

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.Splitter(ctx, opts) → M.draw(ctx, opts)
return setmetatable(M, {
  __call = function(_, ctx, opts)
    return M.draw(ctx, opts)
  end
})
