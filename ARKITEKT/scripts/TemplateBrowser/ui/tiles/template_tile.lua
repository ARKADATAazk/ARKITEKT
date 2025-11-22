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

  -- Background color with smooth hover transition and subtle color tint
  local bg_color = BG_BASE
  local color_blend = 0.035  -- Very subtle 3.5% color influence

  -- Apply very subtle color tint if template has color
  if chip_color then
    local cr, cg, cb = Colors.rgba_to_components(chip_color)
    local br, bg_c, bb = Colors.rgba_to_components(BG_BASE)
    local r = math.floor(br * (1 - color_blend) + cr * color_blend)
    local g = math.floor(bg_c * (1 - color_blend) + cg * color_blend)
    local b = math.floor(bb * (1 - color_blend) + cb * color_blend)
    bg_color = Colors.components_to_rgba(r, g, b, 255)
  end

  if hover_factor > 0.01 then
    local r1, g1, b1 = Colors.rgba_to_components(bg_color)
    local r2, g2, b2 = Colors.rgba_to_components(BG_HOVER)
    local r = math.floor(r1 + (r2 - r1) * hover_factor * 0.5)
    local g = math.floor(g1 + (g2 - g1) * hover_factor * 0.5)
    local b = math.floor(b1 + (b2 - b1) * hover_factor * 0.5)
    bg_color = Colors.components_to_rgba(r, g, b, 255)
  end

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, rounding)

  -- Draw border or marching ants
  if state.selected then
    -- Marching ants for selection - light grey base with very subtle color tint
    local ant_color
    if chip_color then
      -- Extract RGB from chip color and blend with light grey
      local cr, cg, cb = Colors.rgba_to_components(chip_color)
      -- Light grey base (190) with 15% chip color influence
      local blend = 0.15
      local r = math.floor(190 * (1 - blend) + cr * blend)
      local g = math.floor(190 * (1 - blend) + cg * blend)
      local b = math.floor(190 * (1 - blend) + cb * blend)
      ant_color = Colors.components_to_rgba(r, g, b, 0x99)
    else
      ant_color = hexrgb("#C0C0C099")  -- Lighter grey with 60% opacity
    end
    MarchingAnts.draw(dl, x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5, ant_color, 1.5, rounding, 8, 6, 20)
  else
    -- Normal border with hover highlight and subtle color tint
    local border_color = BRD_BASE

    -- Apply subtle color tint to border if template has color
    if chip_color then
      local cr, cg, cb = Colors.rgba_to_components(chip_color)
      local br, bg_c, bb = Colors.rgba_to_components(BRD_BASE)
      local r = math.floor(br * (1 - color_blend) + cr * color_blend)
      local g = math.floor(bg_c * (1 - color_blend) + cg * color_blend)
      local b = math.floor(bb * (1 - color_blend) + cb * color_blend)
      border_color = Colors.components_to_rgba(r, g, b, 255)
    end

    if hover_factor > 0.01 then
      local r1, g1, b1 = Colors.rgba_to_components(border_color)
      local r2, g2, b2 = Colors.rgba_to_components(BRD_HOVER)
      local r = math.floor(r1 + (r2 - r1) * hover_factor)
      local g = math.floor(g1 + (g2 - g1) * hover_factor)
      local b = math.floor(b1 + (b2 - b1) * hover_factor)
      border_color = Colors.components_to_rgba(r, g, b, 255)
    end
    ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, rounding, 0, 1)
  end

  -- Calculate text alpha based on tile height
  local text_alpha = 255
  if tile_h < M.CONFIG.hide_path_below then
    text_alpha = math.floor(255 * (tile_h / M.CONFIG.hide_path_below))
  end

  -- Content positioning with internal padding (like Parameter Library tiles)
  local padding = 6
  local content_x = x1 + padding
  local content_y = y1 + padding
  local content_w = tile_w - (padding * 2)

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

    -- Calculate max width for chip (leave room for favorite badge and margin)
    local max_chip_width = content_w - 40

    -- Truncate VST name if it's too long
    local display_vst = first_vst
    local text_width = ImGui.CalcTextSize(ctx, first_vst)
    local chip_content_width = 16  -- padding on both sides (8 + 8)
    if text_width + chip_content_width > max_chip_width then
      -- Truncate with ellipsis
      local available_width = max_chip_width - chip_content_width - ImGui.CalcTextSize(ctx, "...")
      display_vst = truncate_text(ctx, first_vst, available_width)
      text_width = ImGui.CalcTextSize(ctx, display_vst)
    end

    -- Use DrawList directly to avoid cursor position issues
    local chip_w = text_width + chip_content_width
    local chip_h = 20

    -- Background (ACTION style: teal background)
    local chip_bg = hexrgb("#35504C")
    ImGui.DrawList_AddRectFilled(dl, chip_x, chip_y, chip_x + chip_w, chip_y + chip_h, chip_bg, 2)

    -- Border (dark, square style)
    local chip_border = hexrgb("#181818")
    ImGui.DrawList_AddRect(dl, chip_x, chip_y, chip_x + chip_w, chip_y + chip_h, chip_border, 2, 0, 1)

    -- Text (centered, white)
    local text_height = 13  -- Approximate default font height
    local text_x = chip_x + (chip_w - text_width) * 0.5
    local text_y = chip_y + ((chip_h - text_height) * 0.5)
    local text_color = hexrgb("#FFFFFF")
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
