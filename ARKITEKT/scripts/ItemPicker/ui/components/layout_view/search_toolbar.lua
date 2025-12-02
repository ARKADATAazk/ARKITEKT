-- @noindex
-- ItemPicker/ui/components/layout_view/search_toolbar.lua
-- Search input, sort buttons, layout toggle, and toolbar controls
-- Uses ImGui cursor flow for horizontal layout

local ImGui = require('arkitekt.platform.imgui')
local Ark = require('arkitekt')
local Defaults = require('ItemPicker.defs.defaults')
local Constants = require('ItemPicker.defs.constants')

-- Search modes
local SEARCH_MODES = Defaults.SEARCH_MODES

local function get_search_mode_label(mode_id)
  for _, mode in ipairs(SEARCH_MODES) do
    if mode.value == mode_id then
      return mode.label
    end
  end
  return SEARCH_MODES[1].label
end

local M = {}

-- Draw track filter icon (3 horizontal lines representing tracks)
local function draw_track_icon(dl, x, y, w, h, color)
  local icon_w = 12
  local icon_h = 10
  local line_h = 2
  local line_gap = 2
  local icon_x = x + (w - icon_w) / 2
  local icon_y = y + (h - icon_h) / 2

  for i = 0, 2 do
    local line_y = icon_y + i * (line_h + line_gap)
    local line_w = icon_w - i * 2
    ImGui.DrawList_AddRectFilled(dl,
      icon_x, line_y,
      icon_x + line_w, line_y + line_h,
      color, 1)
  end
end

-- Draw layout icon factory
local function make_layout_icon_drawer(is_vertical)
  return function(dl, x, y, w, h, color)
    local icon_size = 14
    local gap = 2
    local top_bar_h = 2
    local top_padding = 2
    local icon_x = x + (w - icon_size) / 2
    local icon_y = y + (h - icon_size) / 2

    -- Top bar
    ImGui.DrawList_AddRectFilled(dl, icon_x, icon_y, icon_x + icon_size, icon_y + top_bar_h, color, 0)

    local panels_start_y = icon_y + top_bar_h + top_padding
    local panels_height = icon_size - top_bar_h - top_padding

    if is_vertical then
      local rect_h = (panels_height - gap) / 2
      ImGui.DrawList_AddRectFilled(dl, icon_x, panels_start_y, icon_x + icon_size, panels_start_y + rect_h, color, 0)
      ImGui.DrawList_AddRectFilled(dl, icon_x, panels_start_y + rect_h + gap, icon_x + icon_size, icon_y + icon_size, color, 0)
    else
      local rect_w = (icon_size - gap) / 2
      ImGui.DrawList_AddRectFilled(dl, icon_x, panels_start_y, icon_x + rect_w, icon_y + icon_size, color, 0)
      ImGui.DrawList_AddRectFilled(dl, icon_x + rect_w + gap, panels_start_y, icon_x + icon_size, icon_y + icon_size, color, 0)
    end
  end
end

