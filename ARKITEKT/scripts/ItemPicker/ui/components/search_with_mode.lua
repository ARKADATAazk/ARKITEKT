-- @noindex
-- ItemPicker/ui/components/search_with_mode.lua
-- Custom search field with mode selector

local ImGui = require 'imgui' '0.10'
local SearchInput = require('rearkitekt.gui.widgets.inputs.search_input')
local Style = require('rearkitekt.gui.style.defaults')

local M = {}

-- Search modes
local MODES = {
  {id = "items", label = "Items", letter = "I"},
  {id = "tracks", label = "Tracks", letter = "T"},
  {id = "regions", label = "Regions", letter = "R"},
  {id = "mixed", label = "Mixed", letter = "M"},
}

-- Dropdown state
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

  -- Dimensions
  local button_width = 32
  local overlap = -1  -- Negative pixel for border overlap
  local input_width = width - button_width + overlap

  -- Draw search input using ARKITEKT primitive
  SearchInput.draw(ctx, draw_list, x, y, input_width, height, {
    id = "item_picker_search_with_mode",
    placeholder = "Search " .. mode_config.label:lower() .. "...",
    value = state.settings.search_string or "",
    on_change = function(new_text)
      state.set_search_filter(new_text)
    end,
  }, "item_picker_search_with_mode")

  -- Mode selector button position
  local button_x = x + input_width + overlap
  local button_y = y

  -- Get mouse position
  local mx, my = ImGui.GetMousePos(ctx)
  local is_button_hovered = mx >= button_x and mx <= button_x + button_width and
                            my >= button_y and my <= button_y + height

  -- ARKITEKT colors
  local bg_color = Style.COLORS.BG_BASE
  local bg_hover = Style.COLORS.BG_HOVER
  local bg_active = Style.COLORS.BG_ACTIVE
  local border_outer = Style.COLORS.BORDER_OUTER
  local border_inner = Style.COLORS.BORDER_INNER
  local text_color = Style.COLORS.TEXT_NORMAL

  -- Button background
  local button_bg = is_button_hovered and bg_hover or bg_color
  if is_button_hovered and ImGui.IsMouseDown(ctx, 0) then
    button_bg = bg_active
  end

  -- Draw button background
  ImGui.DrawList_AddRectFilled(draw_list, button_x, button_y, button_x + button_width, button_y + height, button_bg, 0)

  -- Draw button borders
  ImGui.DrawList_AddRect(draw_list, button_x + 1, button_y + 1, button_x + button_width - 1, button_y + height - 1, border_inner, 0, 0, 1)
  ImGui.DrawList_AddRect(draw_list, button_x, button_y, button_x + button_width, button_y + height, border_outer, 0, 0, 1)

  -- Mode letter centered
  local letter_w, letter_h = ImGui.CalcTextSize(ctx, mode_config.letter)
  local letter_x = button_x + (button_width - letter_w) / 2
  local letter_y = button_y + (height - letter_h) / 2
  ImGui.DrawList_AddText(draw_list, letter_x, letter_y, text_color, mode_config.letter)

  -- Handle button click
  if is_button_hovered and ImGui.IsMouseClicked(ctx, 0) then
    dropdown_open = not dropdown_open
  end

  -- Draw dropdown menu
  if dropdown_open then
    local dropdown_x = button_x
    local dropdown_y = button_y + height + 2
    local dropdown_width = 100
    local item_height = 26
    local dropdown_height = #MODES * item_height

    -- Dropdown background
    ImGui.DrawList_AddRectFilled(draw_list, dropdown_x, dropdown_y, dropdown_x + dropdown_width, dropdown_y + dropdown_height, Style.COLORS.BG_BASE, 2)
    ImGui.DrawList_AddRect(draw_list, dropdown_x, dropdown_y, dropdown_x + dropdown_width, dropdown_y + dropdown_height, border_outer, 2, 0, 1)

    -- Menu items
    for i, mode in ipairs(MODES) do
      local item_y = dropdown_y + (i - 1) * item_height
      local is_item_hovered = mx >= dropdown_x and mx <= dropdown_x + dropdown_width and
                              my >= item_y and my <= item_y + item_height
      local is_current = mode.id == mode_id

      -- Highlight on hover
      if is_item_hovered then
        ImGui.DrawList_AddRectFilled(draw_list, dropdown_x, item_y, dropdown_x + dropdown_width, item_y + item_height, Style.COLORS.BG_HOVER, 2)
      end

      -- Text: "I - Items"
      local item_text = mode.letter .. " - " .. mode.label
      local item_text_color = is_item_hovered and Style.COLORS.TEXT_HOVER or Style.COLORS.TEXT_NORMAL
      local text_x = dropdown_x + 12
      local text_y = item_y + (item_height - 14) / 2
      ImGui.DrawList_AddText(draw_list, text_x, text_y, item_text_color, item_text)

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
