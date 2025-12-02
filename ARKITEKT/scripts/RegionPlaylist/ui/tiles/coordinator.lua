-- @noindex
-- RegionPlaylist/ui/tiles/coordinator.lua

local ImGui = require('arkitekt.platform.imgui')
local Ark = require('arkitekt')

local CoordinatorFactory = require('RegionPlaylist.ui.tiles.coordinator_factory')
local ActiveGridFactory = require('RegionPlaylist.ui.tiles.active_grid_factory')
local PoolGridFactory = require('RegionPlaylist.ui.tiles.pool_grid_factory')
local ActiveTile = require('RegionPlaylist.ui.tiles.renderers.active')
local PoolTile = require('RegionPlaylist.ui.tiles.renderers.pool')
local ResponsiveGrid = require('arkitekt.gui.layout.responsive')
local Dnd = require('arkitekt.gui.interaction.drag_visual')
local DragIndicator = Dnd.DragIndicator
local BatchRenameModal = require('arkitekt.gui.widgets.overlays.batch_rename_modal')
local State = require('RegionPlaylist.app.state')

-- Menu components
local ActiveActionsMenu = require('RegionPlaylist.ui.components.menus.active_actions_menu')
local PoolActionsMenu = require('RegionPlaylist.ui.components.menus.pool_actions_menu')
local PoolTileContextMenu = require('RegionPlaylist.ui.components.menus.pool_tile_context_menu')

local M = {}

local Coordinator = {}
Coordinator.__index = Coordinator

-- =============================================================================
-- CONSTRUCTOR
-- =============================================================================

function M.new(opts)
  return CoordinatorFactory.new(Coordinator, opts)
end

-- =============================================================================
-- CONFIGURATION METHODS
-- =============================================================================
-- Update coordinator configuration at runtime.

function Coordinator:set_layout_mode(mode)
  self.layout_mode = mode
  if mode == 'vertical' then
    self._active_min_col_w_fn = function() return 9999 end
  else
    self._active_min_col_w_fn = function() return ActiveTile.CONFIG.tile_width end
  end

  -- Also update the grid instance directly if it exists (for immediate effect)
  if self.active_grid and self.active_grid.min_col_w_fn then
    self.active_grid.min_col_w_fn = self._active_min_col_w_fn
  end
end

function Coordinator:set_app_bridge(bridge)
  self.app_bridge = bridge
end

function Coordinator:set_pool_mode(mode)
  if self.pool_container then
    self.pool_container.current_mode = mode
  end
end

function Coordinator:_find_hovered_tile(ctx, items)
  if not self.active_grid or not self.active_grid.rect_track then
    return nil, nil, false
  end

  local mx, my = ImGui.GetMousePos(ctx)

  for _, item in ipairs(items) do
    local key = item.key
    local rect = self.active_grid.rect_track:get(key)
    if rect then
      if mx >= rect[1] and mx < rect[3] and my >= rect[2] and my < rect[4] then
        local is_selected = self.active_grid.selection:is_selected(key)
        return item, key, is_selected
      end
    end
  end

  return nil, nil, false
end

function Coordinator:is_mouse_over_active_tile(ctx, playlist)
  if not self.active_bounds then return false end
  
  local mx, my = ImGui.GetMousePos(ctx)
  
  if not (mx >= self.active_bounds[1] and mx < self.active_bounds[3] and
          my >= self.active_bounds[2] and my < self.active_bounds[4]) then
    return false
  end
  
  local item, key, _ = self:_find_hovered_tile(ctx, playlist.items)
  return item ~= nil and key ~= nil
end

function Coordinator:should_consume_wheel(ctx, playlist)
  self.wheel_consumed_this_frame = false
  
  if not self.on_repeat_adjust then return false end
  
  local wheel_y = ImGui.GetMouseWheel(ctx)
  if wheel_y == 0 then return false end
  
  return self:is_mouse_over_active_tile(ctx, playlist)
end

