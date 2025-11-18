-- @noindex
-- ReArkitekt/gui/widgets/grid/core.lua
-- Main grid orchestrator - composes rendering, animation, and input modules
-- UPDATED: Now handles extended input areas (padding zones)
-- FIXED: Tiles outside grid bounds are no longer interactive or rendered
-- FIXED: Respects parent panel scrollable bounds

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local LayoutGrid = require('rearkitekt.gui.widgets.containers.grid.layout')
local Tracks = require('rearkitekt.gui.fx.animation.tracks')
local RectTrack = Tracks.RectTrack
local Colors = require('rearkitekt.core.colors')
local Selection  = require('rearkitekt.gui.systems.selection')
local SelRect    = require('rearkitekt.gui.widgets.data.selection_rectangle')
local Draw       = require('rearkitekt.gui.draw')
local Dnd = require('rearkitekt.gui.fx.interactions.dnd')
local DragIndicator = Dnd.DragIndicator
local DropIndicator = Dnd.DropIndicator
local Rendering  = require('rearkitekt.gui.widgets.containers.grid.rendering')
local Animation  = require('rearkitekt.gui.widgets.containers.grid.animation')
local Input      = require('rearkitekt.gui.widgets.containers.grid.input')
local DnDState   = require('rearkitekt.gui.widgets.containers.grid.dnd_state')
local DropZones  = require('rearkitekt.gui.widgets.containers.grid.drop_zones')

local M = {}
local hexrgb = Colors.hexrgb

local DEFAULTS = {
  layout = { speed = 14.0, snap_epsilon = 0.5 },
  drag = { threshold = 6 },
  
  spawn = {
    enabled = true,
    duration = 0.28,
  },
  
  destroy = {
    enabled = true,
  },
  
  marquee = {
    drag_threshold = 3,
    fill_color = hexrgb("#FFFFFF22"),
    fill_color_add = hexrgb("#FFFFFF33"),
    stroke_color = hexrgb("#FFFFFF"),
    stroke_thickness = 1,
    rounding = 0,
  },

  dim = {
    fill_color = hexrgb("#00000088"),
    stroke_color = hexrgb("#FFFFFF33"),
    stroke_thickness = 1.5,
    rounding = 6,
  },
  
  drop = {
    line = {
      width = 2,
      color = hexrgb("#42E896"),
      glow_width = 12,
      glow_color = hexrgb("#42E89633"),
    },
    caps = {
      width = 8,
      height = 3,
      color = hexrgb("#42E896"),
      rounding = 0,
      glow_size = 3,
      glow_color = hexrgb("#42E89644"),
    },
    pulse_speed = 2.5,
  },
  
  wheel = {
    step = 1,
  },
  
  tile_helpers = {
    hover_shadow = {
      enabled = true,
      max_offset = 2,
      max_alpha = 20,
    },
    selection = {
      ant_speed = 20,
      ant_dash = 8,
      ant_gap = 6,
      brightness_factor = 1.5,
      saturation_factor = 0.5,
    },
  },
}

M.TileHelpers = Rendering.TileHelpers

local Grid = {}
Grid.__index = Grid

