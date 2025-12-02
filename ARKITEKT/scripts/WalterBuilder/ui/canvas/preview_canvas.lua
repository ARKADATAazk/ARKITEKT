-- @noindex
-- WalterBuilder/ui/canvas/preview_canvas.lua
-- Main resizable preview canvas for WALTER layout visualization

local ImGui = require('arkitekt.platform.imgui')
local Colors = require('WalterBuilder.defs.colors')
local Simulator = require('WalterBuilder.domain.simulator')
local ElementRenderer = require('WalterBuilder.ui.canvas.element_renderer')
local TrackRenderer = require('WalterBuilder.ui.canvas.track_renderer')

local M = {}
local Canvas = {}
Canvas.__index = Canvas

-- View modes
M.VIEW_SINGLE = 'single'    -- Single track/element view
M.VIEW_TRACKS = 'tracks'    -- Multiple tracks stacked vertically

-- Default canvas configuration
local DEFAULT_CONFIG = {
  min_parent_w = 150,
  min_parent_h = 60,
  max_parent_w = 800,
  max_parent_h = 600,
  default_parent_w = 300,
  default_parent_h = 90,
  grid_size = 10,
  show_grid = true,
  show_attachments = true,
  handle_size = 8,
  element_handle_size = 6,  -- Size of element resize handles
  element_edge_threshold = 5,  -- Pixels from edge to trigger resize
}

function M.new(opts)
  opts = opts or {}

  local self = setmetatable({
    -- Parent container dimensions (what user resizes)
    parent_w = opts.parent_w or DEFAULT_CONFIG.default_parent_w,
    parent_h = opts.parent_h or DEFAULT_CONFIG.default_parent_h,

    -- View mode
    view_mode = opts.view_mode or M.VIEW_TRACKS,

    -- Configuration
    config = {
      min_parent_w = opts.min_parent_w or DEFAULT_CONFIG.min_parent_w,
      min_parent_h = opts.min_parent_h or DEFAULT_CONFIG.min_parent_h,
      max_parent_w = opts.max_parent_w or DEFAULT_CONFIG.max_parent_w,
      max_parent_h = opts.max_parent_h or DEFAULT_CONFIG.max_parent_h,
      grid_size = opts.grid_size or DEFAULT_CONFIG.grid_size,
      show_grid = opts.show_grid ~= false,
      show_attachments = opts.show_attachments ~= false,
      handle_size = opts.handle_size or DEFAULT_CONFIG.handle_size,
      element_handle_size = DEFAULT_CONFIG.element_handle_size,
      element_edge_threshold = DEFAULT_CONFIG.element_edge_threshold,
    },

    -- Interaction state
    dragging = nil,  -- nil, 'right', 'bottom', 'corner', 'width', 'track_height', 'element_move', 'element_resize_*'
    drag_start_w = 0,
    drag_start_h = 0,
    drag_start_x = 0,
    drag_start_y = 0,
    drag_track = nil,  -- Track being resized

    -- Element drag state
    drag_element = nil,  -- Element being dragged
    drag_element_start_coords = nil,  -- Original coords before drag
    drag_element_start_rect = nil,  -- Computed rect at drag start

    -- Edit tracking
    modified_elements = {},  -- Track which elements have been modified

    -- Selection
    selected_element = nil,
    hovered_element = nil,
    selected_track = nil,
    hovered_track = nil,

    -- Elements to display
    elements = {},

    -- Tracks to display (for VIEW_TRACKS mode)
    tracks = {},

    -- Cached simulation results
    sim_cache = nil,
    sim_cache_w = 0,
    sim_cache_h = 0,

    -- Canvas offset (for centering/scrolling)
    offset_x = 20,
    offset_y = 20,

    -- Scroll offset for track view
    scroll_y = 0,

    -- Element renderer instance
    renderer = ElementRenderer.new(),

    -- Track renderer instance
    track_renderer = TrackRenderer.new(),
  }, Canvas)

  return self
end

-- Set elements to display
function Canvas:set_elements(elements)
  self.elements = elements
  self.sim_cache = nil  -- Invalidate cache
end

-- Set tracks to display
function Canvas:set_tracks(tracks)
  self.tracks = tracks or {}
end

-- Set selected element
function Canvas:set_selected(element)
  self.selected_element = element
end

-- Set selected track
function Canvas:set_selected_track(track)
  self.selected_track = track
end

-- Set view mode
function Canvas:set_view_mode(mode)
  self.view_mode = mode
