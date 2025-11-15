-- @noindex
-- ItemPicker/ui/performance_grid.lua
-- Custom performance-optimized grid for Item Picker
-- Based on rearkitekt.gui.widgets.grid.core but with resize handling

local ImGui = require 'imgui' '0.10'

local LayoutGrid = require('rearkitekt.gui.widgets.grid.layout')
local RectTrack = require('rearkitekt.gui.fx.animation.rect_track')
local Colors = require('rearkitekt.core.colors')
local Selection  = require('rearkitekt.gui.systems.selection')
local SelRect    = require('rearkitekt.gui.widgets.selection_rectangle')
local Draw       = require('rearkitekt.gui.draw')
local DragIndicator = require('rearkitekt.gui.fx.dnd.drag_indicator')
local DropIndicator = require('rearkitekt.gui.fx.dnd.drop_indicator')
local Rendering  = require('rearkitekt.gui.widgets.grid.rendering')
local Animation  = require('rearkitekt.gui.widgets.grid.animation')
local Input      = require('rearkitekt.gui.widgets.grid.input')
local DnDState   = require('rearkitekt.gui.widgets.grid.dnd_state')
local DropZones  = require('rearkitekt.gui.widgets.grid.drop_zones')

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

    -- Cache string IDs for performance
    _cached_bg_id = "##grid_bg_" .. grid_id,
    _cached_empty_id = "##grid_empty_" .. grid_id,
  }, Grid)

  grid.animator:set_rect_track(grid.rect_track)

  -- Copy methods from base grid (reuse all the helper methods)
  local BaseGrid = require('rearkitekt.gui.widgets.grid.core')
  local base_instance = BaseGrid.new(opts)

  grid._is_mouse_in_bounds = base_instance._is_mouse_in_bounds
  grid._rect_intersects_bounds = base_instance._rect_intersects_bounds
  grid._find_drop_target = base_instance._find_drop_target
  grid._update_external_drop_target = base_instance._update_external_drop_target
  grid._draw_drag_visuals = base_instance._draw_drag_visuals
  grid._draw_external_drop_visuals = base_instance._draw_external_drop_visuals
  grid._draw_marquee = base_instance._draw_marquee
  grid.get_drop_target_index = base_instance.get_drop_target_index
  grid.mark_spawned = base_instance.mark_spawned
  grid.mark_destroyed = base_instance.mark_destroyed
  grid.clear = base_instance.clear

  return grid
end

