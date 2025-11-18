-- @noindex
-- Region_Playlist/ui/tiles/renderers/base.lua
-- MODIFIED: Dynamic index overflow - reserves space for 2 digits, extends right for 3+

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local Draw = require('rearkitekt.gui.draw')
local Colors = require('rearkitekt.core.colors')
local TileFX = require('rearkitekt.gui.rendering.tile.renderer')
local TileFXConfig = require('rearkitekt.gui.rendering.tile.defaults')
local MarchingAnts = require('rearkitekt.gui.fx.interactions.marching_ants')
local TileUtil = require('rearkitekt.gui.systems.tile_utilities')
local Chip = require('rearkitekt.gui.widgets.data.chip')

local M = {}
local hexrgb = Colors.hexrgb

M.CONFIG = {
  rounding = 6,
  badge_font_scale = 0.88,
  length_margin = 6,
  length_padding_x = 4,
  length_padding_y = 2,
  length_font_size = 0.82,
  length_offset_x = 5,  -- Additional offset from right edge
  playlist_chip_radius = 4,
  chip_offset = { x = 0, y = 0 },
  text_padding_left = 6,
  text_padding_top = 6,
  text_vertical_nudge_small_tiles = -3,
  vertical_center_threshold = 40,
  badge_vertical_center_threshold = 45,
  chip_vertical_center_threshold = 50,
  
  -- Dynamic index sizing: reserve space for 2 digits, overflow for 3+
  index_reserved_digits = 2,
  index_separator_spacing = 4,
}

-- Cache for reserved index width (calculated once per context)
local _reserved_index_width_cache = {}

-- ========================================
-- AUTOMATED TEXT OVERFLOW SYSTEM
-- ========================================

function M.calculate_right_elements_width(ctx, elements)
  local total_width = 0
  for _, element in ipairs(elements) do
    if element.visible then
      total_width = total_width + element.width + element.margin
    end
  end
  return total_width
end

function M.create_element(visible, width, margin)
  return {
    visible = visible,
    width = width,
    margin = margin or 0
  }
end

function M.calculate_text_right_bound(ctx, x2, text_margin, right_elements)
  local right_occupied = M.calculate_right_elements_width(ctx, right_elements)
  return x2 - text_margin - right_occupied
end

-- ========================================
-- UNIFIED POSITIONING SYSTEM
-- ========================================

function M.calculate_text_position(ctx, rect, actual_height, text_sample)
  local x1, y1 = rect[1], rect[2]
  local text_height = ImGui.CalcTextSize(ctx, text_sample or "Tg")
  
  local x = x1 + M.CONFIG.text_padding_left
  local y
  
  if actual_height < M.CONFIG.vertical_center_threshold then
    y = y1 + (actual_height - text_height) / 2 + M.CONFIG.text_vertical_nudge_small_tiles
  else
    y = y1 + M.CONFIG.text_padding_top
  end
  
  return { x = x, y = y }
end

function M.calculate_badge_position(ctx, rect, badge_height, actual_height)
  local y1 = rect[2]
  
  if actual_height < M.CONFIG.badge_vertical_center_threshold then
    return y1 + (actual_height - badge_height) / 2
  else
    return y1 + 6
  end
end

function M.calculate_chip_position(ctx, rect, text_height, actual_height)
  local y1 = rect[2]
  
  if actual_height < M.CONFIG.chip_vertical_center_threshold then
    return y1 + (actual_height / 2) + M.CONFIG.chip_offset.y
  else
    local text_y
    if actual_height < M.CONFIG.vertical_center_threshold then
      text_y = y1 + (actual_height - text_height) / 2 + M.CONFIG.text_vertical_nudge_small_tiles
    else
      text_y = y1 + M.CONFIG.text_padding_top
    end
    return text_y + (text_height / 2) + M.CONFIG.chip_offset.y
  end
end

-- ========================================
-- DYNAMIC INDEX WIDTH CALCULATION
-- ========================================

local function get_reserved_index_width(ctx)
  local ctx_ptr = tostring(ctx)
  if _reserved_index_width_cache[ctx_ptr] then
    return _reserved_index_width_cache[ctx_ptr]
  end
  
  local max_digits = M.CONFIG.index_reserved_digits
  local reserved_str = string.rep("9", max_digits)
  local width = ImGui.CalcTextSize(ctx, reserved_str)
  
  _reserved_index_width_cache[ctx_ptr] = width
  return width
end

-- ========================================
-- TEXT TRUNCATION
-- ========================================

