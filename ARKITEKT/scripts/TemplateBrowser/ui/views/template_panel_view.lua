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

-- Draw recent templates horizontal row
local function draw_recent_templates(ctx, gui, width, available_height)
  local state = gui.state
  local recent_templates = get_recent_templates(state, 10)

  if #recent_templates == 0 then
    return 0  -- No height consumed
  end

  local section_height = UI.TILE.RECENT_SECTION_HEIGHT
  local tile_height = UI.TILE.RECENT_HEIGHT
  local tile_width = UI.TILE.RECENT_WIDTH
  local tile_gap = UI.TILE.GAP

  -- Draw section header
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, Colors.hexrgb("#B3B3B3"))
  ImGui.Text(ctx, "Recent Templates")
  ImGui.PopStyleColor(ctx)
  ImGui.Spacing(ctx)

  -- Scroll area for horizontal tiles
  local scroll_height = tile_height + UI.PADDING.PANEL_INNER * 2
  if Helpers.begin_child_compat(ctx, "RecentTemplatesScroll", width, scroll_height, false, ImGui.WindowFlags_HorizontalScrollbar) then
    -- Draw tiles horizontally
    local TemplateTile = require('TemplateBrowser.ui.tiles.template_tile')

  for idx, tmpl in ipairs(recent_templates) do
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
  -- This prevents SetCursorPos error when EndChild is called
  if #recent_templates > 0 then
    local total_width = (#recent_templates * tile_width) + ((#recent_templates - 1) * tile_gap)
    ImGui.Dummy(ctx, total_width, tile_height)
  end

    ImGui.EndChild(ctx)
  end

  -- Separator after recent templates
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  return section_height
end

-- Draw template list panel (middle)
-- Draw template panel using TilesContainer
local function draw_template_panel(ctx, gui, width, height)
  local state = gui.state
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Begin outer container
  if not Helpers.begin_child_compat(ctx, "TemplatePanel", width, height, true) then
    return
  end

  local content_x, content_y = ImGui.GetCursorScreenPos(ctx)
  local available_height = height - 16  -- Account for padding

  -- 1. VIEW MODE TOGGLE BUTTONS AT THE TOP (using Button primitive)
  local button_w = 60
  local button_h = 24
  local button_gap = 2
  local total_button_width = (button_w * 2) + button_gap

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
  ImGui.SetCursorScreenPos(ctx, content_x, content_y + button_h + 8)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  local after_buttons_y = content_y + button_h + 16  -- 8px spacing + separator
  local remaining_height = available_height - (button_h + 16)

  -- 2. MAIN TEMPLATE GRID IN THE MIDDLE
  -- Reserve space for recent templates at bottom (if any)
  local recent_templates = get_recent_templates(state, 10)
  local recent_section_height = #recent_templates > 0 and UI.TILE.RECENT_SECTION_HEIGHT or 0

  local grid_height = remaining_height - recent_section_height

  -- Update grid layout properties for current view mode
  TemplateGridFactory.update_for_view_mode(gui.template_grid)

  -- Set container dimensions for main grid
  gui.template_container.width = width - 16
  gui.template_container.height = grid_height

  -- Begin panel drawing
  if gui.template_container:begin_draw(ctx) then
    -- Draw template grid
    gui.template_grid:draw(ctx)

    -- End panel drawing
    gui.template_container:end_draw(ctx)
  end

  -- 3. RECENT TEMPLATES AT THE BOTTOM
  if #recent_templates > 0 then
    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    draw_recent_templates(ctx, gui, width - 16, recent_section_height)
  end

  ImGui.EndChild(ctx)
end

-- Export the main draw function
M.draw_template_panel = draw_template_panel

return M