function Coordinator:_get_drag_colors()
  local colors = {}

  if not self.bridge:is_drag_active() then return nil end

  local source = self.bridge:get_source_grid()
  local payload = self.bridge:get_drag_payload()

  if source == 'active' then
    local data = payload and payload.data or {}
    if type(data) == 'table' and self.active_grid then
      local playlist_items = self.active_grid.get_items()
      for _, key in ipairs(data) do
        for _, item in ipairs(playlist_items) do
          if item.key == key then
            if item.type == 'playlist' then
              if self.get_playlist_by_id then
                local playlist = self.get_playlist_by_id(item.playlist_id)
                if playlist and playlist.chip_color then
                  colors[#colors + 1] = playlist.chip_color
                end
              end
            else
              local region = self.get_region_by_rid(item.rid)
              if region and region.color then
                colors[#colors + 1] = region.color
              end
            end
            break
          end
        end
      end
    end
  elseif source == 'pool' then
    local data = payload and payload.data or {}
    if type(data) == 'table' then
      for _, item in ipairs(data) do
        if type(item) == 'number' then
          local region = self.get_region_by_rid(item)
          if region and region.color then
            colors[#colors + 1] = region.color
          end
        elseif type(item) == 'table' and item.type == 'playlist' then
          if item.chip_color then
            colors[#colors + 1] = item.chip_color
          end
        end
      end
    end
  end
  
  return #colors > 0 and colors or nil
end

function Coordinator:update_animations(dt)
  self.selector:update(dt)
  self.active_animator:update(dt)
  self.pool_animator:update(dt)
end

function Coordinator:set_tabs(tabs, active_id)
  if self.active_container then
    self.active_container:set_tabs(tabs, active_id)
  end
end

function Coordinator:get_active_tab_id()
  if self.active_container then
    return self.active_container:get_active_tab_id()
  end
  return nil
end

function Coordinator:get_pool_search_text()
  return self.pool_container:get_search_text()
end

function Coordinator:set_pool_search_text(text)
  self.pool_container:set_search_text(text)
end

function Coordinator:get_pool_sort_mode()
  return self.pool_container:get_sort_mode()
end

function Coordinator:set_pool_sort_mode(mode)
  self.pool_container:set_sort_mode(mode)
end

function Coordinator:get_pool_sort_direction()
  return self.pool_container:get_sort_direction()
end

function Coordinator:set_pool_sort_direction(direction)
  self.pool_container:set_sort_direction(direction)
end

-- =============================================================================
-- QUERY METHODS
-- =============================================================================
-- Query coordinator state (hover, mouse position, modal blocking).

function Coordinator:is_modal_blocking(ctx)
  -- Check if custom overlay modal is open (overflow tabs picker)
  local overflow_active = self.active_container and self.active_container:is_overflow_visible()
  if overflow_active then return true end

  -- Check if any ImGui popup is open (context menus, etc)
  if ctx then
    return ImGui.IsPopupOpen(ctx, '', ImGui.PopupFlags_AnyPopupId)
  end

  return false
end

-- =============================================================================
-- RENDERING METHODS
-- =============================================================================

function Coordinator:draw_selector(ctx, playlists, active_id, height)
  self.selector:draw(ctx, playlists, active_id, height, self.on_playlist_changed)
end

function Coordinator:draw_active(ctx, playlist, height, shell_state)
  self._imgui_ctx = ctx
  local window = shell_state and shell_state.window

  -- Inject modal blocking state and icon font into corner buttons
  local is_blocking = self:is_modal_blocking(ctx)
  local icons_font = shell_state and shell_state.fonts and shell_state.fonts.icons
  local icons_size = shell_state and shell_state.fonts and shell_state.fonts.icons_size
  if self.active_container and self.active_container.config and self.active_container.config.corner_buttons then
    local cb = self.active_container.config.corner_buttons
    if cb.top_right then
      cb.top_right.icon_font = icons_font
      cb.top_right.icon_font_size = icons_size
      cb.top_right.is_blocking = is_blocking
    end
    if cb.top_left then
      cb.top_left.icon_font = icons_font
      cb.top_left.icon_font_size = icons_size
      cb.top_left.is_blocking = is_blocking
    end
    if cb.bottom_right then
      cb.bottom_right.icon_font = icons_font
      cb.bottom_right.icon_font_size = icons_size
      cb.bottom_right.is_blocking = is_blocking
    end
    if cb.bottom_left then
      cb.bottom_left.icon_font = icons_font
      cb.bottom_left.icon_font_size = icons_size
      cb.bottom_left.is_blocking = is_blocking
    end
  end

  -- Inject icon font into tab_strip config for color picker
  if icons_font and self.active_container and self.active_container.config and self.active_container.config.header then
    local header = self.active_container.config.header
    if header.elements then
      for _, element in ipairs(header.elements) do
        if element.type == 'tab_strip' and element.config then
          element.config.icon_font = icons_font
          element.config.icon_font_size = icons_size or 12
        end
      end
    end
  end

  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local avail_w, _ = ImGui.GetContentRegionAvail(ctx)

  self.active_bounds = {cursor_x, cursor_y, cursor_x + avail_w, cursor_y + height}
  self.bridge:update_bounds('active', cursor_x, cursor_y, cursor_x + avail_w, cursor_y + height)

  self.active_container.width = avail_w
  self.active_container.height = height

  local draw_success = self.active_container:begin_draw(ctx)

  if draw_success then
    local header_height = 0
    if self.active_container.config.header and self.active_container.config.header.enabled then
      header_height = self.active_container.config.header.height or 36
    end

    local child_w = avail_w - (self.container_config.padding * 2)
    local child_h = (height - header_height) - (self.container_config.padding * 2)

    local raw_height, raw_gap = ResponsiveGrid.calculate_responsive_tile_height({
      item_count = #playlist.items,
      avail_width = child_w,
      avail_height = child_h,
      base_gap = ActiveTile.CONFIG.gap,
      min_col_width = self._active_min_col_w_fn(),
      base_tile_height = self.responsive_config.base_tile_height_active,
      min_tile_height = self.responsive_config.min_tile_height,
      responsive_config = self.responsive_config,
    })

    local responsive_height = self.active_height_stabilizer:update(raw_height)

    self.current_active_tile_height = responsive_height

    -- Set per-frame state for opts
    self._active_items = playlist.items
    self._active_tile_height = responsive_height
    self._active_gap = raw_gap
    self._active_clip_bounds = self.active_container.visible_bounds

    local wheel_y = ImGui.GetMouseWheel(ctx)

    if wheel_y ~= 0 then
      local item, key, is_selected = self:_find_hovered_tile(ctx, playlist.items)

      if item and key and self.on_repeat_adjust then
        local delta = (wheel_y > 0) and self.wheel_config.step or -self.wheel_config.step
        local shift_held = ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) or ImGui.IsKeyDown(ctx, ImGui.Key_RightShift)

        local keys_to_adjust = {}
        if self.active_grid and self.active_grid.selection and is_selected and self.active_grid.selection:count() > 0 then
          keys_to_adjust = self.active_grid.selection:selected_keys()
        else
          keys_to_adjust = {key}
        end

        if shift_held and self.on_repeat_sync then
          local target_reps = item.reps or 1
          self.on_repeat_sync(keys_to_adjust, target_reps)
        end

        self.on_repeat_adjust(keys_to_adjust, delta)
        self.wheel_consumed_this_frame = true
      end
    end

    -- Draw grid using opts-based API
    local opts = ActiveGridFactory.create_opts(self, self.config)
    opts.gap = raw_gap
    local result = Ark.Grid(ctx, opts)

    -- Store grid reference for other operations
    if result and result.grid then
      -- Register with bridge if not already
      if not self._active_grid_registered and self.bridge then
        self.bridge:register_grid('active', result.grid, self._active_grid_bridge_config)
        self._active_grid_registered = true
      end
      self.active_grid = result.grid
    end
  end

  -- CRITICAL: Always call end_draw to balance begin_draw (even if it failed)
  self.active_container:end_draw(ctx)

  -- Active grid actions menu
  ActiveActionsMenu.render(ctx, self, shell_state)

  -- Draw batch rename modal (if open)
  if BatchRenameModal.is_open() then
    local active_playlist = State.get_active_playlist()
    local selected_count = 0
    if self.active_grid and self.active_grid.selection then
      selected_count = self.active_grid.selection:count()
    end
    -- Pass window object to enable overlay mode and shell_state for fonts
    BatchRenameModal.Draw(ctx, selected_count, window, shell_state)
  end

  if self.bridge:is_drag_active() and self.bridge:get_source_grid() == 'active' and ImGui.IsMouseReleased(ctx, 0) then
    if not self.bridge:is_mouse_over_grid(ctx, 'active') then
      self.bridge:cancel_drag()
    else
      self.bridge:clear_drag()
    end
  end
end

function Coordinator:draw_pool(ctx, regions, height, shell_state)
  self._imgui_ctx = ctx

  -- Inject modal blocking state into corner buttons
  local is_blocking = self:is_modal_blocking(ctx)
  if self.pool_container and self.pool_container.config and self.pool_container.config.corner_buttons then
    local cb = self.pool_container.config.corner_buttons
    if cb.bottom_left then
      cb.bottom_left.is_blocking = is_blocking
    end
  end

  -- Inject icon font and size into corner buttons
  local icons_font = shell_state and shell_state.fonts and shell_state.fonts.icons
  local icons_size = shell_state and shell_state.fonts and shell_state.fonts.icons_size
  if icons_font and self.pool_container and self.pool_container.config and self.pool_container.config.corner_buttons then
    local cb = self.pool_container.config.corner_buttons
    if cb.top_right then
      cb.top_right.icon_font = icons_font
      cb.top_right.icon_font_size = icons_size
    end
    if cb.top_left then
      cb.top_left.icon_font = icons_font
      cb.top_left.icon_font_size = icons_size
    end
    if cb.bottom_right then
      cb.bottom_right.icon_font = icons_font
      cb.bottom_right.icon_font_size = icons_size
    end
    if cb.bottom_left then
      cb.bottom_left.icon_font = icons_font
      cb.bottom_left.icon_font_size = icons_size
    end
  end

  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  local avail_w, _ = ImGui.GetContentRegionAvail(ctx)

  self.pool_bounds = {cursor_x, cursor_y, cursor_x + avail_w, cursor_y + height}
  self.bridge:update_bounds('pool', cursor_x, cursor_y, cursor_x + avail_w, cursor_y + height)

  self.pool_container.width = avail_w
  self.pool_container.height = height

  local draw_success = self.pool_container:begin_draw(ctx)

  if draw_success then
    local header_height = 0
    if self.container_config.header and self.container_config.header.enabled then
      header_height = self.container_config.header.height or 36
    end

    local child_w = avail_w - (self.container_config.padding * 2)
    local child_h = (height - header_height) - (self.container_config.padding * 2)

    local raw_height, raw_gap = ResponsiveGrid.calculate_responsive_tile_height({
      item_count = #regions,
      avail_width = child_w,
      avail_height = child_h,
      base_gap = PoolTile.CONFIG.gap,
      min_col_width = PoolTile.CONFIG.tile_width,
      base_tile_height = self.responsive_config.base_tile_height_pool,
      min_tile_height = self.responsive_config.min_tile_height,
      responsive_config = self.responsive_config,
    })

    local responsive_height = self.pool_height_stabilizer:update(raw_height)

    self.current_pool_tile_height = responsive_height

    -- Set per-frame state for opts
    self._pool_items = regions
    self._pool_tile_height = responsive_height
    self._pool_gap = raw_gap
    self._pool_clip_bounds = self.pool_container.visible_bounds
    self._pool_disable_background_clicks = ImGui.IsPopupOpen(ctx, 'PoolActionsMenu')

    -- Draw grid using opts-based API
    local opts = PoolGridFactory.create_opts(self, self.config)
    local result = Ark.Grid(ctx, opts)

    -- Store grid reference for other operations
    if result and result.grid then
      -- Register with bridge if not already
      if not self._pool_grid_registered and self.bridge then
        self.bridge:register_grid('pool', result.grid, self._pool_grid_bridge_config)
        self._pool_grid_registered = true
      end
      self.pool_grid = result.grid
    end
  end

  -- CRITICAL: Always call end_draw to balance begin_draw (even if it failed)
  self.pool_container:end_draw(ctx)

  -- Pool grid menus
  PoolActionsMenu.render(ctx, self)
  PoolTileContextMenu.render(ctx, self, shell_state)

  if self.bridge:is_drag_active() and self.bridge:get_source_grid() == 'pool' and ImGui.IsMouseReleased(ctx, 0) then
    if not self.bridge:is_mouse_over_grid(ctx, 'active') then
      self.bridge:clear_drag()
    end
  end
end

function Coordinator:draw_ghosts(ctx)
  if not self.bridge:is_drag_active() then return nil end

  local mx, my = ImGui.GetMousePos(ctx)
  local count = self.bridge:get_drag_count()

  local colors = self:_get_drag_colors()
  local fg_dl = ImGui.GetForegroundDrawList(ctx)

  local is_over_active = self.bridge:is_mouse_over_grid(ctx, 'active')
  local is_over_pool = self.bridge:is_mouse_over_grid(ctx, 'pool')

  local target_grid = nil
  if is_over_active then
    target_grid = 'active'
  elseif is_over_pool then
    target_grid = 'pool'
  end

  local is_copy_mode = false
  local is_delete_mode = false

  if target_grid then
    is_copy_mode = self.bridge:compute_copy_mode(target_grid)
    is_delete_mode = self.bridge:compute_delete_mode(ctx, target_grid)
  else
    local source = self.bridge:get_source_grid()
    if source == 'active' then
      is_delete_mode = true
    end
  end

  DragIndicator.Draw(ctx, fg_dl, mx, my, count, self.config.ghost_config, colors, is_copy_mode, is_delete_mode)
end

return M