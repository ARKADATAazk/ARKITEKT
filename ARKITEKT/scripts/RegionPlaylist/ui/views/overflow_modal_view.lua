-- @noindex
-- RegionPlaylist/ui/views/overflow_modal_view.lua
-- Overflow modal for playlist picker

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Container = require('arkitekt.gui.widgets.overlays.overlay.container')
local ChipList = require('arkitekt.gui.widgets.data.chip_list')
local SearchInput = require('arkitekt.gui.widgets.inputs.search_input')
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb

local M = {}

local OverflowModalView = {}
OverflowModalView.__index = OverflowModalView

function M.new(region_tiles, state_module, on_tab_selected)
  return setmetatable({
    region_tiles = region_tiles,
    state = state_module,
    on_tab_selected = on_tab_selected,
    search_text = "",
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
      color = tab.chip_color or hexrgb("#888888"),
    })
  end
  
  local active_id = self.state.get_active_playlist_id()
  local selected_ids = {}
  selected_ids[active_id] = true
  
  if not window or not window.overlay then
    if not self.is_open then
      ImGui.OpenPopup(ctx, "##overflow_tabs_popup")
      self.is_open = true
    end
    
    ImGui.SetNextWindowSize(ctx, 600, 500, ImGui.Cond_FirstUseEver)
    
    local visible = ImGui.BeginPopupModal(ctx, "##overflow_tabs_popup", true, ImGui.WindowFlags_NoTitleBar)
    
    if not visible then
      self.is_open = false
      self:close()
      return
    end
    
    ImGui.SetNextItemWidth(ctx, -1)
    local changed, text = ImGui.InputTextWithHint(ctx, "##tab_search", "Search playlists...", self.search_text)
    if changed then
      self.search_text = text
    end

    ImGui.Dummy(ctx, 0, 8)

    if ImGui.BeginChild(ctx, "##tab_list", 0, -40) then
      local text_h = ImGui.GetTextLineHeight(ctx)
      local clicked_tab = ChipList.draw_columns(ctx, tab_items, {
        selected_ids = selected_ids,
        search_text = self.search_text,
        use_dot_style = true,
        bg_color = hexrgb("#3a3a3a"),  -- Grey fill
        item_height = text_h + 1,  -- Further reduced (was text_h + 4, now ~30% smaller)
        dot_size = 7,
        dot_spacing = 7,
        rounding = 0,  -- Square tiles like tabstrip
        padding_h = 6,  -- Reduced by 50% (was 12)
        column_width = 200,
        column_spacing = 16,
        item_spacing = 4,
        center_when_sparse = true,  -- Center items when there aren't many
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
    end
    ImGui.EndChild(ctx)
    
    ImGui.Separator(ctx)
    ImGui.Dummy(ctx, 0, 4)
    
    local button_w = 100
    local avail_w = ImGui.GetContentRegionAvail(ctx)
    ImGui.SetCursorPosX(ctx, (avail_w - button_w) * 0.5)
    
    if ImGui.Button(ctx, "Close", button_w, 0) then
      ImGui.CloseCurrentPopup(ctx)
      self.is_open = false
      self:close()
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
        self.is_open = false
        self:close()
      end,
      render = function(ctx, alpha, bounds)
        Container.render(ctx, alpha, bounds, function(ctx, content_w, content_h, w, h, a, padding)
          -- Search input using primitive
          local search_height = 28
          local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)

          SearchInput.draw_at_cursor(ctx, {
            id = "overflow_search",
            width = content_w,
            height = search_height,
            placeholder = "Search playlists...",
            value = self.search_text,
            on_change = function(new_text)
              self.search_text = new_text
            end
          })

          -- Manually advance cursor down after primitive
          ImGui.SetCursorScreenPos(ctx, cursor_x, cursor_y + search_height)
          ImGui.Dummy(ctx, 0, 12)

          ImGui.Separator(ctx)
          ImGui.Dummy(ctx, 0, 12)

          -- Playlist grid
          local text_h = ImGui.GetTextLineHeight(ctx)
          local clicked_tab = ChipList.draw_columns(ctx, tab_items, {
            selected_ids = selected_ids,
            search_text = self.search_text,
            use_dot_style = true,
            bg_color = hexrgb("#3a3a3a"),  -- Grey fill
            item_height = text_h + 1,  -- Further reduced (was text_h + 4, now ~30% smaller)
            dot_size = 7,
            dot_spacing = 7,
            rounding = 0,  -- Square tiles like tabstrip
            padding_h = 6,  -- Reduced by 50% (was 12)
            column_width = 200,
            column_spacing = 16,
            item_spacing = 4,
            center_when_sparse = true,  -- Center items when there aren't many
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
        end)
      end
    })
  end
end

return M
