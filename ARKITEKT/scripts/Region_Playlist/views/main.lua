local ImGui = require 'imgui' '0.10'

local TransportBar = require('Region_Playlist.views.transport_bar')
local ActivePanel = require('Region_Playlist.views.active_panel')
local PoolPanel = require('Region_Playlist.views.pool_panel')
local StatusBarView = require('Region_Playlist.views.status_bar')
local ModalManager = require('Region_Playlist.components.modal_manager')
local SeparatorManager = require('Region_Playlist.components.separator_manager')
local Shortcuts = require('Region_Playlist.app.shortcuts')
local StateStore = require('Region_Playlist.core.state')

local M = {}
M.__index = M

local function S()
  return StateStore.for_project(0)
end

local function build_dependencies(arg1, coordinator, events, extras)
  if type(arg1) == 'table' and coordinator == nil and events == nil then
    return arg1
  end

  local bundle = {}
  if type(extras) == 'table' then
    for k, v in pairs(extras) do
      bundle[k] = v
    end
  end

  bundle.state = arg1
  bundle.coordinator = coordinator
  bundle.events = events

  if not bundle.gui and bundle.app_state and bundle.config then
    local GUI = require('Region_Playlist.app.gui')
    bundle.gui = GUI.create(bundle.app_state, bundle.config, bundle.settings)
  end

  return bundle
end

local function ensure_selection_struct(selection)
  selection = selection or {}
  local active = selection.active or {}
  local pool = selection.pool or {}

  selection.active = {
    keys = active.keys or {},
    last_clicked = active.last_clicked,
  }

  selection.pool = {
    keys = pool.keys or {},
    last_clicked = pool.last_clicked,
  }

  return selection
end

local function apply_selection_to_grid(grid, selection_data)
  if not grid or not grid.selection then
    return
  end

  grid.selection:clear()

  local keys = selection_data.keys or {}
  for i = 1, #keys do
    grid.selection.selected[keys[i]] = true
  end

  grid.selection.last_clicked = selection_data.last_clicked
end

function M.new(arg1, coordinator, events, extras)
  local deps = build_dependencies(arg1, coordinator, events, extras)

  local self = setmetatable({
    deps = deps or {},
    gui = deps.gui,
    State = deps.app_state or deps.state,
    Config = deps.config,
    settings = deps.settings,
    coordinator = deps.coordinator,
    events = deps.events,
  }, M)

  if not self.gui then
    error('MainView requires a GUI instance')
  end

  self.gui:set_main_view(self)

  self.transport_bar = TransportBar.new({
    State = self.State,
    Config = self.Config,
    settings = self.settings,
    region_tiles = self.gui.region_tiles,
  })

  self.active_panel = ActivePanel.new({
    State = self.State,
    region_tiles = self.gui.region_tiles,
  })

  self.pool_panel = PoolPanel.new({
    State = self.State,
    region_tiles = self.gui.region_tiles,
  })

  self.modal_manager = ModalManager.new({
    State = self.State,
  })

  self.separator_manager = SeparatorManager.new({
    Config = self.Config,
  })

  self.status_view = StatusBarView.new({
    status_bar = deps.status_bar,
  })

  if self.State and self.State.state then
    self.State.state.active_search_filter = self.State.state.active_search_filter or ''
  end

  self:apply_selection(S():get('ui.selection'))
  self:setup_state_hooks()

  return self
end

function M:set_gui(gui)
  self.gui = gui
end

function M:setup_state_hooks()
  if not (self.State and self.State.state) then return end

  self.State.state.on_state_restored = function()
    self:refresh_tabs()
    self:update_selection(function(selection)
      selection.active = { keys = {}, last_clicked = nil }
      selection.pool = { keys = {}, last_clicked = nil }
    end)
  end

  self.State.state.on_repeat_cycle = function(key, current_loop, total_reps)
    reaper.ShowConsoleMsg(string.format('[GUI] Repeat cycle: %s (%d/%d)\n', key, current_loop, total_reps))
  end
end

function M:refresh_tabs()
  if self.gui and self.gui.region_tiles and self.State then
    self.gui.region_tiles:set_tabs(self.State.get_tabs(), S():get('playlists.active_id'))
  end
end

function M:apply_selection(selection)
  selection = ensure_selection_struct(selection)

  local region_tiles = self.gui and self.gui.region_tiles
  if region_tiles then
    apply_selection_to_grid(region_tiles.active_grid, selection.active)
    apply_selection_to_grid(region_tiles.pool_grid, selection.pool)
  end

  return selection
end

function M:update_selection(mutator)
  local selection = ensure_selection_struct(S():get('ui.selection'))
  if mutator then mutator(selection) end
  S():set('ui.selection', selection)
  return self:apply_selection(selection)
end