end

-- Get view mode
function Canvas:get_view_mode()
  return self.view_mode
end

-- Get simulation results (cached)
function Canvas:get_simulation()
  if self.sim_cache and self.sim_cache_w == self.parent_w and self.sim_cache_h == self.parent_h then
    return self.sim_cache
  end

  self.sim_cache = Simulator.simulate(self.elements, self.parent_w, self.parent_h)
  self.sim_cache_w = self.parent_w
  self.sim_cache_h = self.parent_h

  return self.sim_cache
end

-- Draw grid lines
function Canvas:draw_grid(ctx, dl, canvas_x, canvas_y)
  if not self.config.show_grid then return end

  local grid = self.config.grid_size
  local w, h = self.parent_w, self.parent_h

  -- Minor grid lines
  for x = grid, w - 1, grid do
    local px = canvas_x + x
    ImGui.DrawList_AddLine(dl, px, canvas_y, px, canvas_y + h, Colors.CANVAS.GRID, 1)
  end
  for y = grid, h - 1, grid do
    local py = canvas_y + y
    ImGui.DrawList_AddLine(dl, canvas_x, py, canvas_x + w, py, Colors.CANVAS.GRID, 1)
  end

  -- Major grid lines (every 50px)
  for x = 50, w - 1, 50 do
    local px = canvas_x + x
    ImGui.DrawList_AddLine(dl, px, canvas_y, px, canvas_y + h, Colors.CANVAS.GRID_MAJOR, 1)
  end
  for y = 50, h - 1, 50 do
    local py = canvas_y + y
    ImGui.DrawList_AddLine(dl, canvas_x, py, canvas_x + w, py, Colors.CANVAS.GRID_MAJOR, 1)
  end
end

-- Draw resize handles
function Canvas:draw_handles(ctx, dl, canvas_x, canvas_y)
  local w, h = self.parent_w, self.parent_h
  local hs = self.config.handle_size

  -- Right edge handle
  local right_handle = {
    x = canvas_x + w - hs/2,
    y = canvas_y + h/2 - hs,
    w = hs,
    h = hs * 2,
  }

  -- Bottom edge handle
  local bottom_handle = {
    x = canvas_x + w/2 - hs,
    y = canvas_y + h - hs/2,
    w = hs * 2,
    h = hs,
  }

  -- Corner handle
  local corner_handle = {
    x = canvas_x + w - hs,
    y = canvas_y + h - hs,
    w = hs,
    h = hs,
  }

  -- Determine colors based on drag state
  local right_color = self.dragging == 'right' and Colors.CANVAS.HANDLE_ACTIVE or Colors.CANVAS.HANDLE_NORMAL
  local bottom_color = self.dragging == 'bottom' and Colors.CANVAS.HANDLE_ACTIVE or Colors.CANVAS.HANDLE_NORMAL
  local corner_color = self.dragging == 'corner' and Colors.CANVAS.HANDLE_ACTIVE or Colors.CANVAS.HANDLE_NORMAL

  -- Draw handles
  ImGui.DrawList_AddRectFilled(dl,
    right_handle.x, right_handle.y,
    right_handle.x + right_handle.w, right_handle.y + right_handle.h,
    right_color, 2)

  ImGui.DrawList_AddRectFilled(dl,
    bottom_handle.x, bottom_handle.y,
    bottom_handle.x + bottom_handle.w, bottom_handle.y + bottom_handle.h,
    bottom_color, 2)

  ImGui.DrawList_AddRectFilled(dl,
    corner_handle.x, corner_handle.y,
    corner_handle.x + corner_handle.w, corner_handle.y + corner_handle.h,
    corner_color, 2)

  return {
    right = right_handle,
    bottom = bottom_handle,
    corner = corner_handle,
  }
end

-- Check if point is in handle
local function point_in_rect(px, py, rect)
  return px >= rect.x and px <= rect.x + rect.w
     and py >= rect.y and py <= rect.y + rect.h
end

