-- @noindex
-- TemplateBrowser/ui/tiles/tile.lua
-- Template tile renderer using arkitekt design system

local ImGui = require('arkitekt.platform.imgui')
local Ark = require('arkitekt')
local MarchingAnts = require('arkitekt.gui.interaction.marching_ants')
local TileHelpers = require('TemplateBrowser.ui.tiles.helpers')

local M = {}
local hexrgb = Ark.Colors.hexrgb

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

  -- Stacked visual for multi-track templates
  stack_offset = 3,        -- Pixel offset between layers
  stack_max_layers = 3,    -- Maximum number of stack layers
}

-- Local aliases for frequently used helpers
local truncate_text = TileHelpers.truncate_text
local is_favorited = TileHelpers.is_favorited
local strip_parentheses = TileHelpers.strip_parentheses
local get_display_vst = TileHelpers.get_display_vst

-- Draw stacked layers behind tile for multi-track templates
local function draw_stack_layers(ctx, dl, x1, y1, x2, y2, track_count, chip_color)
  if track_count <= 1 then return end

  -- Calculate number of layers (capped at max)
  local num_layers = math.min(track_count - 1, M.CONFIG.stack_max_layers)
  local offset = M.CONFIG.stack_offset
  local rounding = 4

  -- Stack layer colors (progressively darker/more transparent)
  local STACK_BASE = hexrgb('#1E1E1E')
  local STACK_BORDER = hexrgb('#2A2A2A')

  -- Draw layers from back to front
  for i = num_layers, 1, -1 do
    local layer_offset = offset * i
    local alpha_factor = 0.5 + (0.3 * (1 - i / num_layers))  -- More visible for closer layers

    -- Layer background with color tint if chip_color exists
    local layer_bg = STACK_BASE
    local layer_border = STACK_BORDER
    if chip_color then
      local cr, cg, cb = Ark.Colors.rgba_to_components(chip_color)
      local br, bg_c, bb = Ark.Colors.rgba_to_components(STACK_BASE)
      local blend = 0.05  -- Very subtle tint
      local r = math.floor(br * (1 - blend) + cr * blend)
      local g = math.floor(bg_c * (1 - blend) + cg * blend)
      local b = math.floor(bb * (1 - blend) + cb * blend)
      layer_bg = Ark.Colors.components_to_rgba(r, g, b, math.floor(255 * alpha_factor))
    else
      layer_bg = Ark.Colors.with_alpha(STACK_BASE, math.floor(255 * alpha_factor))
    end

    -- Draw layer rectangle (offset to bottom-right)
    local lx1 = x1 + layer_offset
    local ly1 = y1 + layer_offset
    local lx2 = x2 + layer_offset
    local ly2 = y2 + layer_offset

    ImGui.DrawList_AddRectFilled(dl, lx1, ly1, lx2, ly2, layer_bg, rounding)
    ImGui.DrawList_AddRect(dl, lx1, ly1, lx2, ly2, Ark.Colors.with_alpha(layer_border, math.floor(180 * alpha_factor)), rounding, 0, 1)
  end
