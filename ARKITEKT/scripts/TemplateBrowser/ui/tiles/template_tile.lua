-- @noindex
-- TemplateBrowser/ui/tiles/template_tile.lua
-- Template tile renderer using rearkitekt design system

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Draw = require('rearkitekt.gui.draw')
local Chip = require('rearkitekt.gui.widgets.data.chip')
local MarchingAnts = require('rearkitekt.gui.fx.interactions.marching_ants')
local Badge = require('rearkitekt.gui.widgets.primitives.badge')

local M = {}
local hexrgb = Colors.hexrgb

-- Configuration for template tiles
M.CONFIG = {
  gap = 12,
  min_col_width = 180,
  base_tile_height = 84,
  min_tile_height = 40,
  chip_radius = 4,
  badge_rounding = 3,
  text_margin = 8,
  chip_spacing = 4,

  -- Responsive thresholds
  hide_chips_below = 50,
  hide_path_below = 60,
  compact_mode_below = 70,
}

-- Calculate tile height based on content
local function calculate_content_height(template, config)
  local base_height = config.base_tile_height
  local has_fx = template.fx and #template.fx > 0
  local has_tags = template.tags and #template.tags > 0

  -- Add space for chips if present
  if has_fx or has_tags then
    base_height = base_height + 24
  end

  return math.max(base_height, config.min_tile_height)
end

-- Truncate text to fit width
local function truncate_text(ctx, text, max_width)
  if not text or max_width <= 0 then return "" end

  local text_width = ImGui.CalcTextSize(ctx, text)
  if text_width <= max_width then return text end

  local ellipsis = "..."
  local ellipsis_width = ImGui.CalcTextSize(ctx, ellipsis)
  local available_width = max_width - ellipsis_width

  for i = #text, 1, -1 do
    local truncated = text:sub(1, i)
    if ImGui.CalcTextSize(ctx, truncated) <= available_width then
      return truncated .. ellipsis
    end
  end

  return ellipsis
end

-- Check if template is favorited
local function is_favorited(template_uuid, metadata)
  if not metadata or not metadata.virtual_folders then
    return false
  end

  local favorites = metadata.virtual_folders["__FAVORITES__"]
  if not favorites or not favorites.template_refs then
    return false
  end

  for _, ref_uuid in ipairs(favorites.template_refs) do
    if ref_uuid == template_uuid then
      return true
    end
  end

  return false
end