-- Determine which part of an element was clicked (for resize vs move)
-- Returns: nil (outside), 'move' (interior), 'resize_e', 'resize_s', 'resize_se', 'resize_w', 'resize_n', etc.
local function get_element_hit_zone(px, py, rect, threshold)
  if not rect or rect.w <= 0 or rect.h <= 0 then return nil end

  local in_bounds = px >= rect.x and px <= rect.x + rect.w
                and py >= rect.y and py <= rect.y + rect.h

  if not in_bounds then return nil end

  local on_left = px < rect.x + threshold
  local on_right = px > rect.x + rect.w - threshold
  local on_top = py < rect.y + threshold
  local on_bottom = py > rect.y + rect.h - threshold

  -- Corners first (priority over edges)
  if on_bottom and on_right then return 'resize_se' end
  if on_bottom and on_left then return 'resize_sw' end
  if on_top and on_right then return 'resize_ne' end
  if on_top and on_left then return 'resize_nw' end

  -- Edges
  if on_right then return 'resize_e' end
  if on_left then return 'resize_w' end
  if on_bottom then return 'resize_s' end
  if on_top then return 'resize_n' end

  -- Interior = move
  return 'move'
end

-- Get cursor style for a hit zone
local function get_cursor_for_zone(zone)
  if not zone then return nil end
  local cursors = {
    move = ImGui.MouseCursor_Hand,
    resize_e = ImGui.MouseCursor_ResizeEW,
    resize_w = ImGui.MouseCursor_ResizeEW,
    resize_n = ImGui.MouseCursor_ResizeNS,
    resize_s = ImGui.MouseCursor_ResizeNS,
    resize_ne = ImGui.MouseCursor_ResizeNESW,
    resize_sw = ImGui.MouseCursor_ResizeNESW,
    resize_nw = ImGui.MouseCursor_ResizeNWSE,
    resize_se = ImGui.MouseCursor_ResizeNWSE,
  }
  return cursors[zone]
end

-- Draw element resize handles on selected element
function Canvas:draw_element_handles(ctx, dl, canvas_x, canvas_y, rect)
  local hs = self.config.element_handle_size
  local half = hs / 2

  -- Handle positions (centered on edges and corners)
  local handles = {
    -- Corners
    { x = rect.x - half, y = rect.y - half },                     -- NW
    { x = rect.x + rect.w - half, y = rect.y - half },           -- NE
    { x = rect.x - half, y = rect.y + rect.h - half },           -- SW
    { x = rect.x + rect.w - half, y = rect.y + rect.h - half }, -- SE
    -- Edge centers
    { x = rect.x + rect.w / 2 - half, y = rect.y - half },       -- N
    { x = rect.x + rect.w / 2 - half, y = rect.y + rect.h - half }, -- S
    { x = rect.x - half, y = rect.y + rect.h / 2 - half },       -- W
    { x = rect.x + rect.w - half, y = rect.y + rect.h / 2 - half }, -- E
  }

  -- Draw handles (white fill with dark border)
  for _, h in ipairs(handles) do
    ImGui.DrawList_AddRectFilled(dl,
      canvas_x + h.x, canvas_y + h.y,
      canvas_x + h.x + hs, canvas_y + h.y + hs,
      0xFFFFFFFF, 1)
    ImGui.DrawList_AddRect(dl,
      canvas_x + h.x, canvas_y + h.y,
      canvas_x + h.x + hs, canvas_y + h.y + hs,
      0x000000FF, 1, 0, 1)
  end
end

-- Apply drag delta to element coordinates
function Canvas:apply_element_drag(drag_type, dx, dy)
  if not self.drag_element or not self.drag_element_start_coords then return end

  local coords = self.drag_element.coords
  local start = self.drag_element_start_coords

  -- Snap to grid if enabled
  local snap = self.config.grid_size
  local snap_dx = math.floor(dx / snap + 0.5) * snap
  local snap_dy = math.floor(dy / snap + 0.5) * snap

  if drag_type == 'element_move' then
    -- Move: update x and y
    coords.x = start.x + snap_dx
    coords.y = start.y + snap_dy

  elseif drag_type == 'element_resize_e' then
    -- East: extend width
    coords.w = math.max(5, start.w + snap_dx)

  elseif drag_type == 'element_resize_w' then
    -- West: move left edge, adjust width
    coords.x = start.x + snap_dx
    coords.w = math.max(5, start.w - snap_dx)

  elseif drag_type == 'element_resize_s' then
    -- South: extend height
    coords.h = math.max(5, start.h + snap_dy)

  elseif drag_type == 'element_resize_n' then
    -- North: move top edge, adjust height
    coords.y = start.y + snap_dy
    coords.h = math.max(5, start.h - snap_dy)

  elseif drag_type == 'element_resize_se' then
    -- Southeast: extend both
    coords.w = math.max(5, start.w + snap_dx)
    coords.h = math.max(5, start.h + snap_dy)

  elseif drag_type == 'element_resize_nw' then
    -- Northwest: move both edges
    coords.x = start.x + snap_dx
    coords.y = start.y + snap_dy
    coords.w = math.max(5, start.w - snap_dx)
    coords.h = math.max(5, start.h - snap_dy)

  elseif drag_type == 'element_resize_ne' then
    -- Northeast
    coords.y = start.y + snap_dy
    coords.w = math.max(5, start.w + snap_dx)
    coords.h = math.max(5, start.h - snap_dy)

  elseif drag_type == 'element_resize_sw' then
    -- Southwest
    coords.x = start.x + snap_dx
    coords.w = math.max(5, start.w - snap_dx)
    coords.h = math.max(5, start.h + snap_dy)
  end

  -- Mark as modified
  self.modified_elements[self.drag_element.id] = true

  -- Invalidate simulation cache
  self.sim_cache = nil