function M.new(opts)
  opts = opts or {}

  local grid_id = opts.id or "grid"

  local grid = setmetatable({
    id               = grid_id,
    gap              = opts.gap or 12,
    min_col_w_fn     = type(opts.min_col_w) == "function" and opts.min_col_w or function() return opts.min_col_w or 160 end,
    fixed_tile_h     = opts.fixed_tile_h,
    get_items        = opts.get_items or function() return {} end,
    key              = opts.key or function(item) return tostring(item) end,
    get_exclusion_zones = opts.get_exclusion_zones,

    behaviors        = opts.behaviors or {},
    render_tile      = opts.render_tile or function() end,
    render_overlays  = opts.render_overlays,

    external_drag_check = opts.external_drag_check,
    is_copy_mode_check = opts.is_copy_mode_check,
    accept_external_drops = opts.accept_external_drops or false,
    render_drop_zones = opts.render_drop_zones or true,
    on_external_drop = opts.on_external_drop,
    on_destroy_complete = opts.on_destroy_complete,
    on_click_empty   = opts.on_click_empty,

    extend_input_area = opts.extend_input_area or { left = 0, right = 0, top = 0, bottom = 0 },
    clip_rendering = opts.clip_rendering or false,

    config           = opts.config or DEFAULTS,

    selection        = Selection.new(),
    rect_track       = RectTrack.new(
      opts.layout_speed or DEFAULTS.layout.speed,
      opts.layout_snap or DEFAULTS.layout.snap_epsilon
    ),
    sel_rect         = SelRect.new(),
    animator         = Animation.new({
      spawn = opts.config and opts.config.spawn or DEFAULTS.spawn,
      destroy = opts.config and opts.config.destroy or DEFAULTS.destroy,
      on_destroy_complete = opts.on_destroy_complete,
    }),

    hover_id         = nil,
    current_rects    = {},
    drag             = DnDState.new({
      threshold = (opts.config and opts.config.drag and opts.config.drag.threshold) or DEFAULTS.drag.threshold
    }),
    external_drop_target = nil,
    last_window_pos  = nil,
    previous_item_keys = {},

    last_layout_cols = 1,
    grid_bounds = nil,
    visual_bounds = nil,
    panel_clip_bounds = nil,

    -- Cache string IDs for performance (avoid string concatenation every frame)
    _cached_bg_id = "##grid_bg_" .. grid_id,
    _cached_empty_id = "##grid_empty_" .. grid_id,
  }, Grid)

  grid.animator:set_rect_track(grid.rect_track)

  return grid
end

function Grid:_is_mouse_in_bounds(ctx)
  if not self.visual_bounds then return false end
  local mx, my = ImGui.GetMousePos(ctx)
  return mx >= self.visual_bounds[1] and mx < self.visual_bounds[3] and
         my >= self.visual_bounds[2] and my < self.visual_bounds[4]
end

function Grid:_rect_intersects_bounds(rect, buffer)
  if not self.visual_bounds then return true end
  local gb = self.visual_bounds
  local buff = buffer or 0

  -- Expand bounds by buffer for smoother scrolling (pre-render items about to be visible)
  return not (rect[3] < (gb[1] - buff) or
              rect[1] > (gb[3] + buff) or
              rect[4] < (gb[2] - buff) or
              rect[2] > (gb[4] + buff))
end

function Grid:_find_drop_target(ctx, mx, my, dragged_set, items)
  return DropZones.find_drop_target(mx, my, items, self.key, dragged_set, self.rect_track, self.last_layout_cols == 1, self.visual_bounds)
end

function Grid:_update_external_drop_target(ctx)
  self.external_drop_target = nil
  
  if not self.accept_external_drops then return end
  if not Input.is_external_drag_active(self) then return end
  if not self:_is_mouse_in_bounds(ctx) then return end

  local mx, my = ImGui.GetMousePos(ctx)
  local items = self.get_items()
  
  local target_index, coord, alt1, alt2, orientation = self:_find_drop_target(ctx, mx, my, {}, items)
  
  if target_index and coord then
    self.external_drop_target = {
      index = target_index,
      coord = coord,
      alt1 = alt1,
      alt2 = alt2,
      orientation = orientation,
    }
  end
end

