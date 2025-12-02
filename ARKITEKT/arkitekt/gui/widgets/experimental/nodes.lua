-- @noindex
-- arkitekt/gui/widgets/experimental/nodes.lua
-- EXPERIMENTAL: General-purpose node editor for visual programming / patching
-- Inspired by imnodes but using ARKITEKT conventions

local ImGui = require('arkitekt.platform.imgui')
local Theme = require('arkitekt.core.theme')
local Colors = require('arkitekt.core.colors')
local Base = require('arkitekt.gui.widgets.base')

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local PIN_RADIUS = 6
local NODE_PADDING = 8
local NODE_ROUNDING = 4
local LINK_THICKNESS = 3
local GRID_SIZE = 64
local TITLE_HEIGHT = 24

-- Performance: Cache ImGui functions
local DrawList_AddRectFilled = ImGui.DrawList_AddRectFilled
local DrawList_AddRect = ImGui.DrawList_AddRect
local DrawList_AddCircleFilled = ImGui.DrawList_AddCircleFilled
local DrawList_AddBezierCubic = ImGui.DrawList_AddBezierCubic
local DrawList_AddLine = ImGui.DrawList_AddLine
local IsMouseClicked = ImGui.IsMouseClicked
local IsMouseDoubleClicked = ImGui.IsMouseDoubleClicked
local IsMouseDragging = ImGui.IsMouseDragging
local GetMousePos = ImGui.GetMousePos
local GetMouseDragDelta = ImGui.GetMouseDragDelta
local ResetMouseDragDelta = ImGui.ResetMouseDragDelta

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
  width = 800,
  height = 600,

  -- Data structures
  nodes = nil,        -- Array of node definitions
  links = nil,        -- Array of link definitions

  -- Canvas state
  pan_x = 0,          -- Canvas pan offset X
  pan_y = 0,          -- Canvas pan offset Y
  zoom = 1.0,         -- Canvas zoom level

  -- Interaction
  is_interactive = true,
  show_grid = true,

  -- Style
  bg_color = nil,
  grid_color = nil,
  node_bg_color = nil,
  node_border_color = nil,
  node_title_bg_color = nil,
  pin_color = nil,
  link_color = nil,
  link_preview_color = nil,

  -- Callbacks
  on_node_move = nil,      -- function(node_id, x, y)
  on_link_create = nil,    -- function(from_node_id, from_pin, to_node_id, to_pin)
  on_link_delete = nil,    -- function(link_id)
  on_node_select = nil,    -- function(node_id)

  -- Cursor control
  advance = "vertical",

  -- Draw list
  draw_list = nil,
}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local editor_state = {}  -- Per-editor state

local function get_state(unique_id)
  if not editor_state[unique_id] then
    editor_state[unique_id] = {
      dragging_node = nil,
      dragging_link_from_node = nil,
      dragging_link_from_pin = nil,
      dragging_link_is_output = false,
      drag_offset_x = 0,
      drag_offset_y = 0,
      hovered_node = nil,
      hovered_pin_node = nil,
      hovered_pin = nil,
      hovered_pin_is_output = false,
      canvas_dragging = false,
    }
  end
  return editor_state[unique_id]
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Check if point is inside rectangle
local function point_in_rect(px, py, x, y, w, h)
  return px >= x and px <= x + w and py >= y and py <= y + h
end

--- Check if point is inside circle
local function point_in_circle(px, py, cx, cy, radius)
  local dx = px - cx
  local dy = py - cy
  return (dx * dx + dy * dy) <= (radius * radius)
end

--- Get pin world position
local function get_pin_position(node, pin, is_output)
  local pin_y = node.y + TITLE_HEIGHT + 20  -- Title height + first pin offset

  -- Find pin index
  local pins = is_output and node.outputs or node.inputs
  for i, p in ipairs(pins) do
    if p.id == pin.id then
      pin_y = node.y + TITLE_HEIGHT + (i * 24)
      break
    end
  end

  local pin_x = is_output and (node.x + node.width) or node.x
  return pin_x, pin_y
