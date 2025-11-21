-- @noindex
-- TemplateBrowser/ui/tiles/template_tile_compact.lua
-- Compact horizontal template tile renderer (list view mode)
-- Inspired by Parameter Library tiles - much smaller vertically, data laid out horizontally

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Draw = require('rearkitekt.gui.draw')
local Chip = require('rearkitekt.gui.widgets.data.chip')
local MarchingAnts = require('rearkitekt.gui.fx.interactions.marching_ants')
local Badge = require('rearkitekt.gui.widgets.primitives.badge')

local M = {}
local hexrgb = Colors.hexrgb

-- Configuration for compact tiles
M.CONFIG = {
  tile_height = 18,  -- Fixed compact height (50% smaller than before)
  color_bar_width = 3,  -- Left edge color indicator
  text_margin = 6,
  chip_spacing = 3,
  name_width_fraction = 0.4,  -- Name takes ~40% of tile width
  vst_section_width = 100,
  tag_section_width = 120,
  star_size = 10,
  star_margin = 4,
  chip_height = 14,
}

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

-- Render compact template tile (horizontal list style)
function M.render(ctx, rect, template, state, metadata, animator)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local tile_w = x2 - x1
  local tile_h = M.CONFIG.tile_height

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
  local rounding = 3

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
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + tile_h, bg_color, rounding)

  -- Draw border or marching ants
  if state.selected then
    -- Marching ants for selection
    local ant_color = chip_color and Colors.same_hue_variant(chip_color, 1.0, 1.2, 0x7F) or hexrgb("#5588FF7F")
    MarchingAnts.draw(dl, x1 + 0.5, y1 + 0.5, x2 - 0.5, y1 + tile_h - 0.5, ant_color, 1.5, rounding, 8, 6, 20)
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
    ImGui.DrawList_AddRect(dl, x1, y1, x2, y1 + tile_h, border_color, rounding, 0, 1)
  end

  -- Draw color indicator bar on left edge (if template has color)
  if chip_color then
    local bar_color = Colors.same_hue_variant(chip_color, 1.0, 1.1, 200)
    ImGui.DrawList_AddRectFilled(
      dl,
      x1, y1,
      x1 + M.CONFIG.color_bar_width, y1 + tile_h,
      bar_color
    )
  end

  -- Horizontal layout sections with internal padding (like Parameter Library tiles)
  local padding = 3
  local color_stripe_width = chip_color and M.CONFIG.color_bar_width or 0
  local cursor_x = x1 + padding + color_stripe_width
  local cursor_y = y1 + (tile_h / 2) - 6  -- Vertically center text (adjusted for smaller height)

  -- Section 1: Template Name (left-aligned, takes ~35% width)
  local available_width = tile_w - (padding * 2) - color_stripe_width
  local name_width = math.floor(available_width * M.CONFIG.name_width_fraction)
  local name_color = hexrgb("#CCCCCC")  -- Match Parameter Library text color
  if state.selected or state.hover then
    name_color = hexrgb("#FFFFFF")
  end

  local truncated_name = truncate_text(ctx, template.name, name_width - 8)
  Draw.text(dl, cursor_x, cursor_y, name_color, truncated_name)
  cursor_x = cursor_x + name_width

  -- Section 2: VST Info (just show count badge, no chips due to small height)
  if template.fx and #template.fx > 0 then
    local vst_text = string.format("VST:%d", #template.fx)
    local vst_color = Colors.with_alpha(hexrgb("#6A9EFF"), 200)
    Draw.text(dl, cursor_x, cursor_y, vst_color, vst_text)
    cursor_x = cursor_x + ImGui.CalcTextSize(ctx, vst_text) + 12
  else
    cursor_x = cursor_x + M.CONFIG.vst_section_width
  end

  -- Section 3: Tags (just show count, no chips due to small height)
  if tmpl_meta and tmpl_meta.tags and #tmpl_meta.tags > 0 then
    local tags_text = string.format("Tags:%d", #tmpl_meta.tags)
    local tags_color = Colors.with_alpha(hexrgb("#888888"), 180)
    Draw.text(dl, cursor_x, cursor_y, tags_color, tags_text)
  end

  -- Section 4: Favorite Star (right-aligned)
  local star_x = x2 - M.CONFIG.star_size - M.CONFIG.star_margin
  local star_y = y1 + (tile_h / 2) - (M.CONFIG.star_size / 2)
  local star_center_x = star_x + M.CONFIG.star_size / 2
  local star_center_y = star_y + M.CONFIG.star_size / 2

  -- Check if mouse is over star icon
  local mx, my = ImGui.GetMousePos(ctx)
  local is_star_hovered = mx >= star_x and mx <= star_x + M.CONFIG.star_size and
                          my >= star_y and my <= star_y + M.CONFIG.star_size

  -- Star color based on favorite status and hover
  local star_color
  if is_favorite then
    star_color = is_star_hovered and hexrgb("#FFD700") or hexrgb("#FFA500")  -- Gold/Orange when favorited
  else
    star_color = is_star_hovered and hexrgb("#AAAAAA") or hexrgb("#555555")  -- Gray when not favorited
  end

  -- Draw star using ImGui Path API
  local function draw_star(cx, cy, radius, color)
    ImGui.DrawList_PathClear(dl)
    for i = 0, 9 do
      local angle = (i * 36 - 90) * math.pi / 180  -- 5 points, starting from top
      local r = (i % 2 == 0) and radius or radius * 0.4  -- Outer and inner radius
      local px = cx + r * math.cos(angle)
      local py = cy + r * math.sin(angle)
      ImGui.DrawList_PathLineTo(dl, px, py)
    end
    ImGui.DrawList_PathFillConvex(dl, color)
  end

  draw_star(star_center_x, star_center_y, M.CONFIG.star_size / 2, star_color)

  -- Handle star click
  if is_star_hovered and ImGui.IsMouseClicked(ctx, 0) then
    state.star_clicked = true
  end

  -- Render favorite badge if template is favorited (compact version)
  if is_favorite then
    local badge_text = "FAV"  -- Shorter text for compact view
    local badge_x = x1 + 4  -- Left side with small margin
    local badge_y = y1 + 2  -- Top with small margin (adjusted for compact height)

    -- Badge configuration (smaller for compact view)
    local badge_config = {
      padding_x = 4,
      padding_y = 1,
      rounding = 2,
      bg = Colors.hexrgb("#FFA50088"),  -- Orange background with transparency
      border_alpha = 0x99,
      border_darken = 0.3,
      text_color = Colors.hexrgb("#FFFFFF"),
    }

    -- Render the badge
    Badge.render_text_badge(ctx, dl, badge_x, badge_y, badge_text,
                           chip_color or hexrgb("#FFA500"), 255, badge_config)
  end
end

return M