end

-- Check if an element has been modified
function Canvas:is_element_modified(element)
  return self.modified_elements[element.id] == true
end

-- Get all modified elements
function Canvas:get_modified_elements()
  local modified = {}
  for _, elem in ipairs(self.elements) do
    if self.modified_elements[elem.id] then
      modified[#modified + 1] = elem
    end
  end
  return modified
end

-- Clear modification tracking
function Canvas:clear_modifications()
  self.modified_elements = {}
end

-- Handle mouse interaction
function Canvas:handle_interaction(ctx, canvas_x, canvas_y, handles)
  local mx, my = ImGui.GetMousePos(ctx)
  local rel_x = mx - canvas_x
  local rel_y = my - canvas_y
  local result = nil

  -- Get simulation for hit testing
  local sim = self:get_simulation()

  -- Find selected element's current rect (if any)
  local selected_rect = nil
  if self.selected_element then
    for _, sim_result in ipairs(sim) do
      if sim_result.element == self.selected_element then
        selected_rect = sim_result.rect
        break
      end
    end
  end

  -- Check for drag start
  if ImGui.IsMouseClicked(ctx, 0) then
    -- First check canvas resize handles
    if point_in_rect(mx, my, handles.corner) then
      self.dragging = 'corner'
      self.drag_start_w = self.parent_w
      self.drag_start_h = self.parent_h
      self.drag_start_x = mx
      self.drag_start_y = my
    elseif point_in_rect(mx, my, handles.right) then
      self.dragging = 'right'
      self.drag_start_w = self.parent_w
      self.drag_start_x = mx
    elseif point_in_rect(mx, my, handles.bottom) then
      self.dragging = 'bottom'
      self.drag_start_h = self.parent_h
      self.drag_start_y = my

    -- Check if clicking on selected element (for drag/resize)
    elseif selected_rect and self.selected_element then
      local zone = get_element_hit_zone(rel_x, rel_y, selected_rect, self.config.element_edge_threshold)
      if zone then
        -- Start element drag
        if zone == 'move' then
          self.dragging = 'element_move'
        else
          self.dragging = 'element_' .. zone  -- e.g., 'element_resize_se'
        end
        self.drag_element = self.selected_element
        self.drag_element_start_coords = {
          x = self.selected_element.coords.x,
          y = self.selected_element.coords.y,
          w = self.selected_element.coords.w,
          h = self.selected_element.coords.h,
        }
        self.drag_element_start_rect = {
          x = selected_rect.x,
          y = selected_rect.y,
          w = selected_rect.w,
          h = selected_rect.h,
        }
        self.drag_start_x = mx
        self.drag_start_y = my
      else
        -- Clicked outside selected element - try to select another
        if rel_x >= 0 and rel_x <= self.parent_w and rel_y >= 0 and rel_y <= self.parent_h then
          local clicked = Simulator.hit_test(sim, rel_x, rel_y)
          if clicked then
            self.selected_element = clicked
            result = { type = 'select', element = clicked }
          else
            self.selected_element = nil
            result = { type = 'deselect' }
          end
        end
      end

    -- No element selected - check for element selection
    else
      if rel_x >= 0 and rel_x <= self.parent_w and rel_y >= 0 and rel_y <= self.parent_h then
        local clicked = Simulator.hit_test(sim, rel_x, rel_y)
        if clicked then
          self.selected_element = clicked
          result = { type = 'select', element = clicked }
        else
          -- Clicked empty space - deselect
          self.selected_element = nil
          result = { type = 'deselect' }
        end
      end
    end
  end

  -- Handle dragging
  if self.dragging and ImGui.IsMouseDown(ctx, 0) then
    local dx = mx - self.drag_start_x
    local dy = my - self.drag_start_y

    -- Canvas resize
    if self.dragging == 'right' or self.dragging == 'corner' then
      local new_w = self.drag_start_w + dx
      new_w = math.max(self.config.min_parent_w, math.min(self.config.max_parent_w, new_w))
      self.parent_w = math.floor(new_w)
      self.sim_cache = nil
    end

    if self.dragging == 'bottom' or self.dragging == 'corner' then
      local new_h = self.drag_start_h + dy
      new_h = math.max(self.config.min_parent_h, math.min(self.config.max_parent_h, new_h))
      self.parent_h = math.floor(new_h)
      self.sim_cache = nil
    end

    -- Element drag/resize
    if self.dragging:match('^element_') then
      self:apply_element_drag(self.dragging, dx, dy)
      result = { type = 'element_modified', element = self.drag_element }
    end
  end

  -- End dragging
  if ImGui.IsMouseReleased(ctx, 0) then
    if self.dragging and self.dragging:match('^element_') and self.drag_element then
      result = { type = 'element_drag_end', element = self.drag_element }
    end
    self.dragging = nil
    self.drag_element = nil
    self.drag_element_start_coords = nil
    self.drag_element_start_rect = nil
  end

  -- Update hovered element and cursor
  if rel_x >= 0 and rel_x <= self.parent_w and rel_y >= 0 and rel_y <= self.parent_h then
    self.hovered_element = Simulator.hit_test(sim, rel_x, rel_y)

    -- Set cursor based on what we're hovering over
    if selected_rect and not self.dragging then
      local zone = get_element_hit_zone(rel_x, rel_y, selected_rect, self.config.element_edge_threshold)
      local cursor = get_cursor_for_zone(zone)
      if cursor then
        ImGui.SetMouseCursor(ctx, cursor)
      end
    end
  else
    self.hovered_element = nil
  end

  return result
end

-- Draw track list view with resize handles
function Canvas:draw_tracks_view(ctx, dl, win_x, win_y, win_w, win_h)
  local result = nil
  local hs = self.config.handle_size  -- Handle size

  -- Calculate total height needed for all tracks
  local total_height = 0
  for _, track in ipairs(self.tracks) do
    if track.visible then
      total_height = total_height + track.height
    end
  end

  -- Canvas position (left-aligned with padding, scrollable vertically)
  local canvas_x = win_x + 20
  local canvas_y = win_y + 10 - self.scroll_y
  local visible_top = win_y + 10
  local visible_bottom = win_y + win_h - 10

  -- Draw tracks and collect resize handle positions
  local track_y = canvas_y
  local track_handles = {}  -- Store track bottom handles for interaction

  for i, track in ipairs(self.tracks) do
    if track.visible then
      local is_selected = (track == self.selected_track)
      local track_bottom = track_y + track.height

      -- Only draw if track is visible in the scrollable area
      if track_bottom > visible_top and track_y < visible_bottom then
        -- Draw track background and info
        self.track_renderer:draw_track(ctx, dl, canvas_x, track_y, self.parent_w, track, {
          selected = is_selected,
          index = i,
        })

        -- Draw elements within this track
        local sim = Simulator.simulate(self.elements, self.parent_w, track.height)
        local track_selected_rect = nil
        for _, sim_result in ipairs(sim) do
          local elem_is_selected = sim_result.element == self.selected_element and is_selected
          local elem_is_hovered = sim_result.element == self.hovered_element
          local is_modified = self:is_element_modified(sim_result.element)

          -- Offset element by track position
          local offset_result = {
            element = sim_result.element,
            rect = {
              x = sim_result.rect.x,
              y = sim_result.rect.y,
              w = sim_result.rect.w,
              h = sim_result.rect.h,
            },
            h_behavior = sim_result.h_behavior,
            v_behavior = sim_result.v_behavior,
          }

          self.renderer:draw_element(ctx, dl, canvas_x, track_y, offset_result, {
            selected = elem_is_selected,
            hovered = elem_is_hovered,
            show_attachments = self.config.show_attachments,
            modified = is_modified,
          })

          -- Track selected element's rect for handles (in track-relative coords)
          if elem_is_selected and sim_result.rect.w > 0 and sim_result.rect.h > 0 then
            track_selected_rect = {
              x = sim_result.rect.x,
              y = sim_result.rect.y,
              w = sim_result.rect.w,
              h = sim_result.rect.h,
              track_y = track_y,  -- Store track Y for absolute positioning
            }
          end
        end

        -- Draw resize handles on selected element (if in this track)
        if track_selected_rect then
          self:draw_element_handles(ctx, dl, canvas_x, track_selected_rect.track_y, track_selected_rect)
        end

        -- Track height resize handle (bottom edge, center)
        local track_handle = {
          x = canvas_x + self.parent_w / 2 - hs,
          y = track_bottom - hs / 2,
          w = hs * 2,
          h = hs,
          track = track,
          track_index = i,
        }
        track_handles[#track_handles + 1] = track_handle

        -- Draw track height handle
        local handle_color = (self.dragging == 'track_height' and self.drag_track == track)
                           and Colors.CANVAS.HANDLE_ACTIVE or Colors.CANVAS.HANDLE_NORMAL
        ImGui.DrawList_AddRectFilled(dl,
          track_handle.x, track_handle.y,
          track_handle.x + track_handle.w, track_handle.y + track_handle.h,
          handle_color, 2)
      end

      track_y = track_y + track.height
    end
  end

  -- Width resize handle (right edge of track list, vertically centered)
  local list_height = math.min(total_height, win_h - 20)
  local width_handle = {
    x = canvas_x + self.parent_w - hs / 2,
    y = win_y + 10 + list_height / 2 - hs,
    w = hs,
    h = hs * 2,
  }

  -- Draw width resize handle
  local width_handle_color = (self.dragging == 'width')
                           and Colors.CANVAS.HANDLE_ACTIVE or Colors.CANVAS.HANDLE_NORMAL
  ImGui.DrawList_AddRectFilled(dl,
    width_handle.x, width_handle.y,
    width_handle.x + width_handle.w, width_handle.y + width_handle.h,
    width_handle_color, 2)

  -- Handle mouse interaction
  local mx, my = ImGui.GetMousePos(ctx)
  local rel_x = mx - canvas_x
  local rel_y = my - canvas_y + self.scroll_y

  -- Find which track the mouse is in and get simulation for it
  local mouse_track = nil
  local mouse_track_top = 0
  local mouse_track_sim = nil
  local track_search_top = 0
  for _, track in ipairs(self.tracks) do
    if track.visible then
      if rel_y >= track_search_top and rel_y < track_search_top + track.height then
        mouse_track = track
        mouse_track_top = track_search_top
        mouse_track_sim = Simulator.simulate(self.elements, self.parent_w, track.height)
        break
      end
      track_search_top = track_search_top + track.height
    end
  end

  -- Find selected element's rect in current track context (for drag/resize detection)
  local selected_rect_screen = nil
  if self.selected_element and self.selected_track then
    local track_sim = Simulator.simulate(self.elements, self.parent_w, self.selected_track.height)
    for _, sim_result in ipairs(track_sim) do
      if sim_result.element == self.selected_element then
        -- Find where this track is rendered
        local sel_track_y = 0
        for _, t in ipairs(self.tracks) do
          if t == self.selected_track then break end
          if t.visible then sel_track_y = sel_track_y + t.height end
        end
        -- Convert to mouse-relative coordinates (accounting for scroll)
        selected_rect_screen = {
          x = sim_result.rect.x,
          y = sim_result.rect.y + sel_track_y,
          w = sim_result.rect.w,
          h = sim_result.rect.h,
        }
        break
      end
    end
  end

  -- Check for drag start
  if ImGui.IsMouseClicked(ctx, 0) then
    -- First check canvas resize handles
    if point_in_rect(mx, my, width_handle) then
      self.dragging = 'width'
      self.drag_start_w = self.parent_w
      self.drag_start_x = mx

    -- Then check if clicking on selected element (for drag/resize)
    elseif selected_rect_screen and self.selected_element then
      local zone = get_element_hit_zone(rel_x, rel_y, selected_rect_screen, self.config.element_edge_threshold)
      if zone then
        -- Start element drag
        if zone == 'move' then
          self.dragging = 'element_move'
        else
          self.dragging = 'element_' .. zone
        end
        self.drag_element = self.selected_element
        self.drag_element_start_coords = {
          x = self.selected_element.coords.x,
          y = self.selected_element.coords.y,
          w = self.selected_element.coords.w,
          h = self.selected_element.coords.h,
        }
        self.drag_start_x = mx
        self.drag_start_y = my
      else
        -- Clicked outside selected element - check for new selection
        if rel_x >= 0 and rel_x <= self.parent_w and mouse_track then
          self.selected_track = mouse_track
          local track_rel_y = rel_y - mouse_track_top
          local clicked_elem = Simulator.hit_test(mouse_track_sim, rel_x, track_rel_y)
          if clicked_elem then
            self.selected_element = clicked_elem
            result = { type = 'select', element = clicked_elem, track = mouse_track }
          else
            self.selected_element = nil
            result = { type = 'select_track', track = mouse_track }
          end
        end
      end

    else
      -- Check track height handles
      local handle_hit = false
      for _, handle in ipairs(track_handles) do
        if point_in_rect(mx, my, handle) then
          self.dragging = 'track_height'
          self.drag_track = handle.track
          self.drag_start_h = handle.track.height
          self.drag_start_y = my
          handle_hit = true
          break
        end
      end

      -- If no handle hit, check for track/element selection
      if not handle_hit and rel_x >= 0 and rel_x <= self.parent_w and mouse_track then
        self.selected_track = mouse_track
        result = { type = 'select_track', track = mouse_track }

        -- Check for element within track
        local track_rel_y = rel_y - mouse_track_top
        local clicked_elem = Simulator.hit_test(mouse_track_sim, rel_x, track_rel_y)
        if clicked_elem then
          self.selected_element = clicked_elem
          result = { type = 'select', element = clicked_elem, track = mouse_track }
        else
          -- Clicked empty space in track - deselect element
          self.selected_element = nil
        end
      end
    end
  end

  -- Handle dragging
  if self.dragging and ImGui.IsMouseDown(ctx, 0) then
    local dx = mx - self.drag_start_x
    local dy = my - self.drag_start_y

    if self.dragging == 'width' then
      local new_w = self.drag_start_w + dx
      new_w = math.max(self.config.min_parent_w, math.min(self.config.max_parent_w, new_w))
      self.parent_w = math.floor(new_w)
      result = { type = 'resize_width', width = self.parent_w }

    elseif self.dragging == 'track_height' and self.drag_track then
      local new_h = self.drag_start_h + dy
      new_h = math.max(25, math.min(200, new_h))
      self.drag_track.height = math.floor(new_h)
      result = { type = 'resize_track', track = self.drag_track, height = self.drag_track.height }

    elseif self.dragging:match('^element_') then
      self:apply_element_drag(self.dragging, dx, dy)
      result = { type = 'element_modified', element = self.drag_element }
    end
  end

  -- End dragging
  if ImGui.IsMouseReleased(ctx, 0) then
    if self.dragging and self.dragging:match('^element_') and self.drag_element then
      result = { type = 'element_drag_end', element = self.drag_element }
    end
    self.dragging = nil
    self.drag_track = nil
    self.drag_element = nil
    self.drag_element_start_coords = nil
  end

  -- Update cursor based on what we're hovering over
  if selected_rect_screen and not self.dragging then
    local zone = get_element_hit_zone(rel_x, rel_y, selected_rect_screen, self.config.element_edge_threshold)
    local cursor = get_cursor_for_zone(zone)
    if cursor then
      ImGui.SetMouseCursor(ctx, cursor)
    end
  end

  -- Handle mouse scroll
  local wheel = ImGui.GetMouseWheel(ctx)
  if wheel ~= 0 then
    local scroll_speed = 30
    self.scroll_y = math.max(0, math.min(total_height - win_h + 40, self.scroll_y - wheel * scroll_speed))
  end

  -- Draw border around the track list area
  ImGui.DrawList_AddRect(dl,
    canvas_x, win_y + 10,
    canvas_x + self.parent_w, win_y + 10 + list_height,
    Colors.CANVAS.PARENT_BORDER, 0, 0, 1)

  return result
end

-- Main draw function
function Canvas:draw(ctx)
  local result = nil

  -- Get available space
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local canvas_h = math.max(200, avail_h - 40)  -- Leave room for size display

  -- Begin child region for canvas (no window moving/scrolling)
  -- child_flags: 1 = border, window_flags: NoScrollbar | NoScrollWithMouse | NoMove
  local window_flags = ImGui.WindowFlags_NoScrollbar
                     | ImGui.WindowFlags_NoScrollWithMouse
                     | ImGui.WindowFlags_NoMove
                     | ImGui.WindowFlags_NoNav

  ImGui.BeginChild(ctx, 'walter_canvas', avail_w, canvas_h, 1, window_flags)

  local win_x, win_y = ImGui.GetWindowPos(ctx)
  local win_w, win_h = ImGui.GetWindowSize(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, win_x, win_y, win_x + win_w, win_y + win_h,
    Colors.CANVAS.BACKGROUND)

  -- Draw based on view mode
  if self.view_mode == M.VIEW_TRACKS and #self.tracks > 0 then
    result = self:draw_tracks_view(ctx, dl, win_x, win_y, win_w, win_h)
  else
    -- Single track view (original behavior)
    -- Calculate canvas position (centered in the child window)
    local canvas_x = win_x + math.max(20, (win_w - self.parent_w) / 2)
    local canvas_y = win_y + math.max(20, (win_h - self.parent_h) / 2)

    -- Draw parent container background
    ImGui.DrawList_AddRectFilled(dl,
      canvas_x, canvas_y,
      canvas_x + self.parent_w, canvas_y + self.parent_h,
      Colors.CANVAS.PARENT_FILL)

    -- Draw grid
    self:draw_grid(ctx, dl, canvas_x, canvas_y)

    -- Draw elements
    local sim = self:get_simulation()
    local selected_rect = nil
    for _, sim_result in ipairs(sim) do
      local is_selected = sim_result.element == self.selected_element
      local is_hovered = sim_result.element == self.hovered_element
      local is_modified = self:is_element_modified(sim_result.element)

      self.renderer:draw_element(ctx, dl, canvas_x, canvas_y, sim_result, {
        selected = is_selected,
        hovered = is_hovered,
        show_attachments = self.config.show_attachments,
        modified = is_modified,
      })

      -- Track selected element's rect for drawing handles
      if is_selected then
        selected_rect = sim_result.rect
      end
    end

    -- Draw resize handles on selected element
    if selected_rect and selected_rect.w > 0 and selected_rect.h > 0 then
      self:draw_element_handles(ctx, dl, canvas_x, canvas_y, selected_rect)
    end

    -- Draw parent container border
    ImGui.DrawList_AddRect(dl,
      canvas_x, canvas_y,
      canvas_x + self.parent_w, canvas_y + self.parent_h,
      Colors.CANVAS.PARENT_BORDER, 0, 0, 2)

    -- Draw resize handles
    local handles = self:draw_handles(ctx, dl, canvas_x, canvas_y)

    -- Handle mouse interaction (only for handles and element selection)
    result = self:handle_interaction(ctx, canvas_x, canvas_y, handles)
  end

  ImGui.EndChild(ctx)

  -- Draw controls below canvas
  ImGui.Text(ctx, string.format('TCP Width: %d px', self.parent_w))

  -- Show selected track height in tracks view
  if self.view_mode == M.VIEW_TRACKS and self.selected_track then
    ImGui.SameLine(ctx, 0, 15)
    ImGui.Text(ctx, string.format('Track: %s  H: %d px', self.selected_track.name, self.selected_track.height))
  elseif self.view_mode == M.VIEW_SINGLE then
    ImGui.SameLine(ctx, 0, 15)
    ImGui.Text(ctx, string.format('H: %d px', self.parent_h))
  end

  ImGui.SameLine(ctx, 0, 20)

  -- View mode toggle
  if ImGui.Button(ctx, self.view_mode == M.VIEW_TRACKS and 'Tracks' or 'Single', 60, 0) then
    self.view_mode = (self.view_mode == M.VIEW_TRACKS) and M.VIEW_SINGLE or M.VIEW_TRACKS
  end

  ImGui.SameLine(ctx, 0, 10)

  -- Toggle buttons
  local _, show_grid = ImGui.Checkbox(ctx, 'Grid', self.config.show_grid)
  self.config.show_grid = show_grid

  ImGui.SameLine(ctx)
  local _, show_attach = ImGui.Checkbox(ctx, 'Attachments', self.config.show_attachments)
  self.config.show_attachments = show_attach

  return result
end

-- Get current parent dimensions
function Canvas:get_parent_size()
  return self.parent_w, self.parent_h
end

-- Set parent dimensions
function Canvas:set_parent_size(w, h)
  self.parent_w = math.max(self.config.min_parent_w, math.min(self.config.max_parent_w, w))
  self.parent_h = math.max(self.config.min_parent_h, math.min(self.config.max_parent_h, h))
  self.sim_cache = nil
end

return M
