-- @noindex
-- ThemeAdjuster/ui/grids/renderers/assignment_tile.lua
-- Renders parameter tiles in assignment grids

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Visuals = require('ThemeAdjuster.ui.grids.renderers.tile_visuals')
local hexrgb = Colors.hexrgb

local M = {}

-- Animation state storage (persistent across frames)
M._anim = M._anim or {}

function M.render(ctx, rect, item, state, view, tab_id)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local w = x2 - x1
  local h = y2 - y1
  local dl = ImGui.GetWindowDrawList(ctx)

  local param_name = item.param_name
  local metadata = view.custom_metadata[param_name] or {}

  -- Animation state (smooth transitions)
  local key = "assign_" .. tab_id .. "_" .. param_name
  M._anim[key] = M._anim[key] or { hover = 0 }

  local hover_t = Visuals.lerp(M._anim[key].hover, (state.is_hovered and not state.is_dragged) and 1 or 0, 12.0 * 0.016)
  M._anim[key].hover = hover_t

  -- Color definitions
  local BG_BASE = hexrgb("#1A1A22")
  local BG_HOVER = hexrgb("#222230")
  local BG_DRAGGED = hexrgb("#252535")
  local BRD_BASE = hexrgb("#2A2A2A")
  local BRD_HOVER = hexrgb("#5588FF")
  local ANT_COLOR = hexrgb("#5588FFFF")

  -- Hover shadow effect (only when not selected)
  if hover_t > 0.01 and not state.is_selected then
    Visuals.draw_hover_shadow(dl, x1, y1, x2, y2, hover_t, 3)
  end

  -- Background color (with smooth transitions)
  local bg_color = BG_BASE
  if state.is_dragged then
    bg_color = BG_DRAGGED
  else
    bg_color = Visuals.color_lerp(bg_color, BG_HOVER, hover_t * 0.5)
  end

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, 3)

  -- Border / Selection
  if state.is_selected then
    -- Marching ants for selection
    Visuals.draw_marching_ants_rounded(dl, x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5, ANT_COLOR, 1, 3)
  else
    -- Normal border with hover highlight
    local border_color = Visuals.color_lerp(BRD_BASE, BRD_HOVER, hover_t)
    ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, 3, 0, 1)
  end

  -- Position cursor inside tile
  ImGui.SetCursorScreenPos(ctx, x1 + 8, y1 + 4)

  ImGui.AlignTextToFramePadding(ctx)

  -- Display: [PARAM NAME] [CUSTOM NAME]
  -- Format: "tcp_LabelSize" → "Label Size"

  -- Parameter name (muted color)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
  local display_name = param_name
  if #display_name > 25 then
    display_name = display_name:sub(1, 22) .. "..."
  end
  ImGui.Text(ctx, display_name)
  ImGui.PopStyleColor(ctx)

  -- Tooltip
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Parameter: " .. param_name)
  end

  -- Custom name (if set)
  if metadata.display_name and metadata.display_name ~= "" then
    ImGui.SameLine(ctx, 0, 12)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CCCCCC"))
    local custom_name = metadata.display_name
    if #custom_name > 30 then
      custom_name = custom_name:sub(1, 27) .. "..."
    end
    ImGui.Text(ctx, "→ " .. custom_name)
    ImGui.PopStyleColor(ctx)
  end

  -- Show order number for debugging (optional)
  if view.dev_mode and item.order then
    ImGui.SameLine(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#555555"))
    ImGui.Text(ctx, string.format("#%d", item.order))
    ImGui.PopStyleColor(ctx)
  end
end

return M
