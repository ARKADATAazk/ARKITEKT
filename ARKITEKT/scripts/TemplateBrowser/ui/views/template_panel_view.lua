-- @noindex
-- TemplateBrowser/ui/views/template_panel_view.lua
-- Middle panel view: Recent templates + template grid

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local TemplateOps = require('TemplateBrowser.domain.template_ops')
local Helpers = require('TemplateBrowser.ui.views.helpers')
local UI = require('TemplateBrowser.ui.ui_constants')
local TemplateGridFactory = require('TemplateBrowser.ui.tiles.template_grid_factory')
local Button = require('rearkitekt.gui.widgets.primitives.button')

local M = {}

-- Get recent templates (up to max_count)
local function get_recent_templates(state, max_count)
  max_count = max_count or 10

  local recent = {}

  -- Collect templates with last_used timestamp
  for _, tmpl in ipairs(state.templates) do
    local metadata = state.metadata and state.metadata.templates[tmpl.uuid]
    if metadata and metadata.last_used then
      table.insert(recent, {
        template = tmpl,
        last_used = metadata.last_used,
      })
    end
  end

  -- Sort by last_used (most recent first)
  table.sort(recent, function(a, b)
    return a.last_used > b.last_used
  end)

  -- Extract just the templates
  local result = {}
  for i = 1, math.min(max_count, #recent) do
    table.insert(result, recent[i].template)
  end

  return result
end

-- Get favorite templates (up to max_count)
local function get_favorite_templates(state, max_count)
  max_count = max_count or 10

  if not state.metadata or not state.metadata.virtual_folders then
    return {}
  end

  local favorites = state.metadata.virtual_folders["__FAVORITES__"]
  if not favorites or not favorites.template_refs then
    return {}
  end

  local result = {}
  for _, ref_uuid in ipairs(favorites.template_refs) do
    -- Find template by UUID
    for _, tmpl in ipairs(state.templates) do
      if tmpl.uuid == ref_uuid then
        table.insert(result, tmpl)
        if #result >= max_count then
          return result
        end
        break
      end
    end
  end

  return result
end

-- Get most used templates (up to max_count)
local function get_most_used_templates(state, max_count)
  max_count = max_count or 10

  local usage_list = {}

  -- Collect templates with usage_count
  for _, tmpl in ipairs(state.templates) do
    local metadata = state.metadata and state.metadata.templates[tmpl.uuid]
    local usage_count = metadata and metadata.usage_count or 0
    if usage_count > 0 then
      table.insert(usage_list, {
        template = tmpl,
        usage_count = usage_count,
      })
    end
  end

  -- Sort by usage_count (most used first)
  table.sort(usage_list, function(a, b)
    return a.usage_count > b.usage_count
  end)

  -- Extract just the templates
  local result = {}
  for i = 1, math.min(max_count, #usage_list) do
    table.insert(result, usage_list[i].template)
  end

  return result
end

-- Get quick access templates based on mode
local function get_quick_access_templates(state, max_count)
  if state.quick_access_mode == "favorites" then
    return get_favorite_templates(state, max_count)
  elseif state.quick_access_mode == "most_used" then
    return get_most_used_templates(state, max_count)
  else
    return get_recent_templates(state, max_count)
  end
end

-- Draw quick access panel (recent/favorites/most used templates)
local function draw_quick_access_panel(ctx, gui, width, height)
  local state = gui.state
  local dl = ImGui.GetWindowDrawList(ctx)
  local quick_access_templates = get_quick_access_templates(state, 10)

  if #quick_access_templates == 0 then
    return  -- Don't draw panel if no templates
  end

  -- Panel background (solid, matching Region Playlist)
  local panel_x, panel_y = ImGui.GetCursorScreenPos(ctx)
  local panel_bg = Colors.hexrgb("#1A1A1AFF")
  local panel_border = Colors.hexrgb("#000000DD")
  local header_bg = Colors.hexrgb("#1E1E1EFF")
  local rounding = 8

  -- Draw panel background
  ImGui.DrawList_AddRectFilled(dl, panel_x, panel_y, panel_x + width, panel_y + height, panel_bg, rounding, ImGui.DrawFlags_RoundCornersAll)
  ImGui.DrawList_AddRect(dl, panel_x, panel_y, panel_x + width, panel_y + height, panel_border, rounding, ImGui.DrawFlags_RoundCornersAll, 1)

  -- Header with dropdown
  local header_height = 32
  ImGui.DrawList_AddRectFilled(dl, panel_x, panel_y, panel_x + width, panel_y + header_height, header_bg, rounding, ImGui.DrawFlags_RoundCornersTop)

  -- Position dropdown in header
  ImGui.SetCursorScreenPos(ctx, panel_x + 8, panel_y + 6)
  ImGui.SetNextItemWidth(ctx, 140)

  local mode_names = {"Recents", "Favorites", "Most Used"}
  local mode_values = {"recents", "favorites", "most_used"}
  local current_idx = 1
  for i, val in ipairs(mode_values) do
    if val == state.quick_access_mode then
      current_idx = i
      break
    end
  end

  local changed, new_idx = ImGui.Combo(ctx, "##quick_access_mode", current_idx - 1, table.concat(mode_names, "\0") .. "\0")
  if changed then
    state.quick_access_mode = mode_values[new_idx + 1]
  end

  -- Content area (horizontal scrolling tiles)
  local content_y = panel_y + header_height + 8
  local content_height = height - header_height - 16
  local tile_height = UI.TILE.RECENT_HEIGHT
  local tile_width = UI.TILE.RECENT_WIDTH
  local tile_gap = UI.TILE.GAP

  ImGui.SetCursorScreenPos(ctx, panel_x + 12, content_y)

  if Helpers.begin_child_compat(ctx, "QuickAccessScroll", width - 24, content_height, false, ImGui.WindowFlags_HorizontalScrollbar) then
    -- Draw tiles horizontally
    local TemplateTile = require('TemplateBrowser.ui.tiles.template_tile')

    for idx, tmpl in ipairs(quick_access_templates) do
      local x1, y1 = ImGui.GetCursorScreenPos(ctx)
      local x2 = x1 + tile_width
      local y2 = y1 + tile_height

      -- Create tile state for rendering
      local tile_state = {
        hover = false,
        selected = state.selected_template and state.selected_template.uuid == tmpl.uuid,
        star_clicked = false,
      }

      -- Check hover
      local mx, my = ImGui.GetMousePos(ctx)
      tile_state.hover = mx >= x1 and mx <= x2 and my >= y1 and my <= y2

      -- Render tile
      TemplateTile.render(ctx, {x1, y1, x2, y2}, tmpl, tile_state, state.metadata, gui.template_animator)

      -- Handle tile click
      if tile_state.hover and ImGui.IsMouseClicked(ctx, 0) and not tile_state.star_clicked then
        state.selected_template = tmpl
      end

      -- Handle star click
      if tile_state.star_clicked then
        local Persistence = require('TemplateBrowser.domain.persistence')
        local favorites_id = "__FAVORITES__"
        local favorites = state.metadata.virtual_folders[favorites_id]

        if favorites then
          -- Toggle favorite
          local is_favorited = false
          local favorite_index = nil
          for i, ref_uuid in ipairs(favorites.template_refs) do
            if ref_uuid == tmpl.uuid then
              is_favorited = true
              favorite_index = i
              break
            end
          end

          if is_favorited then
            table.remove(favorites.template_refs, favorite_index)
            state.set_status("Removed from Favorites: " .. tmpl.name, "success")
          else
            table.insert(favorites.template_refs, tmpl.uuid)
            state.set_status("Added to Favorites: " .. tmpl.name, "success")
          end

          Persistence.save_metadata(state.metadata)
        end
      end

      -- Handle double-click
      if tile_state.hover and ImGui.IsMouseDoubleClicked(ctx, 0) then
        TemplateOps.apply_to_selected_track(tmpl.path, tmpl.uuid, state)
      end

      -- Move cursor for next tile
      ImGui.SetCursorScreenPos(ctx, x2 + tile_gap, y1)
    end

    -- Add dummy to consume the space used by horizontally positioned tiles
    if #quick_access_templates > 0 then
      local total_width = (#quick_access_templates * tile_width) + ((#quick_access_templates - 1) * tile_gap)
      ImGui.Dummy(ctx, total_width, tile_height)
    end

    ImGui.EndChild(ctx)
  end
end

-- Handle tile size adjustment with SHIFT/CTRL + MouseWheel
local function handle_tile_resize(ctx, state, config)
  local wheel = ImGui.GetMouseWheel(ctx)
  if wheel == 0 then return false end

  local shift = ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) or ImGui.IsKeyDown(ctx, ImGui.Key_RightShift)
  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)

  if not shift and not ctrl then return false end

  local is_list_mode = state.template_view_mode == "list"
  local delta = wheel > 0 and 1 or -1

  if shift then
    -- SHIFT+MouseWheel: adjust tile width
    if is_list_mode then
      local step = config.TILE.LIST_WIDTH_STEP
      local new_width = state.list_tile_width + (delta * step)
      state.list_tile_width = math.max(config.TILE.LIST_MIN_WIDTH, math.min(config.TILE.LIST_MAX_WIDTH, new_width))
    else
      local step = config.TILE.GRID_WIDTH_STEP
      local new_width = state.grid_tile_width + (delta * step)
      state.grid_tile_width = math.max(config.TILE.GRID_MIN_WIDTH, math.min(config.TILE.GRID_MAX_WIDTH, new_width))
    end
    return true
  elseif ctrl then
    -- CTRL+MouseWheel: reserved for future height adjustment
    -- Currently tiles have fixed heights, but this can be implemented later
    return true
  end

  return false
end

-- Draw template list panel (middle)
-- Draw template panel using TilesContainer
local function draw_template_panel(ctx, gui, width, height)
  local state = gui.state
  local config = gui.config
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Handle tile resizing with SHIFT/CTRL + MouseWheel
  if handle_tile_resize(ctx, state, config) then
    -- Consumed wheel event, prevent scrolling (if we're in a scrollable area)
  end

  local content_x, content_y = ImGui.GetCursorScreenPos(ctx)

  -- 1. VIEW MODE TOGGLE BUTTONS AT THE TOP (using Button primitive)
  local button_w = 60
  local button_h = 24
  local button_gap = 2
  local button_margin = 8

  -- Grid button
  local grid_clicked = Button.draw(ctx, dl, content_x, content_y, button_w, button_h, {
    id = "grid_view_btn",
    label = "Grid",
    is_toggled = state.template_view_mode == "grid",
  }, "template_panel_view_mode_grid")

  if grid_clicked then
    state.template_view_mode = "grid"
  end

  -- List button
  local list_clicked = Button.draw(ctx, dl, content_x + button_w + button_gap, content_y, button_w, button_h, {
    id = "list_view_btn",
    label = "List",
    is_toggled = state.template_view_mode == "list",
  }, "template_panel_view_mode_list")

  if list_clicked then
    state.template_view_mode = "list"
  end

  -- Move cursor past buttons
  ImGui.SetCursorScreenPos(ctx, content_x, content_y + button_h + button_margin)

  local panel_y = content_y + button_h + button_margin
  local panel_height = height - (button_h + button_margin)

  -- Reserve space for quick access panel at bottom (if any)
  local quick_access_templates = get_quick_access_templates(state, 10)
  local quick_access_height = #quick_access_templates > 0 and (UI.TILE.RECENT_SECTION_HEIGHT + 16) or 0

  -- 2. MAIN TEMPLATE GRID PANEL (with background)
  local grid_panel_height = panel_height - quick_access_height

  -- Update grid layout properties for current view mode
  TemplateGridFactory.update_for_view_mode(gui.template_grid)

  -- Set container dimensions for main grid
  gui.template_container.width = width
  gui.template_container.height = grid_panel_height

  -- Begin panel drawing
  if gui.template_container:begin_draw(ctx) then
    -- Draw template grid
    gui.template_grid:draw(ctx)

    -- End panel drawing
    gui.template_container:end_draw(ctx)
  end

  -- 3. QUICK ACCESS PANEL AT THE BOTTOM (Recents/Favorites/Most Used)
  if #quick_access_templates > 0 then
    ImGui.Spacing(ctx)

    draw_quick_access_panel(ctx, gui, width, quick_access_height)
  end
end

-- Export the main draw function
M.draw_template_panel = draw_template_panel

return M
