-- @noindex
-- ItemPicker/ui/components/search_with_mode.lua
-- Custom search field with mode selector using dropdown primitive

local ImGui = require 'imgui' '0.10'
local Input = require('arkitekt.gui.widgets.primitives.input')
local Combobox = require('arkitekt.gui.widgets.inputs.combobox')
local Defaults = require('ItemPicker.defs.defaults')
local Constants = require('ItemPicker.defs.constants')

local M = {}

-- Search modes from defs
local MODES = Defaults.SEARCH_MODES

function M.get_mode_config(mode_id)
  for _, mode in ipairs(MODES) do
    if mode.value == mode_id then
      return mode
    end
  end
  return MODES[1]  -- Default to Items
end

function M.draw(ctx, draw_list, x, y, width, height, state, config)
  local mode_id = state.settings.search_mode or "items"
  local mode_config = M.get_mode_config(mode_id)

  -- Dimensions
  local dropdown_width = Constants.SEARCH.dropdown_width
  local overlap = Constants.SEARCH.overlap
  local input_width = width - dropdown_width + overlap

  -- Draw search input using ARKITEKT primitive
  Input.search(ctx, {
    id = "item_picker_search_with_mode",
    draw_list = draw_list,
    x = x,
    y = y,
    width = input_width,
    height = height,
    placeholder = "Search " .. mode_config.label:lower() .. "...",
    value = state.settings.search_string or "",
    on_change = function(new_text)
      state.set_search_filter(new_text)
    end,
  })

  -- Dropdown position (overlaps 1 pixel left)
  local dropdown_x = x + input_width + overlap
  local dropdown_y = y

  -- Draw dropdown using ARKITEKT primitive
  Combobox.draw(ctx, {
    id = "search_mode_dropdown",
    draw_list = draw_list,
    x = dropdown_x,
    y = dropdown_y,
    width = dropdown_width,
    height = height,
    options = MODES,
    current_value = mode_id,
    on_change = function(new_value)
      state.set_setting('search_mode', new_value)
      -- Invalidate cache to re-filter with new mode
      if state.runtime_cache then
        state.runtime_cache.audio_filter_hash = nil
        state.runtime_cache.midi_filter_hash = nil
      end
    end,
  })
end

return M
