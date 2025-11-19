-- @noindex
-- ThemeAdjuster/ui/grids/renderers/assignment_tile.lua
-- Renders parameter tiles in assignment grids

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Visuals = require('ThemeAdjuster.ui.grids.renderers.tile_visuals')
local ParameterLinkManager = require('ThemeAdjuster.core.parameter_link_manager')
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

  -- CORRECT: Grid passes state.hover and state.selected (not is_hovered/is_selected!)
  local hover_t = Visuals.lerp(M._anim[key].hover, state.hover and 1 or 0, 12.0 * 0.016)
  M._anim[key].hover = hover_t

  -- Get tab color
  local tab_color = view.tab_colors[tab_id] or hexrgb("#888888")

  -- Color definitions - use tab color for base with very low opacity
  local function dim_color(color, opacity)
    local r = (color >> 24) & 0xFF
    local g = (color >> 16) & 0xFF
    local b = (color >> 8) & 0xFF
    local a = math.floor(255 * opacity)
    return (r << 24) | (g << 16) | (b << 8) | a
  end

  local BG_BASE = dim_color(tab_color, 0.12)  -- 12% opacity of tab color
  local BG_HOVER = dim_color(tab_color, 0.18)  -- 18% opacity on hover
  local BRD_BASE = dim_color(tab_color, 0.3)  -- 30% opacity for border
  local BRD_HOVER = tab_color  -- Full tab color on hover
  local ANT_COLOR = dim_color(tab_color, 0.5)  -- 50% opacity for marching ants

  -- Hover shadow effect (only when not selected)
  if hover_t > 0.01 and not state.selected then
    Visuals.draw_hover_shadow(dl, x1, y1, x2, y2, hover_t, 3)
  end

  -- Background color (with smooth transitions)
  local bg_color = BG_BASE
  bg_color = Visuals.color_lerp(bg_color, BG_HOVER, hover_t * 0.5)

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, 3)

  -- Border / Selection
  if state.selected then
    -- Marching ants for selection
    Visuals.draw_marching_ants_rounded(dl, x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5, ANT_COLOR, 1, 3)
  else
    -- Normal border with hover highlight
    local border_color = Visuals.color_lerp(BRD_BASE, BRD_HOVER, hover_t)
    ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, 3, 0, 1)
  end

  -- Position cursor inside tile (moved 3 pixels up)
  ImGui.SetCursorScreenPos(ctx, x1 + 8, y1 + 1)

  ImGui.AlignTextToFramePadding(ctx)

  -- Display: [CUSTOM NAME] → [PARAM NAME] (when custom name exists)
  -- Otherwise: [PARAM NAME]

  -- Check link status for visual indicator
  local is_linked = ParameterLinkManager.is_linked(param_name)
  local is_parent = ParameterLinkManager.is_parent(param_name)
  local link_prefix = ""
  local link_color = hexrgb("#FFFFFF")

  if is_linked then
    local mode = ParameterLinkManager.get_link_mode(param_name)
    link_prefix = mode == ParameterLinkManager.LINK_MODE.LINK and "⇄ " or "⇉ "
    link_color = hexrgb("#4AE290")  -- Green for linked
  elseif is_parent then
    link_prefix = "⇶ "
    link_color = hexrgb("#5588FF")  -- Blue for parent
  end

  if metadata.display_name and metadata.display_name ~= "" then
    -- Link indicator
    if link_prefix ~= "" then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, link_color)
      ImGui.Text(ctx, link_prefix)
      ImGui.PopStyleColor(ctx)
      ImGui.SameLine(ctx, 0, 0)
    end

    -- Custom name on LEFT (bright color)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#CCCCCC"))
    local custom_name = metadata.display_name
    local max_len = link_prefix ~= "" and 26 or 30
    if #custom_name > max_len then
      custom_name = custom_name:sub(1, max_len - 3) .. "..."
    end
    ImGui.Text(ctx, custom_name)
    ImGui.PopStyleColor(ctx)

    -- Parameter name on RIGHT (muted)
    ImGui.SameLine(ctx, 0, 12)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#666666"))
    local display_name = param_name
    if #display_name > 25 then
      display_name = display_name:sub(1, 22) .. "..."
    end
    ImGui.Text(ctx, "(" .. display_name .. ")")
    ImGui.PopStyleColor(ctx)
  else
    -- Link indicator
    if link_prefix ~= "" then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, link_color)
      ImGui.Text(ctx, link_prefix)
      ImGui.PopStyleColor(ctx)
      ImGui.SameLine(ctx, 0, 0)
    end

    -- No custom name - just show parameter name (muted color)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb("#888888"))
    local display_name = param_name
    local max_len = link_prefix ~= "" and 21 or 25
    if #display_name > max_len then
      display_name = display_name:sub(1, max_len - 3) .. "..."
    end
    ImGui.Text(ctx, display_name)
    ImGui.PopStyleColor(ctx)

    -- Tooltip
    if ImGui.IsItemHovered(ctx) then
      local tooltip = "Parameter: " .. param_name
      if is_linked then
        local parent = ParameterLinkManager.get_parent(param_name)
        local mode = ParameterLinkManager.get_link_mode(param_name)
        local mode_text = mode == ParameterLinkManager.LINK_MODE.LINK and "LINK" or "SYNC"
        tooltip = tooltip .. string.format("\nLinked to: %s [%s]", parent, mode_text)
      elseif is_parent then
        tooltip = tooltip .. "\nParent of linked parameters"
      end
      ImGui.SetTooltip(ctx, tooltip)
    end
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
