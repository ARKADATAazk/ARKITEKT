-- @noindex
-- arkitekt/gui/widgets/modal/rendering.lua
-- Visual rendering for Modal widget (shadows, borders, scrim, close button)
-- Derived from overlay/sheet.lua visual styling

local ImGui = require('arkitekt.core.imgui')
local Colors = require('arkitekt.core.colors')

local M = {}

-- ============================================================================
-- SCRIM RENDERING
-- ============================================================================

--- Draw the darkened scrim behind the modal
--- @param dl userdata Draw list
--- @param bounds table {x, y, width, height}
--- @param config table Scrim config
--- @param alpha number Current fade alpha (0-1)
function M.draw_scrim(dl, bounds, config, alpha)
  local scrim_alpha = Colors.Opacity(config.opacity * alpha)
  local scrim_color = Colors.WithAlpha(config.color, scrim_alpha)
  ImGui.DrawList_AddRectFilled(dl, bounds.x, bounds.y, bounds.x + bounds.width, bounds.y + bounds.height, scrim_color, 0)
end

-- ============================================================================
-- SHADOW RENDERING
-- ============================================================================

--- Draw layered shadows behind the modal sheet
--- @param dl userdata Draw list
--- @param x number Modal x position
--- @param y number Modal y position
--- @param w number Modal width
--- @param h number Modal height
--- @param r number Corner rounding
--- @param config table Shadow config
--- @param alpha number Current fade alpha (0-1)
function M.draw_shadow(dl, x, y, w, h, r, config, alpha)
  if not config.enabled then return end

  for i = config.layers, 1, -1 do
    local shadow_offset = math.floor((i / config.layers) * config.max_offset)
    local shadow_alpha = Colors.Opacity((config.base_alpha / i) * alpha / 255)
    local shadow_color = Colors.WithAlpha(0x000000FF, shadow_alpha)
    ImGui.DrawList_AddRectFilled(dl,
      x - shadow_offset, y - shadow_offset,
      x + w + shadow_offset, y + h + shadow_offset,
      shadow_color, r + shadow_offset)
  end
end

-- ============================================================================
-- SHEET/PANEL RENDERING
-- ============================================================================

--- Draw the modal sheet background and borders
--- @param dl userdata Draw list
--- @param x number Modal x position
--- @param y number Modal y position
--- @param w number Modal width
--- @param h number Modal height
--- @param config table Sheet config
--- @param alpha number Current fade alpha (0-1)
function M.draw_sheet(dl, x, y, w, h, config, alpha)
  local r = config.rounding

  -- Background
  local bg_alpha = Colors.Opacity(config.background.opacity * alpha)
  local bg_color = Colors.WithAlpha(config.background.color, bg_alpha)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, bg_color, r)

  -- Outer border
  local outer_alpha = Colors.Opacity(config.border.outer_opacity * alpha)
  local outer_color = Colors.WithAlpha(config.border.outer_color, outer_alpha)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, outer_color, r, 0, config.border.outer_thickness)

  -- Inner border (highlight)
  local inner_alpha = Colors.Opacity(config.border.inner_opacity * alpha)
  local inner_color = Colors.WithAlpha(config.border.inner_color, inner_alpha)
  ImGui.DrawList_AddRect(dl, x + 1, y + 1, x + w - 1, y + h - 1, inner_color, r - 1, 0, config.border.inner_thickness)
end

-- ============================================================================
-- HEADER RENDERING
-- ============================================================================

