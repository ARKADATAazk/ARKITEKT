local ImGui = require 'imgui' '0.10'
local ChipList = require('rearkitekt.gui.widgets.chip_list.list')
local Sheet = require('rearkitekt.gui.widgets.overlay.sheet')
local StateStore = require('Region_Playlist.core.state')

local ModalManager = {}
ModalManager.__index = ModalManager

local function S()
  return StateStore.for_project(0)
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

local function set_active_playlist_id(State, playlist_id)
  if not (State and playlist_id) then return end
  S():set('playlists.active_id', playlist_id)
  if State.set_active_playlist then
    State.set_active_playlist(playlist_id)
  end
end

local function build_tab_items(State)
  local all_tabs = State and State.get_tabs and State.get_tabs() or {}
  local tab_items = {}

  for _, tab in ipairs(all_tabs) do
    tab_items[#tab_items + 1] = {
      id = tab.id,
      label = tab.label,
      color = tab.chip_color or 0x888888FF,
    }
  end

  return tab_items
end

function ModalManager.new(deps)
  deps = deps or {}

  local self = setmetatable({
    State = deps.State or deps.state,
    search_text = '',
    is_open = false,
  }, ModalManager)

  return self
end

function ModalManager:close(region_tiles)
  self.is_open = false
  if region_tiles and region_tiles.active_container and region_tiles.active_container.close_overflow_modal then
    region_tiles.active_container:close_overflow_modal()
  end
end

local function draw_chip_columns(ctx, items, search_text, selected_ids)
  return ChipList.draw_columns(ctx, items, {
    selected_ids = selected_ids,
    search_text = search_text,
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
end

function ModalManager:draw(ctx, window, region_tiles)
  if not region_tiles or not region_tiles.active_container then
    self.is_open = false
    return
  end

  local should_be_visible = region_tiles.active_container:is_overflow_visible()
  if not should_be_visible then
    self.is_open = false
    return
  end

  local tab_items = build_tab_items(self.State)
  local active_id = get_active_playlist_id(self.State)
  local selected_ids = {}
  if active_id then
    selected_ids[active_id] = true
  end

  if not window or not window.overlay then
    if not self.is_open then
      ImGui.OpenPopup(ctx, '##overflow_tabs_popup')
      self.is_open = true
    end

    ImGui.SetNextWindowSize(ctx, 600, 500, ImGui.Cond_FirstUseEver)
    local visible = ImGui.BeginPopupModal(ctx, '##overflow_tabs_popup', true, ImGui.WindowFlags_NoTitleBar)

    if not visible then
      self:close(region_tiles)
      return
    end

    ImGui.Text(ctx, 'All Playlists:')
    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 8)

    ImGui.SetNextItemWidth(ctx, -1)
    local changed, text = ImGui.InputTextWithHint(ctx, '##tab_search', 'Search playlists...', self.search_text)
    if changed then
      self.search_text = text
    end

    ImGui.Dummy(ctx, 0, 8)

    if ImGui.BeginChild(ctx, '##tab_list', 0, -40) then
      local clicked_tab = draw_chip_columns(ctx, tab_items, self.search_text, selected_ids)
      if clicked_tab then
        set_active_playlist_id(self.State, clicked_tab)
        ImGui.CloseCurrentPopup(ctx)
        self:close(region_tiles)
      end
    end
    ImGui.EndChild(ctx)

    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 4)

    local button_w = 100
    local avail_w = ImGui.GetContentRegionAvail(ctx)
    ImGui.SetCursorPosX(ctx, (avail_w - button_w) * 0.5)

    if ImGui.Button(ctx, 'Close', button_w, 0) then
      ImGui.CloseCurrentPopup(ctx)
      self:close(region_tiles)
    end

    ImGui.EndPopup(ctx)
    return
  end

  if not self.is_open then
    self.is_open = true

    window.overlay:push({
      id = 'overflow-tabs',
      close_on_scrim = true,
      esc_to_close = true,
      on_close = function()
        self:close(region_tiles)
      end,
      render = function(render_ctx, alpha, bounds)
        Sheet.render(render_ctx, alpha, bounds, function(ctx2, w, h)
          local padding_h = 16

          ImGui.SetCursorPos(ctx2, padding_h, 16)
          ImGui.Text(ctx2, 'All Playlists:')
          ImGui.SetCursorPosX(ctx2, padding_h)
          ImGui.SetNextItemWidth(ctx2, w - padding_h * 2)

          local changed, text = ImGui.InputTextWithHint(ctx2, '##tab_search', 'Search playlists...', self.search_text)
          if changed then
            self.search_text = text
          end

          ImGui.Dummy(ctx2, 0, 12)
          ImGui.SetCursorPosX(ctx2, padding_h)
          ImGui.Separator(ctx2)
          ImGui.Dummy(ctx2, 0, 12)

          ImGui.SetCursorPosX(ctx2, padding_h)
          local clicked_tab = draw_chip_columns(ctx2, tab_items, self.search_text, selected_ids)
          if clicked_tab then
            set_active_playlist_id(self.State, clicked_tab)
            window.overlay:pop('overflow-tabs')
            self:close(region_tiles)
          end

          ImGui.Dummy(ctx2, 0, 20)
          ImGui.SetCursorPosX(ctx2, padding_h)
          ImGui.Separator(ctx2)
          ImGui.Dummy(ctx2, 0, 12)

          local button_w = 100
          local start_x = (w - button_w) * 0.5

          ImGui.SetCursorPosX(ctx2, start_x)
          if ImGui.Button(ctx2, 'Close', button_w, 32) then
            window.overlay:pop('overflow-tabs')
            self:close(region_tiles)
          end
        end, {
          width = bounds.width,
          height = bounds.height,
        })
      end,
    })
  end
end

return ModalManager
