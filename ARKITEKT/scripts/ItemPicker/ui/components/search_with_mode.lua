-- @noindex
-- ItemPicker/ui/components/search_with_mode.lua
-- Custom search field with mode selector using ARKITEKT primitives

local ImGui = require 'imgui' '0.10'
local SearchInput = require('rearkitekt.gui.widgets.inputs.search_input')
local Button = require('rearkitekt.gui.widgets.primitives.button')
local ContextMenu = require('rearkitekt.gui.widgets.overlays.context_menu')
local Style = require('rearkitekt.gui.style.defaults')

local M = {}

-- Search modes
local MODES = {
  {id = "items", label = "Items", letter = "I"},
  {id = "tracks", label = "Tracks", letter = "T"},
  {id = "regions", label = "Regions", letter = "R"},
  {id = "mixed", label = "Mixed", letter = "M"},
}

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
  local overlap = -1  -- Negative pixel for border overlap
  local input_width = width - button_width + overlap

  -- Draw search input using ARKITEKT primitive
  local search_x = x
  local search_y = y

  SearchInput.draw(ctx, draw_list, search_x, search_y, input_width, height, {
    id = "item_picker_search_with_mode",
    placeholder = "Search " .. mode_config.label:lower() .. "...",
    value = state.settings.search_string or "",
    on_change = function(new_text)
      state.set_search_filter(new_text)
    end,
  }, "item_picker_search_with_mode")

  -- Mode selector button
  local button_x = search_x + input_width + overlap
  local button_y = search_y

  -- Draw button using ARKITEKT primitive
  local button_clicked = Button.draw(ctx, draw_list, button_x, button_y, button_width, height, {
    id = "search_mode_button",
    label = mode_config.letter,
    is_blocking = true,
  }, "search_mode_button")

  -- Open context menu on button click
  if button_clicked then
    ImGui.OpenPopup(ctx, "search_mode_menu")
  end

  -- Draw context menu
  if ContextMenu.begin(ctx, "search_mode_menu") then
    for _, mode in ipairs(MODES) do
      local menu_label = mode.letter .. " - " .. mode.label
      if ContextMenu.item(ctx, menu_label) then
        state.set_setting('search_mode', mode.id)
        -- Invalidate cache to re-filter with new mode
        if state.runtime_cache then
          state.runtime_cache.audio_filter_hash = nil
          state.runtime_cache.midi_filter_hash = nil
        end
      end
    end
    ContextMenu.end_menu(ctx)
  end

  return height
end

return M
