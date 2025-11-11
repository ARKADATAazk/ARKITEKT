-- @noindex
-- Region_Playlist/app/gui.lua

local ImGui = require 'imgui' '0.10'
local RegionTiles = require("Region_Playlist.widgets.region_tiles.coordinator")
local Colors = require("rearkitekt.core.colors")
local Shortcuts = require("Region_Playlist.app.shortcuts")
local PlaylistController = require("Region_Playlist.app.controller")
local TransportContainer = require("rearkitekt.gui.widgets.transport.transport_container")
local Sheet = require("rearkitekt.gui.widgets.overlay.sheet")
local ChipList = require("rearkitekt.gui.widgets.chip_list.list")
local Config = require('Region_Playlist.app.config')
local TransportWidgets = require("Region_Playlist.widgets._temp_transportwidgets")

local M = {}
local GUI = {}
GUI.__index = GUI

function M.create(State, AppConfig, settings)
  local self = setmetatable({
    State = State,
    Config = Config,
    settings = settings,
    region_tiles = nil,
    controller = nil,
    transport_container = nil,
    separator_drag_state = {
      is_dragging = false,
      drag_offset = 0
    },
    quantize_lookahead = Config.QUANTIZE.default_lookahead,
    overflow_modal_search = "",
    overflow_modal_is_open = false,
    
    -- New transport widgets
    view_mode_button = TransportWidgets.ViewModeButton.new(Config.TRANSPORT.view_mode),
    transport_display = TransportWidgets.TransportDisplay.new(Config.TRANSPORT.display),
    jump_controls = TransportWidgets.JumpControls.new(Config.TRANSPORT.jump),
    global_controls = TransportWidgets.GlobalControls.new(Config.TRANSPORT.global),
  }, GUI)
  
  self.controller = PlaylistController.new(State, settings, State.state.undo_manager)
  
  self.transport_container = TransportContainer.new({
    id = "region_playlist_transport",
    height = Config.TRANSPORT.height,
  })
  
  State.state.bridge:set_controller(self.controller)
  State.state.bridge:set_playlist_lookup(State.get_playlist_by_id)
  
  if not State.state.separator_position_horizontal then
    State.state.separator_position_horizontal = Config.SEPARATOR.horizontal.default_position
  end
  if not State.state.separator_position_vertical then
    State.state.separator_position_vertical = Config.SEPARATOR.vertical.default_position
  end
  
  State.state.on_state_restored = function()
    self:refresh_tabs()
    if self.region_tiles.active_grid and self.region_tiles.active_grid.selection then
      self.region_tiles.active_grid.selection:clear()
    end
    if self.region_tiles.pool_grid and self.region_tiles.pool_grid.selection then
      self.region_tiles.pool_grid.selection:clear()
    end
  end
  
  State.state.on_repeat_cycle = function(key, current_loop, total_reps)
    reaper.ShowConsoleMsg(string.format("[GUI] Repeat cycle: %s (%d/%d)\n", key, current_loop, total_reps))
  end
  
  self.region_tiles = RegionTiles.create({
    controller = self.controller,
    
    get_region_by_rid = function(rid)
      return State.state.region_index[rid]
    end,
    
    get_playlist_by_id = function(playlist_id)
      return State.get_playlist_by_id(playlist_id)
    end,
    
    detect_circular_ref = function(target_playlist_id, source_playlist_id)
      return State.detect_circular_reference(target_playlist_id, source_playlist_id)
    end,
    
    allow_pool_reorder = true,
    enable_active_tabs = true,
    tabs = State.get_tabs(),
    active_tab_id = State.state.active_playlist,
    pool_mode = State.state.pool_mode,
    config = AppConfig.get_region_tiles_config(State.state.layout_mode),
    
    on_playlist_changed = function(new_id)
      State.set_active_playlist(new_id)
    end,
    
    on_pool_search = function(text)
      State.state.search_filter = text
      State.persist_ui_prefs()
    end,
    
    on_pool_sort = function(mode)
      State.state.sort_mode = mode
      State.persist_ui_prefs()
    end,

    on_pool_sort_direction = function(direction)
      State.state.sort_direction = direction
      State.persist_ui_prefs()
    end,
    
    on_pool_mode_changed = function(mode)
      State.state.pool_mode = mode
      self.region_tiles:set_pool_mode(mode)
      State.persist_ui_prefs()
    end,
    
    on_active_reorder = function(new_order)
      self.controller:reorder_items(State.state.active_playlist, new_order)
    end,
    
    on_active_remove = function(item_key)
      self.controller:delete_items(State.state.active_playlist, {item_key})
    end,
    
    on_active_toggle_enabled = function(item_key, new_state)
      self.controller:toggle_item_enabled(State.state.active_playlist, item_key, new_state)
    end,
    
    on_active_delete = function(item_keys)
      self.controller:delete_items(State.state.active_playlist, item_keys)
      for _, key in ipairs(item_keys) do
        State.state.pending_destroy[#State.state.pending_destroy + 1] = key
      end
    end,
    
    on_destroy_complete = function(key)
    end,
    
    on_active_copy = function(dragged_items, target_index)
      local success, keys = self.controller:copy_items(State.state.active_playlist, dragged_items, target_index)
      if success and keys then
        for _, key in ipairs(keys) do
          State.state.pending_spawn[#State.state.pending_spawn + 1] = key
          State.state.pending_select[#State.state.pending_select + 1] = key
        end
      end
    end,
    
    on_pool_to_active = function(rid, insert_index)
      local success, key = self.controller:add_item(State.state.active_playlist, rid, insert_index)
      return success and key or nil
    end,
    
    on_pool_playlist_to_active = function(playlist_id, insert_index)
      local success, key = self.controller:add_playlist_item(State.state.active_playlist, playlist_id, insert_index)
      return success and key or nil
    end,
    
    on_pool_reorder = function(new_rids)
      State.state.pool_order = new_rids
      State.persist_ui_prefs()
    end,
    
    on_repeat_cycle = function(item_key)
      self.controller:cycle_repeats(State.state.active_playlist, item_key)
    end,
    
    on_repeat_adjust = function(keys, delta)
      self.controller:adjust_repeats(State.state.active_playlist, keys, delta)
    end,
    
    on_repeat_sync = function(keys, target_reps)
      self.controller:sync_repeats(State.state.active_playlist, keys, target_reps)
    end,
    
    on_pool_double_click = function(rid)
      local success, key = self.controller:add_item(State.state.active_playlist, rid)
      if success and key then
        State.state.pending_spawn[#State.state.pending_spawn + 1] = key
        State.state.pending_select[#State.state.pending_select + 1] = key
      end
    end,
    
    on_pool_playlist_double_click = function(playlist_id)
      local active_playlist_id = State.state.active_playlist
      
      if State.detect_circular_reference then
        local circular, path = State.detect_circular_reference(active_playlist_id, playlist_id)
        if circular then
          local path_str = table.concat(path, " → ")
          reaper.ShowConsoleMsg(string.format("Circular reference detected: %s\n", path_str))
          reaper.MB("Cannot add playlist: circular reference detected.\n\nPath: " .. path_str, "Circular Reference", 0)
          return
        end
      end
      
      local success, key = self.controller:add_playlist_item(State.state.active_playlist, playlist_id)
      if success and key then
        State.state.pending_spawn[#State.state.pending_spawn + 1] = key
        State.state.pending_select[#State.state.pending_select + 1] = key
      end
    end,
    
    settings = settings,
  })
  
  self.region_tiles:set_pool_search_text(State.state.search_filter)
  self.region_tiles:set_pool_sort_mode(State.state.sort_mode)
  self.region_tiles:set_pool_sort_direction(State.state.sort_direction)
  self.region_tiles:set_app_bridge(State.state.bridge)
  self.region_tiles:set_pool_mode(State.state.pool_mode)
  
  State.state.active_search_filter = ""
  
  return self
end


function GUI:refresh_tabs()
  self.region_tiles:set_tabs(self.State.get_tabs(), self.State.state.active_playlist)
end

function GUI:draw_overflow_modal(ctx, window)
  local should_be_visible = self.region_tiles.active_container and 
                           self.region_tiles.active_container:is_overflow_visible()
  
  if not should_be_visible then
    self.overflow_modal_is_open = false
    return
  end
  
  local all_tabs = self.State.get_tabs()
  
  local tab_items = {}
  for _, tab in ipairs(all_tabs) do
    local region_count, playlist_count = self.State.count_playlist_contents(tab.id)
    local count_str = ""
    if region_count > 0 or playlist_count > 0 then
      local parts = {}
      if region_count > 0 then table.insert(parts, region_count .. "R") end
      if playlist_count > 0 then table.insert(parts, playlist_count .. "P") end
      count_str = " (" .. table.concat(parts, ", ") .. ")"
    end
    
    table.insert(tab_items, {
      id = tab.id,
      label = tab.label .. count_str,
      color = tab.chip_color or 0x888888FF,
    })
  end
  
  local active_id = self.State.state.active_playlist
  local selected_ids = {}
  selected_ids[active_id] = true
  
  if not window or not window.overlay then
    -- Fallback: Use simple popup if no overlay system
    if not self.overflow_modal_is_open then
      ImGui.OpenPopup(ctx, "##overflow_tabs_popup")
      self.overflow_modal_is_open = true
    end
    
    ImGui.SetNextWindowSize(ctx, 600, 500, ImGui.Cond_FirstUseEver)
    
    local visible = ImGui.BeginPopupModal(ctx, "##overflow_tabs_popup", true, ImGui.WindowFlags_NoTitleBar)
    
    if not visible then
      self.overflow_modal_is_open = false
      self.region_tiles.active_container:close_overflow_modal()
      return
    end
    
    ImGui.Text(ctx, "All Playlists:")
    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 8)
    
    ImGui.SetNextItemWidth(ctx, -1)
    local changed, text = ImGui.InputTextWithHint(ctx, "##tab_search", "Search playlists...", self.overflow_modal_search)
    if changed then 
      self.overflow_modal_search = text 
    end
    
    ImGui.Dummy(ctx, 0, 8)
    
    if ImGui.BeginChild(ctx, "##tab_list", 0, -40) then
      local clicked_tab = ChipList.draw_columns(ctx, tab_items, {
        selected_ids = selected_ids,
        search_text = self.overflow_modal_search,
        use_dot_style = true,
        bg_color = 0x252530FF,
        dot_size = 7,
        dot_spacing = 7,
        rounding = 5,
        padding_h = 12,
        column_width = 200,
        column_spacing = 16,
        item_spacing = 4,
      })
      
      if clicked_tab then
        self.State.set_active_playlist(clicked_tab, true)
        self:refresh_tabs()
        ImGui.CloseCurrentPopup(ctx)
        self.overflow_modal_is_open = false
        self.region_tiles.active_container:close_overflow_modal()
      end
    end
    ImGui.EndChild(ctx)
    
    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 4)
    
    local button_w = 100
    local avail_w = ImGui.GetContentRegionAvail(ctx)
    ImGui.SetCursorPosX(ctx, (avail_w - button_w) * 0.5)
    
    if ImGui.Button(ctx, "Close", button_w, 0) then
      ImGui.CloseCurrentPopup(ctx)
      self.overflow_modal_is_open = false
      self.region_tiles.active_container:close_overflow_modal()
    end
    
    ImGui.EndPopup(ctx)
    
    return
  end
  
  -- Original overlay system path
  if not self.overflow_modal_is_open then
    self.overflow_modal_is_open = true
    
    window.overlay:push({
      id = 'overflow-tabs',
      close_on_scrim = true,
      esc_to_close = true,
      on_close = function()
        self.overflow_modal_is_open = false
        self.region_tiles.active_container:close_overflow_modal()
      end,
      render = function(ctx, alpha, bounds)
        Sheet.render(ctx, alpha, bounds, function(ctx, w, h, a)
          local padding_h = 16
          
          ImGui.SetCursorPos(ctx, padding_h, 16)
          ImGui.Text(ctx, "All Playlists:")
          ImGui.SetCursorPosX(ctx, padding_h)
          ImGui.SetNextItemWidth(ctx, w - padding_h * 2)
          local changed, text = ImGui.InputTextWithHint(ctx, "##tab_search", "Search playlists...", self.overflow_modal_search)
          if changed then 
            self.overflow_modal_search = text 
          end
          
          ImGui.Dummy(ctx, 0, 12)
          ImGui.SetCursorPosX(ctx, padding_h)
          ImGui.Separator(ctx)
          ImGui.Dummy(ctx, 0, 12)
          
          ImGui.SetCursorPosX(ctx, padding_h)
          
          local clicked_tab = ChipList.draw_columns(ctx, tab_items, {
            selected_ids = selected_ids,
            search_text = self.overflow_modal_search,
            use_dot_style = true,
            bg_color = 0x252530FF,
            dot_size = 7,
            dot_spacing = 7,
            rounding = 5,
            padding_h = 12,
            column_width = 200,
            column_spacing = 16,
            item_spacing = 4,
          })
          
          if clicked_tab then
            self.State.set_active_playlist(clicked_tab, true)
            self:refresh_tabs()
            window.overlay:pop('overflow-tabs')
            self.overflow_modal_is_open = false
            self.region_tiles.active_container:close_overflow_modal()
          end
          
          ImGui.Dummy(ctx, 0, 20)
          ImGui.SetCursorPosX(ctx, padding_h)
          ImGui.Separator(ctx)
          ImGui.Dummy(ctx, 0, 12)
          
          local button_w = 100
          local start_x = (w - button_w) * 0.5
          
          ImGui.SetCursorPosX(ctx, start_x)
          if ImGui.Button(ctx, "Close", button_w, 32) then
            window.overlay:pop('overflow-tabs')
            self.overflow_modal_is_open = false
            self.region_tiles.active_container:close_overflow_modal()
          end
        end, { 
          title = "Select Playlist", 
          width = 0.6, 
          height = 0.7 
        })
      end
    })
  end
end

function GUI:draw_transport_section(ctx)
  local content_w, content_h = self.transport_container:begin_draw(ctx)
  
  local spacing = self.Config.TRANSPORT.spacing
  
  -- Responsive layout calculations
  local view_mode_w = self.Config.TRANSPORT.view_mode.size
  local global_w = self.Config.TRANSPORT.global.pad_width + 16
  local display_w = content_w - view_mode_w - global_w - spacing * 3
  
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
  
  -- Left: View Mode Button (vertically centered)
  local view_x = cursor_x
  local view_y = cursor_y + (content_h - view_mode_w) / 2
  
  self.view_mode_button:draw(ctx, view_x, view_y, self.State.state.layout_mode, function()
    self.State.state.layout_mode = (self.State.state.layout_mode == 'horizontal') and 'vertical' or 'horizontal'
    self.region_tiles:set_layout_mode(self.State.state.layout_mode)
    self.State.persist_ui_prefs()
  end)
  
  -- Center: Transport Display + Jump Controls
  local display_x = view_x + view_mode_w + spacing
  local display_y = cursor_y
  local display_h = content_h - self.Config.TRANSPORT.jump.height - 6
  
  local bridge_state = {
    is_playing = self.State.state.bridge:get_state().is_playing,
    time_remaining = self.State.state.bridge:get_time_remaining(),
    progress = self.State.state.bridge:get_progress() or 0,
    quantize_mode = self.State.state.bridge:get_state().quantize_mode,
  }
  
  local get_current_region = function()
    local rid = self.State.state.bridge:get_current_rid()
    if rid then
      return self.State.state.region_index[rid]
    end
    return nil
  end
  
  self.transport_display:draw(ctx, display_x, display_y, display_w, display_h, bridge_state, get_current_region)
  
  -- Jump Controls (below display)
  local jump_x = display_x
  local jump_y = display_y + display_h + 6
  
  local engine = self.State.state.bridge.engine
  
  self.jump_controls:draw(ctx, jump_x, jump_y, display_w, bridge_state, self.quantize_lookahead,
    function()
      self.State.state.bridge:jump_to_next_quantized(self.quantize_lookahead)
    end,
    function(mode)
      if engine and engine.quantize then
        engine.quantize:set_quantize_mode(mode)
      end
    end,
    function(value)
      self.quantize_lookahead = value
    end
  )
  
  -- Right: Global Controls (StatusPads)
  local global_x = display_x + display_w + spacing
  local global_y = cursor_y + (content_h - 72) / 2
  
  local transport_override = engine and engine:get_transport_override() or false
  local loop_playlist = self.State.state.bridge:get_loop_playlist()
  
  self.global_controls:draw(ctx, global_x, global_y, transport_override, loop_playlist,
    function(value)
      if engine then
        engine:set_transport_override(value)
        if self.settings then
          self.settings:set('transport_override', value)
        end
      end
    end,
    function(value)
      self.State.state.bridge:set_loop_playlist(value)
    end
  )
  
  self.transport_container:end_draw(ctx)
end

function GUI:draw_horizontal_separator(ctx, x, y, width, height)
  local separator_config = self.Config.SEPARATOR.horizontal
  local separator_thickness = separator_config.thickness
  
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x and mx < x + width and 
                     my >= y - separator_thickness/2 and my < y + separator_thickness/2
  
  if is_hovered or self.separator_drag_state.is_dragging then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeNS)
  end
  
  ImGui.SetCursorScreenPos(ctx, x, y - separator_thickness/2)
  ImGui.InvisibleButton(ctx, "##hseparator", width, separator_thickness)
  
  if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
    return "reset", 0
  end
  
  if ImGui.IsItemActive(ctx) then
    if not self.separator_drag_state.is_dragging then
      self.separator_drag_state.is_dragging = true
      self.separator_drag_state.drag_offset = my - y
    end
    
    local new_pos = my - self.separator_drag_state.drag_offset
    return "drag", new_pos
  elseif self.separator_drag_state.is_dragging and not ImGui.IsMouseDown(ctx, 0) then
    self.separator_drag_state.is_dragging = false
  end
  
  return "none", y
end

function GUI:draw_vertical_separator(ctx, x, y, width, height)
  local separator_config = self.Config.SEPARATOR.vertical
  local separator_thickness = separator_config.thickness
  
  local mx, my = ImGui.GetMousePos(ctx)
  local is_hovered = mx >= x - separator_thickness/2 and mx < x + separator_thickness/2 and 
                     my >= y and my < y + height
  
  if is_hovered or self.separator_drag_state.is_dragging then
    ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
  end
  
  ImGui.SetCursorScreenPos(ctx, x - separator_thickness/2, y)
  ImGui.InvisibleButton(ctx, "##vseparator", separator_thickness, height)
  
  if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
    return "reset", 0
  end
  
  if ImGui.IsItemActive(ctx) then
    if not self.separator_drag_state.is_dragging then
      self.separator_drag_state.is_dragging = true
      self.separator_drag_state.drag_offset = mx - x
    end
    
    local new_pos = mx - self.separator_drag_state.drag_offset
    return "drag", new_pos
  elseif self.separator_drag_state.is_dragging and not ImGui.IsMouseDown(ctx, 0) then
    self.separator_drag_state.is_dragging = false
  end
  
  return "none", x
end

function GUI:get_filtered_active_items(playlist)
  local filter = self.State.state.active_search_filter or ""
  
  if filter == "" then
    return playlist.items
  end
  
  local filtered = {}
  local filter_lower = filter:lower()
  
  for _, item in ipairs(playlist.items) do
    if item.type == "playlist" then
      local playlist_data = self.State.get_playlist_by_id(item.playlist_id)
      local name_lower = playlist_data and playlist_data.name:lower() or ""
      if name_lower:find(filter_lower, 1, true) then
        filtered[#filtered + 1] = item
      end
    else
      local region = self.State.state.region_index[item.rid]
      if region then
        local name_lower = region.name:lower()
        if name_lower:find(filter_lower, 1, true) then
          filtered[#filtered + 1] = item
        end
      end
    end
  end
  
  return filtered
end

function GUI:draw(ctx, window)
  if self.region_tiles.active_container and self.region_tiles.active_container:is_overflow_visible() then
    self:draw_overflow_modal(ctx, window)
  end
  
  self.State.state.bridge:update()
  self.State.update()
  
  if #self.State.state.pending_spawn > 0 then
    self.region_tiles.active_grid:mark_spawned(self.State.state.pending_spawn)
    self.State.state.pending_spawn = {}
  end
  
  if #self.State.state.pending_select > 0 then
    if self.region_tiles.pool_grid and self.region_tiles.pool_grid.selection then
      self.region_tiles.pool_grid.selection:clear()
    end
    if self.region_tiles.active_grid and self.region_tiles.active_grid.selection then
      self.region_tiles.active_grid.selection:clear()
    end
    
    for _, key in ipairs(self.State.state.pending_select) do
      if self.region_tiles.active_grid.selection then
        self.region_tiles.active_grid.selection.selected[key] = true
      end
    end
    
    if self.region_tiles.active_grid.selection then
      self.region_tiles.active_grid.selection.last_clicked = self.State.state.pending_select[#self.State.state.pending_select]
    end
    
    if self.region_tiles.active_grid.behaviors and self.region_tiles.active_grid.behaviors.on_select and self.region_tiles.active_grid.selection then
      self.region_tiles.active_grid.behaviors.on_select(self.region_tiles.active_grid.selection:selected_keys())
    end
    
    self.State.state.pending_select = {}
  end
  
  if #self.State.state.pending_destroy > 0 then
    self.region_tiles.active_grid:mark_destroyed(self.State.state.pending_destroy)
    self.State.state.pending_destroy = {}
  end
  
  self.region_tiles:update_animations(0.016)
  
  Shortcuts.handle_keyboard_shortcuts(ctx, self.State.state, self.region_tiles)
  
  self:draw_transport_section(ctx)
  
  ImGui.Dummy(ctx, 1, 8)
  
  local pl = self.State.get_active_playlist()
  local filtered_active_items = self:get_filtered_active_items(pl)
  local display_playlist = {
    id = pl.id,
    name = pl.name,
    items = filtered_active_items,
  }
  
  local pool_data
  if self.State.state.pool_mode == "playlists" then
    pool_data = self.State.get_playlists_for_pool()
  elseif self.State.state.pool_mode == "mixed" then
    pool_data = {}
    local regions = self.State.get_filtered_pool_regions()
    local playlists = self.State.get_playlists_for_pool()
    for _, region in ipairs(regions) do
      pool_data[#pool_data + 1] = region
    end
    for _, playlist in ipairs(playlists) do
      pool_data[#pool_data + 1] = playlist
    end
  else
    pool_data = self.State.get_filtered_pool_regions()
  end
  
  if self.State.state.layout_mode == 'horizontal' then
    local content_w, content_h = ImGui.GetContentRegionAvail(ctx)
    
    local separator_config = self.Config.SEPARATOR.horizontal
    local min_active_height = separator_config.min_active_height
    local min_pool_height = separator_config.min_pool_height
    local separator_gap = separator_config.gap
    
    local min_total_height = min_active_height + min_pool_height + separator_gap
    
    local active_height, pool_height
    
    if content_h < min_total_height then
      local ratio = content_h / min_total_height
      active_height = math.floor(min_active_height * ratio)
      pool_height = content_h - active_height - separator_gap
      
      if active_height < 50 then active_height = 50 end
      if pool_height < 50 then pool_height = 50 end
      
      pool_height = math.max(1, content_h - active_height - separator_gap)
    else
      active_height = self.State.state.separator_position_horizontal
      active_height = math.max(min_active_height, math.min(active_height, content_h - min_pool_height - separator_gap))
      pool_height = content_h - active_height - separator_gap
    end
    
    active_height = math.max(1, active_height)
    pool_height = math.max(1, pool_height)
    
    local start_x, start_y = ImGui.GetCursorScreenPos(ctx)

    local sep_thickness = separator_config.thickness
    local sep_y = start_y + active_height + separator_gap/2
    local mx, my = ImGui.GetMousePos(ctx)
    local over_sep_h = (mx >= start_x and mx < start_x + content_w and my >= sep_y - sep_thickness/2 and my < sep_y + sep_thickness/2)
    local block_input = self.separator_drag_state.is_dragging or (over_sep_h and ImGui.IsMouseDown(ctx, 0))

    if self.region_tiles.active_grid then self.region_tiles.active_grid.block_all_input = block_input end
    if self.region_tiles.pool_grid then self.region_tiles.pool_grid.block_all_input = block_input end
    
    self.region_tiles:draw_active(ctx, display_playlist, active_height)
    
    local separator_y = sep_y
    local action, value = self:draw_horizontal_separator(ctx, start_x, separator_y, content_w, content_h)
    
    if action == "reset" then
      self.State.state.separator_position_horizontal = separator_config.default_position
      self.State.persist_ui_prefs()
    elseif action == "drag" and content_h >= min_total_height then
      local new_active_height = value - start_y - separator_gap/2
      new_active_height = math.max(min_active_height, math.min(new_active_height, content_h - min_pool_height - separator_gap))
      self.State.state.separator_position_horizontal = new_active_height
      self.State.persist_ui_prefs()
    end
    
    ImGui.SetCursorScreenPos(ctx, start_x, start_y + active_height + separator_gap)
    
    self.region_tiles:draw_pool(ctx, pool_data, pool_height)

    if not self.separator_drag_state.is_dragging and not (over_sep_h and ImGui.IsMouseDown(ctx, 0)) then
      if self.region_tiles.active_grid then self.region_tiles.active_grid.block_all_input = false end
      if self.region_tiles.pool_grid then self.region_tiles.pool_grid.block_all_input = false end
    end
  else
    local content_w, content_h = ImGui.GetContentRegionAvail(ctx)
    
    local separator_config = self.Config.SEPARATOR.vertical
    local min_active_width = separator_config.min_active_width
    local min_pool_width = separator_config.min_pool_width
    local separator_gap = separator_config.gap
    
    local min_total_width = min_active_width + min_pool_width + separator_gap
    
    local active_width, pool_width
    
    if content_w < min_total_width then
      local ratio = content_w / min_total_width
      active_width = math.floor(min_active_width * ratio)
      pool_width = content_w - active_width - separator_gap
      
      if active_width < 50 then active_width = 50 end
      if pool_width < 50 then pool_width = 50 end
      
      pool_width = math.max(1, content_w - active_width - separator_gap)
    else
      active_width = self.State.state.separator_position_vertical
      active_width = math.max(min_active_width, math.min(active_width, content_w - min_pool_width - separator_gap))
      pool_width = content_w - active_width - separator_gap
    end
    
    active_width = math.max(1, active_width)
    pool_width = math.max(1, pool_width)
    
    local start_cursor_x, start_cursor_y = ImGui.GetCursorScreenPos(ctx)

    local sep_thickness = separator_config.thickness
    local sep_x = start_cursor_x + active_width + separator_gap/2
    local mx, my = ImGui.GetMousePos(ctx)
    local over_sep_v = (mx >= sep_x - sep_thickness/2 and mx < sep_x + sep_thickness/2 and my >= start_cursor_y and my < start_cursor_y + content_h)
    local block_input = self.separator_drag_state.is_dragging or (over_sep_v and ImGui.IsMouseDown(ctx, 0))

    if self.region_tiles.active_grid then self.region_tiles.active_grid.block_all_input = block_input end
    if self.region_tiles.pool_grid then self.region_tiles.pool_grid.block_all_input = block_input end
    
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0)
    
    if ImGui.BeginChild(ctx, "##left_column", active_width, content_h, ImGui.ChildFlags_None, 0) then
      self.region_tiles:draw_active(ctx, display_playlist, content_h)
    end
    ImGui.EndChild(ctx)
    
    ImGui.PopStyleVar(ctx)
    
    local separator_x = sep_x
    local action, value = self:draw_vertical_separator(ctx, separator_x, start_cursor_y, content_w, content_h)
    
    if action == "reset" then
      self.State.state.separator_position_vertical = separator_config.default_position
      self.State.persist_ui_prefs()
    elseif action == "drag" and content_w >= min_total_width then
      local new_active_width = value - start_cursor_x - separator_gap/2
      new_active_width = math.max(min_active_width, math.min(new_active_width, content_w - min_pool_width - separator_gap))

    if not self.separator_drag_state.is_dragging and not (over_sep_v and ImGui.IsMouseDown(ctx, 0)) then
      if self.region_tiles.active_grid then self.region_tiles.active_grid.block_all_input = false end
      if self.region_tiles.pool_grid then self.region_tiles.pool_grid.block_all_input = false end
    end
      self.State.state.separator_position_vertical = new_active_width
      self.State.persist_ui_prefs()
    end
    
    ImGui.SetCursorScreenPos(ctx, start_cursor_x + active_width + separator_gap, start_cursor_y)
    
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0)
    
    if ImGui.BeginChild(ctx, "##right_column", pool_width, content_h, ImGui.ChildFlags_None, 0) then
      self.region_tiles:draw_pool(ctx, pool_data, content_h)
    end
    ImGui.EndChild(ctx)
    
    ImGui.PopStyleVar(ctx)
  end
  
  self.region_tiles:draw_ghosts(ctx)
end

return M