-- Custom draw() method with resize handling
function Grid:draw(ctx)
  local items = self.get_items()
  local num_items = #items

  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local origin_x, origin_y = ImGui.GetCursorScreenPos(ctx)

  local ext = self.extend_input_area
  local extended_x = origin_x - ext.left
  local extended_y = origin_y - ext.top

  if num_items == 0 then
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

    self:_update_external_drop_target(ctx)

    if Input.is_external_drag_active(self) then
      local dl = ImGui.GetWindowDrawList(ctx)
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

  -- Detect layout change and find anchor item
  local layout_changed = (self.last_layout_cols ~= cols)
  local anchor_item_idx = nil
  local anchor_offset_from_scroll = 0

  if layout_changed and num_items > 0 then
    local scroll_y = ImGui.GetScrollY(ctx)
    reaper.ShowConsoleMsg(string.format("[LAYOUT] cols: %d->%d, scroll=%.1f\n", self.last_layout_cols, cols, scroll_y))

    -- Find item closest to current scroll position (in content space)
    local min_dist = math.huge
    for i, item in ipairs(items) do
      local key = self.key(item)
      local rect = self.rect_track:get(key)
      if rect then
        -- Convert screen space to content space
        local item_content_y = rect[2] - origin_y + scroll_y
        local dist = math.abs(item_content_y - scroll_y)
        if dist < min_dist then
          min_dist = dist
          anchor_item_idx = i
          anchor_offset_from_scroll = item_content_y - scroll_y
        end
      end
    end

    if anchor_item_idx then
      reaper.ShowConsoleMsg(string.format("[ANCHOR] Found item #%d, offset=%.1f\n", anchor_item_idx, anchor_offset_from_scroll))
    end
  end

  self.last_layout_cols = cols

  -- Keep smooth animations (don't teleport - teleport kills responsiveness)
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
    local window_x, window_y = ImGui.GetWindowPos(ctx)
    self.visual_bounds = {
      window_x,
      window_y + 30,
      window_x + avail_w,
      window_y + 30 + avail_h
    }
  end

  self.grid_bounds = {extended_x, extended_y, extended_x + extended_w, extended_y + extended_h}

  ImGui.SetCursorScreenPos(ctx, extended_x, extended_y)
  ImGui.InvisibleButton(ctx, self._cached_bg_id, extended_w, extended_h)
  ImGui.SetCursorScreenPos(ctx, origin_x, origin_y)

  -- Adjust scroll to keep anchor item in same position
  if layout_changed and anchor_item_idx and anchor_item_idx <= num_items then
    local key = self.key(items[anchor_item_idx])
    local new_rect = self.rect_track:get(key)

    if new_rect then
      -- Convert new position to content space
      local new_item_content_y = new_rect[2] - origin_y + ImGui.GetScrollY(ctx)
      -- We want item to be at same offset from scroll position
      local desired_scroll_y = new_item_content_y - anchor_offset_from_scroll

      -- Clamp to valid range
      local max_scroll = ImGui.GetScrollMaxY(ctx)
      desired_scroll_y = math.max(0, math.min(desired_scroll_y, max_scroll))

      local old_scroll = ImGui.GetScrollY(ctx)
      ImGui.SetScrollY(ctx, desired_scroll_y)

      reaper.ShowConsoleMsg(string.format("[SCROLL] Adjusted: %.1f -> %.1f (max=%.1f)\n",
        old_scroll, desired_scroll_y, max_scroll))
    end
  end

  local bg_clicked = ImGui.IsItemClicked(ctx, 0)

  local mouse_over_tile = false
  if bg_clicked then
    local mx, my = ImGui.GetMousePos(ctx)
    for i = 1, num_items do
      local item = items[i]
      local r = self.rect_track:get(self.key(item))
      if r and self:_rect_intersects_bounds(r) and Draw.point_in_rect(mx, my, r[1], r[2], r[3], r[4]) then
        mouse_over_tile = true
        break
      end
    end
  end

  if bg_clicked and not mouse_over_tile and not Input.is_external_drag_active(self) then
    local mx, my = ImGui.GetMousePos(ctx)
    local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)
    local shift = ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) or ImGui.IsKeyDown(ctx, ImGui.Key_RightShift)
    local mode = (ctrl or shift) and "add" or "replace"

    self.sel_rect:begin(mx, my, mode, ctx)
    if self.on_click_empty then self.on_click_empty() end
  end

  local marquee_threshold = (self.config.marquee and self.config.marquee.drag_threshold) or DEFAULTS.marquee.drag_threshold

  if self.sel_rect:is_active() and ImGui.IsMouseDragging(ctx, 0, marquee_threshold) and not Input.is_external_drag_active(self) then
    local mx, my = ImGui.GetMousePos(ctx)
    self.sel_rect:update(mx, my)

    if self.visual_bounds then
      local scroll_speed = 15
      local edge_threshold = 30
      local bounds = self.visual_bounds

      local scroll_x = ImGui.GetScrollX(ctx)
      local scroll_y = ImGui.GetScrollY(ctx)
      local scroll_max_y = ImGui.GetScrollMaxY(ctx)
      local scroll_max_x = ImGui.GetScrollMaxX(ctx)

      if my < bounds[2] + edge_threshold and scroll_y > 0 then
        local distance_from_edge = (bounds[2] + edge_threshold) - my
        local scroll_amount = math.min(scroll_speed * (distance_from_edge / edge_threshold), scroll_speed)
        ImGui.SetScrollY(ctx, math.max(0, scroll_y - scroll_amount))
      elseif my > bounds[4] - edge_threshold and scroll_y < scroll_max_y then
        local distance_from_edge = my - (bounds[4] - edge_threshold)
        local scroll_amount = math.min(scroll_speed * (distance_from_edge / edge_threshold), scroll_speed)
        ImGui.SetScrollY(ctx, math.min(scroll_max_y, scroll_y + scroll_amount))
      end

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

  if self.sel_rect:is_active() and ImGui.IsMouseReleased(ctx, 0) then
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

  local VIEWPORT_BUFFER = (num_items > 500) and 100 or 200

  local first_item, last_item = 1, num_items
  if self.visual_bounds and rects[1] then
    local floor = math.floor
    local ceil = math.ceil
    local max = math.max
    local min = math.min

    local tile_h = rects[1][4] - rects[1][2]
    local row_height = tile_h + self.gap

    local viewport_top = self.visual_bounds[2] - VIEWPORT_BUFFER
    local viewport_bottom = self.visual_bounds[4] + VIEWPORT_BUFFER

    local first_visible_row = max(0, floor((viewport_top - origin_y - self.gap) / row_height))
    local last_visible_row = ceil((viewport_bottom - origin_y - self.gap) / row_height)

    first_item = max(1, first_visible_row * cols + 1)
    last_item = min(num_items, (last_visible_row + 1) * cols)
  end

  for i = first_item, last_item do
    local item = items[i]
    local key = self.key(item)
    local rect = self.rect_track:get(key)

    if rect then
      rect = self.animator:apply_spawn_to_rect(key, rect)

      local is_visible = self:_rect_intersects_bounds(rect, VIEWPORT_BUFFER)

      if not is_visible then
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

      self.render_tile(ctx, rect, item, state)

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

return M
