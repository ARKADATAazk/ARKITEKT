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

-- Get quick access templates based on mode, with search and sort
local function get_quick_access_templates(state, max_count)
  local templates
  if state.quick_access_mode == "favorites" then
    templates = get_favorite_templates(state, 100)  -- Get more for filtering
  elseif state.quick_access_mode == "most_used" then
    templates = get_most_used_templates(state, 100)
  else
    templates = get_recent_templates(state, 100)
  end

  -- Apply search filter
  local search_query = (state.quick_access_search or ""):lower()
  if search_query ~= "" then
    local filtered = {}
    for _, tmpl in ipairs(templates) do
      if tmpl.name:lower():find(search_query, 1, true) then
        table.insert(filtered, tmpl)
      end
    end
    templates = filtered
  end

  -- Apply sort
  local sort_mode = state.quick_access_sort or "alphabetical"
  if sort_mode == "alphabetical" then
    table.sort(templates, function(a, b) return a.name:lower() < b.name:lower() end)
  elseif sort_mode == "color" then
    table.sort(templates, function(a, b)
      local a_color = (state.metadata and state.metadata.templates[a.uuid] and state.metadata.templates[a.uuid].color) or 0
      local b_color = (state.metadata and state.metadata.templates[b.uuid] and state.metadata.templates[b.uuid].color) or 0
      return a_color < b_color
    end)
  elseif sort_mode == "insertion" then
    -- Keep original order (insertion order)
  end

  -- Limit to max_count
  local result = {}
  for i = 1, math.min(max_count, #templates) do
    table.insert(result, templates[i])
  end

  return result
end

-- Draw quick access panel (recent/favorites/most used templates)
local function draw_quick_access_panel(ctx, gui, width, height)
  local state = gui.state
  local quick_access_templates = get_quick_access_templates(state, 10)

  if #quick_access_templates == 0 then
    return  -- Don't draw panel if no templates
  end

  -- Set container dimensions
  gui.recent_container.width = width
  gui.recent_container.height = height

  -- Begin panel drawing (includes background, border, header)
  if gui.recent_container:begin_draw(ctx) then
    -- Determine view mode (grid or list)
    local view_mode = state.quick_access_view_mode or "grid"
    local TemplateTile = require('TemplateBrowser.ui.tiles.template_tile')
    local TemplateTileCompact = require('TemplateBrowser.ui.tiles.template_tile_compact')

    if view_mode == "list" then
      -- LIST VIEW - Vertical stack of compact tiles
      local tile_height = 18
      local tile_gap = 4

      for idx, tmpl in ipairs(quick_access_templates) do
        local x1, y1 = ImGui.GetCursorScreenPos(ctx)
        local x2 = x1 + width - 16  -- Account for padding
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

        -- Render compact tile
        TemplateTileCompact.render(ctx, {x1, y1, x2, y2}, tmpl, tile_state, state.metadata, gui.template_animator)

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

        -- Move cursor for next tile (vertical layout)
        ImGui.SetCursorScreenPos(ctx, x1, y2 + tile_gap)
      end

      -- Add dummy for total height
      if #quick_access_templates > 0 then
        local total_height = (#quick_access_templates * tile_height) + ((#quick_access_templates - 1) * tile_gap)
        ImGui.Dummy(ctx, 0, total_height)
      end
    else
      -- GRID VIEW - Horizontal scrolling tiles
      local tile_height = UI.TILE.RECENT_HEIGHT
      local tile_width = UI.TILE.RECENT_WIDTH
      local tile_gap = UI.TILE.GAP

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

        -- Move cursor for next tile (horizontal layout)
        ImGui.SetCursorScreenPos(ctx, x2 + tile_gap, y1)
      end

      -- Add dummy to consume the space used by horizontally positioned tiles
      if #quick_access_templates > 0 then
        local total_width = (#quick_access_templates * tile_width) + ((#quick_access_templates - 1) * tile_gap)
        ImGui.Dummy(ctx, total_width, tile_height)
      end
    end

    -- End panel drawing
    gui.recent_container:end_draw(ctx)
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
  local panel_y = content_y
  local panel_height = height

  -- 1. FILTER CHIPS (Tags and FX) - Below header, before grid
  local Chip = require('rearkitekt.gui.widgets.data.chip')
  local Colors = require('rearkitekt.core.colors')

  local filter_chip_height = 0
  local has_filters = (next(state.filter_tags) ~= nil) or (next(state.filter_fx) ~= nil)

  if has_filters then
    local chip_y_start = content_y
    local chip_x = content_x + 8
    local chip_y = chip_y_start + 4
    local chip_spacing = 4
    local chip_height = 22
    local max_chip_x = content_x + width - 8

    -- Draw tag filter chips
    for tag_name, _ in pairs(state.filter_tags) do
      local tag_data = state.metadata and state.metadata.tags and state.metadata.tags[tag_name]
      if tag_data then
        local chip_w = Chip.calculate_width(ctx, tag_name, { style = Chip.STYLE.ACTION, padding_h = 8 })

        -- Wrap to next line if needed
        if chip_x + chip_w > max_chip_x and chip_x > content_x + 8 then
          chip_x = content_x + 8
          chip_y = chip_y + chip_height + chip_spacing
        end

        ImGui.SetCursorScreenPos(ctx, chip_x, chip_y)
        local clicked = Chip.draw(ctx, {
          style = Chip.STYLE.ACTION,
          label = tag_name,
          bg_color = tag_data.color,
          text_color = Colors.auto_text_color(tag_data.color),
          height = chip_height,
          padding_h = 8,
          rounding = 2,
          is_selected = true,
          interactive = true,
        })

        if clicked then
          state.filter_tags[tag_name] = nil
          local Scanner = require('TemplateBrowser.domain.scanner')
          Scanner.filter_templates(state)
        end

        chip_x = chip_x + chip_w + chip_spacing
      end
    end

    -- Draw FX filter chips
    for fx_name, _ in pairs(state.filter_fx) do
      local chip_w = Chip.calculate_width(ctx, fx_name, { style = Chip.STYLE.ACTION, padding_h = 8 })

      -- Wrap to next line if needed
      if chip_x + chip_w > max_chip_x and chip_x > content_x + 8 then
        chip_x = content_x + 8
        chip_y = chip_y + chip_height + chip_spacing
      end

      ImGui.SetCursorScreenPos(ctx, chip_x, chip_y)
      local clicked = Chip.draw(ctx, {
        style = Chip.STYLE.ACTION,
        label = fx_name,
        bg_color = Colors.hexrgb("#888888"),
        text_color = Colors.hexrgb("#000000"),
        height = chip_height,
        padding_h = 8,
        rounding = 2,
        is_selected = true,
        interactive = true,
      })

      if clicked then
        state.filter_fx[fx_name] = nil
        local Scanner = require('TemplateBrowser.domain.scanner')
        Scanner.filter_templates(state)
      end

      chip_x = chip_x + chip_w + chip_spacing
    end

    -- Calculate total height used by filter chips
    filter_chip_height = (chip_y - chip_y_start) + chip_height + 8
    panel_y = panel_y + filter_chip_height
    panel_height = panel_height - filter_chip_height

    -- Set cursor after chips
    ImGui.SetCursorScreenPos(ctx, content_x, panel_y)
  end

  -- 2. CALCULATE SEPARATOR POSITION AND PANEL HEIGHTS
  local quick_access_templates = get_quick_access_templates(state, 10)
  local has_quick_access = #quick_access_templates > 0

  if not has_quick_access then
    -- No quick access panel - use full height for main grid
    gui.template_container.width = width
    gui.template_container.height = panel_height

    -- Update grid layout properties for current view mode
    TemplateGridFactory.update_for_view_mode(gui.template_grid)

    -- Begin panel drawing
    if gui.template_container:begin_draw(ctx) then
      gui.template_grid:draw(ctx)
      gui.template_container:end_draw(ctx)
    end
    return
  end

  -- Quick access panel enabled - use separator
  local separator_gap = 8
  local min_grid_height = 200
  local min_quick_access_height = 120

  -- Get separator position from state (default to 350)
  local grid_panel_height = state.quick_access_separator_position or 350

  -- Clamp to valid range
  grid_panel_height = math.max(min_grid_height, math.min(grid_panel_height, panel_height - min_quick_access_height - separator_gap))
  local quick_access_height = panel_height - grid_panel_height - separator_gap

  -- 3. DRAW MAIN TEMPLATE GRID PANEL
  gui.template_container.width = width
  gui.template_container.height = grid_panel_height

  -- Update grid layout properties for current view mode
  TemplateGridFactory.update_for_view_mode(gui.template_grid)

  -- Begin panel drawing
  if gui.template_container:begin_draw(ctx) then
    gui.template_grid:draw(ctx)
    gui.template_container:end_draw(ctx)
  end

  -- 4. DRAW DRAGGABLE SEPARATOR
  local sep_y = panel_y + grid_panel_height + separator_gap / 2
  local sep_action, sep_value = gui.quick_access_separator:draw_horizontal(
    ctx,
    content_x,
    sep_y,
    width,
    panel_height,
    {
      thickness = 6,
      gap = separator_gap,
      default_position = 350,
      min_active_height = min_grid_height,
      min_pool_height = min_quick_access_height,
    }
  )

  if sep_action == "reset" then
    state.quick_access_separator_position = 350
  elseif sep_action == "drag" then
    local new_grid_height = sep_value - panel_y - separator_gap / 2
    new_grid_height = math.max(min_grid_height, math.min(new_grid_height, panel_height - min_quick_access_height - separator_gap))
    state.quick_access_separator_position = new_grid_height
  end

  -- 5. DRAW QUICK ACCESS PANEL AT THE BOTTOM
  local quick_panel_y = panel_y + grid_panel_height + separator_gap
  ImGui.SetCursorScreenPos(ctx, content_x, quick_panel_y)

  draw_quick_access_panel(ctx, gui, width, quick_access_height)
end

-- Export the main draw function
M.draw_template_panel = draw_template_panel

return M
