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

  -- VST and Tag chips (if height allows)
  if tile_h >= M.CONFIG.hide_chips_below then
    local chip_y = tile_h >= M.CONFIG.compact_mode_below and (content_y + 40) or (content_y + 24)
    local chip_x_offset = content_x

    ImGui.SetCursorScreenPos(ctx, chip_x_offset, chip_y)

    -- VST chips (DOT style)
    if template.fx and #template.fx > 0 then
      for idx, fx_name in ipairs(template.fx) do
        if idx > 3 then break end  -- Limit to 3 VSTs

        local vst_color = hexrgb("#4A9EFF")
        local chip_clicked, chip_w, chip_h = Chip.draw(ctx, {
          style = Chip.STYLE.DOT,
          label = fx_name,
          color = vst_color,
          height = 20,
          dot_size = 6,
          dot_spacing = 6,
          padding_h = 8,
          is_selected = false,
          is_hovered = state.hover,
          interactive = false,
        })

        ImGui.SameLine(ctx, 0, 4)
      end

      -- More indicator
      if #template.fx > 3 then
        local more_text = string.format("+%d", #template.fx - 3)
        local more_color = Colors.with_alpha(hexrgb("#808080"), text_alpha)
        local cx, cy = ImGui.GetCursorScreenPos(ctx)
        Draw.text(dl, cx, cy + 4, more_color, more_text)
      end
    end

    -- Tag chips (PILL style) - on next line if both present
    if tmpl_meta and tmpl_meta.tags and #tmpl_meta.tags > 0 and tile_h >= M.CONFIG.compact_mode_below + 20 then
      ImGui.SetCursorScreenPos(ctx, chip_x_offset, chip_y + 24)

      for idx, tag_name in ipairs(tmpl_meta.tags) do
        if idx > 2 then break end  -- Limit to 2 tags

        local tag_data = metadata.tags and metadata.tags[tag_name]
        local tag_color = tag_data and tag_data.color or hexrgb("#666666")

        local chip_clicked, chip_w, chip_h = Chip.draw(ctx, {
          style = Chip.STYLE.ACTION,
          label = tag_name,
          bg_color = tag_color,
          text_color = Colors.auto_text_color(tag_color),
          height = 18,
          padding_h = 6,
          rounding = 2,
          is_selected = false,
          is_hovered = state.hover,
          interactive = false,
        })

        ImGui.SameLine(ctx, 0, 4)
      end
    end
  end

  -- Draw favorite star icon in top-right corner
  local star_size = 16
  local star_margin = 6
  local star_x = x2 - star_size - star_margin
  local star_y = y1 + star_margin
  local star_center_x = star_x + star_size / 2
  local star_center_y = star_y + star_size / 2

  -- Check if mouse is over star icon
  local mx, my = ImGui.GetMousePos(ctx)
  local is_star_hovered = mx >= star_x and mx <= star_x + star_size and
                          my >= star_y and my <= star_y + star_size

  -- Star color based on favorite status and hover
  local star_color
  if is_favorite then
    star_color = is_star_hovered and Colors.hexrgb("#FFD700") or Colors.hexrgb("#FFA500")  -- Gold/Orange when favorited
  else
    star_color = is_star_hovered and Colors.hexrgb("#AAAAAA") or Colors.hexrgb("#555555")  -- Gray when not favorited
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

  draw_star(star_center_x, star_center_y, star_size / 2, star_color)

  -- Handle star click (needs to be reported back to parent)
  -- Store star click state in template state for parent to handle
  if is_star_hovered and ImGui.IsMouseClicked(ctx, 0) then
    state.star_clicked = true
  end

  -- Render favorite badge if template is favorited (icon badge matching ItemPicker style)
  if is_favorite then
    local badge_size = 18  -- Badge size
    local badge_margin = 6
    local badge_x = x1 + badge_margin  -- Left side with margin
    local badge_y = y1 + badge_margin  -- Top with margin

    -- Badge configuration (matching ItemPicker style)
    local badge_config = {
      rounding = 3,
      bg = hexrgb("#14181C"),
      border_alpha = 0x66,
      border_darken = 0.4,
      icon_color = hexrgb("#FFA500"),  -- Orange star icon
    }

    -- Render using standardized favorite badge method
    Badge.render_favorite_badge(ctx, dl, badge_x, badge_y, badge_size, 255, is_favorite,
                               nil, nil, chip_color or hexrgb("#555555"), badge_config)
  end
end

return M
