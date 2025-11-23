-- @noindex
-- ItemPickerWindow/ui/toolbar_view.lua
-- Top toolbar with search, sort, and layout controls

local ImGui = require 'imgui' '0.10'
local SearchWithMode = require('ItemPicker.ui.components.search_with_mode')
local Button = require('arkitekt.gui.widgets.primitives.button')
local Colors = require('arkitekt.core.colors')

local M = {}

local ToolbarView = {}
ToolbarView.__index = ToolbarView

function M.new(config, state)
  return setmetatable({
    config = config,
    state = state,
    focus_search = false,
  }, ToolbarView)
end

function ToolbarView:handle_shortcuts(ctx)
  local ctrl = ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl)

  if ctrl and ImGui.IsKeyPressed(ctx, ImGui.Key_F) then
    self.focus_search = true
  end

  if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    if self.state.settings.search_string and self.state.settings.search_string ~= "" then
      self.state.set_search_filter("")
    end
  end
end

function ToolbarView:draw(ctx, shell_state)
  self:handle_shortcuts(ctx)

  local toolbar_height = self.config.TOOLBAR and self.config.TOOLBAR.height or 44
  local padding = 8
  local button_height = 28
  local button_gap = 4

  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local start_x, start_y = ImGui.GetCursorScreenPos(ctx)
  local draw_list = ImGui.GetWindowDrawList(ctx)

  -- Draw toolbar background
  local bg_color = Colors.hexrgb("#1A1A1AFF")
  ImGui.DrawList_AddRectFilled(draw_list, start_x, start_y, start_x + avail_w, start_y + toolbar_height, bg_color, 0)

  -- Sort modes
  local sort_modes = {
    {id = "none", label = "None"},
    {id = "length", label = "Length"},
    {id = "color", label = "Color"},
    {id = "name", label = "Name"},
    {id = "pool", label = "Pool"},
  }

  local current_sort = self.state.settings.sort_mode or "none"

  -- Calculate sort button widths
  local sort_button_widths = {}
  local total_sort_width = 0
  for i, mode in ipairs(sort_modes) do
    local label_width = ImGui.CalcTextSize(ctx, mode.label)
    local button_w = label_width + 16
    sort_button_widths[i] = button_w
    total_sort_width = total_sort_width + button_w
    if i < #sort_modes then
      total_sort_width = total_sort_width + button_gap
    end
  end

  -- Layout toggle button
  local layout_button_width = button_height
  local layout_mode = self.state.settings.layout_mode or "vertical"
  local is_vertical = layout_mode == "vertical"

  -- Search field dimensions
  local search_width = avail_w * 0.35
  local search_x = start_x + (avail_w - search_width) / 2
  local search_y = start_y + (toolbar_height - button_height) / 2

  -- Position layout button to the left of search
  local layout_x = search_x - layout_button_width - button_gap

  -- Draw layout toggle button
  local icon_color = Colors.hexrgb("#AAAAAA")
  local draw_layout_icon = function(btn_draw_list, icon_x, icon_y)
    local icon_size = 14
    local gap = 2
    local top_bar_h = 2
    local top_padding = 2

    ImGui.DrawList_AddRectFilled(btn_draw_list, icon_x, icon_y, icon_x + icon_size, icon_y + top_bar_h, icon_color, 0)

    local panels_start_y = icon_y + top_bar_h + top_padding
    local panels_height = icon_size - top_bar_h - top_padding

    if is_vertical then
      local rect_h = (panels_height - gap) / 2
      ImGui.DrawList_AddRectFilled(btn_draw_list, icon_x, panels_start_y, icon_x + icon_size, panels_start_y + rect_h, icon_color, 0)
      ImGui.DrawList_AddRectFilled(btn_draw_list, icon_x, panels_start_y + rect_h + gap, icon_x + icon_size, icon_y + icon_size, icon_color, 0)
    else
      local rect_w = (icon_size - gap) / 2
      ImGui.DrawList_AddRectFilled(btn_draw_list, icon_x, panels_start_y, icon_x + rect_w, icon_y + icon_size, icon_color, 0)
      ImGui.DrawList_AddRectFilled(btn_draw_list, icon_x + rect_w + gap, panels_start_y, icon_x + icon_size, icon_y + icon_size, icon_color, 0)
    end
  end

  Button.draw(ctx, draw_list, layout_x, search_y, layout_button_width, button_height, {
    label = "",
    preset_name = "BUTTON_TOGGLE_WHITE",
    tooltip = is_vertical and "Switch to Horizontal Layout" or "Switch to Vertical Layout",
    on_click = function()
      local new_mode = layout_mode == "vertical" and "horizontal" or "vertical"
      self.state.set_setting('layout_mode', new_mode)
    end,
  }, "layout_toggle_button")

  -- Draw layout icon on button
  local icon_x = (layout_x + (layout_button_width - 14) / 2 + 0.5) // 1
  local icon_y = (search_y + (button_height - 14) / 2 + 0.5) // 1
  draw_layout_icon(draw_list, icon_x, icon_y)

  -- Draw search field
  if self.focus_search then
    ImGui.SetCursorScreenPos(ctx, search_x, search_y)
    ImGui.SetKeyboardFocusHere(ctx)
    self.focus_search = false
  end

  SearchWithMode.draw(ctx, draw_list, search_x, search_y, search_width, button_height, self.state, self.config)

  -- Position sort buttons to the right of search
  local sort_x = search_x + search_width + button_gap

  -- Draw "Sorting:" label
  local sort_label = "Sort:"
  local sort_label_width = ImGui.CalcTextSize(ctx, sort_label)
  local sort_label_color = Colors.with_alpha(Colors.hexrgb("#AAAAAA"), 200)
  ImGui.DrawList_AddText(draw_list, sort_x, search_y + 6, sort_label_color, sort_label)

  sort_x = sort_x + sort_label_width + 8

  -- Draw sort buttons
  for i, mode in ipairs(sort_modes) do
    local button_w = sort_button_widths[i]
    local is_active = (current_sort == mode.id)

    Button.draw(ctx, draw_list, sort_x, search_y, button_w, button_height, {
      label = mode.label,
      is_toggled = is_active,
      preset_name = "BUTTON_TOGGLE_WHITE",
      on_click = function()
        if current_sort == mode.id then
          local current_reverse = self.state.settings.sort_reverse or false
          self.state.set_setting('sort_reverse', not current_reverse)
        else
          self.state.set_setting('sort_mode', mode.id)
          self.state.set_setting('sort_reverse', false)
        end
      end,
    }, "sort_button_" .. mode.id)

    sort_x = sort_x + button_w + button_gap
  end

  -- Advance cursor past toolbar
  ImGui.SetCursorScreenPos(ctx, start_x, start_y + toolbar_height)

  return toolbar_height
end

return M
