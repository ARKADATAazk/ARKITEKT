-- @noindex
-- TemplateBrowser/ui/tiles/template_tile_compact.lua
-- Compact horizontal template tile renderer (list view mode)
-- Inspired by Parameter Library tiles - much smaller vertically, data laid out horizontally

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Draw = require('arkitekt.gui.draw')
local Chip = require('arkitekt.gui.widgets.data.chip')
local MarchingAnts = require('arkitekt.gui.fx.interactions.marching_ants')
local Badge = require('arkitekt.gui.widgets.primitives.badge')

local M = {}
local hexrgb = Colors.hexrgb

-- Configuration for compact tiles
M.CONFIG = {
  tile_height = 15,  -- Fixed compact height (reduced by 3)
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
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y1 + tile_h, bg_color, rounding)

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
    MarchingAnts.draw(dl, x1 + 0.5, y1 + 0.5, x2 - 0.5, y1 + tile_h - 0.5, ant_color, 1.5, rounding, 8, 6, 20)
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
    ImGui.DrawList_AddRect(dl, x1, y1, x2, y1 + tile_h, border_color, rounding, 0, 1)
  end

  -- Horizontal layout sections with internal padding (like Parameter Library tiles)
  local padding = 2
  local cursor_x = x1 + padding
  local cursor_y = y1 + (tile_h / 2) - 9  -- Vertically center text (moved up 3px)

  -- Section 1: Template Name (left-aligned, takes ~35% width)
  local available_width = tile_w - (padding * 2)
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
  local star_size = 10  -- Smaller star for compact view
  local star_margin = 4
  local star_x = x2 - star_size - star_margin  -- Right side
  local star_y = y1 + (tile_h - star_size) / 2  -- Vertically centered

  -- Check if mouse is over star for click detection
  local mx, my = ImGui.GetMousePos(ctx)
  local is_star_hovered = mx >= star_x and mx <= star_x + star_size and
                          my >= star_y and my <= star_y + star_size

  -- Star color: light grey when enabled, dark when disabled
  local star_color
  if is_favorite then
    star_color = hexrgb("#E8E8E8")  -- Light grey when enabled
  else
    star_color = is_star_hovered and hexrgb("#282828A0") or hexrgb("#18181850")
  end

  -- Render star using remix icon font
  local star_char = utf8.char(0xF186)  -- Remix star-fill icon

  -- Use icon font if available in state
  if state.fonts and state.fonts.icons then
    local base_size = state.fonts.icons_size or 14
    local font_size = math.floor(base_size * 0.7)  -- Smaller for compact view

    ImGui.PushFont(ctx, state.fonts.icons, font_size)
    local text_w, text_h = ImGui.CalcTextSize(ctx, star_char)
    local star_text_x = star_x + (star_size - text_w) * 0.5
    local star_text_y = star_y + (star_size - text_h) * 0.5
    ImGui.DrawList_AddText(dl, star_text_x, star_text_y, star_color, star_char)
    ImGui.PopFont(ctx)
  else
    -- Fallback to Unicode star if no icon font
    local star_char_fallback = "★"
    local text_w, text_h = ImGui.CalcTextSize(ctx, star_char_fallback)
    local star_text_x = star_x + (star_size - text_w) * 0.5
    local star_text_y = star_y + (star_size - text_h) * 0.5
    Draw.text(dl, star_text_x, star_text_y, star_color, star_char_fallback)
  end

  -- Handle star click to toggle favorite
  if is_star_hovered and ImGui.IsMouseClicked(ctx, 0) then
    state.star_clicked = true
  end
end

return M