end

--- Transform canvas coordinates to screen coordinates
local function canvas_to_screen(cx, cy, pan_x, pan_y, zoom, editor_x, editor_y)
  return editor_x + cx * zoom + pan_x, editor_y + cy * zoom + pan_y
end

--- Transform screen coordinates to canvas coordinates
local function screen_to_canvas(sx, sy, pan_x, pan_y, zoom, editor_x, editor_y)
  return ((sx - editor_x) - pan_x) / zoom, ((sy - editor_y) - pan_y) / zoom
end

--- Find node at screen position
local function find_node_at_pos(nodes, sx, sy, pan_x, pan_y, zoom, editor_x, editor_y)
  -- Check nodes in reverse order (top to bottom in render order)
  for i = #nodes, 1, -1 do
    local node = nodes[i]
    local nx, ny = canvas_to_screen(node.x, node.y, pan_x, pan_y, zoom, editor_x, editor_y)
    local nw = node.width * zoom
    local nh = node.height * zoom

    if point_in_rect(sx, sy, nx, ny, nw, nh) then
      return node, i
    end
  end
  return nil
end

--- Find pin at screen position
local function find_pin_at_pos(nodes, sx, sy, pan_x, pan_y, zoom, editor_x, editor_y)
  for _, node in ipairs(nodes) do
    -- Check output pins
    if node.outputs then
      for _, pin in ipairs(node.outputs) do
        local px, py = get_pin_position(node, pin, true)
        local spx, spy = canvas_to_screen(px, py, pan_x, pan_y, zoom, editor_x, editor_y)

        if point_in_circle(sx, sy, spx, spy, PIN_RADIUS * zoom * 1.5) then
          return node, pin, true
        end
      end
    end

    -- Check input pins
    if node.inputs then
      for _, pin in ipairs(node.inputs) do
        local px, py = get_pin_position(node, pin, false)
        local spx, spy = canvas_to_screen(px, py, pan_x, pan_y, zoom, editor_x, editor_y)

        if point_in_circle(sx, sy, spx, spy, PIN_RADIUS * zoom * 1.5) then
          return node, pin, false
        end
      end
    end
  end
  return nil, nil, false
end

-- ============================================================================
-- RENDERING
-- ============================================================================

--- Render grid background
local function render_grid(dl, x, y, w, h, pan_x, pan_y, zoom, grid_color)
  local grid_size = GRID_SIZE * zoom

  -- Calculate grid offset
  local offset_x = (pan_x % grid_size)
  local offset_y = (pan_y % grid_size)

  -- Vertical lines
  local grid_x = x + offset_x
  while grid_x < x + w do
    DrawList_AddLine(dl, grid_x, y, grid_x, y + h, grid_color, 1)
    grid_x = grid_x + grid_size
  end

  -- Horizontal lines
  local grid_y = y + offset_y
  while grid_y < y + h do
    DrawList_AddLine(dl, x, grid_y, x + w, grid_y, grid_color, 1)
    grid_y = grid_y + grid_size
  end
end