local function truncate_text(ctx, text, max_width)
  if not text or max_width <= 0 then return "" end
  local text_width = ImGui.CalcTextSize(ctx, text)
  if text_width <= max_width then return text end
  local ellipsis = "..."
  local ellipsis_width = ImGui.CalcTextSize(ctx, ellipsis)
  if max_width <= ellipsis_width then return "" end
  local available_width = max_width - ellipsis_width
  for i = #text, 1, -1 do
    local truncated = text:sub(1, i)
    if ImGui.CalcTextSize(ctx, truncated) <= available_width then
      return truncated .. ellipsis
    end
  end
  return ellipsis
end
M.truncate_text = truncate_text

-- ========================================
-- TILE RENDERING FUNCTIONS
-- ========================================

function M.draw_base_tile(dl, rect, base_color, fx_config, state, hover_factor, playback_progress, playback_fade, override_color)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local border_color = override_color or base_color
  local progress_color = override_color or base_color
  local stripe_color = override_color
  local stripe_enabled = (override_color ~= nil) and fx_config.stripe_enabled
  TileFX.render_complete(dl, x1, y1, x2, y2, base_color, fx_config, state.selected, hover_factor, playback_progress or 0, playback_fade or 0, border_color, progress_color, stripe_color, stripe_enabled)
end

function M.draw_marching_ants(dl, rect, color, fx_config)
  local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
  local ants_color = Colors.same_hue_variant(color, fx_config.border_saturation, fx_config.border_brightness, fx_config.ants_alpha or 0xFF)
  local inset = fx_config.ants_inset or 0
  MarchingAnts.draw(dl, x1 + inset, y1 + inset, x2 - inset, y2 - inset, ants_color,
    fx_config.ants_thickness or 1, M.CONFIG.rounding, fx_config.ants_dash, fx_config.ants_gap, fx_config.ants_speed)
end

function M.draw_region_text(ctx, dl, pos, region, base_color, text_alpha, right_bound_x, grid, rect, item_key_override)
  local fx_config = TileFXConfig.get()
  local accent_color = Colors.with_alpha(Colors.same_hue_variant(base_color, fx_config.index_saturation, fx_config.index_brightness, 0xFF), text_alpha)
  local name_color = Colors.with_alpha(Colors.adjust_brightness(fx_config.name_base_color, fx_config.name_brightness), text_alpha)

  local index_str = string.format("%d", region.rid)
  local name_str = region.name or "Unknown"
  local separator = " "

  -- Calculate widths
  local reserved_width = get_reserved_index_width(ctx)
  local index_w = ImGui.CalcTextSize(ctx, index_str)
  local sep_w = ImGui.CalcTextSize(ctx, separator)

  -- Determine if index overflows reserved space
  local overflow = math.max(0, index_w - reserved_width)

  -- Index shifts RIGHT when it overflows, title shifts by same amount
  local index_start_x = pos.x + overflow + (reserved_width - index_w)
  Draw.text(dl, index_start_x, pos.y, accent_color, index_str)

  -- Separator position: shifts right by overflow amount
  local separator_x = pos.x + reserved_width + M.CONFIG.index_separator_spacing + overflow
  local separator_color = Colors.with_alpha(Colors.same_hue_variant(base_color, fx_config.separator_saturation, fx_config.separator_brightness, fx_config.separator_alpha), text_alpha)
  Draw.text(dl, separator_x, pos.y, separator_color, separator)

  -- Name starts after separator (also shifted by overflow)
  local name_start_x = separator_x + sep_w
  local name_width = right_bound_x - name_start_x

  -- Check if inline editing mode (if grid is provided)
  if grid and rect then
    local GridInput = require('rearkitekt.gui.widgets.containers.grid.input')
    -- Use override key if provided, otherwise try to get from grid.key function
    local item_key = item_key_override or (grid.key and grid.key(region)) or region.rid
    local is_editing, edited_text = GridInput.handle_inline_edit_input(grid, ctx, item_key,
      {name_start_x, rect[2], right_bound_x, rect[4]}, name_str, base_color)

    if is_editing then
      -- Don't draw text while editing (InputText is drawn instead)
      return
    end
  end

  local truncated_name = truncate_text(ctx, name_str, name_width)
  Draw.text(dl, name_start_x, pos.y, name_color, truncated_name)
end