function M.Draw(ctx, coord_offset_x, search_y, screen_w, search_height, search_fade, title_font, state, config)
  local button_height = search_height
  local button_gap = 4

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha, search_fade)
  ImGui.PushFont(ctx, title_font, 14)

  -- Sort modes
  local sort_modes = {
    {id = 'none', label = 'None'},
    {id = 'length', label = 'Length'},
    {id = 'color', label = 'Color'},
    {id = 'name', label = 'Name'},
    {id = 'pool', label = 'Pool'},
  }

  local current_sort = state.settings.sort_mode or 'none'

  -- Pre-calculate button widths
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
  local content_filter_mode = 'MIXED'
  if state.settings.show_audio and not state.settings.show_midi then
    content_filter_mode = 'AUDIO'
  elseif state.settings.show_midi and not state.settings.show_audio then
    content_filter_mode = 'MIDI'
  end

  local layout_button_width = button_height
  local track_button_width = button_height

  -- Calculate search dimensions
  local search_width = screen_w * config.LAYOUT.SEARCH_WIDTH_RATIO
  local search_x = coord_offset_x + math.floor((screen_w - search_width) / 2)

  -- Calculate left buttons total width
  local left_buttons_width = track_button_width + button_gap + content_button_width + button_gap + layout_button_width + button_gap

  -- Calculate sort label width
  local sort_label = 'Sorting:'
  local sort_label_width = ImGui.CalcTextSize(ctx, sort_label)

  -- ============================================================================
  -- LEFT SECTION: Filter buttons (right-aligned to search)
  -- Order: Layout → Content → Track (left to right, Track closest to search)
  -- ============================================================================
  local left_section_x = search_x - left_buttons_width
  ImGui.SetCursorScreenPos(ctx, left_section_x, search_y)

  -- Layout toggle button
  local layout_mode = state.settings.layout_mode or 'vertical'
  local is_vertical = layout_mode == 'vertical'
  local is_mixed_mode = content_filter_mode == 'MIXED'

  Ark.Button(ctx, {
    id = 'layout_toggle_button',
    width = layout_button_width,
    height = button_height,
    draw_icon = make_layout_icon_drawer(is_vertical),
    is_toggled = is_mixed_mode,
    preset_name = 'BUTTON_TOGGLE_WHITE',
    tooltip = not is_mixed_mode and 'Enable Split View (MIXED mode)' or
              (is_vertical and 'Switch to Horizontal Layout' or 'Switch to Vertical Layout'),
    ignore_modal = true,
    advance = 'none',
    on_click = function()
      if not is_mixed_mode then
        state.set_setting('show_audio', true)
        state.set_setting('show_midi', true)
      else
        local new_mode = layout_mode == 'vertical' and 'horizontal' or 'vertical'
        state.set_setting('layout_mode', new_mode)
      end
    end,
  })

  ImGui.SameLine(ctx, 0, button_gap)

  -- Content filter button
  Ark.Button(ctx, {
    id = 'content_filter_button',
    width = content_button_width,
    height = button_height,
    label = content_filter_mode,
    is_toggled = content_filter_mode == 'MIXED',
    preset_name = 'BUTTON_TOGGLE_WHITE',
    tooltip = 'Left: Toggle MIDI/AUDIO | Right: Show both',
    ignore_modal = true,
    advance = 'none',
    on_click = function()
      if content_filter_mode == 'MIDI' then
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

  ImGui.SameLine(ctx, 0, button_gap)

  -- Track filter button
  local track_filter_active = state.show_track_filter or false
  Ark.Button(ctx, {
    id = 'track_filter_button',
    width = track_button_width,
    height = button_height,
    draw_icon = draw_track_icon,
    is_toggled = track_filter_active,
    preset_name = 'BUTTON_TOGGLE_WHITE',
    tooltip = 'Track Filter',
    ignore_modal = true,
    advance = 'none',
    on_click = function()
      state.open_track_filter_modal = true
    end,
  })

  -- ============================================================================
  -- CENTER SECTION: Search input + mode dropdown
  -- Note: Uses absolute positioning for pixel-perfect overlap between input and combo
  -- ============================================================================
  local mode_id = state.settings.search_mode or 'items'
  local mode_label = get_search_mode_label(mode_id)
  local dropdown_width = Constants.SEARCH.dropdown_width
  local overlap = Constants.SEARCH.overlap  -- -1 for overlap effect
  local input_width = search_width - dropdown_width + overlap

  -- Focus search on init or Ctrl+F
  if (not state.initialized and state.settings.focus_keyboard_on_init) or state.focus_search then
    ImGui.SetCursorScreenPos(ctx, search_x, search_y)
    ImGui.SetKeyboardFocusHere(ctx)
    state.initialized = true
    state.focus_search = false
  end

  Ark.InputText.Search(ctx, {
    id = 'item_picker_search',
    x = search_x,
    y = search_y,
    width = input_width,
    height = search_height,
    placeholder = 'Search ' .. mode_label:lower() .. '...',
    value = state.settings.search_string or '',
    on_change = function(new_text)
      state.set_search_filter(new_text)
    end,
  })

  Ark.Combo(ctx, {
    id = 'search_mode_dropdown',
    x = search_x + input_width + overlap,
    y = search_y,
    width = dropdown_width,
    height = search_height,
    options = SEARCH_MODES,
    current_value = mode_id,
    on_change = function(new_value)
      state.set_setting('search_mode', new_value)
      if state.runtime_cache then
        state.runtime_cache.audio_filter_hash = nil
        state.runtime_cache.midi_filter_hash = nil
      end
    end,
  })

  -- ============================================================================
  -- RIGHT SECTION: Sorting label and buttons
  -- ============================================================================
  local sort_section_x = search_x + search_width + button_gap
  ImGui.SetCursorScreenPos(ctx, sort_section_x, search_y)

  -- Sorting label
  local sort_label_color = Ark.Colors.Hexrgb('#AAAAAA')
  sort_label_color = Ark.Colors.WithAlpha(sort_label_color, (search_fade * 200) // 1)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddText(dl, sort_section_x, search_y + 4, sort_label_color, sort_label)

  -- Position sort buttons after label
  ImGui.SetCursorScreenPos(ctx, sort_section_x + sort_label_width + 8, search_y)

  for i, mode in ipairs(sort_modes) do
    local button_w = sort_button_widths[i]
    local is_active = (current_sort == mode.id)

    Ark.Button(ctx, {
      id = 'sort_button_' .. mode.id,
      width = button_w,
      height = button_height,
      label = mode.label,
      is_toggled = is_active,
      preset_name = 'BUTTON_TOGGLE_WHITE',
      ignore_modal = true,
      advance = 'none',
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

    if i < #sort_modes then
      ImGui.SameLine(ctx, 0, button_gap)
    end
  end

  ImGui.PopFont(ctx)
  ImGui.PopStyleVar(ctx)

  -- Reset cursor for next elements
  ImGui.SetCursorScreenPos(ctx, search_x, search_y + search_height)

  return search_x, search_y, search_width
end

return M
