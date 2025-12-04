-- @noindex
-- ThemeAdjuster/ui/grids/renderers/result_tile.lua
-- Renders result tiles showing resolved image key → provider mapping

local ImGui = require('arkitekt.core.imgui')
local Ark = require('arkitekt')
local ImageTooltip = require('ThemeAdjuster.ui.image_tooltip')

local M = {}

-- Tile dimensions (exported for grid configuration)
M.TILE_WIDTH = 260
M.TILE_HEIGHT = 52

function M.render(ctx, rect, item, state, view)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local w = x2 - x1
  local dl = ImGui.GetWindowDrawList(ctx)

  local key = item.key
  local entry = item.entry
  local current_provider = entry.provider or item.provider or '(unknown)'
  local is_pinned = entry.pinned or false

  -- Background
  local bg_color = state.hover and 0x252525FF or 0x1E1E1EFF
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, 3)

  -- Border (green if pinned, highlight on hover)
  local border_color
  if is_pinned then
    border_color = 0x4AE290FF
  elseif state.hover then
    border_color = 0x555555FF
  else
    border_color = 0x333333FF
  end
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, 3, 0, is_pinned and 2 or 1)

  -- Key name (truncated) - top row
  local display_name = key
  if #display_name > 32 then
    display_name = display_name:sub(1, 30) .. '..'
  end
  ImGui.DrawList_AddText(dl, x1 + 6, y1 + 4, 0xDDDDDDFF, display_name)

  -- Pin indicator (top right)
  if is_pinned then
    ImGui.DrawList_AddCircleFilled(dl, x2 - 10, y1 + 10, 5, 0x4AE290FF)
  end

  -- Get all providers for this key
  local providers = view:get_providers_for_key(key)

  -- Build combo options
  local combo_options = {}
  for i, p in ipairs(providers) do
    local display = p.name
    if #display > 28 then
      display = display:sub(1, 26) .. '..'
    end
    combo_options[#combo_options + 1] = {
      value = p.id,
      label = display,
      path = p.path,  -- Store for tooltip
    }
  end

  -- Draw combo if multiple providers available
  if #providers > 1 then
    local combo_result = Ark.Combo(ctx, {
      id = 'result_combo_' .. key,
      x = x1 + 4,
      y = y1 + 24,
      width = w - 8,
      height = 24,
      options = combo_options,
      current_value = current_provider,
      on_change = function(new_value)
        if view.on_provider_selected then
          view.on_provider_selected(key, new_value)
        end
      end,
      advance = 'none',
    })
  else
    -- Single provider - just show text
    local provider_display = current_provider
    if #provider_display > 30 then
      provider_display = provider_display:sub(1, 28) .. '..'
    end
    ImGui.DrawList_AddText(dl, x1 + 6, y1 + 28, 0x888888FF, provider_display)
  end

  -- Image tooltip on tile hover (when not hovering combo)
  if state.hover and entry.path then
    local mx, my = ImGui.GetMousePos(ctx)
    -- Only show if mouse is in top part of tile (not on combo)
    if my < y1 + 24 then
      ImageTooltip.show_for_rect(ctx, entry.path, {x1, y1, x2, y1 + 24}, {
        label = key,
        show_path = true,
      })
    end
  end
end

return M