function Grid:_draw_drag_visuals(ctx, dl)
  local mx, my = ImGui.GetMousePos(ctx)
  local dragged_ids = self.drag:get_dragged_ids()
  local dragged_set = DropZones.build_dragged_set(dragged_ids)

  local items = self.get_items()
  local target_index, coord, alt1, alt2, orientation = self:_find_drop_target(ctx, mx, my, dragged_set, items)

  local cfg = self.config

  -- Cache lengths for performance
  local num_items = #items
  local num_dragged = #dragged_ids
  local all_items_dragged = (num_items > 0) and (num_dragged == num_items) or false

  if all_items_dragged then
    self.drag:set_target(nil)
  else
    self.drag:set_target(target_index)
  end

  for i = 1, num_dragged do
    local id = dragged_ids[i]
    local r = self.rect_track:get(id)
    if r then
      local dim_fill = (cfg.dim and cfg.dim.fill_color) or DEFAULTS.dim.fill_color
      local dim_stroke = (cfg.dim and cfg.dim.stroke_color) or DEFAULTS.dim.stroke_color
      local dim_thickness = (cfg.dim and cfg.dim.stroke_thickness) or DEFAULTS.dim.stroke_thickness
      local dim_rounding = (cfg.dim and cfg.dim.rounding) or DEFAULTS.dim.rounding

      ImGui.DrawList_AddRectFilled(dl, r[1], r[2], r[3], r[4], dim_fill, dim_rounding)
      ImGui.DrawList_AddRect(dl, r[1]+0.5, r[2]+0.5, r[3]-0.5, r[4]-0.5, dim_stroke, dim_rounding, 0, dim_thickness)
    end
  end

  if (not all_items_dragged) and target_index and coord and alt1 and alt2 and orientation and self.render_drop_zones then
    local is_copy_mode = self.is_copy_mode_check and self.is_copy_mode_check() or false
    if orientation == 'horizontal' then
      DropIndicator.draw(ctx, dl, cfg.drop or DEFAULTS.drop, is_copy_mode, orientation, alt1, alt2, coord)
    else
      DropIndicator.draw(ctx, dl, cfg.drop or DEFAULTS.drop, is_copy_mode, orientation, coord, alt1, alt2)
    end
  end

  if num_dragged > 0 then
    local fg_dl = ImGui.GetForegroundDrawList(ctx)
    DragIndicator.draw(ctx, fg_dl, mx, my, num_dragged, cfg.ghost or DEFAULTS.ghost)
  end
end

function Grid:_draw_external_drop_visuals(ctx, dl)
  if not self.external_drop_target or not self.render_drop_zones then return end
  
  if not self:_is_mouse_in_bounds(ctx) then return end
  
  local cfg = self.config
  local is_copy_mode = self.is_copy_mode_check and self.is_copy_mode_check() or false
  
  if self.external_drop_target.orientation == 'horizontal' then
    DropIndicator.draw(
      ctx, dl,
      cfg.drop or DEFAULTS.drop,
      is_copy_mode,
      self.external_drop_target.orientation,
      self.external_drop_target.alt1,
      self.external_drop_target.alt2,
      self.external_drop_target.coord
    )
  else
    DropIndicator.draw(
      ctx, dl,
      cfg.drop or DEFAULTS.drop,
      is_copy_mode,
      self.external_drop_target.orientation,
      self.external_drop_target.coord,
      self.external_drop_target.alt1,
      self.external_drop_target.alt2
    )
  end
end

function Grid:_draw_marquee(ctx, dl)
  if not self.sel_rect:is_active() or not self.sel_rect.start_pos then return end
  
  local x1, y1, x2, y2 = self.sel_rect:aabb_visual()
  if not x1 then return end
  
  if not self.sel_rect:did_drag() then return end
  
  local cfg = self.config.marquee or DEFAULTS.marquee
  local fill = (self.sel_rect.mode == "add") and 
              (cfg.fill_color_add or DEFAULTS.marquee.fill_color_add) or
              (cfg.fill_color or DEFAULTS.marquee.fill_color)
  local stroke = cfg.stroke_color or DEFAULTS.marquee.stroke_color
  local thickness = cfg.stroke_thickness or DEFAULTS.marquee.stroke_thickness
  local rounding = cfg.rounding or DEFAULTS.marquee.rounding
  
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, fill, rounding)
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, stroke, rounding, 0, thickness)
end

function Grid:get_drop_target_index()
  if self.external_drop_target then
    return self.external_drop_target.index
  end
  return nil
end

function Grid:mark_spawned(keys)
  self.animator:mark_spawned(keys)
end

function Grid:mark_destroyed(keys)
  self.animator:mark_destroyed(keys)
end