-- Render template tile
function M.render(ctx, rect, template, state, metadata, animator)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local tile_w = x2 - x1
  local tile_h = y2 - y1

  -- Get template metadata
  local tmpl_meta = metadata and metadata.templates[template.uuid]
  local chip_color = tmpl_meta and tmpl_meta.chip_color
  local is_favorite = is_favorited(template.uuid, metadata)

  -- Animation tracking
  animator:track(template.uuid, 'hover', state.hover and 1.0 or 0.0, 12.0)
  local hover_factor = animator:get(template.uuid, 'hover')

  -- Color definitions (inspired by Parameter Library)
  local BG_BASE = hexrgb("#252525")
  local BG_HOVER = hexrgb("#2D2D2D")
  local BRD_BASE = hexrgb("#333333")
  local BRD_HOVER = hexrgb("#5588FF")
  local rounding = 4

  -- Background color with smooth hover transition
  local bg_color = BG_BASE
  if hover_factor > 0.01 then
    local r1, g1, b1 = (BG_BASE >> 24) & 0xFF, (BG_BASE >> 16) & 0xFF, (BG_BASE >> 8) & 0xFF
    local r2, g2, b2 = (BG_HOVER >> 24) & 0xFF, (BG_HOVER >> 16) & 0xFF, (BG_HOVER >> 8) & 0xFF
    local r = math.floor(r1 + (r2 - r1) * hover_factor * 0.5)
    local g = math.floor(g1 + (g2 - g1) * hover_factor * 0.5)
    local b = math.floor(b1 + (b2 - b1) * hover_factor * 0.5)
    bg_color = (r << 24) | (g << 16) | (b << 8) | 0xFF
  end

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, rounding)

  -- Draw border or marching ants
  if state.selected then
    -- Marching ants for selection
    local ant_color = chip_color and Colors.same_hue_variant(chip_color, 1.0, 1.2, 0x7F) or hexrgb("#5588FF7F")
    MarchingAnts.draw(dl, x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5, ant_color, 1.5, rounding, 8, 6, 20)
  else
    -- Normal border with hover highlight
    local border_color = BRD_BASE
    if hover_factor > 0.01 then
      local r1, g1, b1 = (BRD_BASE >> 24) & 0xFF, (BRD_BASE >> 16) & 0xFF, (BRD_BASE >> 8) & 0xFF
      local r2, g2, b2 = (BRD_HOVER >> 24) & 0xFF, (BRD_HOVER >> 16) & 0xFF, (BRD_HOVER >> 8) & 0xFF
      local r = math.floor(r1 + (r2 - r1) * hover_factor)
      local g = math.floor(g1 + (g2 - g1) * hover_factor)
      local b = math.floor(b1 + (b2 - b1) * hover_factor)
      border_color = (r << 24) | (g << 16) | (b << 8) | 0xFF
    end
    ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, rounding, 0, 1)
  end

  -- Draw color indicator stripe on left edge if template has color
  if chip_color then
    local stripe_color = Colors.same_hue_variant(chip_color, 1.0, 1.1, 200)
    ImGui.DrawList_AddRectFilled(dl, x1, y1, x1 + 3, y2, stripe_color)
  end

  -- Calculate text alpha based on tile height
  local text_alpha = 255
  if tile_h < M.CONFIG.hide_path_below then
    text_alpha = math.floor(255 * (tile_h / M.CONFIG.hide_path_below))
  end

  -- Content positioning with internal padding (like Parameter Library tiles)
  local padding = 6
  local color_stripe_width = chip_color and 3 or 0
  local content_x = x1 + padding + color_stripe_width
  local content_y = y1 + padding
  local content_w = tile_w - (padding * 2) - color_stripe_width

  -- Chip indicator removed - color is shown via diagonal stripes only

  -- Template name
  local name_color = Colors.with_alpha(hexrgb("#CCCCCC"), text_alpha)  -- Match Parameter Library text color
  if state.selected or state.hover then
    name_color = Colors.with_alpha(hexrgb("#FFFFFF"), text_alpha)
  end

  local truncated_name = truncate_text(ctx, template.name, content_w)
  Draw.text(dl, content_x, content_y, name_color, truncated_name)

  -- Template path (if height allows)
  if tile_h >= M.CONFIG.hide_path_below and template.relative_path ~= "" then
    local path_y = content_y + 18
    local path_alpha = math.floor(text_alpha * 0.6)
    local path_color = Colors.with_alpha(hexrgb("#A0A0A0"), path_alpha)
    local path_text = "[" .. template.folder .. "]"
    local truncated_path = truncate_text(ctx, path_text, content_w)
    Draw.text(dl, content_x, path_y, path_color, truncated_path)
  end

  -- Show first VST chip (if height allows and VSTs exist)
  if tile_h >= M.CONFIG.hide_chips_below and template.fx and #template.fx > 0 then
    local chip_y = tile_h >= M.CONFIG.compact_mode_below and (content_y + 40) or (content_y + 24)
    local chip_x = content_x

    -- Get first VST name and truncate if needed
    local first_vst = template.fx[1]
    local vst_color = hexrgb("#4A9EFF")

    -- Calculate max width for chip (leave room for favorite badge and margin)
    local max_chip_width = content_w - 40

    -- Truncate VST name if it's too long
    local display_vst = first_vst
    local text_width = ImGui.CalcTextSize(ctx, first_vst)
    local chip_content_width = 12 + 6 + 10 + 8  -- padding + dot + spacing + end padding
    if text_width + chip_content_width > max_chip_width then
      -- Truncate with ellipsis
      local available_width = max_chip_width - chip_content_width - ImGui.CalcTextSize(ctx, "...")
      display_vst = truncate_text(ctx, first_vst, available_width)
      text_width = ImGui.CalcTextSize(ctx, display_vst)
    end

    -- Use DrawList directly to avoid cursor position issues
    local chip_w = text_width + chip_content_width
    local chip_h = 20

    -- Background
    local bg_color = hexrgb("#1E1E1E")
    ImGui.DrawList_AddRectFilled(dl, chip_x, chip_y, chip_x + chip_w, chip_y + chip_h, bg_color, 6)

    -- Borders (tabstrip style)
    local border_inner = hexrgb("#2f2f2fff")
    ImGui.DrawList_AddRect(dl, chip_x + 1, chip_y + 1, chip_x + chip_w - 1, chip_y + chip_h - 1, border_inner, 6, 0, 1)
    local border_outer = hexrgb("#000000DD")
    ImGui.DrawList_AddRect(dl, chip_x, chip_y, chip_x + chip_w, chip_y + chip_h, border_outer, 6, 0, 1)

    -- Dot
    local dot_x = chip_x + 12
    local dot_y = chip_y + (chip_h * 0.5)
    local dot_radius = 3
    ImGui.DrawList_AddCircleFilled(dl, dot_x, dot_y, dot_radius + 1, Colors.with_alpha(hexrgb("#000000"), 80))
    ImGui.DrawList_AddCircleFilled(dl, dot_x, dot_y, dot_radius, vst_color)

    -- Text (use fixed text height for vertical centering)
    local text_height = 13  -- Approximate default font height
    local text_x = chip_x + 12 + 6 + 10 - 3  -- padding + dot + spacing - adjustment
    local text_y = chip_y + ((chip_h - text_height) * 0.5)
    local text_color = Colors.with_alpha(hexrgb("#FFFFFF"), 200)
    Draw.text(dl, text_x, text_y, text_color, display_vst)
  end

  -- Render favorite badge in top-right corner (replaces old star icon)
  local badge_size = 24  -- Larger badge size for grid tiles
  local badge_margin = 6
  local badge_x = x2 - badge_size - badge_margin  -- Right side
  local badge_y = y1 + badge_margin  -- Top with margin

  -- Check if mouse is over badge for click detection
  local mx, my = ImGui.GetMousePos(ctx)
  local is_badge_hovered = mx >= badge_x and mx <= badge_x + badge_size and
                           my >= badge_y and my <= badge_y + badge_size

  -- Badge configuration (matching ItemPicker style)
  local badge_config = {
    rounding = 3,
    bg = hexrgb("#14181C"),
    border_alpha = 0x66,
    border_darken = 0.4,
    icon_color = is_favorite and hexrgb("#FFA500") or hexrgb("#555555"),  -- Orange when favorited, gray otherwise
  }

  -- Always render badge (not just when favorited) so it's clickable
  Badge.render_favorite_badge(ctx, dl, badge_x, badge_y, badge_size, 255, true,
                             nil, nil, chip_color or hexrgb("#555555"), badge_config)

  -- Handle badge click to toggle favorite
  if is_badge_hovered and ImGui.IsMouseClicked(ctx, 0) then
    state.star_clicked = true
  end
end

return M