--- Render single node
local function render_node(ctx, dl, node, pan_x, pan_y, zoom, editor_x, editor_y, opts, state)
  -- Transform to screen coordinates
  local sx, sy = canvas_to_screen(node.x, node.y, pan_x, pan_y, zoom, editor_x, editor_y)
  local sw = node.width * zoom
  local sh = node.height * zoom

  -- Colors
  local bg_color = opts.node_bg_color or Theme.COLORS.BG_BASE
  local border_color = opts.node_border_color or Theme.COLORS.BORDER_INNER
  local title_bg_color = opts.node_title_bg_color or Theme.COLORS.ACCENT_PRIMARY
  local pin_color = opts.pin_color or Theme.COLORS.ACCENT_SECONDARY

  if node.is_selected then
    border_color = Theme.COLORS.ACCENT_PRIMARY
  end

  -- Node background
  DrawList_AddRectFilled(dl, sx, sy, sx + sw, sy + sh, bg_color, NODE_ROUNDING)
  DrawList_AddRect(dl, sx, sy, sx + sw, sy + sh, border_color, NODE_ROUNDING, 0, 2)

  -- Title bar
  local title_h = TITLE_HEIGHT * zoom
  DrawList_AddRectFilled(dl, sx, sy, sx + sw, sy + title_h, title_bg_color, NODE_ROUNDING, ImGui.DrawFlags_RoundCornersTop)

  -- Title text
  ImGui.SetCursorScreenPos(ctx, sx + 8 * zoom, sy + 4 * zoom)
  ImGui.Text(ctx, node.label or node.id)

  -- Input pins (left side)
  if node.inputs then
    for i, pin in ipairs(node.inputs) do
      local pin_x, pin_y = get_pin_position(node, pin, false)
      local spx, spy = canvas_to_screen(pin_x, pin_y, pan_x, pan_y, zoom, editor_x, editor_y)

      -- Highlight if hovered
      local is_hovered = (state.hovered_pin_node == node and state.hovered_pin == pin)
      local current_pin_color = is_hovered and Colors.adjust_brightness(pin_color, 1.3) or pin_color

      DrawList_AddCircleFilled(dl, spx, spy, PIN_RADIUS * zoom, current_pin_color, 12)

      -- Pin label
      ImGui.SetCursorScreenPos(ctx, spx + 12 * zoom, spy - 8 * zoom)
      ImGui.Text(ctx, pin.label or pin.id)
    end
  end

  -- Output pins (right side)
  if node.outputs then
    for i, pin in ipairs(node.outputs) do
      local pin_x, pin_y = get_pin_position(node, pin, true)
      local spx, spy = canvas_to_screen(pin_x, pin_y, pan_x, pan_y, zoom, editor_x, editor_y)

      -- Highlight if hovered
      local is_hovered = (state.hovered_pin_node == node and state.hovered_pin == pin)
      local current_pin_color = is_hovered and Colors.adjust_brightness(pin_color, 1.3) or pin_color

      DrawList_AddCircleFilled(dl, spx, spy, PIN_RADIUS * zoom, current_pin_color, 12)

      -- Pin label (right-aligned)
      local label = pin.label or pin.id
      local label_w = ImGui.CalcTextSize(ctx, label)
      ImGui.SetCursorScreenPos(ctx, spx - label_w - 12 * zoom, spy - 8 * zoom)
      ImGui.Text(ctx, label)
    end
  end
end

--- Render link between pins
local function render_link(dl, link, nodes, pan_x, pan_y, zoom, editor_x, editor_y, link_color)
  -- Find nodes
  local from_node, to_node
  for _, node in ipairs(nodes) do
    if node.id == link.from_node then from_node = node end
    if node.id == link.to_node then to_node = node end
  end

  if not from_node or not to_node then return end

  -- Find pins
  local from_pin, to_pin
  for _, pin in ipairs(from_node.outputs or {}) do
    if pin.id == link.from_pin then from_pin = pin break end
  end
  for _, pin in ipairs(to_node.inputs or {}) do
    if pin.id == link.to_pin then to_pin = pin break end
  end

  if not from_pin or not to_pin then return end

  -- Get pin positions
  local x1, y1 = get_pin_position(from_node, from_pin, true)
  local x2, y2 = get_pin_position(to_node, to_pin, false)

  -- Transform to screen
  local sx1, sy1 = canvas_to_screen(x1, y1, pan_x, pan_y, zoom, editor_x, editor_y)
  local sx2, sy2 = canvas_to_screen(x2, y2, pan_x, pan_y, zoom, editor_x, editor_y)

  -- Bezier curve for link
  local curve_offset = 50 * zoom
  DrawList_AddBezierCubic(dl,
    sx1, sy1,
    sx1 + curve_offset, sy1,
    sx2 - curve_offset, sy2,
    sx2, sy2,
    link_color, LINK_THICKNESS * zoom
  )
end

