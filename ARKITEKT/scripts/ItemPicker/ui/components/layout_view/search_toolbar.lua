-- @noindex
-- ItemPicker/ui/components/layout_view/search_toolbar.lua
-- Search input, sort buttons, layout toggle, and toolbar controls

local ImGui = require 'imgui' '0.10'
local ark = require('arkitekt')
local SearchWithMode = require('ItemPicker.ui.components.search')

local M = {}

-- Draw track filter icon (3 horizontal lines representing tracks)
local function draw_track_icon(draw_list, icon_x, icon_y)
  local icon_w = 12
  local icon_h = 10
  local line_h = 2
  local line_gap = 2

  for i = 0, 2 do
    local line_y = icon_y + i * (line_h + line_gap)
    local line_w = icon_w - i * 2
    ImGui.DrawList_AddRectFilled(draw_list,
      icon_x, line_y,
      icon_x + line_w, line_y + line_h,
      ark.Colors.hexrgb("#AAAAAA"), 1)
  end
end

-- Draw layout icon using rectangles
local function draw_layout_icon(draw_list, icon_x, icon_y, is_vertical)
  local icon_size = 14
  local gap = 2
  local top_bar_h = 2
  local top_padding = 2
  local icon_color = ark.Colors.hexrgb("#AAAAAA")

  -- Draw top bar (represents search bar/top panel)
  ImGui.DrawList_AddRectFilled(draw_list, icon_x, icon_y, icon_x + icon_size, icon_y + top_bar_h, icon_color, 0)

  -- Calculate remaining height for panels
  local panels_start_y = icon_y + top_bar_h + top_padding
  local panels_height = icon_size - top_bar_h - top_padding

  if is_vertical then
    -- Vertical mode: 2 rectangles stacked
    local rect_h = (panels_height - gap) / 2
    ImGui.DrawList_AddRectFilled(draw_list, icon_x, panels_start_y, icon_x + icon_size, panels_start_y + rect_h, icon_color, 0)
    ImGui.DrawList_AddRectFilled(draw_list, icon_x, panels_start_y + rect_h + gap, icon_x + icon_size, icon_y + icon_size, icon_color, 0)
  else
    -- Horizontal mode: 2 rectangles side by side
    local rect_w = (icon_size - gap) / 2
    ImGui.DrawList_AddRectFilled(draw_list, icon_x, panels_start_y, icon_x + rect_w, icon_y + icon_size, icon_color, 0)
    ImGui.DrawList_AddRectFilled(draw_list, icon_x + rect_w + gap, panels_start_y, icon_x + icon_size, icon_y + icon_size, icon_color, 0)
  end
end