end

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

  -- Draw stacked layers for multi-track templates (behind main tile)
  local track_count = template.track_count or 1
  draw_stack_layers(ctx, dl, x1, y1, x2, y2, track_count, chip_color)

  -- Animation tracking
  animator:track(template.uuid, 'hover', state.hover and 1.0 or 0.0, 12.0)
  local hover_factor = animator:get(template.uuid, 'hover')

  -- Color definitions (inspired by Parameter Library)
  local BG_BASE = hexrgb('#252525')
  local BG_HOVER = hexrgb('#2D2D2D')
  local BRD_BASE = hexrgb('#333333')
  local BRD_HOVER = hexrgb('#5588FF')
  local rounding = 4

  -- Background color with smooth hover transition and subtle color tint
  local bg_color = BG_BASE
  local color_blend = 0.035  -- Very subtle 3.5% color influence

  -- Apply very subtle color tint if template has color
  if chip_color then
    local cr, cg, cb = Ark.Colors.rgba_to_components(chip_color)
    local br, bg_c, bb = Ark.Colors.rgba_to_components(BG_BASE)
    local r = math.floor(br * (1 - color_blend) + cr * color_blend)
    local g = math.floor(bg_c * (1 - color_blend) + cg * color_blend)
    local b = math.floor(bb * (1 - color_blend) + cb * color_blend)
    bg_color = Ark.Colors.components_to_rgba(r, g, b, 255)
  end

  if hover_factor > 0.01 then
    local r1, g1, b1 = Ark.Colors.rgba_to_components(bg_color)
    local r2, g2, b2 = Ark.Colors.rgba_to_components(BG_HOVER)
    local r = math.floor(r1 + (r2 - r1) * hover_factor * 0.5)
    local g = math.floor(g1 + (g2 - g1) * hover_factor * 0.5)
    local b = math.floor(b1 + (b2 - b1) * hover_factor * 0.5)
    bg_color = Ark.Colors.components_to_rgba(r, g, b, 255)
  end

  -- Draw background
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, rounding)

  -- Draw border or marching ants
  if state.selected then
    -- Marching ants for selection - light grey base with very subtle color tint
    local ant_color
    if chip_color then
      -- Extract RGB from chip color and blend with light grey
      local cr, cg, cb = Ark.Colors.rgba_to_components(chip_color)
      -- Light grey base (190) with 15% chip color influence
      local blend = 0.15
      local r = math.floor(190 * (1 - blend) + cr * blend)
      local g = math.floor(190 * (1 - blend) + cg * blend)
      local b = math.floor(190 * (1 - blend) + cb * blend)
      ant_color = Ark.Colors.components_to_rgba(r, g, b, 0x99)
    else
      ant_color = hexrgb('#C0C0C099')  -- Lighter grey with 60% opacity
    end
    MarchingAnts.draw(dl, x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5, ant_color, 1.5, rounding, 8, 6, 20)
  else
    -- Normal border with hover highlight and subtle color tint
    local border_color = BRD_BASE

    -- Apply subtle color tint to border if template has color
    if chip_color then
      local cr, cg, cb = Ark.Colors.rgba_to_components(chip_color)
      local br, bg_c, bb = Ark.Colors.rgba_to_components(BRD_BASE)
      local r = math.floor(br * (1 - color_blend) + cr * color_blend)
      local g = math.floor(bg_c * (1 - color_blend) + cg * color_blend)
      local b = math.floor(bb * (1 - color_blend) + cb * color_blend)
      border_color = Ark.Colors.components_to_rgba(r, g, b, 255)
    end

    if hover_factor > 0.01 then
      local r1, g1, b1 = Ark.Colors.rgba_to_components(border_color)
      local r2, g2, b2 = Ark.Colors.rgba_to_components(BRD_HOVER)
      local r = math.floor(r1 + (r2 - r1) * hover_factor)
      local g = math.floor(g1 + (g2 - g1) * hover_factor)
      local b = math.floor(b1 + (b2 - b1) * hover_factor)
      border_color = Ark.Colors.components_to_rgba(r, g, b, 255)
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
  local name_color = Ark.Colors.with_alpha(hexrgb('#CCCCCC'), text_alpha)  -- Match Parameter Library text color
  if state.selected or state.hover then
    name_color = Ark.Colors.with_alpha(hexrgb('#FFFFFF'), text_alpha)
  end

  local truncated_name = truncate_text(ctx, template.name, content_w)
  Ark.Draw.text(dl, content_x, content_y, name_color, truncated_name)

  -- Show first VST chip below title (where path used to be)
  local first_vst = get_display_vst(template.fx)
  if tile_h >= M.CONFIG.hide_chips_below and first_vst then
    local chip_y = content_y + 18
    local chip_x = content_x

    -- Strip parenthetical content for display (e.g., 'Kontakt (Native Instruments)' -> 'Kontakt')
    local display_vst = strip_parentheses(first_vst)

    -- Calculate max width for chip (leave room for favorite badge and margin)
    local max_chip_width = content_w - 40

    -- Truncate VST name if it's too long
    local text_width = ImGui.CalcTextSize(ctx, display_vst)
    local chip_content_width = 16  -- padding on both sides (8 + 8)
    if text_width + chip_content_width > max_chip_width then
      -- Truncate with ellipsis
      local available_width = max_chip_width - chip_content_width - ImGui.CalcTextSize(ctx, '...')
      display_vst = truncate_text(ctx, display_vst, available_width)
      text_width = ImGui.CalcTextSize(ctx, display_vst)
    end

    -- Use DrawList directly to avoid cursor position issues
    local chip_w = text_width + chip_content_width
    local chip_h = 20

    -- Background (dark grey with 80% transparency)
    local chip_bg = hexrgb('#3A3A3ACC')
    ImGui.DrawList_AddRectFilled(dl, chip_x, chip_y, chip_x + chip_w, chip_y + chip_h, chip_bg, 2)

    -- Text (centered, white)
    local _, actual_text_height = ImGui.CalcTextSize(ctx, display_vst)
    local text_x = chip_x + (chip_w - text_width) * 0.5
    local text_y = chip_y + math.floor((chip_h - actual_text_height) * 0.5)
    local text_color = hexrgb('#FFFFFF')
    Ark.Draw.text(dl, text_x, text_y, text_color, display_vst)
  end

  -- Template path at bottom right (if height allows)
  if tile_h >= M.CONFIG.hide_path_below and template.relative_path ~= '' then
    local path_alpha = math.floor(text_alpha * 0.6)
    local path_color = Ark.Colors.with_alpha(hexrgb('#A0A0A0'), path_alpha)
    local path_text = '[' .. template.folder .. ']'
    local path_width = ImGui.CalcTextSize(ctx, path_text)
    local truncated_path = truncate_text(ctx, path_text, content_w - 30)  -- Leave room for star
    local actual_path_width = ImGui.CalcTextSize(ctx, truncated_path)
    local path_x = x2 - padding - actual_path_width
    local path_y = y2 - padding - 14  -- 14 is approx text height
    Ark.Draw.text(dl, path_x, path_y, path_color, truncated_path)
  end

  -- Track count badge at bottom left (if multi-track template)
  if tile_h >= M.CONFIG.hide_chips_below and track_count > 1 then
    local badge_text = track_count .. 'T'
    local badge_text_w, badge_text_h = ImGui.CalcTextSize(ctx, badge_text)
    local badge_padding_x = 5
    local badge_padding_y = 2
    local badge_w = badge_text_w + badge_padding_x * 2
    local badge_h = badge_text_h + badge_padding_y * 2
    local badge_x = content_x
    local badge_y = y2 - padding - badge_h

    -- Badge background (semi-transparent dark)
    local badge_bg = hexrgb('#2A2A2ACC')
    ImGui.DrawList_AddRectFilled(dl, badge_x, badge_y, badge_x + badge_w, badge_y + badge_h, badge_bg, M.CONFIG.badge_rounding)

    -- Badge border (subtle)
    local badge_border = hexrgb('#40404080')
    ImGui.DrawList_AddRect(dl, badge_x, badge_y, badge_x + badge_w, badge_y + badge_h, badge_border, M.CONFIG.badge_rounding)

    -- Badge text
    local badge_text_color = hexrgb('#A8A8A8')
    local badge_text_x = badge_x + badge_padding_x
    local badge_text_y = badge_y + badge_padding_y
    Ark.Draw.text(dl, badge_text_x, badge_text_y, badge_text_color, badge_text)
  end

  -- Render favorite star in top-right corner using remix icon font
  local star_size = 15  -- Size of the star (reduced 30%)
  local star_margin = 4
  local star_x = x2 - star_size - star_margin
  local star_y = y1 + star_margin

  -- Hit area for click detection
  local mx, my = ImGui.GetMousePos(ctx)
  local is_star_hovered = mx >= star_x and mx <= star_x + star_size and
                          my >= star_y and my <= star_y + star_size

  -- Determine star color based on favorite state (light grey when enabled, no color influence)
  local star_color

  if is_favorite then
    star_color = hexrgb('#E8E8E8')  -- Light grey when enabled
  else
    -- Darker when disabled, with subtle color influence if tile has color
    if chip_color then
      local cr, cg, cb = Ark.Colors.rgba_to_components(chip_color)
      local blend = 0.3  -- Color influence
      local r = math.floor(cr * 0.2 * blend + 20 * (1 - blend))
      local g = math.floor(cg * 0.2 * blend + 20 * (1 - blend))
      local b = math.floor(cb * 0.2 * blend + 20 * (1 - blend))
      star_color = Ark.Colors.components_to_rgba(r, g, b, is_star_hovered and 160 or 80)
    else
      star_color = is_star_hovered and hexrgb('#282828A0') or hexrgb('#18181850')
    end
  end

  -- Render star using remix icon font
  local star_char = utf8.char(0xF186)  -- Remix star-fill icon

  -- Use icon font if available in state
  if state.fonts and state.fonts.icons then
    local base_size = state.fonts.icons_size or 14

    ImGui.PushFont(ctx, state.fonts.icons, base_size)
    local text_w, text_h = ImGui.CalcTextSize(ctx, star_char)
    local star_text_x = star_x + (star_size - text_w) * 0.5
    local star_text_y = star_y + (star_size - text_h) * 0.5
    ImGui.DrawList_AddText(dl, star_text_x, star_text_y, star_color, star_char)
    ImGui.PopFont(ctx)
  else
    -- Fallback to Unicode star if no icon font
    local star_char_fallback = '★'
    local text_w, text_h = ImGui.CalcTextSize(ctx, star_char_fallback)
    local star_text_x = star_x + (star_size - text_w) * 0.5
    local star_text_y = star_y + (star_size - text_h) * 0.5
    Ark.Draw.text(dl, star_text_x, star_text_y, star_color, star_char_fallback)
  end

  -- Handle star click to toggle favorite
  if is_star_hovered and ImGui.IsMouseClicked(ctx, 0) then
    state.star_clicked = true
  end
end

return M