--- Render link preview (while dragging)
local function render_link_preview(dl, from_x, from_y, to_x, to_y, zoom, color)
  local curve_offset = 50 * zoom
  DrawList_AddBezierCubic(dl,
    from_x, from_y,
    from_x + curve_offset, from_y,
    to_x - curve_offset, to_y,
    to_x, to_y,
    color, LINK_THICKNESS * zoom
  )
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- Draw a node editor widget
--- @param ctx userdata ImGui context
--- @param opts table Widget options
--- @return table Result { changed, nodes, links, pan_x, pan_y, zoom, width, height }
function M.draw(ctx, opts)
  opts = Base.parse_opts(opts, DEFAULTS)

  -- Resolve unique ID
  local unique_id = Base.resolve_id(ctx, opts, "nodes")
  local state = get_state(unique_id)

  -- Get position and draw list
  local x, y = Base.get_position(ctx, opts)
  local dl = Base.get_draw_list(ctx, opts)

  -- Get size
  local w = opts.width or 800
  local h = opts.height or 600

  -- Ensure data structures exist
  local nodes = opts.nodes or {}
  local links = opts.links or {}

  -- Track if anything changed
  local changed = false
  local new_pan_x, new_pan_y = opts.pan_x, opts.pan_y
  local new_zoom = opts.zoom

  -- Background
  local bg_color = opts.bg_color or Colors.with_opacity(Theme.COLORS.BG_BASE, 0.5)
  DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color, 0)

  -- Grid
  if opts.show_grid then
    local grid_color = opts.grid_color or Colors.with_opacity(Theme.COLORS.TEXT_NORMAL, 0.1)
    render_grid(dl, x, y, w, h, opts.pan_x, opts.pan_y, opts.zoom, grid_color)
  end

  -- Render links
  local link_color = opts.link_color or Theme.COLORS.ACCENT_PRIMARY
  for _, link in ipairs(links) do
    render_link(dl, link, nodes, opts.pan_x, opts.pan_y, opts.zoom, x, y, link_color)
  end

  -- Render nodes
  for _, node in ipairs(nodes) do
    render_node(ctx, dl, node, opts.pan_x, opts.pan_y, opts.zoom, x, y, opts, state)
  end

  -- Render link preview (if dragging)
  if state.dragging_link_from_node then
    local from_node = state.dragging_link_from_node
    local from_pin = state.dragging_link_from_pin
    local px, py = get_pin_position(from_node, from_pin, state.dragging_link_is_output)
    local spx, spy = canvas_to_screen(px, py, opts.pan_x, opts.pan_y, opts.zoom, x, y)

    local mx, my = GetMousePos(ctx)
    local preview_color = opts.link_preview_color or Colors.with_opacity(link_color, 0.6)
    render_link_preview(dl, spx, spy, mx, my, opts.zoom, preview_color)
  end

  -- Interaction
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.InvisibleButton(ctx, "##" .. unique_id, w, h)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)

  if opts.is_interactive and hovered then
    local mx, my = GetMousePos(ctx)

    -- Update hovered pin/node
    state.hovered_pin_node, state.hovered_pin, state.hovered_pin_is_output = find_pin_at_pos(nodes, mx, my, opts.pan_x, opts.pan_y, opts.zoom, x, y)
    state.hovered_node = find_node_at_pos(nodes, mx, my, opts.pan_x, opts.pan_y, opts.zoom, x, y)

    -- Mouse click handling
    if IsMouseClicked(ctx, ImGui.MouseButton_Left) then
      -- Check if clicking on pin
      if state.hovered_pin_node then
        -- Start dragging link
        state.dragging_link_from_node = state.hovered_pin_node
        state.dragging_link_from_pin = state.hovered_pin
        state.dragging_link_is_output = state.hovered_pin_is_output
      elseif state.hovered_node then
        -- Start dragging node
        local cx, cy = screen_to_canvas(mx, my, opts.pan_x, opts.pan_y, opts.zoom, x, y)
        state.dragging_node = state.hovered_node
        state.drag_offset_x = cx - state.hovered_node.x
        state.drag_offset_y = cy - state.hovered_node.y

        -- Select node
        for _, node in ipairs(nodes) do
          node.is_selected = (node == state.hovered_node)
        end

        if opts.on_node_select then
          opts.on_node_select(state.hovered_node.id)
        end
      else
        -- Deselect all
        for _, node in ipairs(nodes) do
          node.is_selected = false
        end
      end
    end

    -- Middle mouse button for panning
    if IsMouseClicked(ctx, ImGui.MouseButton_Middle) then
      state.canvas_dragging = true
    end
  end

  -- Handle dragging
  if state.dragging_node and IsMouseDragging(ctx, ImGui.MouseButton_Left, 0) then
    local mx, my = GetMousePos(ctx)
    local cx, cy = screen_to_canvas(mx, my, opts.pan_x, opts.pan_y, opts.zoom, x, y)

    state.dragging_node.x = cx - state.drag_offset_x
    state.dragging_node.y = cy - state.drag_offset_y
    changed = true

    if opts.on_node_move then
      opts.on_node_move(state.dragging_node.id, state.dragging_node.x, state.dragging_node.y)
    end
  elseif not ImGui.IsMouseDown(ctx, ImGui.MouseButton_Left) then
    -- Release link drag
    if state.dragging_link_from_node then
      local mx, my = GetMousePos(ctx)
      local target_node, target_pin, target_is_output = find_pin_at_pos(nodes, mx, my, opts.pan_x, opts.pan_y, opts.zoom, x, y)

      -- Create link if valid (output -> input or input -> output)
      if target_node and target_pin and (state.dragging_link_is_output ~= target_is_output) then
        local from_node, from_pin, to_node, to_pin

        if state.dragging_link_is_output then
          from_node = state.dragging_link_from_node
          from_pin = state.dragging_link_from_pin
          to_node = target_node
          to_pin = target_pin
        else
          from_node = target_node
          from_pin = target_pin
          to_node = state.dragging_link_from_node
          to_pin = state.dragging_link_from_pin
        end

        -- Add link
        local new_link = {
          id = "link_" .. #links + 1,
          from_node = from_node.id,
          from_pin = from_pin.id,
          to_node = to_node.id,
          to_pin = to_pin.id,
        }
        table.insert(links, new_link)
        changed = true

        if opts.on_link_create then
          opts.on_link_create(from_node.id, from_pin.id, to_node.id, to_pin.id)
        end
      end

      state.dragging_link_from_node = nil
      state.dragging_link_from_pin = nil
    end

    state.dragging_node = nil
  end

  -- Handle canvas panning
  if state.canvas_dragging and IsMouseDragging(ctx, ImGui.MouseButton_Middle, 0) then
    local dx, dy = GetMouseDragDelta(ctx, ImGui.MouseButton_Middle)
    new_pan_x = opts.pan_x + dx
    new_pan_y = opts.pan_y + dy
    changed = true
    ResetMouseDragDelta(ctx, ImGui.MouseButton_Middle)
  elseif not ImGui.IsMouseDown(ctx, ImGui.MouseButton_Middle) then
    state.canvas_dragging = false
  end

  -- Handle zoom (mouse wheel)
  if hovered then
    local wheel = ImGui.GetMouseWheel(ctx)
    if wheel ~= 0 then
      local zoom_factor = wheel > 0 and 1.1 or 0.9
      new_zoom = Base.clamp(opts.zoom * zoom_factor, 0.3, 3.0)
      changed = true
    end
  end

  -- Advance cursor
  Base.advance_cursor(ctx, x, y, w, h, opts.advance)

  -- Return standardized result
  return Base.create_result({
    changed = changed,
    nodes = nodes,
    links = links,
    pan_x = new_pan_x,
    pan_y = new_pan_y,
    zoom = new_zoom,
    width = w,
    height = h,
  })
end

-- ============================================================================
-- MODULE EXPORT (Callable)
-- ============================================================================

-- Make module callable: Ark.Nodes(ctx, ...) → M.draw(ctx, ...)
return setmetatable(M, {
  __call = function(_, ctx, ...)
    return M.draw(ctx, ...)
  end
})
