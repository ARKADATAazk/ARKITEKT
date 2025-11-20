-- @noindex
-- ItemPicker/ui/components/search_with_mode.lua
-- Custom search field with mode selector dropdown

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')

local M = {}

-- Search modes
local MODES = {
  {id = "items", label = "Items", letter = "I"},
  {id = "tracks", label = "Tracks", letter = "T"},
  {id = "regions", label = "Regions", letter = "R"},
  {id = "mixed", label = "Mixed", letter = "M"},
}

-- State storage
local search_text = ""
local search_focused = false
local dropdown_open = false

function M.get_mode_config(mode_id)
  for _, mode in ipairs(MODES) do
    if mode.id == mode_id then
      return mode
    end
  end
  return MODES[1]  -- Default to Items
end

function M.draw(ctx, draw_list, x, y, width, height, state, config)
  local mode_id = state.settings.search_mode or "items"
  local mode_config = M.get_mode_config(mode_id)

  -- Mode button dimensions
  local button_width = 32
  local button_padding = 2
  local input_width = width - button_width - button_padding

  -- Colors
  local bg_color = Colors.hexrgb("#1A1A1A")
  local border_color = Colors.hexrgb("#3A3A3A")
  local hover_color = Colors.hexrgb("#2A2A2A")
  local text_color = Colors.hexrgb("#FFFFFF")
  local placeholder_color = Colors.hexrgb("#666666")

  -- Draw search input background
  local input_x = x
  local input_y = y
  ImGui.DrawList_AddRectFilled(draw_list, input_x, input_y, input_x + input_width, input_y + height, bg_color, 4, ImGui.DrawFlags_RoundCornersLeft)
  ImGui.DrawList_AddRect(draw_list, input_x, input_y, input_x + input_width, input_y + height, border_color, 4, ImGui.DrawFlags_RoundCornersLeft, 1)

  -- Search input
  ImGui.SetCursorScreenPos(ctx, input_x + 8, input_y + (height - 14) / 2)
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, 0x00000000)  -- Transparent
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 0, 0)
  ImGui.SetNextItemWidth(ctx, input_width - 16)

  local changed, new_text = ImGui.InputText(ctx, "##itempicker_search", state.settings.search_string or "", ImGui.InputTextFlags_None)
  if changed then
    state.set_search_filter(new_text)
  end

  -- Track focus
  search_focused = ImGui.IsItemActive(ctx)

  ImGui.PopStyleVar(ctx)
  ImGui.PopStyleColor(ctx, 2)

  -- Draw placeholder if empty
  if (state.settings.search_string or "") == "" and not search_focused then
    local placeholder = "Search " .. mode_config.label:lower() .. "..."
    ImGui.DrawList_AddText(draw_list, input_x + 8, input_y + (height - 14) / 2, placeholder_color, placeholder)
  end

  -- Mode selector button
  local button_x = input_x + input_width + button_padding
  local button_y = input_y

  local mx, my = ImGui.GetMousePos(ctx)
  local is_button_hovered = mx >= button_x and mx <= button_x + button_width and
                            my >= button_y and my <= button_y + height

  -- Button background
  local button_bg = is_button_hovered and hover_color or bg_color
  ImGui.DrawList_AddRectFilled(draw_list, button_x, button_y, button_x + button_width, button_y + height, button_bg, 4, ImGui.DrawFlags_RoundCornersRight)
  ImGui.DrawList_AddRect(draw_list, button_x, button_y, button_x + button_width, button_y + height, border_color, 4, ImGui.DrawFlags_RoundCornersRight, 1)

  -- Mode letter
  local letter_w, letter_h = ImGui.CalcTextSize(ctx, mode_config.letter)
  local letter_x = button_x + (button_width - letter_w) / 2
  local letter_y = button_y + (height - letter_h) / 2
  ImGui.DrawList_AddText(draw_list, letter_x, letter_y, text_color, mode_config.letter)

  -- Dropdown arrow
  local arrow = "▼"
  local arrow_w, arrow_h = ImGui.CalcTextSize(ctx, arrow)
  local arrow_x = button_x + (button_width - arrow_w) / 2
  local arrow_y = button_y + height - arrow_h - 2
  ImGui.DrawList_AddText(draw_list, arrow_x, arrow_y, Colors.with_alpha(text_color, 150), arrow)

  -- Handle button click
  if is_button_hovered and ImGui.IsMouseClicked(ctx, 0) then
    dropdown_open = not dropdown_open
  end

  -- Draw dropdown menu
  if dropdown_open then
    local dropdown_x = button_x
    local dropdown_y = button_y + height + 4
    local dropdown_width = 120
    local item_height = 24
    local dropdown_height = #MODES * item_height

    -- Background
    ImGui.DrawList_AddRectFilled(draw_list, dropdown_x, dropdown_y, dropdown_x + dropdown_width, dropdown_y + dropdown_height, bg_color, 4)
    ImGui.DrawList_AddRect(draw_list, dropdown_x, dropdown_y, dropdown_x + dropdown_width, dropdown_y + dropdown_height, border_color, 4, 0, 1)

    -- Menu items
    for i, mode in ipairs(MODES) do
      local item_y = dropdown_y + (i - 1) * item_height
      local is_item_hovered = mx >= dropdown_x and mx <= dropdown_x + dropdown_width and
                              my >= item_y and my <= item_y + item_height
      local is_current = mode.id == mode_id

      -- Highlight
      if is_item_hovered then
        ImGui.DrawList_AddRectFilled(draw_list, dropdown_x, item_y, dropdown_x + dropdown_width, item_y + item_height, hover_color)
      elseif is_current then
        ImGui.DrawList_AddRectFilled(draw_list, dropdown_x, item_y, dropdown_x + dropdown_width, item_y + item_height, Colors.with_alpha(Colors.hexrgb("#4A9EFF"), 40))
      end

      -- Text: "I - Items"
      local item_text = mode.letter .. " - " .. mode.label
      local text_x = dropdown_x + 8
      local text_y = item_y + (item_height - 14) / 2
      ImGui.DrawList_AddText(draw_list, text_x, text_y, text_color, item_text)

      -- Handle click
      if is_item_hovered and ImGui.IsMouseClicked(ctx, 0) then
        state.set_setting('search_mode', mode.id)
        -- Invalidate cache to re-filter with new mode
        if state.runtime_cache then
          state.runtime_cache.audio_filter_hash = nil
          state.runtime_cache.midi_filter_hash = nil
        end
        dropdown_open = false
      end
    end

    -- Close dropdown if clicked outside
    if ImGui.IsMouseClicked(ctx, 0) then
      if not (is_button_hovered or (mx >= dropdown_x and mx <= dropdown_x + dropdown_width and
                                     my >= dropdown_y and my <= dropdown_y + dropdown_height)) then
        dropdown_open = false
      end
    end
  end

  return height
end

return M