function M.draw_playlist_text(ctx, dl, pos, playlist_data, state, text_alpha, right_bound_x, name_color_override, actual_height, rect, grid, base_color, item_key_override)
  local fx_config = TileFXConfig.get()

  local text_height = ImGui.CalcTextSize(ctx, "Tg")

  -- Calculate chip position
  local reserved_width = get_reserved_index_width(ctx)
  local chip_x = pos.x + (reserved_width / 2) + M.CONFIG.chip_offset.x
  local chip_center_y
  if actual_height and rect then
    chip_center_y = M.calculate_chip_position(ctx, rect, text_height, actual_height)
  else
    chip_center_y = pos.y + (text_height / 2) + M.CONFIG.chip_offset.y
  end

  Chip.draw(ctx, {
    style = Chip.STYLE.INDICATOR,
    color = playlist_data.chip_color,
    draw_list = dl,
    x = chip_x,
    y = chip_center_y,
    radius = M.CONFIG.playlist_chip_radius,
    is_selected = state.selected,
    is_hovered = state.hover,
    show_glow = state.selected or state.hover,
    glow_layers = 2,
    alpha_factor = text_alpha / 255,
  })

  local name_color
  if name_color_override then
    name_color = Colors.with_alpha(name_color_override, text_alpha)
  else
    name_color = Colors.with_alpha(Colors.adjust_brightness(fx_config.name_base_color, fx_config.name_brightness), text_alpha)
    if state.hover or state.selected then
      name_color = Colors.with_alpha(hexrgb("#FFFFFF"), text_alpha)
    end
  end

  -- Name starts after reserved space + spacing
  local name_start_x = pos.x + reserved_width + M.CONFIG.index_separator_spacing
  local name_width = right_bound_x - name_start_x
  local name_str = playlist_data.name

  -- Check if inline editing mode (if grid is provided)
  if grid and rect then
    local GridInput = require('rearkitekt.gui.widgets.containers.grid.input')
    -- Use override key if provided, otherwise try to get from grid.key function
    local item_key = item_key_override or (grid.key and grid.key(playlist_data)) or playlist_data.id
    -- Use chip color for inline editing if available, otherwise use base_color
    local edit_color = playlist_data.chip_color or base_color
    local is_editing, edited_text = GridInput.handle_inline_edit_input(grid, ctx, item_key,
      {name_start_x, rect[2], right_bound_x, rect[4]}, name_str, edit_color)

    if is_editing then
      -- Don't draw text while editing (InputText is drawn instead)
      return
    end
  end

  local truncated_name = truncate_text(ctx, name_str, name_width)
  Draw.text(dl, name_start_x, pos.y, name_color, truncated_name)
end

function M.draw_length_display(ctx, dl, rect, region, base_color, text_alpha)
  local x2, y2 = rect[3], rect[4]
  local height_factor = math.min(1.0, math.max(0.0, ((y2 - rect[2]) - 20) / (72 - 20)))
  local fx_config = TileFXConfig.get()

  local length_str = TileUtil.format_bar_length(region.start, region["end"], 0)
  local scaled_margin = M.CONFIG.length_margin * (0.3 + 0.7 * height_factor)

  -- Measure text at actual draw size (ReaImGui draws at full font size)
  local length_w, length_h = ImGui.CalcTextSize(ctx, length_str)

  -- Right-aligned: longer text extends left, position stays fixed relative to right edge
  local length_x = x2 - length_w - scaled_margin - M.CONFIG.length_offset_x
  local length_y = y2 - length_h - scaled_margin

  local length_color = Colors.same_hue_variant(base_color, fx_config.duration_saturation, fx_config.duration_brightness, fx_config.duration_alpha)
  length_color = Colors.with_alpha(length_color, text_alpha)

  Draw.text(dl, length_x, length_y, length_color, length_str)
end

function M.draw_playlist_length_display(ctx, dl, rect, playlist_data, base_color, text_alpha)
  local x2, y2 = rect[3], rect[4]
  local height_factor = math.min(1.0, math.max(0.0, ((y2 - rect[2]) - 20) / (72 - 20)))
  local fx_config = TileFXConfig.get()

  -- Use total_duration from playlist_data (in seconds, same as regions)
  local total_duration_seconds = playlist_data.total_duration or 0

  -- Format using TileUtil.format_bar_length (same as regions)
  -- Pass 0 as start and total_duration as end to get the duration formatted
  local length_str = TileUtil.format_bar_length(0, total_duration_seconds, 0)

  local scaled_margin = M.CONFIG.length_margin * (0.3 + 0.7 * height_factor)

  -- Measure text at actual draw size (ReaImGui draws at full font size)
  local length_w, length_h = ImGui.CalcTextSize(ctx, length_str)

  -- Right-aligned: longer text extends left, position stays fixed relative to right edge
  local length_x = x2 - length_w - scaled_margin - M.CONFIG.length_offset_x
  local length_y = y2 - length_h - scaled_margin

  -- Use chip color for playlist length display (same as region tiles use region color)
  local color_source = playlist_data.chip_color or base_color
  local length_color = Colors.same_hue_variant(color_source, fx_config.duration_saturation, fx_config.duration_brightness, fx_config.duration_alpha)
  length_color = Colors.with_alpha(length_color, text_alpha)

  Draw.text(dl, length_x, length_y, length_color, length_str)
end

return M