function M:process_pending_actions()
  if not (self.State and self.State.state and self.gui and self.gui.region_tiles) then
    return
  end

  local state = self.State.state
  local tiles = self.gui.region_tiles

  if #state.pending_spawn > 0 and tiles.active_grid then
    tiles.active_grid:mark_spawned(state.pending_spawn)
    state.pending_spawn = {}
  end

  if #state.pending_select > 0 then
    local pending_keys = { table.unpack(state.pending_select) }
    local last_clicked = pending_keys[#pending_keys]

    self:update_selection(function(selection)
      selection.pool = { keys = {}, last_clicked = nil }
      selection.active = {
        keys = pending_keys,
        last_clicked = last_clicked,
      }
    end)

    if tiles.active_grid
      and tiles.active_grid.behaviors
      and tiles.active_grid.behaviors.on_select
      and tiles.active_grid.selection then
      tiles.active_grid.behaviors.on_select(tiles.active_grid.selection:selected_keys())
    end

    state.pending_select = {}
  end

  if #state.pending_destroy > 0 and tiles.active_grid then
    tiles.active_grid:mark_destroyed(state.pending_destroy)
    state.pending_destroy = {}
  end
end

local function get_active_playlist_id(State)
  if not State then return nil end

  local active_id = S():get('playlists.active_id')
  if active_id ~= nil then
    return active_id
  end

  local playlist = State.get_active_playlist and State.get_active_playlist()
  return playlist and playlist.id or nil
end

function M:draw(ctx, window)
  if not (self.gui and self.State and self.Config) then
    return
  end

  local region_tiles = self.gui.region_tiles
  if region_tiles and region_tiles.active_container and region_tiles.active_container:is_overflow_visible() then
    self.modal_manager:draw(ctx, window, region_tiles)
  end

  if self.State.state and self.State.state.bridge then
    self.State.state.bridge:update()
  end

  if self.State.update then
    self.State.update()
  end

  self:process_pending_actions()

  if region_tiles and region_tiles.update_animations then
    region_tiles:update_animations(0.016)
  end

  Shortcuts.handle_keyboard_shortcuts(ctx, self.State.state, region_tiles)

  self.transport_bar:draw(ctx)
  ImGui.Dummy(ctx, 1, 8)

  if not get_active_playlist_id(self.State) then return end

  local playlist = self.State.get_active_playlist and self.State.get_active_playlist()
  if not playlist then return end

  local filtered_items = self.active_panel:get_filtered_items(playlist)

  local pool_data = self.pool_panel:get_pool_data()

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

    self.active_panel:draw(ctx, { playlist = playlist, items = filtered_items }, active_height)

    local separator_y = start_y + active_height + separator_gap / 2
    local action, value = self.separator_manager:draw_horizontal(ctx, start_x, separator_y, content_w, content_h)

    if action == 'reset' then
      self.State.state.separator_position_horizontal = separator_config.default_position
      self.State.persist_ui_prefs()
    elseif action == 'drag' and content_h >= min_total_height then
      local new_active_height = value - start_y - separator_gap / 2
      new_active_height = math.max(min_active_height, math.min(new_active_height, content_h - min_pool_height - separator_gap))
      self.State.state.separator_position_horizontal = new_active_height
      self.State.persist_ui_prefs()
    end

    ImGui.SetCursorScreenPos(ctx, start_x, start_y + active_height + separator_gap)
    self.pool_panel:draw(ctx, pool_data, pool_height)
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

    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0)

    if ImGui.BeginChild(ctx, '##left_column', active_width, content_h, ImGui.ChildFlags_None, 0) then
      self.active_panel:draw(ctx, { playlist = playlist, items = filtered_items }, content_h)
    end
    ImGui.EndChild(ctx)

    ImGui.PopStyleVar(ctx)

    local separator_x = start_cursor_x + active_width + separator_gap / 2
    local action, value = self.separator_manager:draw_vertical(ctx, separator_x, start_cursor_y, content_w, content_h)

    if action == 'reset' then
      self.State.state.separator_position_vertical = separator_config.default_position
      self.State.persist_ui_prefs()
    elseif action == 'drag' and content_w >= min_total_width then
      local new_active_width = value - start_cursor_x - separator_gap / 2
      new_active_width = math.max(min_active_width, math.min(new_active_width, content_w - min_pool_width - separator_gap))
      self.State.state.separator_position_vertical = new_active_width
      self.State.persist_ui_prefs()
    end

    ImGui.SetCursorScreenPos(ctx, start_cursor_x + active_width + separator_gap, start_cursor_y)

    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0)
    if ImGui.BeginChild(ctx, '##right_column', pool_width, content_h, ImGui.ChildFlags_None, 0) then
      self.pool_panel:draw(ctx, pool_data, content_h)
    end
    ImGui.EndChild(ctx)
    ImGui.PopStyleVar(ctx)
  end

  if region_tiles and region_tiles.draw_ghosts then
    region_tiles:draw_ghosts(ctx)
  end

  if self.status_view then
    self.status_view:draw(ctx)
  end
end

return M