function Grid:draw(ctx)
  local items = self.get_items()
  -- Cache table length for performance (avoid recalculating #items multiple times)
  local num_items = #items

  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local origin_x, origin_y = ImGui.GetCursorScreenPos(ctx)

  local ext = self.extend_input_area
  local extended_x = origin_x - ext.left
  local extended_y = origin_y - ext.top

  if num_items == 0 then
    -- CRITICAL: Update animations even when grid is empty
    -- so destruction animations can complete properly
    self.animator:update(0.016)

    local extended_w = avail_w + ext.left + ext.right
    local extended_h = avail_h + ext.top + ext.bottom

    if self.panel_clip_bounds then
      self.visual_bounds = self.panel_clip_bounds
    else
      self.visual_bounds = {origin_x, origin_y, origin_x + avail_w, origin_y + avail_h}
    end

    self.grid_bounds = {extended_x, extended_y, extended_x + extended_w, extended_y + extended_h}

    ImGui.SetCursorScreenPos(ctx, extended_x, extended_y)
    ImGui.InvisibleButton(ctx, self._cached_empty_id, extended_w, extended_h)
    ImGui.SetCursorScreenPos(ctx, origin_x, origin_y)

    -- Render destruction animations even when grid is empty
    local dl = ImGui.GetWindowDrawList(ctx)
    self.animator:render_destroy_effects(ctx, dl)

    self:_update_external_drop_target(ctx)

    if Input.is_external_drag_active(self) then
      self:_draw_external_drop_visuals(ctx, dl)

      if self.accept_external_drops and ImGui.IsMouseReleased(ctx, 0) then
        if self.external_drop_target and self.on_external_drop then
          self.on_external_drop(self.external_drop_target.index)
        end
        self.external_drop_target = nil
      end
    end

    return
  end

  local keyboard_consumed = false
  local wheel_consumed = false

  if not self.block_all_input then
    keyboard_consumed = Input.handle_shortcuts(self, ctx)
    wheel_consumed = Input.handle_wheel_input(self, ctx, items)
  end
  
  if wheel_consumed then
    local current_scroll_y = ImGui.GetScrollY(ctx)
    ImGui.SetScrollY(ctx, current_scroll_y)
  end

  self.current_rects = {}

  local min_col_w = self.min_col_w_fn()
  local cols, rows, rects = LayoutGrid.calculate(avail_w, min_col_w, self.gap, num_items, origin_x, origin_y, self.fixed_tile_h)

  self.last_layout_cols = cols

  local current_keys = {}
  for i, item in ipairs(items) do
    local key = self.key(item)
    current_keys[key] = true
    self.rect_track:to(key, rects[i])
  end

  local new_keys = {}
  for key, _ in pairs(current_keys) do
    if not self.previous_item_keys[key] then
      new_keys[#new_keys + 1] = key
    end
  end
  
  self.animator:handle_spawn(new_keys, self.rect_track)
  self.previous_item_keys = current_keys

  local wx, wy = ImGui.GetWindowPos(ctx)
  local window_moved = false
  if self.last_window_pos then
    if wx ~= self.last_window_pos[1] or wy ~= self.last_window_pos[2] then
      window_moved = true
    end
  end
  self.last_window_pos = {wx, wy}

  if window_moved then
    local rect_map = {}
    for i, item in ipairs(items) do rect_map[self.key(item)] = rects[i] end
    self.rect_track:teleport_all(rect_map)
  else
    self.rect_track:update()
  end
  
  self.animator:update(0.016)

  local tile_h = rects[1] and (rects[1][4] - rects[1][2]) or 100
  local grid_height = rows * (tile_h + self.gap) + self.gap

  local bg_height = math.max(grid_height, avail_h)
  
  local extended_w = avail_w + ext.left + ext.right
  local extended_h = bg_height + ext.top + ext.bottom
  
  if self.panel_clip_bounds then
    self.visual_bounds = self.panel_clip_bounds
  else
    -- CRITICAL FIX: Calculate actual visible viewport in screen space
    -- Use GetCursorStartPos to get the content area start, which stays fixed
    local window_x, window_y = ImGui.GetWindowPos(ctx)
    local scroll_y = ImGui.GetScrollY(ctx)

    -- Content area starts at window position (accounting for title bar/padding automatically)
    -- and extends by the available region size
    local content_start_y = window_y + (origin_y - scroll_y - window_y)

    -- Simpler approach: just use window pos and available region
    -- This gives us the visible viewport in screen space
    self.visual_bounds = {
      window_x,
      window_y + 30,  -- Approximate title bar height
      window_x + avail_w,
      window_y + 30 + avail_h
    }
  end
  
  self.grid_bounds = {extended_x, extended_y, extended_x + extended_w, extended_y + extended_h}

  ImGui.SetCursorScreenPos(ctx, extended_x, extended_y)
  ImGui.InvisibleButton(ctx, self._cached_bg_id, extended_w, extended_h)
  ImGui.SetCursorScreenPos(ctx, origin_x, origin_y)

  local bg_clicked = ImGui.IsItemClicked(ctx, 0)
  local bg_double_clicked = ImGui.IsItemClicked(ctx, 0) and ImGui.IsMouseDoubleClicked(ctx, 0)

  -- Optimized: Check if mouse is over any tile (inline to avoid function call overhead)
  local mouse_over_tile = false
  local double_clicked_tile_key = nil

  if bg_clicked or bg_double_clicked then
    local mx, my = ImGui.GetMousePos(ctx)
    for i = 1, num_items do
      local item = items[i]
      local key = self.key(item)
      local r = self.rect_track:get(key)
      if r and self:_rect_intersects_bounds(r) and Draw.point_in_rect(mx, my, r[1], r[2], r[3], r[4]) then
        mouse_over_tile = true
        if bg_double_clicked then
          double_clicked_tile_key = key
        end
        break
      end
    end
  end

  -- Handle double-click on tile at grid level (before marquee selection)
  if bg_double_clicked and double_clicked_tile_key and self.behaviors and self.behaviors.double_click then
    self.behaviors.double_click(double_clicked_tile_key)
  end

  -- Handle left-click or right-click on empty space to start marquee selection
  local bg_right_clicked = ImGui.IsMouseClicked(ctx, 1) and not mouse_over_tile
  if (bg_clicked or bg_right_clicked) and not mouse_over_tile and not Input.is_external_drag_active(self) then
    local mx, my = ImGui.GetMousePos(ctx)
    local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
    local shift = ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) or ImGui.IsKeyDown(ctx, ImGui.Key_RightShift)
    local mode = (ctrl or shift) and "add" or "replace"

    self.sel_rect:begin(mx, my, mode, ctx)
    if self.on_click_empty then self.on_click_empty() end
  end

  local marquee_threshold = (self.config.marquee and self.config.marquee.drag_threshold) or DEFAULTS.marquee.drag_threshold

  -- Support both left-click and right-click dragging for marquee selection
  local is_dragging = (ImGui.IsMouseDragging(ctx, 0, marquee_threshold) or ImGui.IsMouseDragging(ctx, 1, marquee_threshold))
  if self.sel_rect:is_active() and is_dragging and not Input.is_external_drag_active(self) then
    local mx, my = ImGui.GetMousePos(ctx)
    self.sel_rect:update(mx, my)

    -- Auto-scroll when near edges
    if self.visual_bounds then
      local scroll_speed = 15
      local edge_threshold = 30
      local bounds = self.visual_bounds
      
      local scroll_x = ImGui.GetScrollX(ctx)
      local scroll_y = ImGui.GetScrollY(ctx)
      local scroll_max_y = ImGui.GetScrollMaxY(ctx)
      local scroll_max_x = ImGui.GetScrollMaxX(ctx)
      
      -- Vertical scroll
      if my < bounds[2] + edge_threshold and scroll_y > 0 then
        local distance_from_edge = (bounds[2] + edge_threshold) - my
        local scroll_amount = math.min(scroll_speed * (distance_from_edge / edge_threshold), scroll_speed)
        ImGui.SetScrollY(ctx, math.max(0, scroll_y - scroll_amount))
      elseif my > bounds[4] - edge_threshold and scroll_y < scroll_max_y then
        local distance_from_edge = my - (bounds[4] - edge_threshold)
        local scroll_amount = math.min(scroll_speed * (distance_from_edge / edge_threshold), scroll_speed)
        ImGui.SetScrollY(ctx, math.min(scroll_max_y, scroll_y + scroll_amount))
      end
      
      -- Horizontal scroll (if needed)
      if mx < bounds[1] + edge_threshold and scroll_x > 0 then
        local distance_from_edge = (bounds[1] + edge_threshold) - mx
        local scroll_amount = math.min(scroll_speed * (distance_from_edge / edge_threshold), scroll_speed)
        ImGui.SetScrollX(ctx, math.max(0, scroll_x - scroll_amount))
      elseif mx > bounds[3] - edge_threshold and scroll_x < scroll_max_x then
        local distance_from_edge = mx - (bounds[3] - edge_threshold)
        local scroll_amount = math.min(scroll_speed * (distance_from_edge / edge_threshold), scroll_speed)
        ImGui.SetScrollX(ctx, math.min(scroll_max_x, scroll_x + scroll_amount))
      end
    end

    local x1, y1, x2, y2 = self.sel_rect:aabb()
    if x1 then
      local rect_map = {}
      for i = 1, num_items do
        local item = items[i]
        rect_map[self.key(item)] = rects[i]
      end
      self.selection:apply_rect({x1, y1, x2, y2}, rect_map, self.sel_rect.mode)
      if self.behaviors and self.behaviors.on_select then
        self.behaviors.on_select(self.selection:selected_keys())
      end
    end
  end

  -- Support both left-click and right-click release to finish marquee selection
  if self.sel_rect:is_active() and (ImGui.IsMouseReleased(ctx, 0) or ImGui.IsMouseReleased(ctx, 1)) then
    if not self.sel_rect:did_drag() then
      self.selection:clear()
      if self.behaviors and self.behaviors.on_select then
        self.behaviors.on_select(self.selection:selected_keys())
      end
    end
    self.sel_rect:clear()
  end

  ImGui.SetCursorScreenPos(ctx, origin_x, origin_y)

  self.hover_id = nil
  local dl = ImGui.GetWindowDrawList(ctx)
  
  if self.clip_rendering and self.visual_bounds then
    ImGui.PushClipRect(ctx, self.visual_bounds[1], self.visual_bounds[2], self.visual_bounds[3], self.visual_bounds[4], true)
  end

  -- Viewport culling with buffer zone (dynamic based on item count for better performance)
  local VIEWPORT_BUFFER = (num_items > 500) and 100 or 200

  -- CRITICAL OPTIMIZATION: Calculate visible row range to avoid looping through all items
  -- For 1000 items with 10 visible, this reduces loop from 1000 to ~20 items
  local first_item, last_item = 1, num_items
  if self.visual_bounds and rects[1] then
    -- Cache math functions for performance
    local floor = math.floor
    local ceil = math.ceil
    local max = math.max
    local min = math.min

    local tile_h = rects[1][4] - rects[1][2]
    local row_height = tile_h + self.gap

    -- Calculate which rows are visible (with buffer)
    local viewport_top = self.visual_bounds[2] - VIEWPORT_BUFFER
    local viewport_bottom = self.visual_bounds[4] + VIEWPORT_BUFFER

    local first_visible_row = max(0, floor((viewport_top - origin_y - self.gap) / row_height))
    local last_visible_row = ceil((viewport_bottom - origin_y - self.gap) / row_height)

    -- Convert row range to item indices
    first_item = max(1, first_visible_row * cols + 1)
    last_item = min(num_items, (last_visible_row + 1) * cols)
  end

  for i = first_item, last_item do
    local item = items[i]
    local key = self.key(item)
    local rect = self.rect_track:get(key)

    if rect then
      rect = self.animator:apply_spawn_to_rect(key, rect)

      -- Viewport culling check (should pass for most items in range due to row calculation)
      local is_visible = self:_rect_intersects_bounds(rect, VIEWPORT_BUFFER)

      if not is_visible then
        -- Skip rendering, input, and expensive operations for invisible items
        self.current_rects[key] = {rect[1], rect[2], rect[3], rect[4], item}
        goto continue
      end

      self.current_rects[key] = {rect[1], rect[2], rect[3], rect[4], item}

      local state = {
        hover    = false,
        selected = self.selection:is_selected(key),
        index    = i,
      }

      local is_hovered = false
      if not self.block_all_input then
        is_hovered = Input.handle_tile_input(self, ctx, item, rect)
      end
      state.hover = is_hovered

      self.render_tile(ctx, rect, item, state, self)

      ::continue::
    end
  end
  
  if self.clip_rendering then
    ImGui.PopClipRect(ctx)
  end
  
  self.animator:render_destroy_effects(ctx, dl)

  if not self.block_all_input then
    Input.check_start_drag(self, ctx)
  end

  if (not self.block_all_input) and self.drag:is_active() then
    self:_draw_drag_visuals(ctx, dl)
  end

  self:_update_external_drop_target(ctx)

  if Input.is_external_drag_active(self) then
    self:_draw_external_drop_visuals(ctx, dl)
    
    if self.accept_external_drops and ImGui.IsMouseReleased(ctx, 0) then
      if self.external_drop_target and self.on_external_drop then
        self.on_external_drop(self.external_drop_target.index)
      end
      self.external_drop_target = nil
    end
  end

  if self.drag:is_active() and ImGui.IsMouseReleased(ctx, 0) then
    if self.drag:get_target_index() and self.behaviors and self.behaviors.reorder then
      local order = {}
      for i = 1, num_items do
        order[i] = self.key(items[i])
      end

      local dragged_set = DropZones.build_dragged_set(self.drag:get_dragged_ids())

      local filtered_order = {}
      local num_order = #order
      for i = 1, num_order do
        local id = order[i]
        if not dragged_set[id] then
          filtered_order[#filtered_order + 1] = id
        end
      end
      
      local new_order = {}
      local insert_pos = math.min(self.drag:get_target_index(), #filtered_order + 1)
      
      for i = 1, insert_pos - 1 do
        new_order[#new_order + 1] = filtered_order[i]
      end
      
      for _, id in ipairs(self.drag:get_dragged_ids()) do
        new_order[#new_order + 1] = id
      end
      
      for i = insert_pos, #filtered_order do
        new_order[#new_order + 1] = filtered_order[i]
      end

      self.behaviors.reorder(new_order)
    end
    
    local pending = self.drag:release()
    if pending and not Input.is_external_drag_active(self) then
      self.selection:single(pending)
      if self.behaviors and self.behaviors.on_select then 
        self.behaviors.on_select(self.selection:selected_keys()) 
      end
    end
  end

  if not self.drag:is_active() and ImGui.IsMouseReleased(ctx, 0) and not Input.is_external_drag_active(self) then
    if self.drag:has_pending_selection() then
      self.selection:single(self.drag:get_pending_selection())
      if self.behaviors and self.behaviors.on_select then 
        self.behaviors.on_select(self.selection:selected_keys()) 
      end
    end
    
    self.drag:release()
  end

  self:_draw_marquee(ctx, dl)

  if self.render_overlays then
    self.render_overlays(ctx, self.current_rects)
  end
end

function Grid:clear()
  self.selection:clear()
  self.rect_track:clear()
  self.sel_rect:clear()
  self.animator:clear()
  self.hover_id = nil
  self.current_rects = {}
  self.drag:clear()
  self.external_drop_target = nil
  self.last_window_pos = nil
  self.previous_item_keys = {}
  self.last_layout_cols = 1
  self.grid_bounds = nil
  self.visual_bounds = nil
  self.panel_clip_bounds = nil
end

return M