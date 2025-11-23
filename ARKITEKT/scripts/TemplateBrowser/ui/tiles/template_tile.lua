-- @noindex
-- TemplateBrowser/ui/tiles/template_tile.lua
-- Template tile renderer using arkitekt design system

local ImGui = require 'imgui' '0.10'
local Colors = require('arkitekt.core.colors')
local Draw = require('arkitekt.gui.draw')
local Chip = require('arkitekt.gui.widgets.data.chip')
local MarchingAnts = require('arkitekt.gui.fx.interactions.marching_ants')
local Badge = require('arkitekt.gui.widgets.primitives.badge')
local Defaults = require('TemplateBrowser.defs.defaults')

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

-- Strip parenthetical content from VST name for display
-- e.g., "Kontakt (Native Instruments)" -> "Kontakt"
local function strip_parentheses(name)
  if not name then return "" end
  local stripped = name:gsub("%s*%b()", ""):gsub("^%s+", ""):gsub("%s+$", "")
  -- Return original if stripping would leave nothing
  return stripped ~= "" and stripped or name
end

-- Check if VST name is in the tile blacklist
local function is_blacklisted(name)
  if not name then return false end
  local blacklist = Defaults.VST and Defaults.VST.tile_blacklist or {}
  for _, blocked in ipairs(blacklist) do
    if name:find(blocked, 1, true) then
      return true
    end
  end
  return false
end

-- Get first non-blacklisted VST from fx list
local function get_display_vst(fx_list)
  if not fx_list or #fx_list == 0 then return nil end
  for _, fx_name in ipairs(fx_list) do
    if not is_blacklisted(fx_name) then
      return fx_name
    end
  end
  return nil  -- All VSTs are blacklisted
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

  -- Show first VST chip below title (where path used to be)
  local first_vst = get_display_vst(template.fx)
  if tile_h >= M.CONFIG.hide_chips_below and first_vst then
    local chip_y = content_y + 18
    local chip_x = content_x

    -- Strip parenthetical content for display (e.g., "Kontakt (Native Instruments)" -> "Kontakt")
    local display_vst = strip_parentheses(first_vst)

    -- Calculate max width for chip (leave room for favorite badge and margin)
    local max_chip_width = content_w - 40

    -- Truncate VST name if it's too long
    local text_width = ImGui.CalcTextSize(ctx, display_vst)
    local chip_content_width = 16  -- padding on both sides (8 + 8)
    if text_width + chip_content_width > max_chip_width then
      -- Truncate with ellipsis
      local available_width = max_chip_width - chip_content_width - ImGui.CalcTextSize(ctx, "...")
      display_vst = truncate_text(ctx, display_vst, available_width)
      text_width = ImGui.CalcTextSize(ctx, display_vst)
    end

    -- Use DrawList directly to avoid cursor position issues
    local chip_w = text_width + chip_content_width
    local chip_h = 20

    -- Background (dark grey with 80% transparency)
    local chip_bg = hexrgb("#3A3A3ACC")
    ImGui.DrawList_AddRectFilled(dl, chip_x, chip_y, chip_x + chip_w, chip_y + chip_h, chip_bg, 2)

    -- Text (centered, white)
    local _, actual_text_height = ImGui.CalcTextSize(ctx, display_vst)
    local text_x = chip_x + (chip_w - text_width) * 0.5
    local text_y = chip_y + math.floor((chip_h - actual_text_height) * 0.5)
    local text_color = hexrgb("#FFFFFF")
    Draw.text(dl, text_x, text_y, text_color, display_vst)
  end

  -- Template path at bottom right (if height allows)
  if tile_h >= M.CONFIG.hide_path_below and template.relative_path ~= "" then
    local path_alpha = math.floor(text_alpha * 0.6)
    local path_color = Colors.with_alpha(hexrgb("#A0A0A0"), path_alpha)
    local path_text = "[" .. template.folder .. "]"
    local path_width = ImGui.CalcTextSize(ctx, path_text)
    local truncated_path = truncate_text(ctx, path_text, content_w - 30)  -- Leave room for star
    local actual_path_width = ImGui.CalcTextSize(ctx, truncated_path)
    local path_x = x2 - padding - actual_path_width
    local path_y = y2 - padding - 14  -- 14 is approx text height
    Draw.text(dl, path_x, path_y, path_color, truncated_path)
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
    star_color = hexrgb("#E8E8E8")  -- Light grey when enabled
  else
    -- Darker when disabled, with subtle color influence if tile has color
    if chip_color then
      local cr, cg, cb = Colors.rgba_to_components(chip_color)
      local blend = 0.3  -- Color influence
      local r = math.floor(cr * 0.2 * blend + 20 * (1 - blend))
      local g = math.floor(cg * 0.2 * blend + 20 * (1 - blend))
      local b = math.floor(cb * 0.2 * blend + 20 * (1 - blend))
      star_color = Colors.components_to_rgba(r, g, b, is_star_hovered and 160 or 80)
    else
      star_color = is_star_hovered and hexrgb("#282828A0") or hexrgb("#18181850")
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