function M.draw(ctx, draw_list, coord_offset_x, search_y, screen_w, search_height, search_fade, title_font, state, config)
  local button_height = search_height
  local button_gap = 4

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, search_fade)
  ImGui.PushFont(ctx, title_font, 14)

  -- Sort modes
  local sort_modes = {
    {id = "none", label = "None"},
    {id = "length", label = "Length"},
    {id = "color", label = "Color"},
    {id = "name", label = "Name"},
    {id = "pool", label = "Pool"},
  }

  local current_sort = state.settings.sort_mode or "none"
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

  -- Content filter mode
  local content_button_width = 65
  local content_filter_mode = "MIXED"
  if state.settings.show_audio and not state.settings.show_midi then
    content_filter_mode = "AUDIO"
  elseif state.settings.show_midi and not state.settings.show_audio then
    content_filter_mode = "MIDI"
  end

  local layout_button_width = button_height
  local track_button_width = button_height

  -- Calculate search width and center it
  local search_width = screen_w * config.LAYOUT.SEARCH_WIDTH_RATIO
  local search_x = coord_offset_x + math.floor((screen_w - search_width) / 2)

  -- Position buttons left of search
  local buttons_left_x = search_x
  local current_x = buttons_left_x

  -- Track filter button (leftmost)
  current_x = current_x - track_button_width - button_gap
  local track_filter_x = current_x
  local track_filter_active = state.show_track_filter or false

  ark.Button.draw(ctx, {
    id = "track_filter_button",
    draw_list = draw_list,
    x = current_x,
    y = search_y,
    width = track_button_width,
    height = button_height,
    label = "",
    is_toggled = track_filter_active,
    preset_name = "BUTTON_TOGGLE_WHITE",
    tooltip = "Track Filter",
    ignore_modal = true,
    on_click = function()
      state.open_track_filter_modal = true
    end,
  })

  -- Draw track icon
  local track_icon_x = (current_x + (track_button_width - 12) / 2 + 0.5)//1
  local track_icon_y = (search_y + (button_height - 10) / 2 + 0.5)//1
  draw_track_icon(draw_list, track_icon_x, track_icon_y)

  -- Content filter button
  current_x = current_x - content_button_width - button_gap
  ark.Button.draw(ctx, {
    id = "content_filter_button",
    draw_list = draw_list,
    x = current_x,
    y = search_y,
    width = content_button_width,
    height = button_height,
    label = content_filter_mode,
    is_toggled = content_filter_mode == "MIXED",
    preset_name = "BUTTON_TOGGLE_WHITE",
    tooltip = "Left: Toggle MIDI/AUDIO | Right: Show both",
    ignore_modal = true,
    on_click = function()
      if content_filter_mode == "MIDI" then
        state.set_setting('show_audio', true)
        state.set_setting('show_midi', false)
      else
        state.set_setting('show_audio', false)
        state.set_setting('show_midi', true)
      end
    end,
    on_right_click = function()
      state.set_setting('show_audio', true)
      state.set_setting('show_midi', true)
    end,
  })

  -- Layout toggle button
  current_x = current_x - layout_button_width - button_gap
  local layout_mode = state.settings.layout_mode or "vertical"
  local is_vertical = layout_mode == "vertical"
  local is_mixed_mode = content_filter_mode == "MIXED"

  ark.Button.draw(ctx, {
    id = "layout_toggle_button",
    draw_list = draw_list,
    x = current_x,
    y = search_y,
    width = layout_button_width,
    height = button_height,
    label = "",
    is_toggled = is_mixed_mode,
    preset_name = "BUTTON_TOGGLE_WHITE",
    tooltip = not is_mixed_mode and "Enable Split View (MIXED mode)" or
              (is_vertical and "Switch to Horizontal Layout" or "Switch to Vertical Layout"),
    ignore_modal = true,
    on_click = function()
      if not is_mixed_mode then
        state.set_setting('show_audio', true)
        state.set_setting('show_midi', true)
      else
        local new_mode = layout_mode == "vertical" and "horizontal" or "vertical"
        state.set_setting('layout_mode', new_mode)
      end
    end,
  })

  -- Draw layout icon
  local icon_x = (current_x + (layout_button_width - 14) / 2 + 0.5)//1
  local icon_y = (search_y + (button_height - 14) / 2 + 0.5)//1
  draw_layout_icon(draw_list, icon_x, icon_y, is_vertical)

  -- Sorting label and buttons
  local sort_x = search_x + search_width + button_gap
  local sort_label = "Sorting:"
  local sort_label_width = ImGui.CalcTextSize(ctx, sort_label)
  local sort_label_color = ark.Colors.hexrgb("#AAAAAA")
  sort_label_color = ark.Colors.with_alpha(sort_label_color, (search_fade * 200) // 1)
  ImGui.DrawList_AddText(draw_list, sort_x, search_y + 4, sort_label_color, sort_label)

  -- Position sort buttons after label
  sort_x = sort_x + sort_label_width + 8
  for i, mode in ipairs(sort_modes) do
    local button_w = sort_button_widths[i]
    local is_active = (current_sort == mode.id)

    ark.Button.draw(ctx, {
      id = "sort_button_" .. mode.id,
      draw_list = draw_list,
      x = sort_x,
      y = search_y,
      width = button_w,
      height = button_height,
      label = mode.label,
      is_toggled = is_active,
      preset_name = "BUTTON_TOGGLE_WHITE",
      ignore_modal = true,
      on_click = function()
        if current_sort == mode.id then
          local current_reverse = state.settings.sort_reverse or false
          state.set_setting('sort_reverse', not current_reverse)
        else
          state.set_setting('sort_mode', mode.id)
          state.set_setting('sort_reverse', false)
        end
      end,
    })

    sort_x = sort_x + button_w + button_gap
  end

  ImGui.PopFont(ctx)
  ImGui.PopStyleVar(ctx)

  -- Search input
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, search_fade)
  ImGui.PushFont(ctx, title_font, 14)

  -- Focus search on init or Ctrl+F
  if (not state.initialized and state.settings.focus_keyboard_on_init) or state.focus_search then
    ImGui.SetCursorScreenPos(ctx, search_x, search_y)
    ImGui.SetKeyboardFocusHere(ctx)
    state.initialized = true
    state.focus_search = false
  end

  SearchWithMode.draw(ctx, state.draw_list, search_x, search_y, search_width, search_height, state, config)

  ImGui.SetCursorScreenPos(ctx, search_x, search_y + search_height)

  ImGui.PopFont(ctx)
  ImGui.PopStyleVar(ctx)

  return search_x, search_y, search_width
end

return M
