-- @noindex
-- Blocks/blocks/item_browser/grid.lua
-- Grid renderer that uses ItemPicker's renderers when available
-- Falls back to simplified rendering if ItemPicker not loaded

local M = {}

local Ark = require('arkitekt')
local ImGui = Ark.ImGui
local Theme = require('arkitekt.theme')
local Storage = require('scripts.Blocks.blocks.item_browser.storage')
local RendererBridge = require('scripts.Blocks.blocks.item_browser.renderer_bridge')

-- Grid config (fallback values if ItemPicker config not available)
local TILE_GAP = 6
local TILE_ROUNDING = 4
local HEADER_HEIGHT = 20
local STAR_CHAR = '\226\152\133'  -- UTF-8 star ★

-- Check if we can use ItemPicker's renderers
local use_itempicker_renderer = RendererBridge.available()

---Truncate text to fit width (fallback)
local function truncate_text(ctx, text, max_width)
  local text_w = ImGui.CalcTextSize(ctx, text)
  if text_w <= max_width then return text end

  local ellipsis = '..'
  local ellipsis_w = ImGui.CalcTextSize(ctx, ellipsis)
  local target_w = max_width - ellipsis_w

  for i = #text, 1, -1 do
    local sub = text:sub(1, i)
    if ImGui.CalcTextSize(ctx, sub) <= target_w then
      return sub .. ellipsis
    end
  end
  return ellipsis
end

---Brighten a color (fallback)
local function brighten(color, factor)
  local r = math.min(255, ((color >> 24) & 0xFF) * factor)
  local g = math.min(255, ((color >> 16) & 0xFF) * factor)
  local b = math.min(255, ((color >> 8) & 0xFF) * factor)
  local a = color & 0xFF
  return (math.floor(r) << 24) | (math.floor(g) << 16) | (math.floor(b) << 8) | a
end

---Draw a single tile (fallback when ItemPicker not available)
local function draw_tile_fallback(ctx, item, x, y, size, is_selected, item_type)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local result = { clicked = false, right_clicked = false, hovered = false }

  local x2, y2 = x + size, y + size
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local is_hovered = mouse_x >= x and mouse_x < x2 and mouse_y >= y and mouse_y < y2
  result.hovered = is_hovered

  local bg_color = item.color or Theme.COLORS.BG_ELEVATED
  if is_hovered then bg_color = brighten(bg_color, 1.3) end
  if is_selected then bg_color = brighten(bg_color, 1.5) end

  ImGui.DrawList_AddRectFilled(draw_list, x, y, x2, y2, bg_color, TILE_ROUNDING)

  local border_color = is_selected and Theme.COLORS.ACCENT_PRIMARY or Theme.COLORS.BORDER_OUTER
  ImGui.DrawList_AddRect(draw_list, x, y, x2, y2, border_color, TILE_ROUNDING, 0, is_selected and 2 or 1)

  if item.is_favorite then
    ImGui.DrawList_AddText(draw_list, x2 - 16, y + 2, 0xFFD700FF, STAR_CHAR)
  end

  local icon = item_type == 'midi' and 'M' or 'A'
  local icon_bg = item_type == 'midi' and 0x4488FFAA or 0x44FF88AA
  ImGui.DrawList_AddRectFilled(draw_list, x + 2, y + 2, x + 16, y + 16, icon_bg, 2)
  ImGui.DrawList_AddText(draw_list, x + 5, y + 2, 0xFFFFFFFF, icon)

  local name = truncate_text(ctx, item.name, size - 8)
  local text_y = y2 - HEADER_HEIGHT
  ImGui.DrawList_AddRectFilled(draw_list, x, text_y, x2, y2, 0x000000CC, TILE_ROUNDING, ImGui.DrawFlags_RoundCornersBottom)
  local text_w = ImGui.CalcTextSize(ctx, name)
  ImGui.DrawList_AddText(draw_list, x + (size - text_w) / 2, text_y + 3, 0xFFFFFFFF, name)

  if is_hovered then
    if ImGui.IsMouseClicked(ctx, 0) then result.clicked = true end
    if ImGui.IsMouseClicked(ctx, 1) then result.right_clicked = true end
  end

  return result
end

