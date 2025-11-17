-- @noindex
-- TemplateBrowser/ui/tiles/template_tile.lua
-- Template tile renderer using rearkitekt design system

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.core.colors')
local Draw = require('rearkitekt.gui.draw')
local TileFX = require('rearkitekt.gui.rendering.tile.renderer')
local TileFXConfig = require('rearkitekt.gui.rendering.tile.defaults')
local Chip = require('rearkitekt.gui.widgets.data.chip')
local MarchingAnts = require('rearkitekt.gui.fx.interactions.marching_ants')

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

-- Render template tile
function M.render(ctx, rect, template, state, metadata, animator)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local tile_w = x2 - x1
  local tile_h = y2 - y1

  -- Get template metadata
  local tmpl_meta = metadata and metadata.templates[template.uuid]
  local chip_color = tmpl_meta and tmpl_meta.chip_color

  -- Use neutral base color for tile, chip_color only affects stripes and chip
  local base_color = hexrgb("#2A2A2A")

  -- Animation tracking
  animator:track(template.uuid, 'hover', state.hover and 1.0 or 0.0, 12.0)
  local hover_factor = animator:get(template.uuid, 'hover')

  -- Configure visual effects with diagonal stripes if template has color
  local fx_config = TileFXConfig.override({
    fill_opacity = 0.4,
    fill_saturation = 0.6,
    fill_brightness = 0.7,
    gradient_intensity = 0.2,
    gradient_opacity = 0.6,
    specular_strength = state.hover and 0.3 or 0.15,
    specular_coverage = 0.3,
    inner_shadow_strength = 0.25,
    border_saturation = 1.0,
    border_brightness = 1.2,
    border_opacity = 0.7,
    border_thickness = 1.0,
    glow_strength = 0.0,  -- No glow (using marching ants instead)
    glow_layers = 0,
    stripe_enabled = chip_color ~= nil,  -- Enable stripes if template has color
    stripe_spacing = 10,
    stripe_thickness = 4,
    stripe_opacity = 0.04,
    ants_enabled = state.selected,  -- Marching ants for selection
    ants_replace_border = true,
    ants_thickness = 2,
    ants_dash = 8,
    ants_gap = 6,
    ants_speed = 20,
    ants_inset = 0,
    ants_alpha = 0xFF,
    rounding = 6,
  })

  -- Render base tile with stripe_color for diagonals (chip_color affects only stripes)
  TileFX.render_complete(dl, x1, y1, x2, y2, base_color, fx_config,
    state.selected, hover_factor, nil, nil, nil, nil, chip_color, chip_color ~= nil)

  -- Draw marching ants on selected tiles
  if state.selected and fx_config.ants_enabled then
    local ants_color = Colors.same_hue_variant(
      chip_color or base_color,
      fx_config.border_saturation,
      fx_config.border_brightness,
      fx_config.ants_alpha or 0xFF
    )
    local inset = fx_config.ants_inset or 0
    MarchingAnts.draw(
      dl,
      x1 + inset, y1 + inset, x2 - inset, y2 - inset,
      ants_color,
      fx_config.ants_thickness,
      fx_config.rounding,
      fx_config.ants_dash,
      fx_config.ants_gap,
      fx_config.ants_speed
    )
  end

  -- Calculate text alpha based on tile height
  local text_alpha = 255
  if tile_h < M.CONFIG.hide_path_below then
    text_alpha = math.floor(255 * (tile_h / M.CONFIG.hide_path_below))
  end

  -- Content positioning
  local content_x = x1 + M.CONFIG.text_margin
  local content_y = y1 + M.CONFIG.text_margin
  local content_w = tile_w - (M.CONFIG.text_margin * 2)

  -- Draw colored chip indicator if template has color
  if chip_color then
    local chip_x = content_x + M.CONFIG.chip_radius
    local chip_y = content_y + 10

    Chip.draw(ctx, {
      style = Chip.STYLE.INDICATOR,
      color = chip_color,
      draw_list = dl,
      x = chip_x,
      y = chip_y,
      radius = M.CONFIG.chip_radius,
      is_selected = state.selected,
      is_hovered = state.hover,
      show_glow = state.selected or state.hover,
      glow_layers = state.selected and 3 or 2,
      alpha_factor = text_alpha / 255,
    })

    content_x = content_x + (M.CONFIG.chip_radius * 2) + M.CONFIG.chip_spacing + 4
    content_w = content_w - (M.CONFIG.chip_radius * 2) - M.CONFIG.chip_spacing - 4
  end

  -- Template name
  local name_color = Colors.with_alpha(hexrgb("#FFFFFF"), text_alpha)
  if state.selected or state.hover then
    name_color = Colors.adjust_brightness(name_color, 1.2)
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
          style = Chip.STYLE.PILL,
          label = tag_name,
          color = tag_color,
          height = 18,
          padding_h = 8,
          is_selected = false,
          is_hovered = state.hover,
          interactive = false,
        })

        ImGui.SameLine(ctx, 0, 4)
      end
    end
  end
end

return M
