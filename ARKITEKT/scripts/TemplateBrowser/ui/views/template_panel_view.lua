-- @noindex
-- TemplateBrowser/ui/views/template_panel_view.lua
-- Middle panel view: Recent templates + template grid

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local TemplateGridFactory = require('TemplateBrowser.ui.tiles.template_grid_factory')

local M = {}

-- Draw quick access panel (recent/favorites/most used templates)
local function draw_quick_access_panel(ctx, gui, width, height)
  -- Set container dimensions
  gui.recent_container.width = width
  gui.recent_container.height = height

  -- Update grid layout properties for current view mode
  TemplateGridFactory.update_for_view_mode(gui.quick_access_grid)

  -- Begin panel drawing (includes background, border, header)
  if gui.recent_container:begin_draw(ctx) then
    -- Set panel clip bounds AFTER begin_draw when visible_bounds is calculated
    if gui.recent_container.visible_bounds then
      gui.quick_access_grid.panel_clip_bounds = gui.recent_container.visible_bounds
    end

    gui.quick_access_grid:draw(ctx)
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
  local Chip = require('arkitekt.gui.widgets.data.chip')
  local Colors = require('arkitekt.core.colors')

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
  -- Always show both panels with separator (grid handles empty states)
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
    -- Set panel clip bounds AFTER begin_draw when visible_bounds is calculated
    if gui.template_container.visible_bounds then
      gui.template_grid.panel_clip_bounds = gui.template_container.visible_bounds
    end

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