---Draw item grid
---@param ctx userdata ImGui context
---@param items table[] Array of items to display
---@param state table Component state
---@param item_type string 'audio' or 'midi'
function M.draw(ctx, items, state, item_type)
  -- Filter by favorites if enabled
  local filtered_items = items
  if state.show_favorites_only then
    filtered_items = {}
    for _, item in ipairs(items) do
      if item.is_favorite then
        table.insert(filtered_items, item)
      end
    end
  end

  if #filtered_items == 0 then
    if state.show_favorites_only then
      ImGui.TextDisabled(ctx, 'No favorite ' .. item_type .. ' items')
      ImGui.TextDisabled(ctx, 'Right-click items to add favorites')
    else
      ImGui.TextDisabled(ctx, 'No ' .. item_type .. ' items in project')
    end
    return
  end

  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local size = state.tile_size or 80
  local gap = TILE_GAP

  -- Use ItemPicker config for sizing if available
  local config = RendererBridge.get_config()
  if config and config.TILE then
    gap = config.TILE.GAP or gap
  end

  local cols = math.max(1, math.floor((avail_w + gap) / (size + gap)))

  -- Begin frame for ItemPicker renderers
  if use_itempicker_renderer then
    RendererBridge.begin_frame(ctx, state, Storage)
  end

  -- Create scrollable child
  if ImGui.BeginChild(ctx, 'grid_' .. item_type, avail_w, avail_h - 4, ImGui.ChildFlags_None) then
    local grid_start_x, grid_start_y = ImGui.GetCursorScreenPos(ctx)
    local draw_list = ImGui.GetWindowDrawList(ctx)

    local rows = math.ceil(#filtered_items / cols)
    local total_height = rows * (size + gap)
    ImGui.Dummy(ctx, avail_w, total_height)

    local context_item = nil

    for i, item in ipairs(filtered_items) do
      local row = math.floor((i - 1) / cols)
      local col = (i - 1) % cols

      local x = grid_start_x + col * (size + gap)
      local y = grid_start_y + row * (size + gap)

      local is_selected = state.selected_key == item.key

      -- Check hover
      local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
      local is_hovered = mouse_x >= x and mouse_x < x + size and mouse_y >= y and mouse_y < y + size

      -- Render tile
      if use_itempicker_renderer then
        local rect = {x, y, x + size, y + size}
        if item_type == 'audio' then
          RendererBridge.render_audio_tile(ctx, draw_list, rect, item, i, #filtered_items, is_selected, is_hovered)
        else
          RendererBridge.render_midi_tile(ctx, draw_list, rect, item, i, #filtered_items, is_selected, is_hovered)
        end
      else
        draw_tile_fallback(ctx, item, x, y, size, is_selected, item_type)
      end

      -- Handle clicks
      if is_hovered then
        if ImGui.IsMouseClicked(ctx, 0) then
          state.selected_key = item.key
          if ImGui.IsMouseDoubleClicked(ctx, 0) and item.item then
            reaper.SelectAllMediaItems(0, false)
            reaper.SetMediaItemSelected(item.item, true)
            reaper.UpdateArrange()
          end
        end
        if ImGui.IsMouseClicked(ctx, 1) then
          context_item = item
        end
      end

      -- Tooltip
      if is_hovered then
        ImGui.BeginTooltip(ctx)
        ImGui.Text(ctx, item.name)
        if item.track_name then
          ImGui.TextDisabled(ctx, 'Track: ' .. item.track_name)
        end
        if item.is_favorite then
          ImGui.TextColored(ctx, 0xFFD700FF, STAR_CHAR .. ' Favorite')
        end
        ImGui.TextDisabled(ctx, 'Right-click for options')
        ImGui.EndTooltip(ctx)
      end
    end

    -- Context menu
    if context_item then
      ImGui.OpenPopup(ctx, 'item_context_' .. item_type)
      state._context_item = context_item
    end

    if ImGui.BeginPopup(ctx, 'item_context_' .. item_type) then
      local item = state._context_item
      if item then
        local fav_label = item.is_favorite and 'Remove from Favorites' or 'Add to Favorites'
        if ImGui.MenuItem(ctx, fav_label) then
          if item_type == 'audio' then
            Storage.toggle_audio_favorite(item.filename or item.key)
          else
            Storage.toggle_midi_favorite(item.name)
          end
          state.last_scan = 0
        end

        ImGui.Separator(ctx)

        if ImGui.MenuItem(ctx, 'Select in REAPER') then
          if item.item then
            reaper.SelectAllMediaItems(0, false)
            reaper.SetMediaItemSelected(item.item, true)
            reaper.UpdateArrange()
          end
        end
      end
      ImGui.EndPopup(ctx)
    end

    ImGui.EndChild(ctx)
  end
end

return M
