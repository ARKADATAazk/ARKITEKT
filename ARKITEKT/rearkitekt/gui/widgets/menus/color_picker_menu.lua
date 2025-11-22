-- @noindex
-- rearkitekt/gui/widgets/menus/color_picker_menu.lua
-- Reusable color picker for context menus with Chip rendering

local ImGui = require 'imgui' '0.10'
local Colors = require('rearkitekt.defs.colors')
local ColorUtils = require('rearkitekt.core.colors')
local Chip = require('rearkitekt.gui.widgets.data.chip')

local hexrgb = ColorUtils.hexrgb

local M = {}

-- Default configuration
local DEFAULTS = {
  chip_radius = 7,
  columns = 4,
  show_none_option = true,
  none_label = "Remove Color",
}

-- =============================================================================
-- MAIN RENDER FUNCTION
-- =============================================================================

--- Render a color picker grid in a context menu using Chip components
-- @param ctx ImGui context
-- @param opts Options table:
--   - on_select: function(color_int, color_hex, color_name) - called when color is selected
--   - current_color: number - integer color value of currently selected color (optional)
--   - palette: table - custom palette (optional, defaults to Colors.PALETTE)
--   - chip_radius: number - radius of color chips (optional)
--   - columns: number - number of columns (optional)
--   - show_none_option: boolean - show "Remove Color" option (optional)
--   - none_label: string - label for none option (optional)
-- @return boolean - true if a color was selected
function M.render(ctx, opts)
  opts = opts or {}
  local palette = opts.palette or Colors.PALETTE
  local chip_radius = opts.chip_radius or DEFAULTS.chip_radius
  local columns = opts.columns or DEFAULTS.columns
  local show_none = opts.show_none_option == nil and DEFAULTS.show_none_option or opts.show_none_option
  local none_label = opts.none_label or DEFAULTS.none_label

  local selected = false
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Draw separator line at top
  ImGui.Dummy(ctx, 1, 4)
  local sep_x1, sep_y1 = ImGui.GetCursorScreenPos(ctx)
  local sep_w = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddLine(dl, sep_x1 + 8, sep_y1, sep_x1 + sep_w - 8, sep_y1, hexrgb("#505050FF"), 1)
  ImGui.Dummy(ctx, 1, 18)

  -- Calculate grid layout
  local menu_width = ImGui.GetContentRegionAvail(ctx)
  local menu_start_x, menu_start_y = ImGui.GetCursorScreenPos(ctx)

  -- Narrowed horizontal bounds
  local item_padding_x = 21
  local available_width = menu_width - (item_padding_x * 2)
  local chip_spacing = available_width / (columns - 1)
  local grid_offset_x = item_padding_x

  -- Convert palette to integer colors
  local preset_colors = {}
  for i, color in ipairs(palette) do
    preset_colors[i] = hexrgb(color.hex)
  end

  -- Draw color chips
  for i, color in ipairs(preset_colors) do
    local col_idx = (i - 1) % columns
    local row_idx = math.floor((i - 1) / columns)

    local chip_cx = menu_start_x + grid_offset_x + col_idx * chip_spacing
    local chip_cy = menu_start_y + row_idx * chip_spacing
    local hit_size = chip_radius * 2 + 4

    -- Check if this is the current color
    local is_selected = (opts.current_color and opts.current_color == color)

    -- Make it clickable
    local hit_x = chip_cx - hit_size * 0.5
    local hit_y = chip_cy - hit_size * 0.5
    ImGui.SetCursorScreenPos(ctx, hit_x, hit_y)
    if ImGui.InvisibleButton(ctx, "##color_" .. i, hit_size, hit_size) then
      if opts.on_select then
        local color_hex = palette[i].hex
        local color_name = palette[i].name
        opts.on_select(color, color_hex, color_name)
      end
      selected = true
    end
    local is_hovered = ImGui.IsItemHovered(ctx)

    -- Draw chip with glow effects
    Chip.draw(ctx, {
      style = Chip.STYLE.INDICATOR,
      shape = Chip.SHAPE.CIRCLE,
      color = color,
      draw_list = dl,
      x = chip_cx,
      y = chip_cy,
      radius = chip_radius,
      is_selected = is_selected,
      is_hovered = is_hovered,
      show_glow = is_selected or is_hovered,
      glow_layers = is_selected and 6 or 3,
      shadow = true,
      border = is_hovered,
      border_color = hexrgb("#FFFFFF80"),
      border_thickness = 1.0,
    })
  end

  -- Calculate grid height and move cursor past it
  local grid_rows = math.ceil(#preset_colors / columns)
  local grid_height = (grid_rows - 1) * chip_spacing + chip_radius * 2
  ImGui.SetCursorScreenPos(ctx, menu_start_x, menu_start_y + grid_height + 8)

  -- Draw separator before "Remove Color" button
  ImGui.Dummy(ctx, 1, 4)
  local sep_x2, sep_y2 = ImGui.GetCursorScreenPos(ctx)
  local sep_w2 = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddLine(dl, sep_x2 + 8, sep_y2, sep_x2 + sep_w2 - 8, sep_y2, hexrgb("#505050FF"), 1)
  ImGui.Dummy(ctx, 1, 6)

  -- "Remove Color" button
  if show_none then
    local button_text = opts.current_color and none_label or "No Color"
    local button_width = ImGui.GetContentRegionAvail(ctx)

    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + 8)
    if ImGui.Button(ctx, button_text, button_width - 16, 28) then
      if opts.on_select then
        opts.on_select(nil, nil, nil)
      end
      selected = true
    end
    ImGui.Dummy(ctx, 1, 4)
  end

  return selected
end

-- =============================================================================
-- SUBMENU HELPER
-- =============================================================================

--- Render a color picker as a submenu
-- @param ctx ImGui context
-- @param label string - menu label (e.g., "Assign Color")
-- @param opts Options table (same as render)
-- @return boolean - true if a color was selected
function M.submenu(ctx, label, opts)
  local selected = false

  if ImGui.BeginMenu(ctx, label) then
    selected = M.render(ctx, opts)
    ImGui.EndMenu(ctx)
  end

  return selected
end

return M