--- Draw the modal header with title and divider
--- @param ctx userdata ImGui context
--- @param dl userdata Draw list
--- @param x number Modal x position
--- @param y number Modal y position
--- @param w number Modal width
--- @param title string Title text
--- @param config table Header config
--- @param alpha number Current fade alpha (0-1)
--- @return number Header height used
function M.draw_header(ctx, dl, x, y, w, title, config, alpha)
  if not title or title == '' then
    return 0
  end

  local hh = config.height

  -- Title text
  local title_alpha = Colors.Opacity(config.text_opacity * alpha)
  local title_color = Colors.WithAlpha(config.text_color, title_alpha)
  local text_y = y + math.floor((hh - ImGui.GetTextLineHeight(ctx)) / 2)
  ImGui.DrawList_AddText(dl, x + 20, text_y, title_color, title)

  -- Divider line with fade gradient on edges
  local divider_y = y + hh
  local fade_w = config.divider_fade_width
  local base_alpha = Colors.Opacity(config.divider_opacity * alpha)

  -- Left fade gradient
  for i = 0, fade_w do
    local progress = i / fade_w
    local div_alpha = (progress * base_alpha) // 1
    local div_color = Colors.WithAlpha(config.divider_color, div_alpha)
    ImGui.DrawList_AddLine(dl, x + i, divider_y, x + i + 1, divider_y, div_color, config.divider_thickness)
  end

  -- Main divider line
  local main_color = Colors.WithAlpha(config.divider_color, base_alpha)
  ImGui.DrawList_AddLine(dl, x + fade_w, divider_y, x + w - fade_w, divider_y, main_color, config.divider_thickness)

  -- Right fade gradient
  for i = 0, fade_w do
    local progress = 1.0 - (i / fade_w)
    local div_alpha = (progress * base_alpha) // 1
    local div_color = Colors.WithAlpha(config.divider_color, div_alpha)
    ImGui.DrawList_AddLine(dl, x + w - fade_w + i, divider_y, x + w - fade_w + i + 1, divider_y, div_color, config.divider_thickness)
  end

  -- Highlight line below divider
  local highlight_alpha = Colors.Opacity(config.highlight_opacity * alpha)
  local highlight_color = Colors.WithAlpha(config.highlight_color, highlight_alpha)
  ImGui.DrawList_AddLine(dl, x + fade_w, divider_y + 1, x + w - fade_w, divider_y + 1, highlight_color, config.highlight_thickness)

  return hh
end

-- ============================================================================
-- CLOSE BUTTON RENDERING
-- ============================================================================

--- Draw the close button (X) in top-right corner
--- @param ctx userdata ImGui context
--- @param dl userdata Draw list (foreground)
--- @param x number Modal x position
--- @param y number Modal y position
--- @param w number Modal width
--- @param config table Close button config
--- @param state table Modal state (for button animation)
--- @param alpha number Current fade alpha (0-1)
--- @param dt number Delta time
--- @return boolean True if clicked
function M.draw_close_button(ctx, dl, x, y, w, config, state, alpha, dt)
  local btn_size = config.size
  local btn_x = x + w - btn_size - config.margin
  local btn_y = y + config.margin

  -- Check proximity for fade-in effect
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local center_x = btn_x + btn_size / 2
  local center_y = btn_y + btn_size / 2
  local dist = math.sqrt((mouse_x - center_x)^2 + (mouse_y - center_y)^2)
  local in_proximity = dist < config.proximity

  -- Create invisible button for interaction
  ImGui.SetCursorScreenPos(ctx, btn_x, btn_y)
  ImGui.InvisibleButton(ctx, '##modal_close_' .. state.id, btn_size, btn_size)
  local is_hovered = ImGui.IsItemHovered(ctx)
  local clicked = ImGui.IsItemClicked(ctx)

  -- Update button animation state
  state:update_close_button(dt, in_proximity, is_hovered)

  -- Calculate final alpha
  local btn_alpha = alpha * state.close_button_alpha

  -- Draw background circle
  local bg_opacity = is_hovered and config.bg_opacity_hover or config.bg_opacity
  local bg_alpha_final = Colors.Opacity(bg_opacity * btn_alpha)
  local bg_color = Colors.WithAlpha(config.bg_color, bg_alpha_final)
  ImGui.DrawList_AddCircleFilled(dl, center_x, center_y, btn_size / 2, bg_color)

  -- Draw X icon
  local icon_color = is_hovered and config.hover_color or config.icon_color
  local icon_alpha = Colors.Opacity(btn_alpha)
  icon_color = Colors.WithAlpha(icon_color, icon_alpha)

  local padding = btn_size * 0.3
  local x1, y1 = btn_x + padding, btn_y + padding
  local x2, y2 = btn_x + btn_size - padding, btn_y + btn_size - padding
  ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, icon_color, 2)
  ImGui.DrawList_AddLine(dl, x2, y1, x1, y2, icon_color, 2)

  return clicked
end

return M
