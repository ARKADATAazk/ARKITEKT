-- @noindex
-- RegionPlaylist/ui/views/overflow_modal_view.lua
-- Overflow modal for playlist picker - minimal floating UI

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local Base = require('arkitekt.gui.widgets.base')
local ChipList = require('arkitekt.gui.widgets.data.chip_list')

local M = {}

local OverflowModalView = {}
OverflowModalView.__index = OverflowModalView

function M.new(region_tiles, state_module, on_tab_selected)
  return setmetatable({
    region_tiles = region_tiles,
    state = state_module,
    on_tab_selected = on_tab_selected,
    search_text = '',
    is_open = false,
  }, OverflowModalView)
end

function OverflowModalView:should_show()
  return self.region_tiles.active_container and 
         self.region_tiles.active_container:is_overflow_visible()
end

function OverflowModalView:close()
  self.is_open = false
  if self.region_tiles.active_container then
    self.region_tiles.active_container:close_overflow_modal()
  end
end

function OverflowModalView:draw(ctx, window)
  local should_be_visible = self:should_show()
  
  if not should_be_visible then
    self.is_open = false
    return
  end
  
  local all_tabs = self.state.get_tabs()
  
  local tab_items = {}
  for _, tab in ipairs(all_tabs) do
    local region_count, playlist_count = self.state.count_playlist_contents(tab.id)
    local count_str = ''
    if region_count > 0 or playlist_count > 0 then
      local parts = {}
      if region_count > 0 then parts[#parts + 1] = region_count .. 'R' end
      if playlist_count > 0 then parts[#parts + 1] = playlist_count .. 'P' end
      count_str = ' (' .. table.concat(parts, ', ') .. ')'
    end

    tab_items[#tab_items + 1] = {
      id = tab.id,
      label = tab.label .. count_str,
      color = tab.chip_color or 0x888888FF,
      region_count = region_count,
      playlist_count = playlist_count,
    }
  end

  -- Tooltip renderer for playlist chips - shows flattened contents with colors
  local MAX_TOOLTIP_ITEMS = 12
  local DOT_SIZE = 6
  local DOT_SPACING = 8
  local function render_playlist_tooltip(ctx, chip_item)
    local items = self.state.get_playlist_items(chip_item.id)
    if not items or #items == 0 then
      ImGui.Text(ctx, 'Empty playlist')
      return
    end

    for i, item in ipairs(items) do
      if i > MAX_TOOLTIP_ITEMS then
        ImGui.Text(ctx, '... and ' .. (#items - MAX_TOOLTIP_ITEMS) .. ' more')
        break
      end

      local name, color
      if item.type == 'region' then
        name = item.region_name or '(unknown region)'
        -- Get region color
        local region = self.state.get_region_by_rid(item.rid)
        color = region and region.color or 0x888888FF
      else
        -- Nested playlist - use playlist's chip color
        local nested_pl = self.state.get_playlist_by_id and self.state.get_playlist_by_id(item.playlist_id)
        local nested_name = nested_pl and nested_pl.name or self.state.get_playlist_name(item.playlist_id)
        name = '[' .. (nested_name or 'Playlist') .. ']'
        color = nested_pl and nested_pl.chip_color or 0x6688AAFF
      end

      local reps = item.reps or 1
      local text = reps > 1
        and string.format('%d. %s (x%d)', i, name, reps)
        or string.format('%d. %s', i, name)

      -- Draw colored dot + text
      local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
      local text_h = ImGui.GetTextLineHeight(ctx)
      local dot_y = cursor_y + text_h * 0.5

      -- Draw dot
      local dl = ImGui.GetWindowDrawList(ctx)
      ImGui.DrawList_AddCircleFilled(dl, cursor_x + DOT_SIZE * 0.5, dot_y, DOT_SIZE * 0.5, color)

      -- Draw text offset by dot
      ImGui.SetCursorScreenPos(ctx, cursor_x + DOT_SIZE + DOT_SPACING, cursor_y)
      ImGui.Text(ctx, text)
    end
  end
  
  local active_id = self.state.get_active_playlist_id()
  local selected_ids = {}
  selected_ids[active_id] = true

  -- Fallback: use ImGui popup if no overlay system
  if not window or not window.overlay then
    if not self.is_open then
      ImGui.OpenPopup(ctx, '##overflow_tabs_popup')
      self.is_open = true
    end

    ImGui.SetNextWindowSize(ctx, 600, 450, ImGui.Cond_FirstUseEver)

    local visible = ImGui.BeginPopupModal(ctx, '##overflow_tabs_popup', true, ImGui.WindowFlags_NoTitleBar)
    if not visible then
      self.is_open = false
      self:close()
      return
    end

    -- Search input
    ImGui.SetNextItemWidth(ctx, -1)
    local changed, text = ImGui.InputTextWithHint(ctx, '##tab_search', 'Search playlists...', self.search_text)
    if changed then
      self.search_text = text
    end

    ImGui.Dummy(ctx, 0, 8)

    if ImGui.BeginChild(ctx, '##tab_list', 0, -8) then
      local text_h = ImGui.GetTextLineHeight(ctx)
      local clicked_tab = ChipList.draw_columns(ctx, tab_items, {
        selected_ids = selected_ids,
        search_text = self.search_text,
        use_dot_style = true,
        bg_color = 0x252525FF,
        item_height = text_h + 8,
        dot_size = 8,
        dot_spacing = 10,
        rounding = 3,
        padding_h = 10,
        column_width = 180,
        column_spacing = 12,
        item_spacing = 6,
        center_when_sparse = true,
        render_tooltip = render_playlist_tooltip,
      })

      if clicked_tab then
        self.state.set_active_playlist(clicked_tab, true)
        if self.on_tab_selected then
          self.on_tab_selected()
        end
        ImGui.CloseCurrentPopup(ctx)
        self.is_open = false
        self:close()
      end

      ImGui.EndChild(ctx)
    end

    -- Escape to close
    if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
      ImGui.CloseCurrentPopup(ctx)
      self.is_open = false
      self:close()
    end

    ImGui.EndPopup(ctx)
    return
  end
  
  if not self.is_open then
    self.is_open = true

    local selected_ids = {}
    selected_ids[active_id] = true

    window.overlay:push({
      id = 'overflow-tabs',
      close_on_scrim = true,
      esc_to_close = true,
      on_close = function()
        self.is_open = false
        self:close()
      end,
      render = function(ctx, alpha, bounds)
        local dl = Base.get_context(ctx):draw_list()

        -- Layout config
        local content_width = math.min(600, bounds.w * 0.8)
        local search_height = 32
        local list_max_height = math.min(400, bounds.h * 0.6)

        -- Center horizontally
        local start_x = bounds.x + (bounds.w - content_width) * 0.5
        local start_y = bounds.y + bounds.h * 0.15  -- Start 15% from top

        -- Search input
        ImGui.SetCursorScreenPos(ctx, start_x, start_y)
        Ark.InputText.Search(ctx, {
          id = 'overflow_search',
          x = start_x,
          y = start_y,
          width = content_width,
          height = search_height,
          placeholder = 'Search playlists...',
          text = self.search_text,
          draw_list = dl,
          on_change = function(new_text)
            self.search_text = new_text
          end
        })

        -- List area
        local list_y = start_y + search_height + 16

        -- Scrollable child for ChipList
        ImGui.SetCursorScreenPos(ctx, start_x, list_y)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
        ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, 0x00000000)

        if ImGui.BeginChild(ctx, '##overflow_list', content_width, list_max_height, ImGui.ChildFlags_None) then
          local text_h = ImGui.GetTextLineHeight(ctx)
          local clicked_tab = ChipList.draw_columns(ctx, tab_items, {
            selected_ids = selected_ids,
            search_text = self.search_text,
            use_dot_style = true,
            bg_color = 0x252525FF,
            item_height = text_h + 8,
            dot_size = 8,
            dot_spacing = 10,
            rounding = 3,
            padding_h = 10,
            column_width = 180,
            column_spacing = 12,
            item_spacing = 6,
            center_when_sparse = true,
            max_width = content_width,
            render_tooltip = render_playlist_tooltip,
          })

          if clicked_tab then
            self.state.set_active_playlist(clicked_tab, true)
            if self.on_tab_selected then
              self.on_tab_selected()
            end
            window.overlay:pop('overflow-tabs')
            self.is_open = false
            self:close()
          end

          ImGui.EndChild(ctx)
        end

        ImGui.PopStyleColor(ctx)
        ImGui.PopStyleVar(ctx)
      end
    })
  end
end

return M
